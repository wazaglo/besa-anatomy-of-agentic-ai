# Lab 9: Optimizing Agent Quality

**Duration:** ~30 minutes
**Workshop Reference:** [Lab 9](https://catalog.workshops.aws/agentcore-getting-started/en-US/28-lab9-recommendations)

## Overview

Completed the observe-evaluate-improve loop: generated AI-driven optimization recommendations from real traces, packaged them into Configuration Bundles, and validated improvements with A/B testing — all without redeploying code.

## How the Optimization Loop Works

```
1. Generate a recommendation   → point the service at traces + a target evaluator
                                  → get an optimized system prompt or tool descriptions
2. Package as a config bundle   → a versioned, immutable snapshot of the config
3. Validate with an A/B test    → split live traffic (control vs treatment) via Gateway
                                  → online evaluation scores each session
4. Promote the winner & repeat  → route 100% of traffic to the winner
                                  → new traces become the baseline for the next round
```

### How This Builds on Previous Labs

| From this lab | Provides | Used by Optimization as |
|---|---|---|
| Lab 1 | System prompt and tool definitions | The optimization targets — the exact artifacts that get improved |
| Lab 3 | AgentCore Gateway (my-gateway-secure) | The traffic splitter for A/B testing |
| Lab 4 | Observability (OTel traces → CloudWatch) | The input the Recommendations engine analyzes |
| Lab 5 | QualityMonitor online eval with GoalSuccessRate | The target evaluator that defines "better" |

## Prerequisites

1. Update the AgentCore CLI: `agentcore update`
2. Confirm `bedrock-agentcore >= 1.9.1` in `app/CustomerSupport/pyproject.toml`
3. Transaction Search must be enabled in CloudWatch
4. Have a valid Cognito token:

```bash
COGNITO_WEB_CLIENT_ID=$(aws ssm get-parameter \
  --name /app/customersupport/agentcore/web_client_id \
  --query 'Parameter.Value' --output text)

TOKEN=$(aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id $COGNITO_WEB_CLIENT_ID \
  --auth-parameters USERNAME=workshopuser@example.com,PASSWORD='WorkshopPass1!' \
  --query 'AuthenticationResult.AccessToken' --output text)

export TOKEN
```

## Step 1: Generate Traces

Send varied requests so the recommendation engine has recent sessions:

```bash
SESSION_OPT=$(python3 -c 'import uuid; print(uuid.uuid4())')

agentcore invoke "What's the price and battery life of the Smart Watch?" \
  --runtime CustomerSupport --session-id $SESSION_OPT --bearer-token "$TOKEN" --stream

agentcore invoke "My headphones are broken. What should I do?" \
  --runtime CustomerSupport --session-id $SESSION_OPT --bearer-token "$TOKEN" --stream

agentcore invoke "Is PROD-002 still under warranty?" \
  --runtime CustomerSupport --session-id $SESSION_OPT --bearer-token "$TOKEN" --stream

agentcore invoke "I want to return my USB-C Hub and also check if it's under warranty." \
  --runtime CustomerSupport --session-id $SESSION_OPT --bearer-token "$TOKEN" --stream

agentcore invoke "It stopped working. Can I get my money back?" \
  --runtime CustomerSupport --session-id $SESSION_OPT --bearer-token "$TOKEN" --stream
```

Wait 2–5 minutes for CloudWatch ingestion before starting recommendations.

## Step 2: System Prompt Recommendation

```bash
agentcore run recommendation \
  --type system-prompt \
  --run cs-prompt-rec \
  --runtime CustomerSupport \
  --evaluator Builtin.GoalSuccessRate \
  --inline "You are a helpful and professional customer support assistant for an e-commerce company. Provide accurate information using the tools available to you. Be friendly, patient, and understanding. Always offer additional help after answering. Always use tools to get accurate information rather than guessing." \
  --lookback 7 \
  --wait
```

The optimizer analyzes traces, identifies failure patterns, and generates concrete rules. For example:
- When a user mentions a product by name, proactively search for it
- Use `<user_context>` tags to inform responses
- Confirm before real-world actions like refunds

Save the recommended prompt:

```bash
REC_ID=$(agentcore view recommendation --json | jq -r '.recommendations[0].id')
RECOMMENDED_PROMPT=$(agentcore view recommendation --json | jq -r '.recommendations[0].result.systemPromptRecommendationResult.recommendedSystemPrompt')
```

## Step 3: Tool Description Recommendation

```bash
agentcore run recommendation \
  --type tool-description \
  --run cs-tool-rec \
  --runtime CustomerSupport \
  --tools "get_return_policy:Get return policy information for a specific product category (electronics, accessories, audio)." \
  --tools "get_product_info:Search for product information by name, ID (e.g. PROD-001), or keyword." \
  --tools "WarrantyCheck___check_warranty:Check the warranty status of a product by its product ID. Returns duration, status, and expiration date." \
  --lookback 7 \
  --wait
```

The optimizer sharpens tool descriptions based on actual tool-selection patterns in traces.

## A/B Testing

A recommendation is a hypothesis. A/B testing validates it on live traffic.

### Why a Dedicated A/B Runtime?

The CustomerSupport runtime uses CUSTOM_JWT auth, but the Gateway invokes via SigV4. Rather than weaken production, we deploy `CustomerSupportAB` with default IAM auth.

```
Client (Cognito JWT) → Gateway ──┬── Bundle v1 (control)   ──(SigV4)──→ CustomerSupportAB Runtime
                                 └── Bundle v2 (treatment) ──(SigV4)──→ CustomerSupportAB Runtime
```

### Step 4: Deploy A/B Runtime

The `CustomerSupportAB` runtime is already deployed in `agentcore.json` — a lightweight, config-bundle-aware agent that reads its system prompt from the active bundle via a `BeforeModelCallEvent` hook.

### Step 5: Create Configuration Bundles

```bash
# Control — current system prompt
agentcore add config-bundle \
  --name customerSupportControl \
  --commit-message "Baseline prompt" \
  --components '{"{{runtime:CustomerSupportAB}}": {"configuration": {"system_prompt": "You are a helpful and professional customer support assistant for an e-commerce company. Provide accurate information using the tools available to you. Be friendly, patient, and understanding. Always offer additional help after answering. Always use tools to get accurate information rather than guessing."}}}'

# Treatment — recommended prompt
agentcore add config-bundle \
  --name customerSupportTreatment \
  --commit-message "Recommended prompt from cs-prompt-rec" \
  --components "$(jq -n --arg prompt "$RECOMMENDED_PROMPT" '{"{{runtime:CustomerSupportAB}}": {"configuration": {"system_prompt": $prompt}}}')"
```

### Step 6: Create A/B Online Eval

The QualityMonitor from Lab 5 is bound to CustomerSupport. Create one for the A/B runtime:

```bash
agentcore add online-eval \
  --name ABQualityMonitor \
  --runtime CustomerSupportAB \
  --evaluator Builtin.GoalSuccessRate \
  --sampling-rate 100 \
  --enable-on-create
```

Deploy everything:

```bash
agentcore deploy -y -v
```

### Step 7: Create the A/B Test

```bash
agentcore run ab-test \
  --mode config-bundle \
  --name cs_prompt_abtest \
  --gateway my-gateway-secure \
  --runtime CustomerSupportAB \
  --control-bundle customerSupportControl \
  --control-version LATEST \
  --treatment-bundle customerSupportTreatment \
  --treatment-version LATEST \
  --online-eval ABQualityMonitor \
  --control-weight 80 \
  --treatment-weight 20
```

### Step 8: Send Traffic

Switch policy engine to LOG_ONLY for the A/B target:

```bash
jq '(.agentCoreGateways[] | select(.name == "my-gateway-secure") | .policyEngineConfiguration.mode) = "LOG_ONLY"' \
  agentcore/agentcore.json > agentcore/agentcore.json.tmp \
  && mv agentcore/agentcore.json.tmp agentcore/agentcore.json

agentcore deploy -y -v
```

Generate traffic:

```bash
AB_TEST_ID=$(agentcore view ab-test --json | jq -r '.abTests[0].id')
GW_BASE=$(agentcore status --json | jq -r '.deployedState.targets.default.resources.gateways."my-gateway-secure".gatewayUrl')
GATEWAY_URL="${GW_BASE}/customer-support-ab/invocations"

# Create and run loadgen.sh with 30 requests across 6 prompts
```

### Step 9: Read Results

```bash
agentcore view ab-test $AB_TEST_ID --json
```

Each evaluator reports control mean, treatment mean, percent change, p-value, and significance.

### Step 10: Promote or Stop

```bash
# If treatment wins
agentcore promote ab-test -i $AB_TEST_ID
agentcore deploy -y -v

# If regression
agentcore stop ab-test -i $AB_TEST_ID
agentcore archive ab-test -i $AB_TEST_ID
```

## Config-Bundle vs. Target-Based A/B Testing

| | Config-Bundle Routing | Target-Based Routing |
|---|---|---|
| **What changes** | System prompt, config (no code change) | Agent binary, tools, model |
| **Redeployment needed** | No — config applied at request time | Yes — new runtime required |
| **Best for** | Prompt tuning, config experiments | Code releases, version upgrades |
| **Traffic split** | Typically 50/50 | Typically 90/10 canary |
| **Rollback** | Instant — update bundle version | Runtime still running; shift weights back |

## Files Created/Modified

| File | Purpose |
|---|---|
| `app/CustomerSupportAB/main.py` | Config-bundle-aware A/B agent (IAM auth) |
| `app/CustomerSupportAB/pyproject.toml` | Dependencies for A/B runtime |
| `agentcore/agentcore.json` | Added CustomerSupportAB runtime, http-runtime target, ABQualityMonitor, LOG_ONLY policy |

## Key Commands

```bash
# Recommendations
agentcore run recommendation --type system-prompt --runtime CustomerSupport \
  --evaluator Builtin.GoalSuccessRate --inline "..." --wait

agentcore run recommendation --type tool-description --runtime CustomerSupport \
  --tools "get_return_policy:..." --wait

# Config bundles
agentcore add config-bundle --name MyBundle --commit-message "..." --components '...'

# Online eval
agentcore add online-eval --name MyEval --runtime CustomerSupportAB \
  --evaluator Builtin.GoalSuccessRate --sampling-rate 100 --enable-on-create

# A/B test
agentcore run ab-test --mode config-bundle --name MyTest \
  --gateway my-gateway-secure --runtime CustomerSupportAB \
  --control-bundle Control --treatment-bundle Treatment \
  --online-eval MyEval --control-weight 80 --treatment-weight 20

# Monitor
agentcore view ab-test $ID --json

# Promote / Stop
agentcore promote ab-test -i $ID
agentcore stop ab-test -i $ID
```

## Congratulations!

You've completed the full workshop:

| Lab | What you built |
|---|---|
| 1 | Agent prototype with local tools |
| 2 | Persistent memory across sessions |
| 3 | Centralized tools via Gateway |
| 4 | Security, observability, and session management |
| 5 | Continuous quality monitoring |
| 6 | Customer-facing chat interface |
| 7 | Fine-grained governance with Cedar policies |
| 8 | Zero-code agents with Harness |
| 9 | Data-driven optimization with recommendations and A/B testing |
