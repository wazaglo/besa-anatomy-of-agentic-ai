# Lab 6: Building the Customer Interface

**Duration:** ~20 minutes
**Workshop Reference:** [Lab 6](https://catalog.workshops.aws/agentcore-getting-started/en-US/25-lab6-interface)

## Overview

Built a web chat interface using Flask that connects to the deployed AgentCore Runtime. The server authenticates against Cognito on startup and serves a chat page where the browser talks directly to the AgentCore REST API. Customers can now interact with the agent without a terminal or bearer token.

## Architecture

```
User opens browser → Flask server
    ↓
Flask authenticates against Cognito (USER_PASSWORD_AUTH)
    ↓
Flask serves HTML with access token + runtime ARN injected
    ↓
User types message in chat
    ↓
Browser calls AgentCore REST API directly (Authorization: Bearer)
    ↓
AgentCore Runtime validates JWT → Agent processes request
    ↓
Agent uses tools (local + Gateway) and memory
    ↓
Streaming response returned to browser
```

## What Was Built

### 1. Flask Server (`frontend/frontend.py`)

- Authenticates against Cognito on startup using `USER_PASSWORD_AUTH`
- Reads runtime ARN from `agentcore/.cli/deployed-state.json`
- Reads Cognito client ID from SSM parameter store
- Serves a single HTML page with token, ARN, and region injected as template variables
- Disables caching for development iteration

### 2. Chat UI (`frontend/templates/index.html`)

Single-page chat interface that calls AgentCore REST API directly from the browser:
- Streaming SSE response parsing
- Session management with UUID generation
- Quick action buttons (Products, Returns, Warranty, Memory)
- New Session button to reset conversation context
- Responsive design with thinking animation

### 3. Dependencies Added

```bash
uv add flask boto3 requests
```

**Why not boto3 for API calls?** boto3's `invoke_agent_runtime` uses IAM (SigV4) authentication. When the runtime is configured for Custom JWT auth, you need to pass `Authorization: Bearer` directly, which boto3 doesn't support for this operation.

## Files Created

| File | Purpose |
|---|---|
| `app/CustomerSupport/frontend/__init__.py` | Package init |
| `app/CustomerSupport/frontend/frontend.py` | Flask server with Cognito auth |
| `app/CustomerSupport/frontend/templates/index.html` | Chat UI with AgentCore REST API integration |

## Setup & Run

### Enable USER_PASSWORD_AUTH on Cognito

```bash
COGNITO_POOL_ID=$(aws ssm get-parameter \
  --name /app/customersupport/agentcore/pool_id \
  --query 'Parameter.Value' --output text)

COGNITO_WEB_CLIENT_ID=$(aws ssm get-parameter \
  --name /app/customersupport/agentcore/web_client_id \
  --query 'Parameter.Value' --output text)

aws cognito-idp update-user-pool-client \
  --user-pool-id $COGNITO_POOL_ID \
  --client-id $COGNITO_WEB_CLIENT_ID \
  --explicit-auth-flows ALLOW_USER_PASSWORD_AUTH ALLOW_REFRESH_TOKEN_AUTH \
  --supported-identity-providers COGNITO \
  --allowed-o-auth-flows code \
  --allowed-o-auth-scopes openid email profile \
  --allowed-o-auth-flows-user-pool-client \
  --callback-urls "http://localhost:8501/" \
  --logout-urls "http://localhost:8501/" \
  --no-cli-pager
```

### Start the Frontend

```bash
cd app/CustomerSupport/frontend
uv run python frontend.py
```

**Expected output:**
```
✅ Authenticated as workshopuser@example.com
Runtime ARN: arn:aws:bedrock-agentcore:us-east-1:195675606509:runtime/CustomerSupport_CustomerSupport-xxxxx
 * Running on http://127.0.0.1:8501
```

Open `http://localhost:8501` in your browser.

## Testing

### Quick Actions

| Button | What It Tests |
|---|---|
| 🛒 Products | Product lookup (local tool) |
| ↩️ Returns | Return policy (local tool) |
| 🛡️ Warranty | Warranty check (Gateway → Lambda) |
| 🧠 Memory | Long-term memory recall |

### Session Continuity

1. Type "My name is Alex" → Agent acknowledges
2. Type "What's my name?" → Agent remembers "Alex"
3. Click 🔄 New Session → Ask "What's my name?" → Agent doesn't know (session reset)

### Key Behaviors

- **Same session:** Agent remembers conversation context
- **New session:** Conversation context resets, but long-term memory facts persist
- **Token injection:** Flask authenticates once on startup, token embedded in HTML
- **Direct API calls:** Browser calls AgentCore REST API. NOserver-side proxy

## Production Notes

For production use:
- Use Cognito Authorization Code flow with PKCE instead of hardcoded credentials
- Keep user tokens server-side (backend-for-frontend pattern)
- Do not use shared tokens across users

## Key Commands

```bash
# Add dependencies
cd app/CustomerSupport && uv add flask boto3 requests

# Enable USER_PASSWORD_AUTH
aws cognito-idp update-user-pool-client \
  --user-pool-id $COGNITO_POOL_ID \
  --client-id $COGNITO_WEB_CLIENT_ID \
  --explicit-auth-flows ALLOW_USER_PASSWORD_AUTH ALLOW_REFRESH_TOKEN_AUTH

# Run frontend
cd app/CustomerSupport/frontend
uv run python frontend.py
```

## What's Next

Lab 7 will add Cedar policy engine for governing agent actions (e.g., refund limits, tool restrictions).
