# BeSA Cohort 10 — Customer Support Agent with AWS AgentCore

Lab 1 of the [Getting Started with Amazon Bedrock AgentCore](https://catalog.workshops.aws/agentcore-getting-started/en-US) workshop, built as part of **BeSA Cohort 10: Agentic AI from POC to Production on AWS**.

A customer support agent that answers product questions, looks up return policies, and searches the web for troubleshooting help — deployed to AgentCore Runtime.

## What It Does

- **`get_return_policy`** — Returns return policy by product category (electronics, accessories, audio)
- **`get_product_info`** — Searches products by name, ID, or keyword
- **Exa AI MCP** — Web search for troubleshooting and general questions

Built with **Strands Agents** framework, deployed to **Amazon Bedrock AgentCore Runtime**.

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
git clone https://github.com/wazaglo/besa-agentcore-lab1.git
cd besa-agentcore-lab1

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

## Project Structure

```
CustomerSupport/
├── AGENTS.md
├── README.md
├── .gitignore
├── agentcore/
│   ├── agentcore.json          # Project config
│   ├── aws-targets.json        # Deployment targets
│   └── cdk/                    # CDK infrastructure
└── app/
    └── CustomerSupport/
        ├── main.py             # Agent entry point + tools
        ├── model/
        │   └── load.py         # Model config (Amazon Nova Pro)
        └── mcp_client/
            └── client.py       # Exa AI MCP web search
```

## Cleanup

**Important:** AgentCore Runtime and Bedrock model invocations are billable. Clean up when done.

```bash
# 1. Delete the deployed runtime
agentcore remove runtime --name CustomerSupport

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
| Lambda (prereqs) | Free tier: 1M req/mo |
| Cognito | Free tier: 50K MAU |

Lab 1 testing: **under $1 total**. Always clean up to avoid ongoing charges.

## Resources

- [Workshop: Getting Started with AgentCore](https://catalog.workshops.aws/agentcore-getting-started/en-US)
- [BeSA Cohort 10](https://besa.techexpert.io/program/self-paced-become-a-solutions-architect-agentic-ai-on-aws-3849)
- [Amazon Bedrock AgentCore Docs](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/)
- [Strands Agents Framework](https://github.com/strands-agents)
