using System;
using System.Collections.Generic;
using System.Text.Json;
using Azure.Identity;
using Azure.Messaging.ServiceBus;
using ContosoUniversity.Models;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace ContosoUniversity.Services
{
    public class NotificationService : IDisposable
    {
        private readonly ServiceBusClient _serviceBusClient;
        private readonly string _queueName;
        private readonly ILogger<NotificationService> _logger;

        public NotificationService(IConfiguration configuration, ILogger<NotificationService> logger)
        {
            _logger = logger;
            var fullyQualifiedNamespace = configuration["AzureServiceBus:FullyQualifiedNamespace"];
            if (string.IsNullOrWhiteSpace(fullyQualifiedNamespace))
                throw new InvalidOperationException("AzureServiceBus:FullyQualifiedNamespace configuration value is required.");

            _queueName = configuration["AzureServiceBus:QueueName"];
            if (string.IsNullOrWhiteSpace(_queueName))
                _queueName = "contoso-notifications";

            _serviceBusClient = new ServiceBusClient(fullyQualifiedNamespace, new DefaultAzureCredential());
        }

        public void SendNotification(string entityType, string entityId, EntityOperation operation, string userName = null)
        {
            SendNotification(entityType, entityId, null, operation, userName);
        }

        public void SendNotification(string entityType, string entityId, string entityDisplayName, EntityOperation operation, string userName = null)
        {
            try
            {
                var notification = new Notification
                {
                    EntityType = entityType,
                    EntityId = entityId,
                    Operation = operation.ToString(),
                    Message = GenerateMessage(entityType, entityId, entityDisplayName, operation),
                    CreatedAt = DateTime.UtcNow,
                    CreatedBy = userName ?? "System",
                    IsRead = false
                };

                var body = JsonSerializer.Serialize(notification);
                var message = new ServiceBusMessage(body);

                // Fire-and-forget: notifications must not block the main business operation.
                // Task.Run ensures proper async execution and sender disposal via await using.
                _ = System.Threading.Tasks.Task.Run(async () =>
                {
                    try
                    {
                        await using var sender = _serviceBusClient.CreateSender(_queueName);
                        await sender.SendMessageAsync(message);
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, "Failed to send notification to Service Bus for {EntityType} {EntityId}", entityType, entityId);
                    }
                });
            }
            catch (Exception ex)
            {
                // Log error but don't break the main operation
                _logger.LogError(ex, "Failed to send notification for {EntityType} {EntityId} operation {Operation}", entityType, entityId, operation);
            }
        }

        public Notification ReceiveNotification()
        {
            try
            {
                // CreateReceiver returns a receiver; use a local variable so we can dispose it after use
                var receiver = _serviceBusClient.CreateReceiver(_queueName);
                var receivedMessage = receiver.ReceiveMessageAsync().GetAwaiter().GetResult();
                if (receivedMessage == null)
                {
                    receiver.DisposeAsync().GetAwaiter().GetResult();
                    return null;
                }

                receiver.CompleteMessageAsync(receivedMessage).GetAwaiter().GetResult();
                var notification = JsonSerializer.Deserialize<Notification>(receivedMessage.Body.ToString());
                receiver.DisposeAsync().GetAwaiter().GetResult();
                return notification;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to receive notification");
                return null;
            }
        }

        public List<Notification> GetPendingNotifications(int maxCount = 10)
        {
            var notifications = new List<Notification>();
            try
            {
                var receiver = _serviceBusClient.CreateReceiver(_queueName);
                try
                {
                    var messages = receiver.PeekMessagesAsync(maxCount).GetAwaiter().GetResult();
                    foreach (var msg in messages)
                    {
                        try
                        {
                            var notification = JsonSerializer.Deserialize<Notification>(msg.Body.ToString());
                            if (notification != null)
                                notifications.Add(notification);
                        }
                        catch (Exception ex)
                        {
                            _logger.LogWarning(ex, "Failed to deserialize notification message with SequenceNumber {SequenceNumber}", msg.SequenceNumber);
                        }
                    }
                }
                finally
                {
                    receiver.DisposeAsync().GetAwaiter().GetResult();
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to get pending notifications from Service Bus queue");
            }
            return notifications;
        }

        public void MarkAsRead(int notificationId)
        {
            // In Azure Service Bus, receiving and completing a message removes it from the queue
            // (FIFO order), which is equivalent to acknowledging the oldest unread notification.
            // The notificationId parameter is present for API compatibility.
            try
            {
                var receiver = _serviceBusClient.CreateReceiver(_queueName);
                try
                {
                    var receivedMessage = receiver.ReceiveMessageAsync(TimeSpan.FromSeconds(5)).GetAwaiter().GetResult();
                    if (receivedMessage != null)
                        receiver.CompleteMessageAsync(receivedMessage).GetAwaiter().GetResult();
                }
                finally
                {
                    receiver.DisposeAsync().GetAwaiter().GetResult();
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to mark notification {NotificationId} as read", notificationId);
            }
        }

        private string GenerateMessage(string entityType, string entityId, string entityDisplayName, EntityOperation operation)
        {
            var displayText = !string.IsNullOrWhiteSpace(entityDisplayName)
                ? $"{entityType} '{entityDisplayName}'"
                : $"{entityType} (ID: {entityId})";

            switch (operation)
            {
                case EntityOperation.CREATE:
                    return $"New {displayText} has been created";
                case EntityOperation.UPDATE:
                    return $"{displayText} has been updated";
                case EntityOperation.DELETE:
                    return $"{displayText} has been deleted";
                default:
                    return $"{displayText} operation: {operation}";
            }
        }

        public void Dispose()
        {
            _serviceBusClient?.DisposeAsync().GetAwaiter().GetResult();
        }
    }
}
