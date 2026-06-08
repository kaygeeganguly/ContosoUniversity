# Core Business Workflows

ContosoUniversity is a university administration system that manages the complete academic lifecycle: registering students, maintaining instructor assignments, organizing courses across departments, tracking student enrollments, and notifying administrators of entity changes.

## Domain Entities

| Entity | Bounded Context | Description | Key Relationships |
|--------|----------------|-------------|------------------|
| Student | Enrollment Management | A person enrolled at the university; tracks enrollment date and academic records | Has many Enrollments; inherits from Person |
| Instructor | Faculty Management | A faculty member employed at the university; tracks hire date, office location, and course assignments | Has many CourseAssignments; has one OfficeAssignment; inherits from Person |
| Person | Identity | Abstract base representing any person (student or instructor) with a name | Base of Student and Instructor (TPH inheritance) |
| Course | Academic Catalog | An academic course with a credit value belonging to a department; may include teaching material images | Belongs to one Department; has many Enrollments; has many CourseAssignments (instructors) |
| Department | Organizational Structure | An academic department with a budget, founding date, and an assigned administrator | Administered by one Instructor; contains many Courses |
| Enrollment | Academic Records | A student's registration in a course, optionally with a grade | Joins Student and Course; holds optional grade (A–F) |
| CourseAssignment | Teaching Assignment | A many-to-many relationship between Instructors and Courses | Joins Instructor and Course |
| OfficeAssignment | Facility Management | The physical office location assigned to an instructor (optional) | One-to-one with Instructor |
| Notification | Audit / Messaging | A record of an entity lifecycle event (create/update/delete) queued via MSMQ | Standalone; produced by all entity-mutating operations |

## Service-to-Domain Mapping

The application is a single-service monolith; all business contexts are owned by one deployable unit.

| Service | Domain Context | Owned Entities | External Dependencies |
|---------|---------------|---------------|----------------------|
| ContosoUniversity Web App | Student Enrollment | Student, Enrollment | SQL Server (LocalDB) |
| ContosoUniversity Web App | Faculty Management | Instructor, OfficeAssignment, CourseAssignment | SQL Server (LocalDB) |
| ContosoUniversity Web App | Academic Catalog | Course, Department | SQL Server (LocalDB); local filesystem for teaching material images |
| ContosoUniversity Web App | Notifications | Notification | MSMQ (Windows local queue) |

## Primary Workflows

### Workflow 1: Student Registration

A new student is registered in the system with a validated enrollment date, after which a notification is dispatched to the queue.

1. Administrator navigates to `/Students/Create`
2. Form is presented with today's date pre-populated as the default enrollment date
3. Administrator submits the form (POST `/Students/Create`) with last name, first name, and enrollment date
4. Server-side validation is applied:
   - Enrollment date must not be `DateTime.MinValue` or default
   - Enrollment date must be between 1/1/1753 and 12/31/9999
   - Last name and first name are required and max 50 characters
5. If validation passes: student is persisted to the `Person` table (Discriminator=`Student`), then a `Student CREATE` notification is sent to the MSMQ queue
6. Administrator is redirected to `/Students` (paginated list)
7. If validation fails: form is re-rendered with validation error messages; no record is created

### Workflow 2: Course Creation with Teaching Material Upload

A new course is added to the academic catalog, optionally with an uploaded teaching material image.

1. Administrator navigates to `/Courses/Create`
2. Form loads with a department dropdown populated from the database
3. Administrator submits the form (POST `/Courses/Create`) with course ID, title, credits, department, and optionally an image file (multipart/form-data)
4. If an image is uploaded:
   - File extension is validated against allowlist: `.jpg`, `.jpeg`, `.png`, `.gif`, `.bmp`
   - File size is validated: must be ≤ 5 MB
   - A unique filename is generated: `course_{courseId}_{guid}{ext}`
   - File is saved to `~/Uploads/TeachingMaterials/` on the server filesystem
   - The virtual path is stored on the `Course` entity
5. If validation passes: course is persisted; a `Course CREATE` notification is sent to MSMQ
6. Administrator is redirected to `/Courses`

### Workflow 3: Instructor Assignment Management

An instructor's course assignments and office assignment are managed together in a single edit operation.

