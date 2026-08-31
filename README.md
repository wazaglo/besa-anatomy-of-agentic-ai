# Customer Support AI Agent — AWS AgentCore

A hands-on project from **BeSA Cohort 10: Agentic AI from POC to Production on AWS**. Built during the [Getting Started with Amazon Bedrock AgentCore](https://catalog.workshops.aws/agentcore-getting-started/en-US) workshop.

The agent answers product questions, checks return policies, looks up warranty status via a real Lambda function, searches the web, and remembers returning customers across sessions.

## What We Built

![Lab 5 Architecture](docs/images/lab5_architecture_diagram.png)

A customer support agent deployed on **Amazon Bedrock AgentCore** with:

| Feature | Lab | What It Does |
|---|---|---|
| Custom tools | [Lab 1](docs/lab1-building-the-agent.md) | `get_return_policy`, `get_product_info` + Exa AI web search |
| Memory | [Lab 2](docs/lab2-adding-memory.md) | Remembers customer names, preferences, purchases across sessions |
| Gateway | [Lab 3](docs/lab3-scaling-tools-with-gateway.md) | Exposes a real Lambda (warranty check) as an MCP tool |
| JWT Auth | [Lab 4](docs/lab4-securing-and-observing-in-production.md) | Cognito authentication on Runtime + Gateway |
| Observability | [Lab 4](docs/lab4-securing-and-observing-in-production.md) | CloudWatch traces, logs, GenAI Observability dashboard |
| Quality Evaluation | [Lab 5](docs/lab5-evaluating-agent-quality.md) | LLM-as-Judge scoring: goal success, correctness, tool selection |

**Stack:** Strands Agents + Amazon Nova Pro + AgentCore Runtime/Memory/Gateway + CloudWatch + Evaluations

## Labs Progress

| Lab | Topic | Status |
|---|---|---|
| [Lab 1](docs/lab1-building-the-agent.md) | Building the Agent Prototype | ✅ |
| [Lab 2](docs/lab2-adding-memory.md) | Add Memory to Your Agent | ✅ |
| [Lab 3](docs/lab3-scaling-tools-with-gateway.md) | Scaling Tools with Gateway | ✅ |
| [Lab 4](docs/lab4-securing-and-observing-in-production.md) | Securing and Observing in Production | ✅ |
| [Lab 5](docs/lab5-evaluating-agent-quality.md) | Evaluating Agent Quality | ✅ |
| [Lab 6](docs/lab6-building-the-customer-interface.md) | Building the Customer Interface | ✅ |
| Lab 7 | Governing Agent Actions with Policies | ⬜ |
| Lab 8 | Zero-Code Agents with AgentCore Harness | ⬜ |
| Lab 9 | Optimizing Agent Quality | ⬜ |

## Prerequisites

**Tools:**

| Tool | Install |
|---|---|
| Node.js 20+ | `nvm install 20` |
| uv | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| AWS CLI | `aws configure` |
| AgentCore CLI | `npm install -g @aws/agentcore@latest` |

**AWS Account:**

1. Configure credentials for `us-east-1`:
   ```bash
   aws configure
   export AWS_DEFAULT_REGION=us-east-1
   ```

2. Deploy the prerequisites stack (Cognito, Lambda, SSM params):
   ```bash
   aws cloudformation deploy \
     --template-file cloudformation/prereqs.yaml \
     --stack-name agentcore-workshop-prereqs \
     --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
     --region us-east-1
   ```

3. Enable Transaction Search for observability:
   ```bash
   aws xray update-indexing-rule \
     --name Default \
     --rule '{"Probabilistic": {"DesiredSamplingPercentage": 100}}'
   ```

## Getting Started

```bash
# Clone
git clone https://github.com/wazaglo/besa-anatomy-of-agentic-ai.git
cd besa-anatomy-of-agentic-ai

# Install dependencies
cd app/CustomerSupport
uv venv
uv pip install -r requirements.txt

# Run locally
agentcore dev

# Test locally (another terminal)
agentcore invoke "What's the return policy for electronics?"
```

## Deploy to AWS

```bash
agentcore deploy
```

First deploy takes 2-5 minutes. Then:

```bash
agentcore status

# Test memory (Lab 2+)
SESSION=$(python3 -c 'import uuid; print(uuid.uuid4())')
agentcore invoke "My name is Sarah and I prefer email updates." \
  --session-id $SESSION \
  -H "X-Amzn-Bedrock-AgentCore-Runtime-Custom-User-Id: Sarah" --stream

sleep 2m

SESSION2=$(python3 -c 'import uuid; print(uuid.uuid4())')
agentcore invoke "Do you know anything about me?" \
  --session-id $SESSION2 \
  -H "X-Amzn-Bedrock-AgentCore-Runtime-Custom-User-Id: Sarah" --stream
```

## Project Structure

```
CustomerSupport/
├── agentcore/
│   ├── agentcore.json          # Runtime + memory + gateway + JWT auth + online eval
│   ├── aws-targets.json        # Deployment targets (account + region)
│   └── cdk/                    # CDK infrastructure
├── app/CustomerSupport/
│   ├── main.py                 # Agent entry point + tools + auth
│   ├── model/load.py           # Model config (Amazon Nova Pro)
│   ├── memory/session.py       # Memory session manager
│   ├── mcp_client/client.py    # Exa AI + Gateway MCP clients
│   ├── tool/warranty_schema.json  # Gateway tool schema
│   └── frontend/
│       ├── frontend.py         # Flask server with Cognito auth
│       └── templates/index.html  # Chat UI
├── cloudformation/
│   └── prereqs.yaml            # CloudFormation template (Cognito + Lambda + SSM)
└── docs/
    ├── images/                 # Architecture diagrams (Lab 1-5)
    └── lab[1-6]-*.md           # Workshop lab documentation
```

## What Each Lab Covers

| Lab | Key Concepts |
|---|---|
| **Lab 1** | Scaffold project, add custom tools, connect Exa AI MCP, deploy to AgentCore Runtime |
| **Lab 2** | Add SEMANTIC + SUMMARIZATION memory, session isolation, cross-session recall |
| **Lab 3** | Create Gateway, expose Lambda as MCP tool, tool schema, gateway MCP client |
| **Lab 4** | Cognito JWT auth on Runtime + Gateway, extract user from token, CloudWatch observability |
| **Lab 5** | Online evaluation with LLM-as-Judge (goal success, correctness, tool selection) |
| **Lab 6** | Flask web chat interface with Cognito auth, direct AgentCore REST API calls |
| **Lab 7** | Cedar policy engine for governing agent actions |
| **Lab 8** | Zero-code agents with AgentCore Harness |
| **Lab 9** | Optimizing agent quality from real traces |

## Cleanup

AgentCore Runtime and Bedrock model invocations are billable.

```bash
# Remove deployed resources
agentcore remove runtime --name CustomerSupport
agentcore remove memory --name SharedMemory

# Delete CloudFormation stack
aws cloudformation delete-stack --stack-name agentcore-workshop-prereqs
```

## Cost

Lab 1-5 testing: **under $3 total**. Nova Pro is ~$0.0008/1K input tokens. Always clean up to avoid ongoing charges.

## Model Choice

The workshop uses `global.anthropic.claude-sonnet-4-6` but that requires a use case form in Bedrock console. We use `amazon.nova-pro-v1:0` (pre-approved, cheaper, capable enough for this demo).

## Resources

- [Workshop: Getting Started with AgentCore](https://catalog.workshops.aws/agentcore-getting-started/en-US)
- [BeSA Cohort 10](https://besa.techexpert.io/program/self-paced-become-a-solutions-architect-agentic-ai-on-aws-3849)
- [Amazon Bedrock AgentCore Docs](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/)
- [Strands Agents Framework](https://github.com/strands-agents)
