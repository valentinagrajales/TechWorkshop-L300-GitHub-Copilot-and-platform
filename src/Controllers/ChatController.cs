using Microsoft.AspNetCore.Mvc;
using ZavaStorefront.Models;
using ZavaStorefront.Services;

namespace ZavaStorefront.Controllers
{
    public class ChatController : Controller
    {
        private readonly ILogger<ChatController> _logger;
        private readonly ChatService _chatService;
        private const string ChatHistorySessionKey = "ChatHistory";

        public ChatController(ILogger<ChatController> logger, ChatService chatService)
        {
            _logger = logger;
            _chatService = chatService;
        }

        public IActionResult Index()
        {
            _logger.LogInformation("Loading chat page");
            
            var viewModel = new ChatViewModel
            {
                Messages = GetChatHistory()
            };

            ViewBag.IsConfigured = _chatService.IsConfigured;
            return View(viewModel);
        }

        [HttpPost]
        public async Task<IActionResult> SendMessage([FromBody] ChatMessageRequest request)
        {
            if (string.IsNullOrWhiteSpace(request?.Message))
            {
                return BadRequest(new { error = "Message cannot be empty" });
            }

            _logger.LogInformation("Received chat message from user");

            var isSafe = await _chatService.IsContentSafeAsync(request.Message);
            if (!isSafe)
            {
                var warningMessage = new ChatMessage
                {
                    Role = "assistant",
                    Content = "Thanks for your message! I’m not able to help with that request. Please try a different question.",
                    Timestamp = DateTime.UtcNow
                };

                return Json(new
                {
                    assistantMessage = warningMessage
                });
            }

            var chatHistory = GetChatHistory();

            // Add user message to history
            var userMessage = new ChatMessage
            {
                Role = "user",
                Content = request.Message,
                Timestamp = DateTime.UtcNow
            };
            chatHistory.Add(userMessage);

            // Get response from Azure OpenAI
            var response = await _chatService.GetChatResponseAsync(chatHistory.Take(chatHistory.Count - 1).ToList(), request.Message);

            // Add assistant response to history
            var assistantMessage = new ChatMessage
            {
                Role = "assistant",
                Content = response,
                Timestamp = DateTime.UtcNow
            };
            chatHistory.Add(assistantMessage);

            // Save updated history to session
            SaveChatHistory(chatHistory);

            return Json(new { 
                userMessage = userMessage,
                assistantMessage = assistantMessage
            });
        }

        [HttpPost]
        public IActionResult ClearHistory()
        {
            _logger.LogInformation("Clearing chat history");
            HttpContext.Session.Remove(ChatHistorySessionKey);
            return RedirectToAction("Index");
        }

        private List<ChatMessage> GetChatHistory()
        {
            var historyJson = HttpContext.Session.GetString(ChatHistorySessionKey);
            if (string.IsNullOrEmpty(historyJson))
            {
                return new List<ChatMessage>();
            }

            try
            {
                return System.Text.Json.JsonSerializer.Deserialize<List<ChatMessage>>(historyJson) ?? new List<ChatMessage>();
            }
            catch
            {
                return new List<ChatMessage>();
            }
        }

        private void SaveChatHistory(List<ChatMessage> history)
        {
            // Keep only the last 50 messages to prevent session from growing too large
            if (history.Count > 50)
            {
                history = history.Skip(history.Count - 50).ToList();
            }

            var historyJson = System.Text.Json.JsonSerializer.Serialize(history);
            HttpContext.Session.SetString(ChatHistorySessionKey, historyJson);
        }
    }

    public class ChatMessageRequest
    {
        public string Message { get; set; } = string.Empty;
    }
}
