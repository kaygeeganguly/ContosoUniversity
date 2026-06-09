using System;
using System.Diagnostics;
using System.Linq;
using ContosoUniversity.Data;
using ContosoUniversity.Models;
using ContosoUniversity.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ContosoUniversity.Controllers
{
    public class StudentsController : BaseController
    {
        public StudentsController(SchoolContext context, NotificationService notificationService)
            : base(context, notificationService)
        {
        }

        public IActionResult Index(string sortOrder, string currentFilter, string searchString, int? page)
        {
            ViewBag.CurrentSort = sortOrder;
            ViewBag.NameSortParm = string.IsNullOrEmpty(sortOrder) ? "name_desc" : "";
            ViewBag.DateSortParm = sortOrder == "Date" ? "date_desc" : "Date";

            if (searchString != null)
            {
                page = 1;
            }
            else
            {
                searchString = currentFilter;
            }

            ViewBag.CurrentFilter = searchString;

            var students = from s in db.Students
                           select s;

            if (!string.IsNullOrEmpty(searchString))
            {
                students = students.Where(s => s.LastName.Contains(searchString)
                                               || s.FirstMidName.Contains(searchString));
            }

            students = sortOrder switch
            {
                "name_desc" => students.OrderByDescending(s => s.LastName),
                "Date" => students.OrderBy(s => s.EnrollmentDate),
                "date_desc" => students.OrderByDescending(s => s.EnrollmentDate),
                _ => students.OrderBy(s => s.LastName)
            };

            return View(PaginatedList<Student>.Create(students, page ?? 1, 10));
        }

        public IActionResult Details(int? id)
        {
            if (id == null)
            {
                return BadRequest();
            }

            var student = db.Students
                .Include(s => s.Enrollments)
                .ThenInclude(e => e.Course)
                .SingleOrDefault(s => s.ID == id);

            return student == null ? NotFound() : View(student);
        }

        public IActionResult Create()
        {
            return View(new Student { EnrollmentDate = DateTime.Today });
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Create([Bind("LastName,FirstMidName,EnrollmentDate")] Student student)
        {
            try
            {
                if (student.EnrollmentDate == DateTime.MinValue)
                {
                    ModelState.AddModelError("EnrollmentDate", "Please enter a valid enrollment date.");
                }

                if (student.EnrollmentDate < new DateTime(1753, 1, 1) || student.EnrollmentDate > new DateTime(9999, 12, 31))
                {
                    ModelState.AddModelError("EnrollmentDate", "Enrollment date must be between 1753 and 9999.");
                }

                if (!ModelState.IsValid)
                {
                    return View(student);
                }

                db.Students.Add(student);
                db.SaveChanges();

                var studentName = $"{student.FirstMidName} {student.LastName}";
                SendEntityNotification("Student", student.ID.ToString(), studentName, EntityOperation.CREATE);

                return RedirectToAction(nameof(Index));
            }
            catch (Exception ex)
            {
                Trace.TraceError($"Error creating student: {ex.Message} | Student: {student?.FirstMidName} {student?.LastName}");
                ModelState.AddModelError("", "Unable to save changes. Try again, and if the problem persists see your system administrator.");
                return View(student);
            }
        }

        public IActionResult Edit(int? id)
        {
            if (id == null)
            {
                return BadRequest();
            }

            var student = db.Students.Find(id);
            return student == null ? NotFound() : View(student);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public IActionResult Edit([Bind("ID,LastName,FirstMidName,EnrollmentDate")] Student student)
        {
            try
            {
                if (student.EnrollmentDate == DateTime.MinValue)
                {
                    ModelState.AddModelError("EnrollmentDate", "Please enter a valid enrollment date.");
                }

                if (student.EnrollmentDate < new DateTime(1753, 1, 1) || student.EnrollmentDate > new DateTime(9999, 12, 31))
                {
                    ModelState.AddModelError("EnrollmentDate", "Enrollment date must be between 1753 and 9999.");
                }

                if (!ModelState.IsValid)
                {
                    return View(student);
                }

                db.Entry(student).State = EntityState.Modified;
                db.SaveChanges();

                var studentName = $"{student.FirstMidName} {student.LastName}";
                SendEntityNotification("Student", student.ID.ToString(), studentName, EntityOperation.UPDATE);

                return RedirectToAction(nameof(Index));
            }
            catch (Exception ex)
            {
                Trace.TraceError($"Error editing student: {ex.Message} | Student ID: {student?.ID}");
                ModelState.AddModelError("", "Unable to save changes. Try again, and if the problem persists see your system administrator.");
                return View(student);
            }
        }

        public IActionResult Delete(int? id)
        {
            if (id == null)
            {
                return BadRequest();
            }

            var student = db.Students.Find(id);
            return student == null ? NotFound() : View(student);
        }

        [HttpPost, ActionName("Delete")]
        [ValidateAntiForgeryToken]
        public IActionResult DeleteConfirmed(int id)
        {
            try
            {
                var student = db.Students.Find(id);
                if (student == null)
                {
                    return NotFound();
                }

                var studentName = $"{student.FirstMidName} {student.LastName}";
                db.Students.Remove(student);
                db.SaveChanges();

                SendEntityNotification("Student", id.ToString(), studentName, EntityOperation.DELETE);
                return RedirectToAction(nameof(Index));
            }
            catch (Exception ex)
            {
                Trace.TraceError($"Error deleting student: {ex.Message} | Student ID: {id}");
                TempData["ErrorMessage"] = "Unable to delete the student. Try again, and if the problem persists see your system administrator.";
                return RedirectToAction(nameof(Index));
            }
        }
    }
}
