# BeSA Cohort 10 — Anatomy of Agentic AI on AWS AgentCore

A hands-on project from **BeSA Cohort 10: Agentic AI from POC to Production on AWS**, covering the full lifecycle of building and deploying an AI agent on Amazon Bedrock AgentCore.

Built during the [Getting Started with Amazon Bedrock AgentCore](https://catalog.workshops.aws/agentcore-getting-started/en-US) workshop — a customer support agent that answers product questions, looks up return policies, and searches the web for troubleshooting help.

## What It Does

- **`get_return_policy`** — Returns return policy by product category (electronics, accessories, audio)
- **`get_product_info`** — Searches products by name, ID, or keyword
- **Exa AI MCP** — Web search for troubleshooting and general questions
- **AgentCore Memory** — Remembers customer facts across sessions (names, preferences, order history)

Built with **Strands Agents** framework, deployed to **Amazon Bedrock AgentCore Runtime**.

## Labs Completed

| Lab | Topic | Status |
|---|---|---|
| [Lab 1](docs/lab1-building-the-agent.md) | Building the Agent Prototype | ✅ |
| [Lab 2](docs/lab2-adding-memory.md) | Add Memory to Your Agent | ✅ |
| Lab 3 | Scaling Tools with Gateway | ⬜ |
| Lab 4 | Securing and Observing in Production | ⬜ |
| Lab 5 | Evaluating Agent Quality | ⬜ |
| Lab 6 | Building the Customer Interface | ⬜ |
| Lab 7 | Governing Agent Actions with Policies | ⬜ |
| Lab 8 | Zero-Code Agents with AgentCore Harness | ⬜ |
| Lab 9 | Optimizing Agent Quality | ⬜ |

See [docs/README.md](docs/README.md) for detailed workshop notes.

## Prerequisites

### Local Tools

| Tool | Min Version | Install |
|---|---|---|
| Node.js | 20.x | `nvm install 20` |
| uv | 0.4+ | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| AWS CLI | 2.x | `aws configure` |
| Git | 2.x | — |
| AgentCore CLI | latest | `npm install -g @aws/agentcore@latest` |

### AWS Account Setup

1. **Configure credentials** in `us-east-1` or `us-west-2`:
   ```bash
   aws configure
   # Or:
   export AWS_DEFAULT_REGION=us-east-1
   ```

2. **Deploy prerequisites stack** (Cognito, Lambda, SSM params):
   ```bash
   aws cloudformation deploy \
     --template-file cloudformation/prereqs.yaml \
     --stack-name agentcore-workshop-prereqs \
     --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
     --region us-east-1
   ```
   Or use the one-click deploy from the workshop page.

3. **Enable Transaction Search** (for Lab 4 observability):
   ```bash
   aws xray update-indexing-rule \
     --name Default \
     --rule '{"Probabilistic": {"DesiredSamplingPercentage": 100}}'
   ```

4. **Request model access** in Bedrock console if using Claude:
   - Console → Bedrock → Model access → Request model access
   - Select Anthropic Claude Sonnet 4.6 (or use Nova Pro which is pre-approved)

## Quick Start

```bash
# Clone and enter project
git clone https://github.com/wazaglo/besa-anatomy-of-agentic-ai.git
cd besa-anatomy-of-agentic-ai

# Install dependencies
cd app/CustomerSupport
uv venv
uv pip install -r requirements.txt

# Run locally
agentcore dev

# In another terminal, test
agentcore invoke "What's the return policy for electronics?"
```

## Deploy to AWS

```bash
agentcore deploy
```

First deploy takes 2-5 minutes. After deployment:

```bash
agentcore status    # Check deployment status
agentcore invoke "Tell me about the Wireless Headphones"
```

### Testing Memory (Lab 2)

```bash
# Teach the agent about you
SESSION_A=$(python3 -c 'import uuid; print(uuid.uuid4())')
agentcore invoke "My name is Sarah and I prefer email updates. I recently bought a Smart Watch." \
  --session-id $SESSION_A \
  -H "X-Amzn-Bedrock-AgentCore-Runtime-Custom-User-Id: Sarah" --stream

# Wait for memory extraction, then test cross-session recall
sleep 2m
SESSION_B=$(python3 -c 'import uuid; print(uuid.uuid4())')
agentcore invoke "Do you know anything about me?" \
  --session-id $SESSION_B \
  -H "X-Amzn-Bedrock-AgentCore-Runtime-Custom-User-Id: Sarah" --stream
```

## Project Structure

```
CustomerSupport/
├── AGENTS.md
├── README.md
├── .gitignore
├── agentcore/
│   ├── agentcore.json          # Project config + memory + header allowlist
│   ├── aws-targets.json        # Deployment targets
│   └── cdk/                    # CDK infrastructure
├── app/
│   └── CustomerSupport/
│       ├── main.py             # Agent + tools + memory integration
│       ├── model/
│       │   └── load.py         # Model config (Amazon Nova Pro)
│       ├── memory/
│       │   ├── __init__.py
│       │   └── session.py      # Memory session manager
│       └── mcp_client/
│           └── client.py       # Exa AI MCP web search
└── docs/
    ├── README.md               # Workshop documentation index
    ├── lab1-building-the-agent.md
    └── lab2-adding-memory.md
```

## Cleanup

**Important:** AgentCore Runtime and Bedrock model invocations are billable. Clean up when done.

```bash
# 1. Delete the deployed runtime and memory
agentcore remove runtime --name CustomerSupport
agentcore remove memory --name SharedMemory

# 2. Delete the CloudFormation prerequisites stack
aws cloudformation delete-stack --stack-name agentcore-workshop-prereqs

# 3. Confirm deletion
aws cloudformation describe-stacks \
  --stack-name agentcore-workshop-prereqs \
  --query 'Stacks[0].StackStatus' --output text
# Should show DELETE_COMPLETE after a few minutes
```

## Cost Estimate

| Resource | Cost |
|---|---|
| Bedrock Nova Pro invocations | ~$0.0008/1K input tokens |
| AgentCore Runtime | Billed per invocation + compute time |
| AgentCore Memory | Billed per storage + retrieval |
| Lambda (prereqs) | Free tier: 1M req/mo |
| Cognito | Free tier: 50K MAU |

Lab 1-2 testing: **under $2 total**. Always clean up to avoid ongoing charges.

## Model Choice

The workshop specifies `global.anthropic.claude-sonnet-4-6` but this model requires submitting a use case details form in the Bedrock console. We switched to `amazon.nova-pro-v1:0` (Amazon Nova Pro) which is pre-approved and cheaper.

## Resources

- [Workshop: Getting Started with AgentCore](https://catalog.workshops.aws/agentcore-getting-started/en-US)
- [BeSA Cohort 10](https://besa.techexpert.io/program/self-paced-become-a-solutions-architect-agentic-ai-on-aws-3849)
- [Amazon Bedrock AgentCore Docs](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/)
- [Strands Agents Framework](https://github.com/strands-agents)
