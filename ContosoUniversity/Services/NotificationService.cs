using System.Collections.Concurrent;
using ContosoUniversity.Models;
using Microsoft.Extensions.Configuration;
using Newtonsoft.Json;

namespace ContosoUniversity.Services
{
    public class NotificationService
    {
        private readonly ConcurrentQueue<string> _queue = new ConcurrentQueue<string>();
        private readonly int _maxQueueLength;

        public NotificationService(IConfiguration configuration)
        {
            _maxQueueLength = configuration.GetValue<int?>("NotificationSettings:MaxQueueLength") ?? 200;
        }

        public void SendNotification(string entityType, string entityId, EntityOperation operation, string userName = null)
        {
            SendNotification(entityType, entityId, null, operation, userName);
        }

        public void SendNotification(string entityType, string entityId, string entityDisplayName, EntityOperation operation, string userName = null)
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

            _queue.Enqueue(JsonConvert.SerializeObject(notification));
            while (_queue.Count > _maxQueueLength)
            {
                _queue.TryDequeue(out _);
            }
        }

        public Notification ReceiveNotification()
        {
            if (!_queue.TryDequeue(out var json))
            {
                return null;
            }

            return JsonConvert.DeserializeObject<Notification>(json);
        }

        public void MarkAsRead(int notificationId)
        {
        }

        private static string GenerateMessage(string entityType, string entityId, string entityDisplayName, EntityOperation operation)
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
    }
}
