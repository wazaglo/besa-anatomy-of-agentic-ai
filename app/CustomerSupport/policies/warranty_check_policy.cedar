permit(
  principal,
  action == AgentCore::Action::"WarrantyCheck___check_warranty",
  resource == AgentCore::Gateway::"arn:aws:bedrock-agentcore:us-east-1:195675606509:gateway/customersupport-my-gateway-secure-5vhssihj27"
) when {
  principal is AgentCore::OAuthUser
};
