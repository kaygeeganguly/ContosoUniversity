# Core Business Workflows

ContosoUniversity is a university student management system that enables administrators to manage students, instructors, courses, departments, and enrollment records, while broadcasting audit notifications for every data-change operation.

## Domain Entities

| Entity | Service / Bounded Context | Description | Key Relationships |
|---|---|---|---|
| Student | Academic Records | A person enrolled in the university; tracked by enrollment date | Inherits from Person; has many Enrollments |
| Instructor | Academic Records | A person employed by the university as a teacher; tracked by hire date | Inherits from Person; teaches many Courses via CourseAssignment; optionally has one OfficeAssignment |
| Person | Identity | Abstract base for Student and Instructor using Table-Per-Hierarchy; stores shared identity data | Parent of Student and Instructor |
| Course | Curriculum | A unit of study with a credit value, assigned to one Department | Belongs to one Department; enrolled by many Students via Enrollment; taught by many Instructors via CourseAssignment |
| Department | Organizational | An academic department with a budget and a designated administrator (Instructor) | Has many Courses; administered by one Instructor |
| Enrollment | Academic Records | A record of a Student taking a Course, with an optional Grade | Links Student to Course; carries a nullable Grade (A–F) |
| CourseAssignment | Curriculum | A many-to-many join record linking Instructors to the Courses they teach | Links Instructor to Course |
| OfficeAssignment | Facilities | An optional one-to-one office location record for an Instructor | Belongs to exactly one Instructor |
| Notification | Audit/Messaging | An audit event record generated when any entity is created, updated, or deleted | Standalone; not related to other entities via FK |

## Service-to-Domain Mapping

ContosoUniversity is a single-module monolith with no microservice decomposition. All domain contexts are owned by the single application.

| Service | Domain Context | Owned Entities | External Dependencies |
|---|---|---|---|
| ContosoUniversity | Academic Records | Student, Instructor, Person, Enrollment | SQL Server (via EF Core) |
| ContosoUniversity | Curriculum Management | Course, Department, CourseAssignment | SQL Server (via EF Core) |
| ContosoUniversity | Facilities | OfficeAssignment | SQL Server (via EF Core) |
| ContosoUniversity | Audit / Notifications | Notification (MSMQ payload) | Windows MSMQ private queue |

## Primary Workflows

### Workflow 1: Student Enrollment Management

An administrator browses the paginated student list, searches and sorts by name or enrollment date, then creates, edits, or deletes student records.

**Steps:**
1. Admin opens `/Students` — system queries the Person table (Discriminator = 'Student'), applies optional name-contains search filter, applies column sort (LastName or EnrollmentDate), and returns a paginated result (page size: 10).
2. Admin submits the create/edit form — system validates bound fields (LastName, FirstMidName required max 50 chars; EnrollmentDate required, must be between 1/1/1753 and 12/31/9999).
3. On successful save, EF Core persists the INSERT/UPDATE to the Person table and calls `SendEntityNotification("Student", id, CREATE|UPDATE)`.
4. `NotificationService` serializes a `Notification` payload to JSON and enqueues it to the MSMQ private queue.
5. On delete, the system performs a database-level cascaded removal of all linked Enrollments, then deletes the Person row.

### Workflow 2: Course and Teaching Material Management

An administrator manages course records including optional teaching material file uploads.

**Steps:**
1. Admin opens `/Courses` — system loads all courses with their Department (eager-loaded via `Include`).
2. Admin creates or edits a course, optionally uploading a teaching material image file.
3. If a file is uploaded, the server saves it to the filesystem under `~/UploadedFiles/` (or similar server-mapped path) and stores the path in `TeachingMaterialImagePath`.
4. System validates: CourseID is user-assigned (not database-generated); Title 3–50 chars; Credits 0–5; DepartmentID required.
5. On save, an audit notification is enqueued.

### Workflow 3: Department Administration

An administrator manages departments including budget allocation and administrator assignment, with optimistic concurrency protection on updates.

