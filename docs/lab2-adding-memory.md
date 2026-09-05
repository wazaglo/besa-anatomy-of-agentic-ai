# Lab 2: Add Memory to Your Agent

**Duration:** ~20 minutes
**Workshop Reference:** [Lab 2](https://catalog.workshops.aws/agentcore-getting-started/en-US/21-lab2-memory)

## Overview

Added AgentCore Memory so the agent retains facts across sessions. A returning customer gets recognized automatically without repeating themselves. After this lab, the agent remembers user names, preferences, and purchase history across sessions.

## How AgentCore Memory Works

AgentCore Memory provides two types:

| Type | Purpose | What It Does |
|---|---|---|
| **Short-term** | Raw conversation events | Stored within a session, retained for `eventExpiryDuration` (30 days) |
| **Long-term** | Extracted insights | Persists across sessions using strategies (SEMANTIC, SUMMARIZATION) |

### Strategies Used

| Strategy | Purpose | Namespace |
|---|---|---|
| **SEMANTIC** | Facts and context | `/users/{actorId}/facts` |
| **SUMMARIZATION** | Conversation history | `/summaries/{actorId}/{sessionId}` |

- **SEMANTIC** captures factual information (names, preferences, order details) and makes them retrievable across sessions
- **SUMMARIZATION** creates compressed conversation summaries for continuity

### Session Persistence vs Memory

Important distinction:

- **Session persistence**: AgentCore Runtime keeps conversation context alive within the same `session_id`. Wiped when runtime recycles idle microVMs.
- **AgentCore Memory**: Durable storage that survives runtime recycling. A brand-new session can still recall facts about the user.

The test in Step 5 deliberately uses a new session-id to prove recall is coming from Memory, not session persistence.

## What Was Added

### 1. Memory Resource in agentcore.json

```json
"memories": [
  {
    "name": "SharedMemory",
    "eventExpiryDuration": 30,
    "strategies": [
      {
        "type": "SEMANTIC",
        "namespaceTemplates": ["/users/{actorId}/facts"]
      },
      {
        "type": "SUMMARIZATION",
        "namespaceTemplates": ["/summaries/{actorId}/{sessionId}"]
      }
    ]
  }
]
```

### 2. Request Header Allowlist

Added `requestHeaderAllowlist` to the runtime config to allow the custom user ID header:

```json
"runtimes": [
  {
    "name": "CustomerSupport",
    "build": "CodeZip",
    "entrypoint": "main.py",
    "codeLocation": "app/CustomerSupport/",
    "runtimeVersion": "PYTHON_3_14",
    "networkMode": "PUBLIC",
    "protocol": "HTTP",
    "requestHeaderAllowlist": [
      "X-Amzn-Bedrock-AgentCore-Runtime-Custom-User-Id"
    ]
  }
]
```

This is required because the agent extracts `user_id` from this custom header. In Lab 4, this will be replaced with JWT token claims.

### 3. Memory Session Manager

Created `app/CustomerSupport/memory/session.py`:

```python
import os
from typing import Optional
from bedrock_agentcore.memory.integrations.strands.config import AgentCoreMemoryConfig, RetrievalConfig
from bedrock_agentcore.memory.integrations.strands.session_manager import AgentCoreMemorySessionManager

MEMORY_ID = os.getenv("MEMORY_SHAREDMEMORY_ID")
REGION = os.getenv("AWS_REGION")

def get_memory_session_manager(session_id: str, actor_id: str) -> Optional[AgentCoreMemorySessionManager]:
    if not MEMORY_ID:
        return None

    retrieval_config = {
        f"/users/{actor_id}/facts": RetrievalConfig(top_k=3, relevance_score=0.3),
        f"/summaries/{actor_id}/{session_id}": RetrievalConfig(top_k=3, relevance_score=0.3)
    }

    return AgentCoreMemorySessionManager(
        AgentCoreMemoryConfig(
            memory_id=MEMORY_ID,
            session_id=session_id,
            actor_id=actor_id,
            retrieval_config=retrieval_config,
        ),
        REGION
    )
```

**Key points:**
- `MEMORY_SHAREDMEMORY_ID` is injected as an environment variable by AgentCore Runtime after deployment
- Configures two retrieval namespaces: facts (SEMANTIC) and summaries (SUMMARIZATION)
- Returns `None` if not deployed (allows local development without memory)

### 4. Updated main.py

Key changes from Lab 1:

1. **Import memory session manager**
   ```python
   from memory.session import get_memory_session_manager
   ```

2. **Factory pattern** - create agents per session/user instead of single global agent
   ```python
   def get_or_create_agent(session_id, user_id):
       global _agent
       if _agent is None:
           _agent = Agent(
               model=load_model(),
               session_manager=get_memory_session_manager(session_id, user_id),
               system_prompt=SYSTEM_PROMPT,
               tools=tools
           )
       return _agent
   ```

3. **Extract session_id and user_id from runtime context**
   ```python
   @app.entrypoint
   async def invoke(payload, context):
       session_id = context.session_id
       user_id = context.request_headers['x-amzn-bedrock-agentcore-runtime-custom-user-id']
       # ...
   ```

## Testing

### Step 1: Teach the agent about you

```bash
SESSION_A=$(python3 -c 'import uuid; print(uuid.uuid4())')
agentcore invoke "My name is Sarah and I prefer email updates. I recently bought a Smart Watch." \
  --session-id $SESSION_A \
  -H "X-Amzn-Bedrock-AgentCore-Runtime-Custom-User-Id: Sarah" --stream
```

### Step 2: Wait for memory extraction

```bash
sleep 2m
```

### Step 3: Test cross-session recall

```bash
SESSION_B=$(python3 -c 'import uuid; print(uuid.uuid4())')
agentcore invoke "Do you know anything about me?" \
  --session-id $SESSION_B \
  -H "X-Amzn-Bedrock-AgentCore-Runtime-Custom-User-Id: Sarah" --stream
```

**Expected response:** Agent greets Sarah by name, recalls email preference and Smart Watch purchase.

### Step 4: Prove it survives runtime recycle (optional)

```bash
SESSION_C=$(python3 -c 'import uuid; print(uuid.uuid4())')
agentcore invoke "What's my name and how do I like to be contacted?" \
  --session-id $SESSION_C \
  -H "X-Amzn-Bedrock-AgentCore-Runtime-Custom-User-Id: Sarah" --stream
```

## What Each Strategy Captured

| What Happened | Strategy | Result |
|---|---|---|
| "My name is Sarah" | SEMANTIC | Extracted as fact: "The user's name is Sarah" |
| "I prefer email updates" | SEMANTIC | Extracted as fact: "Sarah prefers email updates" |
| Full conversation | SUMMARIZATION | Compressed summary stored for session continuity |

## Architecture

![Lab 2 Architecture](images/lab2_architecture_diagram.png)

The Lab 2 architecture adds **AgentCore Memory** to the runtime. The agent now has two memory namespaces: **SEMANTIC** (`/users/{actorId}/facts`) for durable facts like names and preferences, and **SUMMARIZATION** (`/summaries/{actorId}/{sessionId}`) for compressed conversation history. When a user sends a message, the runtime retrieves relevant memories and injects them into the agent's context before it reasons. The custom header `X-Amzn-Bedrock-AgentCore-Runtime-Custom-User-Id` identifies the user for memory scoping. This means a returning customer gets recognized automatically, the agent remembers their name, preferences, and past purchases across sessions, even after the runtime recycles.

## Files Modified

| File | Change |
|---|---|
| `agentcore/agentcore.json` | Added `SharedMemory` with SEMANTIC + SUMMARIZATION strategies, added `requestHeaderAllowlist` |
| `app/CustomerSupport/memory/__init__.py` | New file (package init) |
| `app/CustomerSupport/memory/session.py` | New file (memory session manager) |
| `app/CustomerSupport/main.py` | Updated to use memory session manager, factory pattern, extract user_id from header |

## Key Commands

```bash
# Add memory resource
agentcore add memory --name SharedMemory --strategies SEMANTIC,SUMMARIZATION --expiry 30

# Deploy with memory
agentcore deploy -y -v

# Test cross-session recall
SESSION_A=$(python3 -c 'import uuid; print(uuid.uuid4())')
agentcore invoke "My name is Sarah and I prefer email updates." \
  --session-id $SESSION_A \
  -H "X-Amzn-Bedrock-AgentCore-Runtime-Custom-User-Id: Sarah" --stream

sleep 2m

SESSION_B=$(python3 -c 'import uuid; print(uuid.uuid4())')
agentcore invoke "Do you know anything about me?" \
  --session-id $SESSION_B \
  -H "X-Amzn-Bedrock-AgentCore-Runtime-Custom-User-Id: Sarah" --stream
```

## What's Next

Lab 3 will expose an existing Lambda as an MCP-compatible tool through AgentCore Gateway, so the agent can discover and call it without owning the code.
