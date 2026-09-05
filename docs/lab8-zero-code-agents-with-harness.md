# Lab 8: Zero-Code Agents with AgentCore Harness

**Duration:** ~25 minutes
**Workshop Reference:** [Lab 8](https://catalog.workshops.aws/agentcore-getting-started/en-US/27-lab8-harness)

## Overview

Created a fully functional "Order Research Agent" using only CLI configuration. NOPython code. AgentCore Harness is a zero-code, declarative way to create and deploy agents. Connected it to the existing secured Gateway with Cedar policies, and built a human-in-the-loop approval flow using inline functions.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    AgentCore Platform                        │
│                                                              │
│  ┌──────────────────┐     ┌──────────────────┐             │
│  │ CustomerSupport   │     │ OrderResearchAgent│             │
│  │ (Python Runtime)  │     │ (Zero-Code Harness)│            │
│  └────────┬─────────┘     └────────┬─────────┘             │
│           │                         │                        │
│           └─────────┬───────────────┘                        │
│                     │                                        │
│           ┌─────────▼─────────┐                             │
│           │ my-gateway-secure │                             │
│           │ (Cedar Policies)  │                             │
│           └─────────┬─────────┘                             │
│                     │                                        │
│           ┌─────────▼─────────┐                             │
│           │ WarrantyCheck     │                             │
│           │ ProcessRefund     │                             │
│           └───────────────────┘                             │
└─────────────────────────────────────────────────────────────┘
```

Both agents share the same Gateway, tools, and governance policies. Cedar policies apply uniformly regardless of which agent calls the tools.

## What Was Built

### 1. Harness Agent (Zero-Code)

```bash
agentcore add harness \
  --name OrderResearchAgent \
  --model-provider bedrock \
  --model-id us.anthropic.claude-sonnet-4-6 \
  --system-prompt "You are an order research specialist..." \
  --tools agentcore_code_interpreter
```

Creates `app/OrderResearchAgent/harness.json` - the entire agent defined declaratively.

### 2. OAuth Credential Provider

The harness has no inbound user token to forward, so it needs its own Cognito token via `client_credentials`:

```bash
agentcore add credential --type oauth --name gateway-egress-oauth \
  --discovery-url "$COGNITO_DISCOVERY_URL" \
  --client-id "$COGNITO_MACHINE_CLIENT_ID" \
  --client-secret "$COGNITO_MACHINE_SECRET" \
  --scopes "$COGNITO_SCOPE"
```

### 3. Gateway Tool with Outbound Auth

```bash
agentcore add tool --harness OrderResearchAgent --type agentcore_gateway \
  --name my-gateway-secure \
  --gateway-arn "$GATEWAY_ARN" \
  --outbound-auth oauth \
  --provider-arn "$PROVIDER_ARN" \
  --scopes "$COGNITO_SCOPE" \
  --grant-type CLIENT_CREDENTIALS
```

### 4. Inline Function (Human-in-the-Loop)

```bash
agentcore add tool --harness OrderResearchAgent --type inline_function \
  --name approve_exception \
  --description "Request manager approval for a refund that exceeds the automated limit." \
  --input-schema '{"type":"object","properties":{...}}'
```

The agent pauses when it calls this tool, returns control to the caller, and resumes with the result.

## Testing

### Basic Invocation

```bash
SESSION=$(uuidgen)
agentcore invoke --harness OrderResearchAgent \
  --session-id "$SESSION" \
  --actor-id "analyst-1" \
  "Check the warranty for PROD-001 and PROD-003. Save a comparison report to /tmp/warranty_report.md"
```

### Shell Access (--exec)

```bash
agentcore invoke --exec --harness OrderResearchAgent \
  --session-id "$SESSION" \
  "cat /tmp/warranty_report.md"

agentcore invoke --exec --harness OrderResearchAgent \
  --session-id "$SESSION" \
  "python3 --version && ls -la /tmp/"
```

### Filesystem Persistence

```bash
agentcore invoke --harness OrderResearchAgent \
  --session-id "$SESSION" \
  --actor-id "analyst-1" \
  "Read the report at /tmp/warranty_report.md and add a recommendation section."
```

### Model Override Per Invocation

```bash
agentcore invoke --harness OrderResearchAgent \
  --model-id us.amazon.nova-2-lite-v1:0 \
  --session-id "$SESSION" \
  --actor-id "analyst-1" \
  "Summarize the warranty report in exactly 3 bullet points."
```

### Policy Enforcement

```bash
agentcore invoke --harness OrderResearchAgent \
  --session-id "$(uuidgen)" \
  --actor-id "analyst-1" \
  'Process a refund of $500 for order ORD-12345 because the customer is unhappy.'
```

**Expected:** Denied by Cedar policy (amount ≥ 100).

### Human-in-the-Loop Test

```bash
export HARNESS_ARN=$(aws bedrock-agentcore-control list-harnesses \
  --query "harnesses[?contains(harnessName, 'OrderResearchAgent')].arn | [0]" \
  --output text)

app/CustomerSupport/.venv/bin/python app/OrderResearchAgent/test_hitl.py
```

**Flow:**
1. Agent tries `process_refund` → Cedar blocks (amount ≥ 100)
2. Agent calls `approve_exception` → harness pauses
3. Script prompts for approval → you type "yes"
4. Script resumes with approval → agent provides summary

## Files Created

| File | Purpose |
|---|---|
| `app/OrderResearchAgent/harness.json` | Declarative agent config |
| `app/OrderResearchAgent/test_hitl.py` | HITL test script (boto3 invoke_harness) |

## Key Concepts

| Concept | Description |
|---|---|
| **Harness** | Zero-code agent defined declaratively |
| **Inline Function** | Tool that pauses agent, returns control to caller |
| **Outbound Auth** | OAuth credential for harness to authenticate to Gateway |
| **Shell Access** | `--exec` flag runs commands in harness microVM |
| **Filesystem Persistence** | Files persist within a session across invocations |
| **Model Override** | Change model per invocation without redeploying |

## Key Commands

```bash
# Create harness
agentcore add harness --name OrderResearchAgent \
  --model-provider bedrock --model-id us.anthropic.claude-sonnet-4-6 \
  --system-prompt "..." --tools agentcore_code_interpreter

# Add gateway tool with OAuth
agentcore add tool --harness OrderResearchAgent --type agentcore_gateway \
  --name my-gateway-secure --gateway-arn "$GATEWAY_ARN" \
  --outbound-auth oauth --provider-arn "$PROVIDER_ARN" \
  --scopes "$COGNITO_SCOPE" --grant-type CLIENT_CREDENTIALS

# Add inline function
agentcore add tool --harness OrderResearchAgent --type inline_function \
  --name approve_exception --description "..." --input-schema '...'

# Deploy
agentcore deploy -y -v

# Test
agentcore invoke --harness OrderResearchAgent --session-id "$SESSION" \
  --actor-id "analyst-1" "Check warranty for PROD-001"
```

## What's Next

Lab 9 will optimize agent quality from real traces.

## Bonus: Additional Harness Agents

### PersistentReportAgent

A harness with persistent session storage using an EFS-mounted volume:

```json
{
  "name": "PersistentReportAgent",
  "model": { "provider": "bedrock", "modelId": "us.anthropic.claude-sonnet-4-6" },
  "systemPrompt": "You are a report writer. Save all reports to /mnt/reports/ for persistent storage.",
  "tools": [{ "type": "agentcore_code_interpreter", "name": "code-interpreter" }],
  "skills": [],
  "memory": { "mode": "disabled" },
  "sessionStorage": "/mnt/reports/"
}
```

Files saved to `/mnt/reports/` persist across invocations within the same session, useful for multi-turn report generation workflows.

### ContainerAgent

A harness running in a Docker container with custom system tools:

```json
{
  "name": "ContainerAgent",
  "model": { "provider": "bedrock", "modelId": "us.anthropic.claude-sonnet-4-6" },
  "systemPrompt": "You are a development assistant with access to git and node.",
  "tools": [{ "type": "agentcore_code_interpreter", "name": "code-interpreter" }],
  "skills": [],
  "memory": { "mode": "disabled" },
  "container": "public.ecr.aws/docker/library/node:slim"
}
```

The `container` field specifies a custom Docker image. The agent runs in a containerized microVM with `git` and `node` available, useful for dev-tooling agents.

### Deploying All Harnesses

All three harnesses (OrderResearchAgent, PersistentReportAgent, ContainerAgent) deploy simultaneously:

```bash
agentcore deploy -y -v
```

Each harness gets its own isolated runtime, IAM role, and execution environment.