**Steps:**
1. Admin views the department list with administrator name (Instructor) loaded via `Include("Administrator")`.
2. Admin edits a department — the form carries a hidden `RowVersion` timestamp byte array for concurrency control.
3. On POST, EF Core issues an UPDATE with a `WHERE RowVersion = <original>` clause. If another user modified the record concurrently, EF Core throws a `DbUpdateConcurrencyException`.
4. The controller catches the concurrency exception and redisplays the form with a conflict message, showing the database values versus the current user's values.
5. Admin either retries with refreshed values or overwrites.

### Workflow 4: Instructor and Course Assignment

An administrator manages instructors, their office locations, and which courses they teach.

**Steps:**
1. Admin opens `/Instructors` with optional drill-down by instructor ID or course ID — the index eagerly loads instructors → CourseAssignments → Course → Enrollments in one chained `Include` query.
2. On create/edit, the form presents a checkbox list of all courses (`AssignedCourseData` view model).
3. On POST, the controller receives `string[] selectedCourses`; it diffing the new set against the existing `CourseAssignment` rows and adds/removes join records accordingly.
4. `OfficeAssignment` is updated or created in the same `SaveChanges()` call.

### Workflow 5: Notification Polling and Display

Administrators can view recent audit events from the MSMQ notification queue.

**Steps:**
1. The notification dashboard (`/Notifications/Index`) renders a page that uses JavaScript to poll `/Notifications/GetNotifications`.
2. The JSON endpoint drains up to 10 messages from the MSMQ queue synchronously (1-second receive timeout per message).
3. Messages are deserialized from JSON and returned as a JSON array.
4. Admin can trigger `POST /Notifications/MarkAsRead` — currently a no-op stub (no persistence of read status).

## Cross-Service Data Flows

ContosoUniversity is a monolith with no cross-service data flows. All data is read and written within a single application process against a single SQL Server database.

The one notable cross-boundary flow is the **write-path notification side-effect**: after every entity mutation (student, course, department, instructor created/updated/deleted), the controller calls `BaseController.SendEntityNotification()`, which invokes `NotificationService.SendNotification()` to enqueue a JSON message to MSMQ. This is a fire-and-forget side-effect — the MSMQ write is wrapped in a try/catch, so failures are silently logged and do not roll back the database transaction.

**Fallback behavior**: If MSMQ is unavailable (service not running, queue path wrong, Windows permissions denied), the `NotificationService` constructor throws on startup (queue creation/access fails) and the application pool crashes. There is no resilience, retry, or graceful degradation for the MSMQ dependency.

## Business Workflow Sequence

```mermaid
sequenceDiagram
    participant Admin as "Administrator"
    participant MVC as "MVC Controller"
    participant EF as "SchoolContext"
    participant DB as "SQL Server"
    participant NS as "NotificationService"
    participant MQ as "MSMQ Queue"

    Admin->>MVC: GET /Students (searchString, sortOrder, page)
    MVC->>EF: Students.Where(filter).OrderBy().Skip/Take
    EF->>DB: SELECT Person WHERE Discriminator=Student
    DB-->>EF: Student rows
    EF-->>MVC: PaginatedList
    MVC-->>Admin: Student list page

    Admin->>MVC: POST /Students/Create (LastName, FirstMidName, EnrollmentDate)
    MVC->>MVC: Validate model (required fields, date range)
    alt Validation fails
        MVC-->>Admin: Redisplay form with validation errors
    else Validation passes
        MVC->>EF: Students.Add(student); SaveChanges()
        EF->>DB: INSERT INTO Person (Discriminator=Student, ...)
        DB-->>EF: Generated ID
        EF-->>MVC: Success
        MVC->>NS: SendEntityNotification("Student", id, CREATE)
        NS->>MQ: Queue.Send JSON notification
        alt MSMQ available
            MQ-->>NS: OK
        else MSMQ unavailable
            Note over NS: Exception caught, logged via Debug.WriteLine
        end
        MVC-->>Admin: 302 Redirect to /Students
    end

    Admin->>MVC: POST /Departments/Edit (DepartmentID, ..., RowVersion)
    MVC->>EF: Attach department with original RowVersion; SaveChanges()
    EF->>DB: UPDATE Department WHERE RowVersion = original
    alt No concurrent modification
        DB-->>EF: 1 row updated
        EF-->>MVC: Success
        MVC-->>Admin: 302 Redirect to /Departments
    else Concurrent modification detected
        DB-->>EF: 0 rows updated
        EF-->>MVC: DbUpdateConcurrencyException
        MVC-->>Admin: Redisplay form with conflict warning
    end
```