1. Administrator opens `/Instructors/Edit/{id}`
2. The instructor is loaded with their current `OfficeAssignment` and all `CourseAssignments`; all available courses are loaded as checkboxes
3. Administrator updates fields and submits (POST `/Instructors/Edit/{id}`) with updated fields and a `selectedCourses[]` array
4. `TryUpdateModel` applies an allowlist update (`LastName`, `FirstMidName`, `HireDate`, `OfficeAssignment`) to prevent over-posting
5. Office assignment logic: if `Location` is whitespace/empty, the `OfficeAssignment` entity is removed (set to null)
6. Course assignment diff: the system compares the submitted course set against the current DB state — adds new assignments and marks removed assignments as `EntityState.Deleted`
7. Changes are saved; an `Instructor UPDATE` notification is sent to MSMQ
8. Redirect to `/Instructors`

### Workflow 4: Department Edit with Optimistic Concurrency

Department records include a `RowVersion` timestamp that detects concurrent modifications.

1. Administrator opens `/Departments/Edit/{id}`
2. The current department record (including hidden `RowVersion` bytes) is loaded and rendered
3. Administrator submits changes (POST `/Departments/Edit/{id}`) including the original `RowVersion`
4. EF Core sends the UPDATE with a `WHERE RowVersion = [original value]` clause
5. If another user modified the record first:
   - `DbUpdateConcurrencyException` is caught
   - Current database values are loaded and compared field-by-field with the submitted values
   - Specific field-level error messages are added (e.g., "Current value: [new name]")
   - A general conflict warning is displayed; `RowVersion` is refreshed with the current DB value
6. If no conflict: record is saved; a `Department UPDATE` notification is sent to MSMQ

### Workflow 5: Instructor Delete with Referential Cleanup

Deleting an instructor must clean up the foreign key reference in any department they administer.

1. Administrator confirms deletion at POST `/Instructors/Delete/{id}`
2. Instructor is loaded with their `OfficeAssignment` via eager loading
3. `db.Instructors.Remove(instructor)` — EF Core cascades deletion to `OfficeAssignment`
4. Any `Department` where `InstructorID = id` has its `InstructorID` set to `null` (explicit FK cleanup before delete)
5. Changes are saved; an `Instructor DELETE` notification is sent to MSMQ

### Workflow 6: Notification Polling (Admin Dashboard)

Administrators can view recent entity lifecycle events accumulated in the MSMQ queue.

1. Administrator opens `/Notifications` — a static HTML view
2. The page polls `/Notifications/GetNotifications` (GET, returns JSON)
3. The server dequeues up to 10 messages from `.\Private$\ContosoUniversityNotifications` (1 second timeout per receive)
4. Deserialized `Notification` objects are returned as JSON `{success, notifications[], count}`
5. `MarkAsRead` (POST) can be called with a notification ID, but the operation is a no-op in the current implementation — no persistence or acknowledgment occurs

## Cross-Service Data Flows

The application is a single-service monolith with no cross-service data flows. All data originates from the shared SQL Server database accessed directly via EF Core. The closest pattern to cross-service aggregation is the **Instructor Index master-detail view**:

- The `InstructorsController.Index` action accepts optional `id` (instructor) and `courseID` query parameters
- On first load: all instructors with their offices and course/department assignments are eagerly loaded in a single EF Core query chain
- If an instructor `id` is selected: the courses for that instructor are extracted from the already-loaded in-memory collection
- If a `courseID` is selected: the enrollments for that course are extracted from the already-loaded courses collection
- No additional database round-trips are made; the aggregation is performed in memory from a single up-front load

**MSMQ as a one-way cross-cutting side channel**: Entity mutation operations publish notification events to MSMQ. The `NotificationsController` dequeues those events. This is the only asynchronous, queue-based data flow in the system. There is no retry, dead-letter queue, or guaranteed delivery. If MSMQ is unavailable, the notification send is silently swallowed and the main operation still succeeds.

## Business Workflow Sequence

