using Azure.Identity;
using Azure.Messaging.ServiceBus;
using ContosoUniversity.Models;
using System.Text.Json;

namespace ContosoUniversity.Services
{
    public class NotificationService : IDisposable, IAsyncDisposable
    {
        private const string QueueName = "ContosoUniversityNotifications";
        private readonly ServiceBusClient _client;
        private readonly ServiceBusSender _sender;
        private bool _disposed;

        public NotificationService(IConfiguration configuration)
        {
            var fullyQualifiedNamespace = configuration["AzureServiceBus:FullyQualifiedNamespace"]
                ?? throw new InvalidOperationException("AzureServiceBus:FullyQualifiedNamespace is not configured.");
            var credential = new DefaultAzureCredential();
            _client = new ServiceBusClient(fullyQualifiedNamespace, credential);
            _sender = _client.CreateSender(QueueName);
        }

        public void SendNotification(string entityType, string entityId, EntityOperation operation, string? userName = null)
        {
            SendNotification(entityType, entityId, null, operation, userName);
        }

        public void SendNotification(string entityType, string entityId, string? entityDisplayName, EntityOperation operation, string? userName = null)
        {
            try
            {
                var notification = new Notification
                {
                    EntityType = entityType,
                    EntityId = entityId,
                    Operation = operation.ToString(),
                    Message = GenerateMessage(entityType, entityId, entityDisplayName, operation),
                    CreatedAt = DateTime.Now,
                    CreatedBy = userName ?? "System",
                    IsRead = false
                };

                var body = JsonSerializer.Serialize(notification);
                var message = new ServiceBusMessage(body);

                // Fire-and-forget: send asynchronously without blocking the caller
                _ = _sender.SendMessageAsync(message).ContinueWith(t =>
                {
                    if (t.IsFaulted)
                    {
                        System.Diagnostics.Debug.WriteLine($"Failed to send notification: {t.Exception?.GetBaseException().Message}");
                    }
                }, TaskScheduler.Default);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Failed to send notification: {ex.Message}");
            }
        }

        public async Task<Notification?> ReceiveNotification()
        {
            try
            {
                await using var receiver = _client.CreateReceiver(QueueName);
                var receivedMessage = await receiver.ReceiveMessageAsync(TimeSpan.FromSeconds(1));

                if (receivedMessage == null)
                    return null;

                var notification = JsonSerializer.Deserialize<Notification>(receivedMessage.Body.ToString());
                await receiver.CompleteMessageAsync(receivedMessage);
                return notification;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Failed to receive notification: {ex.Message}");
                return null;
            }
        }

        public void MarkAsRead(int notificationId)
        {
            // Messages received from Azure Service Bus are acknowledged (completed) upon receipt.
            // This method is retained for API compatibility.
        }

        private string GenerateMessage(string entityType, string entityId, string? entityDisplayName, EntityOperation operation)
        {
            var displayText = !string.IsNullOrWhiteSpace(entityDisplayName)
                ? $"{entityType} '{entityDisplayName}'"
                : $"{entityType} (ID: {entityId})";

            return operation switch
            {
                EntityOperation.CREATE => $"New {displayText} has been created",
                EntityOperation.UPDATE => $"{displayText} has been updated",
                EntityOperation.DELETE => $"{displayText} has been deleted",
                _ => $"{displayText} operation: {operation}"
            };
        }

        public void Dispose()
        {
            DisposeAsync().AsTask().GetAwaiter().GetResult();
        }

        public async ValueTask DisposeAsync()
        {
            if (!_disposed)
            {
                await _sender.DisposeAsync();
                await _client.DisposeAsync();
                _disposed = true;
            }
        }
    }
}
