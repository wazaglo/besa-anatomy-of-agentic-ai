# Lab 5: Evaluating Agent Quality

**Duration:** ~15 minutes
**Workshop Reference:** [Lab 5](https://catalog.workshops.aws/agentcore-getting-started/en-US/24-lab5-evaluate)

## Overview

Set up continuous quality monitoring using AgentCore Evaluations. The agent is deployed, secured, and observable, but how do you know if it's actually giving good answers? This lab uses LLM-as-a-Judge to automatically score every interaction on goal success, correctness, and tool selection.

## Architecture

![Lab 5 Architecture](images/lab5_architecture_diagram.png)

AgentCore Evaluations monitors the deployed agent by sampling live sessions and scoring them automatically. Results flow into CloudWatch where you can track trends over time. The evaluators run in the background alongside your agent. NOcode changes needed.

```
Client → AgentCore Runtime (JWT) → Agent → Tools/Memory/Gateway
                        ↓
              Evaluation Sampler (100%)
                        ↓
              LLM-as-a-Judge Scoring
                        ↓
              CloudWatch Dashboard
```

## Built-in Evaluators Used

| Evaluator | What It Measures |
|---|---|
| `Builtin.GoalSuccessRate` | Did the agent achieve the customer's goal? |
| `Builtin.Correctness` | Is the information factually accurate? |
| `Builtin.ToolSelectionAccuracy` | Did the agent pick the right tools? |

Other available evaluators: helpfulness, faithfulness, harmfulness, coherence, conciseness, instruction-following, and more.

## What Was Built

### Online Evaluation Configuration

```bash
agentcore add online-eval \
  --name QualityMonitor \
  --runtime CustomerSupport \
  --evaluator Builtin.GoalSuccessRate Builtin.Correctness Builtin.ToolSelectionAccuracy \
  --sampling-rate 100 \
  --enable-on-create
```

- **Sampling rate:** 100% for workshop (every interaction evaluated). In production, use 10-20%.
- **`--enable-on-create`:** Activates evaluation immediately after deployment.

### No Code Changes

Evaluation is configured declaratively via the CLI. The agent code remains unchanged, evaluators run as a sidecar to the runtime.

## Testing

### Generate Test Interactions

```bash
SESSION_EVAL=$(python3 -c 'import uuid; print(uuid.uuid4())')

# Product query
agentcore invoke "What can you tell me about the Smart Watch? What's the price and warranty?" \
  --session-id $SESSION_EVAL --bearer-token "$TOKEN" --stream

# Return policy
agentcore invoke "I bought headphones last week but they're not working. What's the return policy for audio products?" \
  --session-id $SESSION_EVAL --bearer-token "$TOKEN" --stream

# Warranty check via Gateway
agentcore invoke "Check the warranty status for product PROD-001" \
  --session-id $SESSION_EVAL --bearer-token "$TOKEN" --stream

# Multi-tool query
agentcore invoke "I want to return my USB-C Hub. What's the policy, and can you check if it's still under warranty?" \
  --session-id $SESSION_EVAL --bearer-token "$TOKEN" --stream

# General capability
agentcore invoke "What kind of support can you provide? List your capabilities." \
  --session-id $SESSION_EVAL --bearer-token "$TOKEN" --stream
```

### Run On-Demand Evaluation

```bash
agentcore run eval \
  --runtime CustomerSupport \
  --evaluator Builtin.GoalSuccessRate Builtin.Correctness \
  --days 1
```

**Example output:**
```
Agent: CustomerSupport | Jul 19, 2026, 09:54 PM | Sessions: 11 | Lookback: 1d
Builtin.GoalSuccessRate: 0.73
Builtin.Correctness: 0.84
```

### View Evaluation History

```bash
agentcore evals history --runtime CustomerSupport --limit 5
```

**Example output:**
```
Date                   Agent                Evaluators                                          Sessions
──────────────────────────────────────────────────────────────────────────────────────────
Jul 19, 2026, 09:54 PM CustomerSupport      Builtin.GoalSuccessRate=0.73, Builtin.Correctness=0.84 11
```

### View Evaluation Logs

```bash
agentcore logs evals --runtime CustomerSupport --since 30m
```

Shows detailed per-interaction scoring with explanations:
- `GoalSuccessRate = 1.0` - "All five user goals were successfully achieved"
- `Correctness = 0.5` - "The assistant invented a specific product identification that was never established"
- `ToolSelectionAccuracy = 1.0` - "Calling get_return_policy with 'audio' directly addresses the user's question"

## Score Interpretation

| Score | Interpretation | Action |
|---|---|---|
| 80-100% | Excellent | Monitor and maintain |
| 60-80% | Good but improvable | Review low-scoring sessions |
| Below 60% | Needs attention | Investigate and fix root causes |

## Common Improvements

| Issue | Fix |
|---|---|
| Low Goal Success Rate | Refine system prompt, add more specific tool descriptions |
| Low Correctness | Update product data, improve tool response formatting |
| Low Tool Selection | Improve tool descriptions, add examples to system prompt |

## Pause/Resume Evaluation

```bash
# Pause
agentcore pause online-eval QualityMonitor

# Resume
agentcore resume online-eval QualityMonitor
```

## CloudWatch Dashboard

Navigate to **GenAI Observability → Bedrock AgentCore** → CustomerSupport → Evaluations tab:
- Goal Success Rate trends
- Correctness trends
- Tool Selection Accuracy trends

## Files Modified

| File | Change |
|---|---|
| (none) | Evaluation is configured declaratively — no code changes |

## Key Commands

```bash
# Create online eval
agentcore add online-eval \
  --name QualityMonitor \
  --runtime CustomerSupport \
  --evaluator Builtin.GoalSuccessRate Builtin.Correctness Builtin.ToolSelectionAccuracy \
  --sampling-rate 100 \
  --enable-on-create

# Deploy
agentcore deploy -y -v

# Run on-demand eval
agentcore run eval --runtime CustomerSupport \
  --evaluator Builtin.GoalSuccessRate Builtin.Correctness --days 1

# View history
agentcore evals history --runtime CustomerSupport --limit 5

# View detailed logs
agentcore logs evals --runtime CustomerSupport --since 30m
```

## What's Next

Lab 6 will build a customer-facing interface with login page and chat UI.