```mermaid
sequenceDiagram
    participant Admin as "Administrator"
    participant MVC as "MVC Controller"
    participant Validator as "ModelState Validation"
    participant EF as "EF Core / SchoolContext"
    participant DB as "SQL Server"
    participant NotifSvc as "NotificationService"
    participant Queue as "MSMQ Queue"

    Admin->>MVC: POST /Students/Create (name + enrollmentDate)
    MVC->>Validator: Validate enrollment date and required fields
    alt Validation fails
        Validator-->>MVC: ModelState errors
        MVC-->>Admin: Re-render form with validation errors
    else Validation passes
        Validator-->>MVC: Valid
        MVC->>EF: db.Students.Add(student)
        EF->>DB: INSERT INTO Person (Discriminator=Student)
        DB-->>EF: Row inserted, ID assigned
        EF-->>MVC: SaveChanges OK
        MVC->>NotifSvc: SendNotification(Student, CREATE)
        NotifSvc->>Queue: Enqueue JSON notification message
        alt MSMQ available
            Queue-->>NotifSvc: Message enqueued
        else MSMQ unavailable
            Note over NotifSvc: Error swallowed silently; main flow unaffected
        end
        MVC-->>Admin: 302 Redirect to /Students
    end

    Note over Admin,Queue: Separate admin notification polling flow
    Admin->>MVC: GET /Notifications/GetNotifications
    MVC->>NotifSvc: ReceiveNotification() up to 10 times
    NotifSvc->>Queue: Dequeue messages (1s timeout each)
    Queue-->>NotifSvc: Notification JSON or timeout
    NotifSvc-->>MVC: List of Notification objects
    MVC-->>Admin: 200 JSON with notifications array
```

## Business Rules & Decision Logic

### Validation Rules

| Entity | Field | Rule |
|--------|-------|------|
| Student | EnrollmentDate | Required; must not be `DateTime.MinValue`; must be between 1/1/1753 and 12/31/9999 |
| Student | LastName | Required; max 50 characters |
| Student | FirstMidName | Required; max 50 characters |
| Instructor | HireDate | Required; must be between 1/1/1753 and 12/31/9999 |
| Instructor | LastName | Required; max 50 characters |
| Instructor | FirstMidName | Required; max 50 characters |
| Course | CourseID | User-assigned integer (not identity); must be provided explicitly |
| Course | Title | Required; 3–50 characters |
| Course | Credits | Integer; range 0–5 |
| Course | TeachingMaterialImagePath | Optional; when image uploaded: extension must be in `{.jpg,.jpeg,.png,.gif,.bmp}`; max 5 MB |
| Department | Name | Required; 3–50 characters |
| Department | Budget | Decimal (money column) |
| Department | StartDate | Date field; not validated for range in controllers |

### Decision Logic

- **Office assignment removal**: During instructor edit, if the `Location` field is blank/whitespace, the `OfficeAssignment` entity is deleted rather than updated — effectively treating an empty office location as "no office assigned."
- **Course assignment diff**: Instructor edit computes a symmetric difference between submitted courses and current DB assignments, only issuing INSERT/DELETE operations for changed rows. No full replace is performed.
- **Enrollment date default**: The student create form pre-populates today's date, reducing the likelihood of an invalid date being submitted.
- **Department administrator FK cleanup**: When an instructor is deleted, any department they administer has its `InstructorID` FK set to null before the delete — preventing a FK constraint violation.
- **Notification send on error**: `NotificationService` wraps all queue operations in `try/catch` and logs failures via `Debug.WriteLine`. The calling controller also wraps `SendEntityNotification` in `try/catch`. Notification failures are non-fatal and never surface to the user.

### State Transitions

| Entity | Lifecycle | Notes |
|--------|-----------|-------|
| Student | Created → Updated → Deleted | No formal state machine; grades are added via Enrollment |
| Enrollment | Created (grade=null) → Graded (grade=A–F) | Grade is optional; `null` displays as "No grade" |
| Department | Active (InstructorID set) → Unmanaged (InstructorID=null) | Occurs when administrating instructor is deleted |
| Notification | Enqueued → Dequeued | MSMQ-based; `MarkAsRead` is a no-op; no persisted read state |

### Transactions

No explicit transaction management is configured. Each call to `db.SaveChanges()` is a single implicit EF Core transaction wrapping all pending changes in the current `DbContext` unit of work. There is no `TransactionScope`, no saga pattern, and no distributed transaction spanning the EF Core save and the MSMQ send. This means a successful database save followed by an MSMQ failure leaves the notification undelivered with no compensating action.

### Authorization

No authorization rules are implemented. All routes are publicly accessible — there are no `[Authorize]` attributes, no role checks, and no resource ownership enforcement anywhere in the codebase.

### Audit / Logging

Entity lifecycle events (create/update/delete) for all managed entities are published as JSON messages to the MSMQ notification queue. The `Notification` model captures: entity type, entity ID, display name, operation (CREATE/UPDATE/DELETE), timestamp, and the acting user (hardcoded as `"System"` since there is no authentication). Errors are logged via `System.Diagnostics.Trace.TraceError` and `Debug.WriteLine` — no structured logging framework is used.
