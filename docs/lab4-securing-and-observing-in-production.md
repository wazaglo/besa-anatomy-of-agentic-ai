# Lab 4: Securing and Observing in Production

**Duration:** ~30 minutes
**Workshop Reference:** [Lab 4](https://catalog.workshops.aws/agentcore-getting-started/en-US/23-lab4-secure-observe)

## Overview

Locked down the agent runtime with JWT authentication using Amazon Cognito, and explored observability features. The agent now validates incoming JWT tokens and extracts user identity from claims for memory access, replacing the custom header approach from earlier labs.

## Architecture

```
Client (JWT) → AgentCore Runtime (JWT validation) → Agent → Gateway → Lambda
                                ↓
                        User ID from JWT claims
                                ↓
                        Memory (per-user isolation)
```

## What Was Built

### 1. JWT Authentication Configuration

Updated `agentcore/agentcore.json` — added Cognito JWT authorizer to the runtime:

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
      "X-Amzn-Bedrock-AgentCore-Runtime-Custom-User-Id",
      "Authorization"
    ],
    "authorizerType": "CUSTOM_JWT",
    "authorizerConfiguration": {
      "customJwtAuthorizer": {
        "discoveryUrl": "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_qZ9eMpY7y/.well-known/openid-configuration",
        "allowedClients": ["5vot9313rbrhv7c1eo30r56bkc", "7ccc2kh61scnb5v90qkj8nt149"]
      }
    }
  }
]
```

**Key fields:**
- `requestHeaderAllowlist`: Includes `Authorization` so the JWT token reaches the agent
- `authorizerType`: `CUSTOM_JWT` — AgentCore Runtime validates the token before it reaches your code
- `discoveryUrl`: Cognito OIDC endpoint for fetching signing keys
- `allowedClients`: Restricts to tokens issued for specific Cognito app clients

### 2. JWT User ID Extraction

Updated `app/CustomerSupport/main.py` — added `extract_user_id()`:

```python
import jwt

def extract_user_id(context) -> str | None:
    """Extract user_id from JWT bearer token (username claim) or fall back to custom header."""
    headers = context.request_headers or {}

    # Try Authorization header first (Bearer JWT)
    auth_header = headers.get("Authorization") or headers.get("authorization")
    if auth_header and auth_header.startswith("Bearer "):
        try:
            token = auth_header.split(" ", 1)[1]
            claims = jwt.decode(token, options={"verify_signature": False})
            username = claims.get("username")
            if username:
                return username
        except Exception as e:
            log.warning(f"Failed to decode JWT for user_id: {e}")

    # Fall back to custom header
    return headers.get("x-amzn-bedrock-agentcore-runtime-custom-user-id")
```

**How it works:**
1. Checks `Authorization` header for Bearer JWT token
2. Decodes token (signature already verified by AgentCore Runtime)
3. Extracts `username` claim for memory isolation
4. Falls back to custom header if no JWT (backward compatible)

### 3. PyJWT Dependency

Added `pyjwt` to dependencies:

```bash
cd app/CustomerSupport
uv add pyjwt
```

### 4. PRODUCTS Data Updated

Restored `warranty_months` to PRODUCTS (previously removed in Lab 3) for local tool use:

```python
PRODUCTS = {
    "PROD-001": {"name": "Wireless Headphones", "price": 79.99, "category": "audio", "description": "...", "warranty_months": 12},
    # ...
}
```

Product info now returns warranty data locally as well.

## Request Flow

```
Client sends request with Authorization: Bearer <JWT>
    ↓
AgentCore Runtime validates JWT against Cognito JWKS
    ↓
Runtime forwards decoded headers to agent
    ↓
extract_user_id() reads username from JWT claims
    ↓
Agent uses user_id for memory session isolation
    ↓
Response returned to client
```

## Testing

### Get a JWT token

```bash
# Get tokens from Cognito
TOKEN=$(aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id <COGNITO_CLIENT_ID> \
  --auth-username <username> \
  --auth-password <password> \
  --query 'AuthenticationResult.AccessToken' \
  --output text)
```

### Test with JWT

```bash
SESSION_C=$(python3 -c "import uuid; print(uuid.uuid4())")
agentcore invoke "Check the warranty for product PROD-003" \
  --session-id $SESSION_C \
  -H "Authorization: Bearer $TOKEN" --stream
```

### Test without JWT (backward compatible)

```bash
agentcore invoke "Check the warranty for product PROD-003" \
  --session-id $SESSION_C \
  -H "X-Amzn-Bedrock-AgentCore-Runtime-Custom-User-Id: Sarah" --stream
```

## Security Model

| Layer | Protection |
|---|---|
| AgentCore Runtime | JWT validation (signature, issuer, audience) |
| `allowedClients` | Restricts to specific Cognito app clients |
| `requestHeaderAllowlist` | Controls which headers reach agent code |
| `extract_user_id()` | Maps JWT claims to memory user_id |
| Memory isolation | Per-user session/semantic memory |

## Files Modified

| File | Change |
|---|---|
| `agentcore/agentcore.json` | Added `Authorization` to allowlist, `authorizerType`, `authorizerConfiguration` |
| `app/CustomerSupport/main.py` | Added `import jwt`, `extract_user_id()`, restored `warranty_months` to PRODUCTS |
| `app/CustomerSupport/pyproject.toml` | Added `pyjwt` dependency |

## Key Commands

```bash
# Add PyJWT
cd app/CustomerSupport && uv add pyjwt

# Deploy with auth
agentcore deploy -y -v

# Test with JWT
agentcore invoke "Check warranty for PROD-003" \
  --session-id $SESSION_C \
  -H "Authorization: Bearer $TOKEN" --stream

# Test backward compatible
agentcore invoke "Check warranty for PROD-003" \
  --session-id $SESSION_C \
  -H "X-Amzn-Bedrock-AgentCore-Runtime-Custom-User-Id: Sarah" --stream
```

## What's Next

Lab 5 will evaluate agent quality using built-in evaluators and custom metrics.
