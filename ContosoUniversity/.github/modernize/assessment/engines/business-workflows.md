# Core Business Workflows

ContosoUniversity is a university management system that allows staff to manage students, instructors, courses, and departments, and tracks student enrolments and academic grades. Every data-change operation also emits a real-time notification to an administrative notification feed.

## Domain Entities

| Entity | Bounded Context | Description | Key Business Relationships |
|---|---|---|---|
| Student | Student Management | A person enrolled at the university, identified by name and enrolment date | Enrolled in many Courses via Enrolments; extends Person |
| Instructor | Academic Staff | A teaching staff member with a hire date | Assigned to many Courses (many-to-many); may have one OfficeAssignment; may administrate one Department; extends Person |
| Course | Academic Catalogue | A unit of study with a credit value and owning Department | Belongs to one Department; has many Student enrolments; taught by many Instructors |
| Department | Organisational Unit | An academic department with a budget and a designated administrator (Instructor) | Owns many Courses; has one optional administrator Instructor |
| Enrollment | Enrolment Record | The link between a Student and a Course, carrying an optional grade (A–F) | Joins Student to Course; grade is nullable (not yet graded) |
| CourseAssignment | Teaching Assignment | The many-to-many join between Instructors and Courses | Joins Instructor to Course |
| OfficeAssignment | Office Allocation | Associates a physical office location with an Instructor (one-to-one, optional) | Owned exclusively by one Instructor |
| Notification | Event Log | A transient audit event raised when any domain entity is created, updated, or deleted | Not linked to other entities; consumed by the notification feed |

## Service-to-Domain Mapping

ContosoUniversity is a monolithic application — there is a single deployable service. All bounded contexts share one database and one codebase.

| Service | Domain Context | Owned Entities | External Dependencies |
|---|---|---|---|
| ContosoUniversity Web App | Student Management | Student, Enrollment | SQL Server (via EF Core), MSMQ |
| ContosoUniversity Web App | Academic Catalogue | Course, CourseAssignment | SQL Server (via EF Core), MSMQ; filesystem (`~/Uploads/TeachingMaterials/`) for image uploads |
| ContosoUniversity Web App | Organisational Units | Department, Instructor, OfficeAssignment | SQL Server (via EF Core), MSMQ |
| ContosoUniversity Web App | Notification Feed | Notification | MSMQ (write on every CRUD operation; read via notification polling endpoint) |

## Primary Workflows

### Workflow 1: Enrol a Student

A new student is added to the university registry. This is a single-step form submission.

1. Staff navigates to `/Students/Create`.
2. The system displays an empty enrolment form.
3. Staff enters the student's last name, first name, and enrolment date, then submits.
4. ASP.NET MVC model binding populates a `Student` entity; `ModelState` validation runs.
5. If validation fails, the form is re-displayed with error messages.
6. If valid, the student record is persisted to `Person` (with `Discriminator = "Student"`).
7. A `CREATE` notification event is enqueued to MSMQ.
8. The browser is redirected to the student list.

### Workflow 2: Create a Course with Teaching Material

Creating a course includes an optional image upload for teaching materials.

1. Staff navigates to `/Courses/Create`.
2. The system displays the form with a dropdown of available Departments.
3. Staff enters Course ID (manually assigned — no auto-increment), title, credits, department, and optionally attaches an image file.
4. On submission, `ModelState` validation runs on the Course entity.
5. If an image was attached:
   - File extension must be `.jpg`, `.jpeg`, `.png`, `.gif`, or `.bmp`.
   - File size must not exceed 5 MB.
   - If either check fails, the form is re-displayed with a file-specific error.
   - If both checks pass, the file is saved to `~/Uploads/TeachingMaterials/` with a GUID-based filename, and the path is stored on the Course entity.
6. The course record is persisted to the `Course` table.
7. A `CREATE` notification event is enqueued to MSMQ.
8. The browser is redirected to the course list.

### Workflow 3: Update a Department (with Optimistic Concurrency)

Editing a department uses a `RowVersion` timestamp to prevent lost updates.