## Business Rules & Decision Logic

### Validation Rules

| Entity / Operation | Rule | Enforcement |
|---|---|---|
| Student.LastName | Required; max 50 characters | `[Required][StringLength(50)]` data annotation; server-side ModelState; client-side jQuery Validation |
| Student.FirstMidName | Required; max 50 characters | Same as above |
| Student.EnrollmentDate | Required; must be between 1/1/1753 and 12/31/9999 | `[Required][Range(DateTime, ...)]` annotation |
| Instructor.HireDate | Required; must be between 1/1/1753 and 12/31/9999 | `[Required][Range(DateTime, ...)]` annotation |
| Course.Title | 3–50 characters | `[StringLength(50, MinimumLength=3)]` |
| Course.Credits | 0–5 | `[Range(0, 5)]` |
| Course.CourseID | User-assigned (not auto-generated) | `[DatabaseGenerated(None)]`; user must supply a non-zero integer |
| Department.Name | 3–50 characters | `[StringLength(50, MinimumLength=3)]` |
| Department.Budget | Decimal / money column | No range constraint; column type `money` |
| OfficeAssignment.Location | Max 50 characters | `[StringLength(50)]` |
| Notification fields | EntityType max 100, EntityId max 50, Operation max 20, Message max 256 | `[StringLength(...)]` annotations |

### State Transitions

**Enrollment Grade**: The `Grade` field is a nullable enum (A, B, C, D, F). `null` means "not yet graded" (displayed as "No grade"). There are no formal state transition guards — the grade can be set or cleared at any time via the edit form.

**Notification IsRead**: Notifications have an `IsRead` boolean and a nullable `ReadAt` timestamp. The `MarkAsRead` endpoint is a stub that does not actually persist the read status — the transition from unread → read is not implemented.

### Business Constraints

- **Optimistic concurrency on Departments**: The `RowVersion` (`[Timestamp]`) byte array is checked on every UPDATE. Concurrent edits to the same department will cause the second writer to receive a concurrency conflict error requiring them to review and retry.
- **Pagination cap**: Student list is hard-coded to page size 10; no configuration to change this.
- **Notification queue cap**: The polling endpoint reads at most 10 notifications per call to prevent overwhelming the UI.
- **File upload size**: `maxRequestLength = 10 MB` (Web.config); `maxAllowedContentLength = 10 MB` (IIS) limit teaching material image uploads.
- **CourseAssignment diffing**: When editing an instructor's course assignments, the controller manually diffs the submitted checkbox selection against the current database rows and adds/removes join records — there is no bulk-replace; only the delta is written.

### Transaction Boundaries

All EF Core operations use implicit transactions via `DbContext.SaveChanges()`. Each controller action calls `SaveChanges()` at most once per request — there are no multi-step saga patterns, `TransactionScope`, or distributed transactions. The MSMQ notification dispatch is outside the EF Core transaction; a MSMQ failure after a successful `SaveChanges()` results in a lost notification (no outbox pattern, no compensating action).

### Error Handling

- `HandleErrorAttribute` is registered globally and catches unhandled MVC exceptions, redirecting to the Error view.
- MSMQ errors in `NotificationService` are caught and logged to `Debug.WriteLine` — they do not surface to the user.
- EF Core `DbUpdateConcurrencyException` is caught in `DepartmentsController.Edit` and results in a user-visible conflict message.
- No custom business exception types or dead-letter queue handling are implemented.

### Authorization

No authentication or authorization is implemented. All workflows are accessible to any anonymous user. The `HomeController.Unauthorized` action exists but is never invoked by any authorization rule — it is a placeholder only.
