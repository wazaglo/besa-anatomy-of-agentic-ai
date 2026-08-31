# Workshop Documentation

Detailed notes for each lab in the **Getting Started with Amazon Bedrock AgentCore** workshop, completed as part of **BeSA Cohort 10: Agentic AI from POC to Production on AWS**.

## Progress

| Lab | Topic | Status |
|---|---|---|
| [Lab 1](lab1-building-the-agent.md) | Building the Agent Prototype | ✅ Complete |
| [Lab 2](lab2-adding-memory.md) | Add Memory to Your Agent | ✅ Complete |
| Lab 3 | Scaling Tools with Gateway | ⬜ Pending |
| Lab 4 | Securing and Observing in Production | ⬜ Pending |
| Lab 5 | Evaluating Agent Quality | ⬜ Pending |
| Lab 6 | Building the Customer Interface | ⬜ Pending |
| Lab 7 | Governing Agent Actions with Policies | ⬜ Pending |
| Lab 8 | Zero-Code Agents with AgentCore Harness | ⬜ Pending |
| Lab 9 | Optimizing Agent Quality | ⬜ Pending |

## Workshop Source

- [Getting Started with Amazon Bedrock AgentCore](https://catalog.workshops.aws/agentcore-getting-started/en-US)
- [BeSA Cohort 10 Registration](https://besa.techexpert.io/program/self-paced-become-a-solutions-architect-agentic-ai-on-aws-3849)

## Key Decisions

### Model Choice

The workshop specifies `global.anthropic.claude-sonnet-4-6` as the model. This model requires submitting a use case details form in the Bedrock console before your account is approved to use it.

**Decision:** Switched to `amazon.nova-pro-v1:0` (Amazon Nova Pro) which is pre-approved and doesn't require a use case form. Nova Pro is capable enough for the customer support agent demo and is significantly cheaper.

### Repository Naming

Renamed from `besa-agentcore-lab1` to `besa-anatomy-of-agentic-ai` since the project covers multiple labs and is not limited to Lab 1.

## AWS Account Details

- **Account:** 195675606509
- **Region:** us-east-1
- **Stack:** agentcore-workshop-prereqs
- **Lambda Functions:** workshop-warranty-check, workshop-process-refund
- **Cognito User Pool:** us-east-1_qZ9eMpY7y
- **SSM Parameters:** /app/customersupport/agentcore/*