1. Staff navigates to `/Departments/Edit/{id}`.
2. The current department data — including the `RowVersion` token — is loaded from the database and presented in the form.
3. Staff modifies fields (name, budget, start date, administrator) and submits.
4. EF Core attaches the entity and checks that the stored `RowVersion` still matches.
5. **If no concurrent modification**: changes are saved, a `UPDATE` notification is enqueued, and the browser redirects to the list.
6. **If concurrent modification detected** (`DbUpdateConcurrencyException`):
   - If the row was deleted by another user: a model error "department was deleted" is shown.
   - If the row was updated by another user: field-level differences between the submitted values and the current database values are highlighted in the form, and staff must decide whether to re-submit with the latest values.
   - No changes are persisted; no notification is sent.

### Workflow 4: Assign Courses to an Instructor

When creating or editing an instructor, course assignments are managed as a checkbox list.

1. Staff navigates to `/Instructors/Create` or `/Instructors/Edit/{id}`.
2. The form includes checkboxes for every course in the catalogue, pre-checked for existing assignments.
3. On submission, the controller receives `string[] selectedCourses` alongside the instructor data.
4. The controller removes all existing `CourseAssignment` rows for this instructor and re-inserts only the newly selected set (replace-all strategy).
5. Office assignment is created or cleared based on whether a `Location` value was provided.
6. Changes are persisted atomically in one `SaveChanges()` call.
7. A `CREATE` or `UPDATE` notification is enqueued.

### Workflow 5: Notification Feed Polling

The browser polls the server periodically to surface recent audit events to the administrator.

1. The notification dashboard page (`/Notifications/Index`) loads a JavaScript poller.
2. Every interval the browser calls `GET /Notifications/GetNotifications`.
3. The server calls `NotificationService.ReceiveNotification()` up to 10 times, draining the MSMQ queue.
4. Collected notifications are returned as a JSON array.
5. If the queue is empty or the 1-second receive timeout elapses, an empty array is returned.
6. The browser renders the new notifications on the dashboard without a page reload.

## Cross-Service Data Flows

ContosoUniversity is a monolith — all data flows are in-process. There is no inter-service HTTP communication or message-driven composition.

The one intra-application asynchronous flow is the **CRUD → MSMQ → Notification dashboard** pipeline:

- **Producer side**: Every controller action that mutates data calls `BaseController.SendEntityNotification()`, which serialises a `Notification` object to JSON and enqueues it on the MSMQ private queue. This is fire-and-forget; the main operation is not blocked or rolled back if MSMQ fails.
- **Consumer side**: The `NotificationsController.GetNotifications()` endpoint synchronously drains the queue. There is no dedicated background worker; consumption only occurs when the notification dashboard is open and polling.
- **Fallback**: If MSMQ is unavailable (e.g., service not running on Linux), `NotificationService` construction throws and `BaseController` instantiation fails, taking the entire application offline. There is no graceful degradation.

## Business Workflow Sequence

```mermaid
sequenceDiagram
    participant Staff as "Staff (Browser)"
    participant Controller as "CoursesController"
    participant Validator as "ModelState Validation"
    participant FS as "File System"
    participant DB as "SQL Server"
    participant NotifSvc as "NotificationService"
    participant MSMQ as "MSMQ Queue"

    Staff->>Controller: POST /Courses/Create (form + optional image)
    Controller->>Validator: Validate Course model
    alt Validation fails
        Validator-->>Controller: ModelState invalid
        Controller-->>Staff: Re-display form with errors
    else Validation passes
        Validator-->>Controller: ModelState valid
        alt Image file attached
            Controller->>Controller: Check extension (jpg/jpeg/png/gif/bmp)
            Controller->>Controller: Check size (max 5 MB)
            alt File invalid
                Controller-->>Staff: Re-display form with file error
            else File valid
                Controller->>FS: Save to ~/Uploads/TeachingMaterials/<GUID>.ext
                FS-->>Controller: File path stored on entity
            end
        end
        Controller->>DB: INSERT Course (with optional image path)
        DB-->>Controller: Course saved
        Controller->>NotifSvc: SendNotification(Course, id, CREATE)
        NotifSvc->>MSMQ: Enqueue JSON notification message
        alt MSMQ available
            MSMQ-->>NotifSvc: Enqueued OK
        else MSMQ unavailable
            Note over NotifSvc: Exception swallowed; main operation succeeds
        end
        Controller-->>Staff: 302 Redirect to /Courses/Index
    end
```

