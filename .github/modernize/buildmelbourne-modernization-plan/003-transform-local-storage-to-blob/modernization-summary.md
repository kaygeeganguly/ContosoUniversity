# Task 003: Migrate Local Storage to Azure Blob Storage

## Summary

Migrated teaching material image upload and retrieval in `CoursesController` from local filesystem (`~/Uploads/TeachingMaterials/`) to Azure Blob Storage using Managed Identity (`DefaultAzureCredential`) authentication.

## Changes Made

### New Files

| File | Description |
|------|-------------|
| `ContosoUniversity/Services/BlobStorageService.cs` | New `IBlobStorageService` interface and `BlobStorageService` implementation wrapping `BlobContainerClient` operations. Provides `UploadAsync` (returns full blob URL) and `DeleteAsync` (extracts blob name from stored URL and deletes). Registered as Singleton in DI. |

### Modified Files

| File | Change |
|------|--------|
| `ContosoUniversity/ContosoUniversity.csproj` | Added `Azure.Storage.Blobs` 12.28.0 package reference |
| `ContosoUniversity/appsettings.json` | Added `Storage` configuration section with `ServiceUri` (`https://${STORAGE_ACCOUNT_NAME}.blob.core.windows.net`) and `ContainerName` (`teaching-materials`) |
| `ContosoUniversity/Program.cs` | Registered `BlobServiceClient` as Singleton with `DefaultAzureCredential`; registered `IBlobStorageService`; removed `Uploads/` static file middleware (no longer needed) |
| `ContosoUniversity/Controllers/CoursesController.cs` | Replaced `IWebHostEnvironment` dependency with `IBlobStorageService`; replaced all local filesystem operations with Azure Blob Storage calls; made `DeleteConfirmed` async |
| `ContosoUniversity/Views/Courses/Details.cshtml` | Changed `@Url.Content(Model.TeachingMaterialImagePath)` → `@Model.TeachingMaterialImagePath` (now stores full HTTPS URLs) |
| `ContosoUniversity/Views/Courses/Edit.cshtml` | Same `Url.Content` → direct URL change |
| `ContosoUniversity/Views/Courses/Index.cshtml` | Same `Url.Content` → direct URL change |

## Migration Details

### Authentication
- Uses `DefaultAzureCredential` (Managed Identity) — no connection strings or shared keys in code
- `BlobServiceClient` constructed with storage account URI from `appsettings.json`

### File Operations Preserved
- **Create**: Uploads new file to Azure Blob Storage; stores full blob URL in `TeachingMaterialImagePath`
- **Edit**: Deletes old blob from storage before uploading replacement; stores new blob URL
- **Delete**: Deletes blob from storage before removing the course record

### Validation Preserved
- Allowed image extensions: `.jpg`, `.jpeg`, `.png`, `.gif`, `.bmp`
- Max file size: 5 MB

### URL Storage Change
- **Before**: `~/Uploads/TeachingMaterials/course_{id}_{guid}.{ext}` (virtual path)
- **After**: `https://{account}.blob.core.windows.net/teaching-materials/course_{id}_{guid}.{ext}` (full HTTPS URL)
- Views updated to use stored URL directly (no `Url.Content()` for absolute URLs)

### Infrastructure Note
The `Storage:ServiceUri` configuration uses a `${STORAGE_ACCOUNT_NAME}` placeholder. This should be replaced with the actual Azure Storage Account name (provisioned in task 007). The blob container name is `teaching-materials` (matching the infrastructure specification in task 007).

### Package Conflict Resolution
`Microsoft.Extensions.Azure` was evaluated but removed because it upgraded `Azure.Core` to 1.53.0 which conflicted with `Azure.Identity` 1.14.2 (CS0433 — same type `DefaultAzureCredential` in both assemblies). `BlobServiceClient` is registered directly as a Singleton via `builder.Services.AddSingleton(...)` which is fully equivalent per the migration skill guidelines.

## Build Status
- ✅ Build: **Succeeded** (0 errors, 0 warnings)
- ✅ Tests: **Passed** (no test projects in solution)
