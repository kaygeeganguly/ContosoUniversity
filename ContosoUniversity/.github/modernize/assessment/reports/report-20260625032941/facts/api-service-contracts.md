# API & Service Communication Contracts

ContosoUniversity exposes a single web application with approximately 28 MVC action endpoints across 6 controllers, using synchronous HTTP (form-post/GET) as the primary communication pattern, with a lightweight JSON API surface for notification polling.

## Service Catalog

| Service | Port | Category | Purpose |
|---|---|---|---|
| ContosoUniversity Web App | 443 / 80 (IIS/IISExpress) | Business | Single-application ASP.NET MVC 5 web app serving all university management functions |

## API Endpoints Inventory

| Controller | Method | Path | Request Type | Response Type |
|---|---|---|---|---|
| HomeController | GET | / | — | HTML (Index view) |
| HomeController | GET | /Home/About | — | HTML + EnrollmentDateGroup list |
| HomeController | GET | /Home/Contact | — | HTML |
| HomeController | GET | /Home/Error | — | HTML (error view) |
| HomeController | GET | /Home/Unauthorized | — | HTML (403 view) |
| StudentsController | GET | /Students | sortOrder, currentFilter, searchString, page (query) | HTML + PaginatedList of Student |
| StudentsController | GET | /Students/Details/{id} | id (path) | HTML + Student detail |
| StudentsController | GET | /Students/Create | — | HTML (create form) |
| StudentsController | POST | /Students/Create | Student (form-bound: LastName, FirstMidName, EnrollmentDate) | Redirect / HTML |
| StudentsController | GET | /Students/Edit/{id} | id (path) | HTML (edit form) |
| StudentsController | POST | /Students/Edit | Student (form-bound: ID, LastName, FirstMidName, EnrollmentDate) | Redirect / HTML |
| StudentsController | GET | /Students/Delete/{id} | id (path) | HTML (delete confirm) |
| StudentsController | POST | /Students/Delete/{id} | id (path) | Redirect |
| CoursesController | GET | /Courses | — | HTML + Course list |
| CoursesController | GET | /Courses/Details/{id} | id (path) | HTML + Course detail |
| CoursesController | GET | /Courses/Create | — | HTML (create form) |
| CoursesController | POST | /Courses/Create | Course + file upload (teachingMaterialImage) | Redirect / HTML |
| CoursesController | GET | /Courses/Edit/{id} | id (path) | HTML (edit form) |
| CoursesController | POST | /Courses/Edit | Course + file upload | Redirect / HTML |
| CoursesController | GET | /Courses/Delete/{id} | id (path) | HTML (delete confirm) |
| CoursesController | POST | /Courses/Delete/{id} | id (path) | Redirect |
| DepartmentsController | GET | /Departments | — | HTML + Department list |
| DepartmentsController | GET | /Departments/Details/{id} | id (path) | HTML + Department detail |
| DepartmentsController | GET | /Departments/Create | — | HTML (create form) |
| DepartmentsController | POST | /Departments/Create | Department (form-bound) | Redirect / HTML |
| DepartmentsController | GET | /Departments/Edit/{id} | id (path) | HTML (edit form) |
| DepartmentsController | POST | /Departments/Edit | Department + RowVersion concurrency token | Redirect / HTML |
| DepartmentsController | GET | /Departments/Delete/{id} | id (path) | HTML (delete confirm) |
| DepartmentsController | POST | /Departments/Delete/{id} | id (path) | Redirect |
| InstructorsController | GET | /Instructors | id, courseID (optional query) | HTML + InstructorIndexData |
| InstructorsController | GET | /Instructors/Details/{id} | id (path) | HTML + Instructor detail |
| InstructorsController | GET | /Instructors/Create | — | HTML (create form) |
| InstructorsController | POST | /Instructors/Create | Instructor + selectedCourses[] | Redirect / HTML |
| InstructorsController | GET | /Instructors/Edit/{id} | id (path) | HTML (edit form) |
| InstructorsController | POST | /Instructors/Edit/{id} | id + selectedCourses[] | Redirect / HTML |
| InstructorsController | GET | /Instructors/Delete/{id} | id (path) | HTML (delete confirm) |
| InstructorsController | POST | /Instructors/Delete/{id} | id (path) | Redirect |
| NotificationsController | GET | /Notifications/GetNotifications | — | JSON: { success, notifications[], count } |
| NotificationsController | POST | /Notifications/MarkAsRead | id (form/body) | JSON: { success } |
| NotificationsController | GET | /Notifications/Index | — | HTML (notification dashboard) |

## Management & Observability Endpoints

| Service | Endpoint | Notes |
|---|---|---|
| ContosoUniversity | None configured | No health check, metrics, or Swagger endpoints present |

No Spring Boot Actuator, ASP.NET Core health checks (`/health`, `/healthz`), Swagger/OpenAPI UI, or custom observability endpoints are configured. The application has no production-ready observability surface.

## DTOs & Contracts

The application uses standard ASP.NET MVC model binding with domain entity classes serving as both persistence models and view/request objects — there is no dedicated DTO layer:

