using System;
using System.IO;
using System.Linq;
using ContosoUniversity.Data;
using ContosoUniversity.Models;
using ContosoUniversity.Services;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Rendering;
using Microsoft.EntityFrameworkCore;

namespace ContosoUniversity.Controllers
{
    public class CoursesController : BaseController
    {
        private readonly IWebHostEnvironment _environment;

        public CoursesController(SchoolContext context, NotificationService notificationService, IWebHostEnvironment environment)
            : base(context, notificationService)
        {
            _environment = environment;
        }

        public IActionResult Index()
        {
            return View(db.Courses.Include(c => c.Department).ToList());
        }

        public IActionResult Details(int? id)
        {
            if (id == null)
            {
                return BadRequest();
            }

            var course = db.Courses.Include(c => c.Department).SingleOrDefault(c => c.CourseID == id);
            return course == null ? NotFound() : View(course);
        }

        public IActionResult Create()
        {
            ViewBag.DepartmentID = new SelectList(db.Departments, "DepartmentID", "Name");
            return View(new Course());
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Create([Bind("CourseID,Title,Credits,DepartmentID,TeachingMaterialImagePath")] Course course, IFormFile teachingMaterialImage)
        {
            if (!ModelState.IsValid)
            {
                ViewBag.DepartmentID = new SelectList(db.Departments, "DepartmentID", "Name", course.DepartmentID);
                return View(course);
            }

            if (!TrySaveTeachingMaterial(course, teachingMaterialImage))
            {
                ViewBag.DepartmentID = new SelectList(db.Departments, "DepartmentID", "Name", course.DepartmentID);
                return View(course);
            }

            db.Courses.Add(course);
            db.SaveChanges();
            SendEntityNotification("Course", course.CourseID.ToString(), course.Title, EntityOperation.CREATE);

            return RedirectToAction(nameof(Index));
        }

        public IActionResult Edit(int? id)
        {
            if (id == null)
            {
                return BadRequest();
            }

            var course = db.Courses.Find(id);
            if (course == null)
            {
                return NotFound();
            }

            ViewBag.DepartmentID = new SelectList(db.Departments, "DepartmentID", "Name", course.DepartmentID);
            return View(course);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Edit([Bind("CourseID,Title,Credits,DepartmentID,TeachingMaterialImagePath")] Course course, IFormFile teachingMaterialImage)
        {
            if (!ModelState.IsValid)
            {
                ViewBag.DepartmentID = new SelectList(db.Departments, "DepartmentID", "Name", course.DepartmentID);
                return View(course);
            }

            if (!TrySaveTeachingMaterial(course, teachingMaterialImage, deletePrevious: true))
            {
                ViewBag.DepartmentID = new SelectList(db.Departments, "DepartmentID", "Name", course.DepartmentID);
                return View(course);
            }

            db.Entry(course).State = EntityState.Modified;
            db.SaveChanges();
            SendEntityNotification("Course", course.CourseID.ToString(), course.Title, EntityOperation.UPDATE);

            return RedirectToAction(nameof(Index));
        }

        public IActionResult Delete(int? id)
        {
            if (id == null)
            {
                return BadRequest();
            }

            var course = db.Courses.Include(c => c.Department).SingleOrDefault(c => c.CourseID == id);
            return course == null ? NotFound() : View(course);
        }

        [HttpPost, ActionName("Delete")]
        [ValidateAntiForgeryToken]
        public IActionResult DeleteConfirmed(int id)
        {
            var course = db.Courses.Find(id);
            if (course == null)
            {
                return NotFound();
            }

            var courseTitle = course.Title;

            if (!string.IsNullOrEmpty(course.TeachingMaterialImagePath))
            {
                var filePath = MapRelativePathToPhysical(course.TeachingMaterialImagePath);
                if (System.IO.File.Exists(filePath))
                {
                    try
                    {
                        System.IO.File.Delete(filePath);
                    }
                    catch (Exception ex)
                    {
                        System.Diagnostics.Debug.WriteLine($"Error deleting file: {ex.Message}");
                    }
                }
            }

            db.Courses.Remove(course);
            db.SaveChanges();

            SendEntityNotification("Course", id.ToString(), courseTitle, EntityOperation.DELETE);
            return RedirectToAction(nameof(Index));
        }

        private bool TrySaveTeachingMaterial(Course course, IFormFile teachingMaterialImage, bool deletePrevious = false)
        {
            if (teachingMaterialImage == null || teachingMaterialImage.Length == 0)
            {
                return true;
            }

            var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".gif", ".bmp" };
            var fileExtension = Path.GetExtension(teachingMaterialImage.FileName).ToLowerInvariant();

            if (!allowedExtensions.Contains(fileExtension))
            {
                ModelState.AddModelError("teachingMaterialImage", "Please upload a valid image file (jpg, jpeg, png, gif, bmp).");
                return false;
            }

            if (teachingMaterialImage.Length > 5 * 1024 * 1024)
            {
                ModelState.AddModelError("teachingMaterialImage", "File size must be less than 5MB.");
                return false;
            }

            try
            {
                var uploadsPath = Path.Combine(_environment.ContentRootPath, "Uploads", "TeachingMaterials");
                if (!Directory.Exists(uploadsPath))
                {
                    Directory.CreateDirectory(uploadsPath);
                }

                if (deletePrevious && !string.IsNullOrEmpty(course.TeachingMaterialImagePath))
                {
                    var oldFilePath = MapRelativePathToPhysical(course.TeachingMaterialImagePath);
                    if (System.IO.File.Exists(oldFilePath))
                    {
                        System.IO.File.Delete(oldFilePath);
                    }
                }

                var fileName = $"course_{course.CourseID}_{Guid.NewGuid()}{fileExtension}";
                var filePath = Path.Combine(uploadsPath, fileName);

                using (var stream = new FileStream(filePath, FileMode.Create))
                {
                    teachingMaterialImage.CopyTo(stream);
                }

                course.TeachingMaterialImagePath = $"~/Uploads/TeachingMaterials/{fileName}";
                return true;
            }
            catch (Exception ex)
            {
                ModelState.AddModelError("teachingMaterialImage", "Error uploading file: " + ex.Message);
                return false;
            }
        }

        private string MapRelativePathToPhysical(string relativePath)
        {
            if (string.IsNullOrWhiteSpace(relativePath))
            {
                return string.Empty;
            }

            var normalizedPath = relativePath.TrimStart('~', '/').Replace('/', Path.DirectorySeparatorChar);
            return Path.Combine(_environment.ContentRootPath, normalizedPath);
        }
    }
}
