using System;
using ContosoUniversity.Data;
using ContosoUniversity.Models;
using ContosoUniversity.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace ContosoUniversity.Controllers
{
    public abstract class BaseController : Controller
    {
        protected readonly SchoolContext db;
        protected readonly NotificationService notificationService;
        protected readonly ILogger _logger;

        protected BaseController(SchoolContext db, NotificationService notificationService, ILogger logger)
        {
            this.db = db;
            this.notificationService = notificationService;
            this._logger = logger;
        }

        protected void SendEntityNotification(string entityType, string entityId, EntityOperation operation)
        {
            SendEntityNotification(entityType, entityId, null, operation);
        }

        protected void SendEntityNotification(string entityType, string entityId, string entityDisplayName, EntityOperation operation)
        {
            try
            {
                var userName = "System";
                notificationService.SendNotification(entityType, entityId, entityDisplayName, operation, userName);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to send notification for {EntityType} {EntityId}", entityType, entityId);
            }
        }

        protected override void Dispose(bool disposing)
        {
            // db and notificationService are managed by DI
            base.Dispose(disposing);
        }
    }
}
