# Task 005 — Configure Console Logging for Cloud and Container Environments

## Summary

Replaced all `System.Diagnostics.Debug.WriteLine` and `System.Diagnostics.Trace.TraceError` calls with structured `ILogger` logging throughout the application, and registered the console logging provider in startup for Azure Container Apps log collection.

## Changes Made

### `ContosoUniversity/Program.cs`
- Added `builder.Logging.AddConsole()` to explicitly register the console logging provider so all log output is directed to stdout/stderr — the mechanism Azure Container Apps uses to capture and aggregate logs.

### `ContosoUniversity/appsettings.json`
- Added `Console` section under `Logging` with JSON formatter configuration (`FormatterName: "json"`) for structured machine-readable output.
- Configured `SingleLine: true`, `IncludeScopes: true`, `UseUtcTimestamp: true` and `Indented: false` for optimal Azure Monitor / Container Apps log parsing.

### `ContosoUniversity/Services/NotificationService.cs`
- Injected `ILogger<NotificationService>` via constructor.
- Replaced 3× `System.Diagnostics.Debug.WriteLine` calls (fire-and-forget faulted task, synchronous send catch, receive catch) with `_logger.LogError(exception, message, params)` using structured log templates.

### `ContosoUniversity/Controllers/BaseController.cs`
- Added `protected readonly ILogger _logger` field.
- Updated constructor to accept `ILogger logger` parameter so each derived controller supplies its own typed logger — log entries are categorized under the concrete controller type.
- Replaced 1× `System.Diagnostics.Debug.WriteLine` (notification send failure) with `_logger.LogError(ex, "Failed to send notification for {EntityType} {EntityId}", ...)`.

### `ContosoUniversity/Controllers/CoursesController.cs`
- Injected `ILogger<CoursesController>` and passed to base constructor.
- Replaced 1× `System.Diagnostics.Debug.WriteLine` (blob deletion failure in `DeleteConfirmed`) with `_logger.LogError(ex, "Error deleting blob for course {CourseId}", id)`.

### `ContosoUniversity/Controllers/NotificationsController.cs`
- Injected `ILogger<NotificationsController>` and passed to base constructor.
- Replaced 2× `System.Diagnostics.Debug.WriteLine` (retrieve notifications error, mark-as-read error) with `_logger.LogError(ex, ...)` using structured templates.

### `ContosoUniversity/Controllers/StudentsController.cs`
- Injected `ILogger<StudentsController>` and passed to base constructor.
- Removed unused `using System.Diagnostics;` import.
- Replaced 3× `Trace.TraceError(...)` calls (create, edit, delete student errors) with `_logger.LogError(ex, ...)` using structured templates.

### `ContosoUniversity/Controllers/DepartmentsController.cs`
- Injected `ILogger<DepartmentsController>` and passed to base constructor.

### `ContosoUniversity/Controllers/HomeController.cs`
- Injected `ILogger<HomeController>` and passed to base constructor.

### `ContosoUniversity/Controllers/InstructorsController.cs`
- Injected `ILogger<InstructorsController>` and passed to base constructor.

## Logging Best Practices Applied

- **Structured logging**: All log calls use named message template parameters (e.g., `{EntityType}`, `{CourseId}`) instead of string interpolation, enabling log filtering and querying in Azure Monitor.
- **Exception-first pattern**: All catch blocks pass the `Exception` as the first argument to `LogError` so stack traces are captured.
- **Appropriate log levels**: All exception catch blocks use `LogError`; future informational or diagnostic messages can use `LogInformation` / `LogDebug`.
- **No sensitive data**: Log messages include only entity type, ID, and operation — no PII.

## Build & Test Results

- **Build**: ✅ Succeeded — 0 errors, 0 warnings
- **Unit Tests**: ✅ Passed — no test projects in solution (pass by default)
