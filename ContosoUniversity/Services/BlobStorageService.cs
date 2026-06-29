using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;

namespace ContosoUniversity.Services
{
    public interface IBlobStorageService
    {
        /// <summary>
        /// Uploads a file stream to Azure Blob Storage and returns the full blob URL.
        /// </summary>
        Task<string> UploadAsync(Stream fileStream, string fileName, string contentType);

        /// <summary>
        /// Deletes a blob identified by its full URL. No-op if the URL is null/empty.
        /// </summary>
        Task DeleteAsync(string? blobUrl);
    }

    public class BlobStorageService : IBlobStorageService
    {
        private readonly BlobContainerClient _containerClient;

        public BlobStorageService(BlobServiceClient blobServiceClient, IConfiguration configuration)
        {
            var containerName = configuration["Storage:ContainerName"] ?? "teaching-materials";
            _containerClient = blobServiceClient.GetBlobContainerClient(containerName);
        }

        public async Task<string> UploadAsync(Stream fileStream, string fileName, string contentType)
        {
            // Ensure the container exists (idempotent — safe to call on every upload)
            await _containerClient.CreateIfNotExistsAsync();

            var blobClient = _containerClient.GetBlobClient(fileName);

            var uploadOptions = new BlobUploadOptions
            {
                HttpHeaders = new BlobHttpHeaders { ContentType = contentType }
                // Conditions intentionally omitted → unconditional overwrite.
                // MIGRATION NOTE: unconditional overwrite to preserve filesystem semantics;
                // file names are unique (GUID-based) so this is effectively always a new upload.
            };

            await blobClient.UploadAsync(fileStream, uploadOptions);
            return blobClient.Uri.ToString();
        }

        public async Task DeleteAsync(string? blobUrl)
        {
            if (string.IsNullOrEmpty(blobUrl))
                return;

            // Extract blob name from the stored full URL.
            // Expected format: https://<account>.blob.core.windows.net/<container>/<blobName>
            if (!Uri.TryCreate(blobUrl, UriKind.Absolute, out var uri))
                return;

            // uri.Segments = [ "/", "<container>/", "<blobName>" ]
            var blobName = uri.Segments.LastOrDefault()?.TrimEnd('/');
            if (string.IsNullOrEmpty(blobName))
                return;

            var blobClient = _containerClient.GetBlobClient(blobName);
            await blobClient.DeleteIfExistsAsync();
        }
    }
}
