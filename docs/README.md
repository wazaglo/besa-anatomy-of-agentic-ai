# Workshop Documentation

Detailed notes for each lab in the **Getting Started with Amazon Bedrock AgentCore** workshop, completed as part of **BeSA Cohort 10: Agentic AI from POC to Production on AWS**.

## Progress

| Lab | Topic | Status |
|---|---|---|
| [Lab 1](lab1-building-the-agent.md) | Building the Agent Prototype | ✅ Complete |
| [Lab 2](lab2-adding-memory.md) | Add Memory to Your Agent | ✅ Complete |
| [Lab 3](lab3-scaling-tools-with-gateway.md) | Scaling Tools with Gateway | ✅ Complete |
| [Lab 4](lab4-securing-and-observing-in-production.md) | Securing and Observing in Production | ✅ Complete |
| [Lab 5](lab5-evaluating-agent-quality.md) | Evaluating Agent Quality | ✅ Complete |
| Lab 6 | Building the Customer Interface | ⬜ Pending |
| Lab 7 | Governing Agent Actions with Policies | ⬜ Pending |
| Lab 8 | Zero-Code Agents with AgentCore Harness | ⬜ Pending |
| Lab 9 | Optimizing Agent Quality | ⬜ Pending |

## Workshop Source

- [Getting Started with Amazon Bedrock AgentCore](https://catalog.workshops.aws/agentcore-getting-started/en-US)
- [BeSA Cohort 10 Registration](https://besa.techexpert.io/program/self-paced-become-a-solutions-architect-agentic-ai-on-aws-3849)

## Infrastructure

The prerequisites CloudFormation template is saved at `cloudformation/prereqs.yaml`. It provisions:

| Resource | Purpose |
|---|---|
| Cognito User Pool | JWT authentication for Runtime + Gateway |
| Cognito App Clients | Machine (client_credentials) + Web (user password auth) |
| `workshop-warranty-check` Lambda | Warranty lookup API (exposed via Gateway in Lab 3) |
| `workshop-process-refund` Lambda | Refund processing (used in Lab 7) |
| SSM Parameters | Cognito config, Lambda ARNs stored at `/app/customersupport/agentcore/*` |

## Deployed Resources (Current State)

| Resource | Config | Status |
|---|---|---|
| Runtime `CustomerSupport` | JWT auth, Python 3.14, PUBLIC network | ✅ |
| Memory `SharedMemory` | SEMANTIC + SUMMARIZATION, 30-day expiry | ✅ |
| Gateway `my-gateway-secure` | JWT auth, WarrantyCheck Lambda target | ✅ |
| Online Eval `QualityMonitor` | GoalSuccessRate + Correctness + ToolSelectionAccuracy, 100% sampling | ✅ |

## AWS Account Details

- **Account:** 195675606509
- **Region:** us-east-1
- **Stack:** agentcore-workshop-prereqs
- **Cognito User Pool:** us-east-1_qZ9eMpY7y
- **SSM Parameters:** `/app/customersupport/agentcore/*`

## Key Decisions

### Model Choice

Workshop default is `global.anthropic.claude-sonnet-4-6` (requires use case form). We use `amazon.nova-pro-v1:0` (pre-approved, cheaper).

### Repository Naming

Renamed from `besa-agentcore-lab1` to `besa-anatomy-of-agentic-ai` since the project covers all 9 labs.

## Architecture Images

| Lab | Image |
|---|---|
| Lab 1 | `docs/images/lab1_updated_architecture_diagram.png` |
| Lab 2 | `docs/images/lab2_architecture_diagram.png` |
| Lab 3 | `docs/images/lab3_architecture_diagram.png` |
| Lab 4 | `docs/images/lab4_architecture_diagram.png` |
| Lab 5 | `docs/images/lab5_architecture_diagram.png` |
