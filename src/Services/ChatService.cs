using Azure;
using Azure.AI.OpenAI;
using OpenAI.Chat;
using ZavaStorefront.Models;

namespace ZavaStorefront.Services
{
    public class ChatService
    {
        private readonly IConfiguration _configuration;
        private readonly ILogger<ChatService> _logger;
        private readonly ChatClient? _chatClient;
        private readonly string _systemPrompt;

        public ChatService(IConfiguration configuration, ILogger<ChatService> logger)
        {
            _configuration = configuration;
            _logger = logger;

            // Read from environment variables (azd convention) or fallback to appsettings
            var endpoint = Environment.GetEnvironmentVariable("AZURE_OPENAI_ENDPOINT") 
                ?? _configuration["AzureOpenAI:Endpoint"];
            var apiKey = Environment.GetEnvironmentVariable("AZURE_OPENAI_API_KEY") 
                ?? _configuration["AzureOpenAI:ApiKey"];
            var deploymentName = Environment.GetEnvironmentVariable("AZURE_OPENAI_DEPLOYMENT_NAME") 
                ?? _configuration["AzureOpenAI:DeploymentName"] 
                ?? "gpt-4o";

            _systemPrompt = _configuration["AzureOpenAI:SystemPrompt"] 
                ?? "You are a helpful AI assistant for the Zava Storefront. Help customers with their questions about products, orders, and general inquiries.";

            if (string.IsNullOrEmpty(endpoint) || string.IsNullOrEmpty(apiKey))
            {
                _logger.LogWarning("Azure OpenAI configuration is missing. Chat functionality will be limited.");
                return;
            }

            try
            {
                var azureClient = new AzureOpenAIClient(new Uri(endpoint), new AzureKeyCredential(apiKey));
                _chatClient = azureClient.GetChatClient(deploymentName);
                _logger.LogInformation("Azure OpenAI ChatClient initialized successfully with deployment: {DeploymentName}", deploymentName);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to initialize Azure OpenAI ChatClient");
            }
        }

        public async Task<string> GetChatResponseAsync(List<Models.ChatMessage> conversationHistory, string userMessage)
        {
            if (_chatClient == null)
            {
                _logger.LogWarning("ChatClient is not configured. Returning fallback message.");
                return "I'm sorry, the chat service is not configured. Please contact support for assistance.";
            }

            try
            {
                var messages = new List<OpenAI.Chat.ChatMessage>
                {
                    new SystemChatMessage(_systemPrompt)
                };

                // Add conversation history
                foreach (var msg in conversationHistory)
                {
                    if (msg.Role.Equals("user", StringComparison.OrdinalIgnoreCase))
                    {
                        messages.Add(new UserChatMessage(msg.Content));
                    }
                    else if (msg.Role.Equals("assistant", StringComparison.OrdinalIgnoreCase))
                    {
                        messages.Add(new AssistantChatMessage(msg.Content));
                    }
                }

                // Add the new user message
                messages.Add(new UserChatMessage(userMessage));

                _logger.LogInformation("Sending chat request with {MessageCount} messages", messages.Count);

                var response = await _chatClient.CompleteChatAsync(messages);

                if (response?.Value?.Content != null && response.Value.Content.Count > 0)
                {
                    var assistantMessage = response.Value.Content[0].Text;
                    _logger.LogInformation("Received response from Azure OpenAI");
                    return assistantMessage ?? "I received an empty response. Please try again.";
                }

                return "I'm sorry, I couldn't generate a response. Please try again.";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error getting chat response from Azure OpenAI");
                return $"I'm sorry, an error occurred while processing your request. Please try again later.";
            }
        }

        public bool IsConfigured => _chatClient != null;
    }
}
