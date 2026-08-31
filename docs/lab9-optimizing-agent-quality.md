# Lab 9: Optimizing Agent Quality

**Duration:** ~30 minutes
**Workshop Reference:** [Lab 9](https://catalog.workshops.aws/agentcore-getting-started/en-US/28-lab9-recommendations)

## Overview

Completed the observe-evaluate-improve loop: generated AI-driven optimization recommendations from production traces, packaged them into Configuration Bundles, and validated improvements with A/B testing — all without redeploying code.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    AgentCore Optimization Loop                       │
│                                                                      │
│  1. Invoke Agent ──────────► CloudWatch Logs (OTel spans)           │
│                                         │                            │
│  2. Batch Evaluate ◄────────────────────┘                           │
│     GoalSuccessRate / ToolSelectionAccuracy                          │
│                │                                                     │
│  3. Recommend ─┘  ──► Improved System Prompt                        │
│                        Improved Tool Descriptions                    │
│                                │                                     │
│  4. Bundle ───────────────────►│  Configuration Bundle (C)          │
│                                 │  Configuration Bundle (T1)        │
│                                 │                                    │
│  5. A/B Test ──────────────────┘                                    │
│      Config-Bundle Routing: same runtime, different prompts         │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                    AgentCore Platform                           │ │
│  │                                                                 │ │
│  │  ┌──────────────────┐     ┌──────────────────┐                │ │
│  │  │ CustomerSupport   │     │ Online Eval       │                │ │
│  │  │ (Python Runtime)  │     │ (QualityMonitor)  │                │ │
│  │  └────────┬─────────┘     └────────┬─────────┘                │ │
│  │           │                         │                           │ │
│  │           └─────────┬───────────────┘                           │ │
│  │                     │                                           │ │
│  │           ┌─────────▼─────────┐                                │ │
│  │           │ my-gateway-secure │                                │ │
│  │           │ (Cedar Policies)  │                                │ │
│  │           └───────────────────┘                                │ │
│ └─────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘
```

## Key Concepts

| Concept | Description |
|---|---|
| **Configuration Bundle** | Versioned snapshot of agent config (system prompt, tool descriptions, model ID) — no code change needed |
| **Recommendations** | AI-generated improvements to system prompts or tool descriptions from production traces |
| **Batch Evaluation** | Offline scoring of sessions against built-in evaluators |
| **A/B Test (Config-Bundle)** | Traffic split between two config variants on the same runtime |
| **A/B Test (Target-Based)** | Traffic split between different runtimes (phased rollout) |

### Config-Bundle vs. Target-Based A/B Testing

| | Config-Bundle Routing | Target-Based Routing |
|---|---|---|
| **What changes** | System prompt, config (no code change) | Agent binary, tools, model |
| **Redeployment needed** | No — config applied at request time | Yes — new runtime required |
| **Best for** | Prompt tuning, config experiments | Code releases, version upgrades |
| **Traffic split** | Typically 50/50 | Typically 90/10 canary |
| **Rollback** | Instant — update bundle version | Runtime still running; shift weights back |

## Workflow

### Step 1: Generate Triggers Traces

Invoke the agent with diverse prompts to generate production traces in CloudWatch:

```bash
# Generate multiple sessions with different scenarios
for i in {1..10}; do
  SESSION=$(uuidgen)
  agentcore invoke \
    --session-id "$SESSION" \
    --actor-id "customer-$i" \
    "Check warranty for PROD-00$i and get product details"
done

# Wait for CloudWatch ingestion (~2-3 minutes)
sleep 180
```

### Step 2: Run Batch Evaluation

Score existing sessions against built-in evaluators:

```bash
agentcore run batch-evaluation \
  --runtime CustomerSupport \
  --evaluators Builtin.GoalSuccessRate Builtin.Correctness Builtin.ToolSelectionAccuracy
```

This produces aggregate scores showing where the agent excels and where it struggles.

### Step 3: Generate Recommendations

#### System Prompt Recommendation

```bash
agentcore run recommendation \
  --runtime CustomerSupport \
  --type system-prompt \
  --evaluator Builtin.GoalSuccessRate \
  --inline "You are a customer support agent for Acme Electronics. Help customers with warranty checks, product information, and refunds."
```

AgentCore analyzes production traces and rewrites the system prompt to improve the target metric.

#### Tool Description Recommendation

```bash
agentcore run recommendation \
  --runtime CustomerSupport \
  --type tool-description \
  --tools "check_warranty:Check warranty status for a product" \
  --tools "get_product_info:Get product details and specifications" \
  --tools "process_refund:Process a customer refund for a given order"
```

Improved tool descriptions help the agent select the right tool more reliably.

### Step 4: Create Configuration Bundles

Bundle the original (control) and optimized (treatment) configurations:

```bash
# Create control bundle (original config)
agentcore config-bundle create \
  --name CustomerSupportControl \
  --description "Original customer support agent configuration" \
  --commit-message "Baseline configuration"

# Create treatment bundle (recommended config)
agentcore config-bundle create \
  --name CustomerSupportTreatment \
  --description "Optimized configuration from recommendations" \
  --commit-message "Recommended improvements from traces"
```

### Step 5: A/B Test — Config-Bundle Routing

```bash
agentcore add ab-test \
  --name CustomerSupportABTest \
  --mode config-bundle \
  --gateway my-gateway-secure \
  --control-bundle CustomerSupportControl \
  --treatment-bundle CustomerSupportTreatment \
  --control-weight 50 \
  --treatment-weight 50 \
  --online-eval QualityMonitor \
  --enable
```

Traffic splits 50/50 between original and optimized configs on the same runtime.

### Step 6: Monitor Results

```bash
# Check A/B test status
agentcore view ab-test --name CustomerSupportABTest

# Check online evaluation scores
agentcore logs evals --since 1h
```

Look for:
- **isSignificant**: Whether results have statistical significance
- **percentChange**: Improvement or regression in the target metric
- **p-value**: Statistical confidence (p < 0.05 = significant)

### Step 7: Promote or Rollback

```bash
# If treatment wins, promote it
agentcore promote ab-test --name CustomerSupportABTest

# If regression, stop the test
agentcore stop ab-test --name CustomerSupportABTest
```

## Phased Rollout (Target-Based)

For code-level changes (new tools, model upgrades):

```
10% canary  →  validate no regressions (errors, latency, quality drop)
      ↓
50% ramp    →  gather statistical significance
      ↓
100% promote →  complete cutover; decommission old runtime
```

```bash
agentcore add ab-test \
  --name CustomerSupportTargetABTest \
  --mode target-based \
  --gateway my-gateway-secure \
  --control-target WarrantyCheck \
  --treatment-target ProcessRefund \
  --control-weight 90 \
  --treatment-weight 10 \
  --online-eval QualityMonitor \
  --enable
```

## Files Created/Modified

| File | Change |
|---|---|
| `agentcore/agentcore.json` | Added `configBundles` and `abTests` arrays |
| `docs/lab9-optimizing-agent-quality.md` | This file |

## Key Commands

```bash
# Batch evaluation
agentcore run batch-evaluation --runtime CustomerSupport \
  --evaluators Builtin.GoalSuccessRate Builtin.ToolSelectionAccuracy

# System prompt recommendation
agentcore run recommendation --runtime CustomerSupport \
  --type system-prompt --evaluator Builtin.GoalSuccessRate \
  --inline "You are a customer support agent..."

# Tool description recommendation
agentcore run recommendation --runtime CustomerSupport \
  --type tool-description \
  --tools "check_warranty:Check warranty status"

# Configuration bundles
agentcore config-bundle create --name MyBundle --description "..."

# A/B test
agentcore add ab-test --name MyTest --mode config-bundle \
  --gateway my-gateway-secure \
  --control-bundle Control --treatment-bundle Treatment \
  --enable

# Monitor
agentcore view ab-test --name MyTest
agentcore logs evals --since 1h

# Promote
agentcore promote ab-test --name MyTest
```

## What's Next

The full optimization loop is now complete:
1. **Lab 1-4**: Built, scaled, and secured the agent
2. **Lab 5**: Evaluated agent quality
3. **Lab 6**: Built the customer interface
4. **Lab 7**: Governed agent actions with Cedar policies
5. **Lab 8**: Created zero-code agents with harnesses
6. **Lab 9**: Optimized agent quality from production traces

The agent is now production-ready with continuous improvement capabilities.