## Business Rules & Decision Logic

### Validation Rules

| Entity | Rule | Enforcement Point |
|---|---|---|
| Student | LastName and FirstMidName required; max 50 characters each | `[Required]`, `[StringLength(50)]` on `Person`; `ModelState` in controller |
| Student | EnrollmentDate required; must be between 1753-01-01 and 9999-12-31 | `[Required]`, `[Range]` on `Student.EnrollmentDate`; `ModelState` |
| Instructor | HireDate required; must be between 1753-01-01 and 9999-12-31 | `[Required]`, `[Range]` on `Instructor.HireDate` |
| Course | Title required; 3–50 characters | `[StringLength(50, MinimumLength=3)]` |
| Course | Credits must be 0–5 | `[Range(0, 5)]` |
| Course | CourseID is manually assigned (no auto-increment) | `[DatabaseGenerated(None)]` |
| Course | TeachingMaterialImagePath max 255 characters | `[StringLength(255)]` |
| Course (image) | File extension must be jpg, jpeg, png, gif, or bmp | Inline check in `CoursesController.Create` and `Edit` |
| Course (image) | File size must be ≤ 5 MB | Inline check in `CoursesController.Create` and `Edit` |
| Department | Name required; 3–50 characters | `[StringLength(50, MinimumLength=3)]` |
| Department | Budget typed as currency (money column) | `[DataType(Currency)]`, `[Column(TypeName="money")]` |
| OfficeAssignment | Location max 50 characters | `[StringLength(50)]` |
| Notification | EntityType max 100 chars; EntityId max 50 chars; Message max 256 chars | `[StringLength]` annotations |

### State Transitions

Entities have no explicit state machine. The closest lifecycle is the **grade lifecycle on Enrollment**: a student's grade starts as `null` (not yet graded) and can be set to A, B, C, D, or F at any time. There is no workflow enforcing this transition; it is a direct field update.

### Business Constraints

- **Department optimistic concurrency**: A `RowVersion` timestamp prevents two users from simultaneously overwriting each other's department edits. The second save is rejected and the user must reconcile the conflict.
- **Course–Department association**: Every Course must belong to exactly one Department. The DepartmentID FK is required (non-nullable).
- **Instructor–Department administrator**: A Department's administrator is optional (`int? InstructorID`), allowing departments without a designated administrator.
- **CourseAssignment replace-all**: When editing an instructor's course list, the system deletes all existing assignments and re-inserts only the checked ones. There is no incremental add/remove.

### Notification Side-Effect

Every successful CRUD mutation on any domain entity triggers a fire-and-forget MSMQ notification. Failures in the notification path are silently logged via `Debug.WriteLine` and do not roll back the main database operation. There is no transaction spanning the EF Core `SaveChanges()` and the MSMQ `Send()` — a process crash between the two can result in a saved record with no corresponding notification.

### Cross-Cutting Concerns

- **Transactions**: Each controller action uses a single implicit EF Core `SaveChanges()` call — no explicit `TransactionScope` or `BeginTransaction()`. The MSMQ send is outside the EF transaction.
- **Error handling**: `DbUpdateConcurrencyException` is handled explicitly only in `DepartmentsController.Edit`. Other concurrency errors bubble up to the `HandleErrorAttribute` global filter, rendering the generic error page.
- **CSRF protection**: Write operations (`[HttpPost]` actions) are protected by `[ValidateAntiForgeryToken]`. The two JSON endpoints in `NotificationsController` use `[HttpPost]` but do not carry an anti-forgery token check.
- **Audit logging**: Notifications serve as a lightweight audit log, but they are ephemeral (stored in MSMQ, not persisted to the database) and are lost if the queue is not drained before restart.
- **Authorisation**: No role-based or attribute-based authorization is enforced at the application level. All workflows are accessible to any user.