- **Student** — domain entity used directly as both the EF Core persistence model and as the MVC model bound from form POST bodies (fields: LastName, FirstMidName, EnrollmentDate). See `data-architecture.md` for full field details.
- **Course** — domain entity used as both persistence and request model; also carries a `HttpPostedFileBase teachingMaterialImage` file upload parameter alongside the bound form fields.
- **Department** — domain entity used as request/response model; includes a `RowVersion` byte array for optimistic concurrency in edit/delete flows.
- **Instructor** — domain entity with a nested `OfficeAssignment` object; edit/create actions also accept a `string[] selectedCourses` parameter to manage the M:N `CourseAssignment` join table.
- **EnrollmentDateGroup** (ViewModel) — aggregate projection used in the About view; groups student count by enrollment date. Not persisted.
- **InstructorIndexData** (ViewModel) — composite view model aggregating an instructor list, their courses, and enrollments for the Instructors index page.
- **AssignedCourseData** (ViewModel) — read model exposing course assignment state per instructor for the edit view.
- **Notification** — domain entity returned as JSON from the notification JSON endpoints; serialized via `Newtonsoft.Json`.

No OpenAPI/Swagger specification, protobuf schemas, or GraphQL schemas are present. JSON serialization uses `Newtonsoft.Json` 13.0.3 (legacy) rather than `System.Text.Json`.

## Communication Patterns

**Synchronous (HTTP + MVC form posts)**: All primary CRUD flows use synchronous HTTP GET/POST via standard ASP.NET MVC form submissions. There is no REST API client, gRPC, or HttpClient inter-service communication — this is a monolithic single-process application.

**Asynchronous (MSMQ)**: The `NotificationService` dispatches notification messages to a local Windows MSMQ private queue (`.\Private$\ContosoUniversityNotifications`) on every entity create/update/delete operation. The `NotificationsController.GetNotifications` endpoint polls and drains the queue synchronously (up to 10 messages per call). There is no separate consumer process — the same web application both produces and consumes messages.

**Resilience patterns**: No circuit breaker, retry policy, timeout configuration, or bulkhead pattern is implemented. The `NotificationService` catches exceptions and logs them via `Debug.WriteLine` but has no retry logic. Database calls via EF Core have no timeout configuration beyond the provider defaults.

**Service discovery**: Not applicable — single-process monolith with no inter-service communication.

**API gateway**: Not applicable — no gateway, reverse proxy, or BFF layer is configured.

**File uploads**: `CoursesController` accepts a `HttpPostedFileBase` multipart file upload for teaching material images, saved to the server filesystem via `Server.MapPath`.

**Security posture**: No authentication or authorization is configured. `FilterConfig.cs` explicitly comments out the global `AuthorizeAttribute`. No TLS enforcement, JWT validation, OAuth2, or Windows Authentication middleware is wired in. All 39 endpoints are publicly accessible with no authorization checks. `Microsoft.Identity.Client 4.21.1` is present as a package dependency but is not integrated into the application.

## Service Technology Matrix

| Service | Web Framework | Data Access | Discovery | Gateway | Health Checks | Cache | Metrics |
|---|---|---|---|---|---|---|---|
| ContosoUniversity | ASP.NET MVC 5.2.9 (System.Web) | EF Core 3.1.32 (SQL Server) | None | None | None | None | None |

## Service Communication Sequence

```mermaid
sequenceDiagram
    participant Client as "Browser"
    participant MVC as "ASP.NET MVC Controller"
    participant Svc as "NotificationService"
    participant EF as "SchoolContext (EF Core)"
    participant DB as "SQL Server"
    participant MQ as "MSMQ Queue"

    Client->>MVC: GET /Students (sortOrder, page)
    MVC->>EF: db.Students.Where(...).OrderBy(...).Skip/Take
    EF->>DB: SELECT FROM Person WHERE Discriminator='Student'
    DB-->>EF: Student rows
    EF-->>MVC: PaginatedList of Student
    MVC-->>Client: 200 HTML (Students/Index view)

    Client->>MVC: POST /Students/Create (form data)
    MVC->>EF: db.Students.Add(student); db.SaveChanges()
    EF->>DB: INSERT INTO Person (...)
    DB-->>EF: OK
    EF-->>MVC: OK
    MVC->>Svc: SendEntityNotification("Student", id, CREATE)
    Svc->>MQ: Queue.Send(JSON message)
    MQ-->>Svc: OK
    MVC-->>Client: 302 Redirect /Students

    Client->>MVC: GET /Notifications/GetNotifications
    MVC->>Svc: ReceiveNotification() loop (max 10)
    Svc->>MQ: Queue.Receive(timeout=1s)
    alt Messages available
        MQ-->>Svc: JSON notification message
        Svc-->>MVC: Notification object
        MVC-->>Client: 200 JSON {success, notifications[], count}
    else Queue empty or timeout
        MQ-->>Svc: IOTimeout exception
        Svc-->>MVC: null
        MVC-->>Client: 200 JSON {success:true, count:0}
    end
```
