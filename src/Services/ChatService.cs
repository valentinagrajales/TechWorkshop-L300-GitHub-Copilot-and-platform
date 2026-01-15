using Azure.AI.ContentSafety;
using Azure.AI.ContentSafety.Models;
using Azure.AI.OpenAI;
using Azure.Identity;
using OpenAI.Chat;
using ZavaStorefront.Models;

namespace ZavaStorefront.Services
{
    public class ChatService
    {
        private readonly IConfiguration _configuration;
        private readonly ILogger<ChatService> _logger;
        private readonly ChatClient? _chatClient;
        private readonly ContentSafetyClient? _contentSafetyClient;
        private readonly string _systemPrompt;

        public ChatService(IConfiguration configuration, ILogger<ChatService> logger)
        {
            _configuration = configuration;
            _logger = logger;

            // Read from environment variables (azd convention) or fallback to appsettings
            var endpoint = Environment.GetEnvironmentVariable("AZURE_OPENAI_ENDPOINT") 
                ?? _configuration["AzureOpenAI:Endpoint"];
            var deploymentName = Environment.GetEnvironmentVariable("AZURE_OPENAI_DEPLOYMENT_NAME") 
                ?? _configuration["AzureOpenAI:DeploymentName"] 
                ?? "gpt-4o";
            var contentSafetyEndpoint = Environment.GetEnvironmentVariable("AZURE_CONTENT_SAFETY_ENDPOINT")
                ?? _configuration["AzureContentSafety:Endpoint"];

            // Get the managed identity client ID for User-Assigned Managed Identity
            var managedIdentityClientId = Environment.GetEnvironmentVariable("AZURE_CLIENT_ID");

            _systemPrompt = _configuration["AzureOpenAI:SystemPrompt"] 
                ?? "You are a helpful AI assistant for the Zava Storefront. Help customers with their questions about products, orders, and general inquiries.";

            var credential = string.IsNullOrEmpty(managedIdentityClientId)
                ? new DefaultAzureCredential()
                : new DefaultAzureCredential(new DefaultAzureCredentialOptions
                {
                    ManagedIdentityClientId = managedIdentityClientId
                });

            if (!string.IsNullOrEmpty(contentSafetyEndpoint))
            {
                try
                {
                    _contentSafetyClient = new ContentSafetyClient(new Uri(contentSafetyEndpoint), credential);
                    _logger.LogInformation("Azure AI Content Safety client initialized successfully");
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Failed to initialize Azure AI Content Safety client");
                }
            }
            else
            {
                _logger.LogWarning("Azure AI Content Safety endpoint is missing. Safety checks will block requests.");
            }

            if (string.IsNullOrEmpty(endpoint))
            {
                _logger.LogWarning("Azure OpenAI endpoint is missing. Chat functionality will be limited.");
                return;
            }

            try
            {
                // Use DefaultAzureCredential with User-Assigned Managed Identity for secure, keyless authentication
                var azureClient = new AzureOpenAIClient(new Uri(endpoint), credential);
                _chatClient = azureClient.GetChatClient(deploymentName);
                _logger.LogInformation("Azure OpenAI ChatClient initialized successfully with deployment: {DeploymentName} using Managed Identity", deploymentName);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to initialize Azure OpenAI ChatClient");
            }
        }

        public async Task<bool> IsContentSafeAsync(string userText)
        {
            if (_contentSafetyClient == null)
            {
                _logger.LogWarning("Content Safety client is not configured. Blocking request.");
                return false;
            }

            try
            {
                var options = new AnalyzeTextOptions(userText);
                var response = await _contentSafetyClient.AnalyzeTextAsync(options);
                var analyses = response.Value?.CategoriesAnalysis ?? Array.Empty<TextCategoryAnalysis>();

                var categoriesToCheck = new List<TextCategory>
                {
                    TextCategory.Violence,
                    TextCategory.Sexual,
                    TextCategory.Hate,
                    TextCategory.SelfHarm
                };

                if (Enum.TryParse<TextCategory>("Jailbreak", out var jailbreakCategory))
                {
                    categoriesToCheck.Add(jailbreakCategory);
                }
                else
                {
                    _logger.LogWarning("Content Safety SDK does not expose Jailbreak category; skipping jailbreak check.");
                }

                var severityByCategory = categoriesToCheck.ToDictionary(
                    category => category,
                    category => analyses.FirstOrDefault(a => a.Category == category)?.Severity ?? 0);

                var isUnsafe = severityByCategory.Values.Any(severity => severity >= 2);

                _logger.LogInformation(
                    "Content safety analysis result: {CategorySeverities}. Unsafe={IsUnsafe}",
                    string.Join(", ", severityByCategory.Select(kvp => $"{kvp.Key}:{kvp.Value}")),
                    isUnsafe);

                return !isUnsafe;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error analyzing content safety");
                return false;
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
