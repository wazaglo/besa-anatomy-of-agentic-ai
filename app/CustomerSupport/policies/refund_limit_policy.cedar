permit(
  principal,
  action == AgentCore::Action::"ProcessRefund___process_refund",
  resource == AgentCore::Gateway::"arn:aws:bedrock-agentcore:us-east-1:195675606509:gateway/customersupport-my-gateway-secure-5vhssihj27"
) when {
  context.input.amount < 100
};
