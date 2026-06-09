using System;
using System.Collections.Generic;
using ContosoUniversity.Data;
using ContosoUniversity.Models;
using ContosoUniversity.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace ContosoUniversity.Controllers
{
    public class NotificationsController : BaseController
    {
        public NotificationsController(SchoolContext db, NotificationService notificationService, ILogger<NotificationsController> logger)
            : base(db, notificationService, logger)
        {
        }

        // GET: api/notifications - Get pending notifications from Azure Service Bus
        [HttpGet]
        public IActionResult GetNotifications()
        {
            var notifications = new List<Notification>();

            try
            {
                // Peek up to 10 pending notifications from Azure Service Bus queue
                notifications = notificationService.GetPendingNotifications(10);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error retrieving notifications");
                return Json(new { success = false, message = "Error retrieving notifications" });
            }

            return Json(new
            {
                success = true,
                notifications = notifications,
                count = notifications.Count
            });
        }

        // POST: api/notifications/mark-read
        [HttpPost]
        public IActionResult MarkAsRead(int id)
        {
            try
            {
                notificationService.MarkAsRead(id);
                return Json(new { success = true });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error marking notification {NotificationId} as read", id);
                return Json(new { success = false, message = "Error updating notification" });
            }
        }

        // GET: Notifications/Index - Notification dashboard
        public IActionResult Index()
        {
            return View();
        }
    }
}
