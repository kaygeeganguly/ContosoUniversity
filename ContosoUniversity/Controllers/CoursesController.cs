using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using ContosoUniversity.Data;
using ContosoUniversity.Models;
using ContosoUniversity.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace ContosoUniversity.Controllers
{
    public class CoursesController : BaseController
    {
        private readonly BlobStorageService _blobStorageService;

        public CoursesController(SchoolContext db, NotificationService notificationService, ILogger<CoursesController> logger, BlobStorageService blobStorageService)
            : base(db, notificationService, logger)
        {
            _blobStorageService = blobStorageService;
        }

        // GET: Courses
        public IActionResult Index()
        {
            var courses = db.Courses.Include(c => c.Department);
            return View(courses.ToList());
        }

        // GET: Courses/Details/5
        public IActionResult Details(int? id)
        {
            if (id == null)
            {
                return BadRequest();
            }
            Course course = db.Courses.Include(c => c.Department).Where(c => c.CourseID == id).SingleOrDefault();
            if (course == null)
            {
                return NotFound();
            }
            return View(course);
        }

        // GET: Courses/Create
        public IActionResult Create()
        {
            ViewBag.DepartmentID = new SelectList(db.Departments, "DepartmentID", "Name");
            return View(new Course());
        }

        // POST: Courses/Create
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Create([Bind("CourseID,Title,Credits,DepartmentID,TeachingMaterialImagePath")] Course course, IFormFile teachingMaterialImage)
        {
            if (ModelState.IsValid)
            {
                string uploadedBlobUrl = null;

                if (teachingMaterialImage != null && teachingMaterialImage.Length > 0)
                {
                    var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".gif", ".bmp" };
                    var fileExtension = Path.GetExtension(teachingMaterialImage.FileName).ToLower();

                    if (!Array.Exists(allowedExtensions, e => e == fileExtension))
                    {
                        ModelState.AddModelError("teachingMaterialImage", "Please upload a valid image file (jpg, jpeg, png, gif, bmp).");
                        ViewBag.DepartmentID = new SelectList(db.Departments, "DepartmentID", "Name", course.DepartmentID);
                        return View(course);
                    }

                    if (teachingMaterialImage.Length > 5 * 1024 * 1024)
                    {
                        ModelState.AddModelError("teachingMaterialImage", "File size must be less than 5MB.");
                        ViewBag.DepartmentID = new SelectList(db.Departments, "DepartmentID", "Name", course.DepartmentID);
                        return View(course);
                    }

                    try
                    {
                        var fileName = $"course_{course.CourseID}_{Guid.NewGuid()}{fileExtension}";
                        var contentType = GetContentType(fileExtension);

                        using var stream = teachingMaterialImage.OpenReadStream();
                        uploadedBlobUrl = await _blobStorageService.UploadBlobAsync(stream, fileName, contentType);
                        course.TeachingMaterialImagePath = uploadedBlobUrl;
                    }
                    catch (Exception ex)
                    {
                        ModelState.AddModelError("teachingMaterialImage", "Error uploading file: " + ex.Message);
                        ViewBag.DepartmentID = new SelectList(db.Departments, "DepartmentID", "Name", course.DepartmentID);
                        return View(course);
                    }
                }

                try
                {
                    db.Courses.Add(course);
                    await db.SaveChangesAsync();
                }
                catch (Exception dbEx)
                {
                    // MIGRATION NOTE: If the database save fails after a blob was uploaded, the blob
                    // will be orphaned in Azure Blob Storage. Clean up the orphaned blob to avoid
                    // storage waste.
                    if (uploadedBlobUrl != null)
                    {
                        try { await _blobStorageService.DeleteBlobAsync(uploadedBlobUrl); }
                        catch (Exception cleanupEx)
                        {
                            _logger.LogWarning(cleanupEx, "Failed to clean up orphaned blob {BlobUrl} after database save failure.", uploadedBlobUrl);
                        }
                    }
                    _logger.LogError(dbEx, "Failed to save course to database.");
                    ModelState.AddModelError("", "An error occurred while saving. Please try again.");
                    ViewBag.DepartmentID = new SelectList(db.Departments, "DepartmentID", "Name", course.DepartmentID);
                    return View(course);
                }

                SendEntityNotification("Course", course.CourseID.ToString(), course.Title, EntityOperation.CREATE);

                return RedirectToAction("Index");
            }

            ViewBag.DepartmentID = new SelectList(db.Departments, "DepartmentID", "Name", course.DepartmentID);
            return View(course);
        }

        // GET: Courses/Edit/5
        public IActionResult Edit(int? id)
        {
            if (id == null)
            {
                return BadRequest();
            }
            Course course = db.Courses.Find(id);
            if (course == null)
            {
                return NotFound();
            }
            ViewBag.DepartmentID = new SelectList(db.Departments, "DepartmentID", "Name", course.DepartmentID);
            return View(course);
        }

        // POST: Courses/Edit/5
        [HttpPost]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> Edit([Bind("CourseID,Title,Credits,DepartmentID,TeachingMaterialImagePath")] Course course, IFormFile teachingMaterialImage)
        {
            if (ModelState.IsValid)
            {
                string newBlobUrl = null;
                string oldBlobUrl = course.TeachingMaterialImagePath;

                if (teachingMaterialImage != null && teachingMaterialImage.Length > 0)
                {
                    var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".gif", ".bmp" };
                    var fileExtension = Path.GetExtension(teachingMaterialImage.FileName).ToLower();

                    if (!Array.Exists(allowedExtensions, e => e == fileExtension))
                    {
                        ModelState.AddModelError("teachingMaterialImage", "Please upload a valid image file (jpg, jpeg, png, gif, bmp).");
                        ViewBag.DepartmentID = new SelectList(db.Departments, "DepartmentID", "Name", course.DepartmentID);
                        return View(course);
                    }

                    if (teachingMaterialImage.Length > 5 * 1024 * 1024)
                    {
                        ModelState.AddModelError("teachingMaterialImage", "File size must be less than 5MB.");
                        ViewBag.DepartmentID = new SelectList(db.Departments, "DepartmentID", "Name", course.DepartmentID);
                        return View(course);
                    }

                    try
                    {
                        var fileName = $"course_{course.CourseID}_{Guid.NewGuid()}{fileExtension}";
                        var contentType = GetContentType(fileExtension);

                        using var stream = teachingMaterialImage.OpenReadStream();
                        newBlobUrl = await _blobStorageService.UploadBlobAsync(stream, fileName, contentType);
                        course.TeachingMaterialImagePath = newBlobUrl;
                    }
                    catch (Exception ex)
                    {
                        ModelState.AddModelError("teachingMaterialImage", "Error uploading file: " + ex.Message);
                        ViewBag.DepartmentID = new SelectList(db.Departments, "DepartmentID", "Name", course.DepartmentID);
                        return View(course);
                    }
                }

                try
                {
                    db.Entry(course).State = EntityState.Modified;
                    await db.SaveChangesAsync();
                }
                catch (Exception dbEx)
                {
                    // MIGRATION NOTE: If the database save fails after a new blob was uploaded,
                    // clean up the orphaned new blob to keep storage consistent.
                    if (newBlobUrl != null)
                    {
                        try { await _blobStorageService.DeleteBlobAsync(newBlobUrl); }
                        catch (Exception cleanupEx)
                        {
                            _logger.LogWarning(cleanupEx, "Failed to clean up orphaned blob {BlobUrl} after database save failure.", newBlobUrl);
                        }
                    }
                    _logger.LogError(dbEx, "Failed to update course in database.");
                    ModelState.AddModelError("", "An error occurred while saving. Please try again.");
                    ViewBag.DepartmentID = new SelectList(db.Departments, "DepartmentID", "Name", course.DepartmentID);
                    return View(course);
                }

                // Delete the old blob after the database is successfully updated
                if (newBlobUrl != null && !string.IsNullOrEmpty(oldBlobUrl))
                {
                    try { await _blobStorageService.DeleteBlobAsync(oldBlobUrl); }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, "Failed to delete old teaching material blob {BlobUrl} after course update.", oldBlobUrl);
                    }
                }

                SendEntityNotification("Course", course.CourseID.ToString(), course.Title, EntityOperation.UPDATE);

                return RedirectToAction("Index");
            }
            ViewBag.DepartmentID = new SelectList(db.Departments, "DepartmentID", "Name", course.DepartmentID);
            return View(course);
        }

        // GET: Courses/Delete/5
        public IActionResult Delete(int? id)
        {
            if (id == null)
            {
                return BadRequest();
            }
            Course course = db.Courses.Include(c => c.Department).Where(c => c.CourseID == id).SingleOrDefault();
            if (course == null)
            {
                return NotFound();
            }
            return View(course);
        }

        // POST: Courses/Delete/5
        [HttpPost, ActionName("Delete")]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> DeleteConfirmed(int id)
        {
            Course course = db.Courses.Find(id);
            var courseTitle = course.Title;
            var blobUrl = course.TeachingMaterialImagePath;

            // Remove the course record from the database first to ensure data consistency.
            // The blob cleanup follows; if blob deletion fails, the record is already removed
            // and the orphaned blob can be cleaned up separately.
            db.Courses.Remove(course);
            await db.SaveChangesAsync();

            SendEntityNotification("Course", id.ToString(), courseTitle, EntityOperation.DELETE);

            // Delete associated teaching material blob from Azure Blob Storage after DB removal
            if (!string.IsNullOrEmpty(blobUrl))
            {
                try
                {
                    await _blobStorageService.DeleteBlobAsync(blobUrl);
                }
                catch (Exception ex)
                {
                    _logger.LogWarning(ex, "Failed to delete teaching material blob {BlobUrl} for deleted course {CourseId}", blobUrl, id);
                }
            }

            return RedirectToAction("Index");
        }

        /// <summary>
        /// Maps a file extension to the corresponding MIME content type.
        /// </summary>
        private static string GetContentType(string fileExtension)
        {
            return fileExtension.ToLower() switch
            {
                ".jpg" or ".jpeg" => "image/jpeg",
                ".png" => "image/png",
                ".gif" => "image/gif",
                ".bmp" => "image/bmp",
                _ => "application/octet-stream"
            };
        }
    }
}