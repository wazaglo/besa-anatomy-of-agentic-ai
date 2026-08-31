forbid(
  principal,
  action == AgentCore::Action::"ProcessRefund___process_refund",
  resource == AgentCore::Gateway::"arn:aws:bedrock-agentcore:us-east-1:195675606509:gateway/customersupport-my-gateway-secure-5vhssihj27"
) when guardrails {
  BedrockGuardrails::SensitiveInformation(
    ["EMAIL"], [context.input.reason]
  ).maxConfidenceScore().greaterThanOrEqual(decimal("0.2"))
};
