using System;
using System.IO;
using System.Threading.Tasks;
using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;
using Microsoft.Extensions.Configuration;

namespace ContosoUniversity.Services
{
    public class BlobStorageService
    {
        private readonly BlobContainerClient _containerClient;

        public BlobStorageService(BlobServiceClient blobServiceClient, IConfiguration configuration)
        {
            var containerName = configuration["Storage:ContainerName"] ?? "teaching-materials";
            _containerClient = blobServiceClient.GetBlobContainerClient(containerName);
            // Ensure the container exists (idempotent — creates only if it does not exist)
            _containerClient.CreateIfNotExists();
        }

        /// <summary>
        /// Uploads a stream to Azure Blob Storage and returns the blob's public URL.
        /// </summary>
        public async Task<string> UploadBlobAsync(Stream stream, string blobName, string contentType)
        {
            var blobClient = _containerClient.GetBlobClient(blobName);
            var uploadOptions = new BlobUploadOptions
            {
                HttpHeaders = new BlobHttpHeaders { ContentType = contentType }
                // Conditions intentionally omitted → unconditional overwrite (handles course image replacement)
            };
            // MIGRATION NOTE: unconditional overwrite to preserve upload-replaces semantics for teaching material images.
            await blobClient.UploadAsync(stream, uploadOptions);
            return blobClient.Uri.ToString();
        }

        /// <summary>
        /// Deletes a blob identified by its full URL from Azure Blob Storage.
        /// No-op if the URL is null/empty or the blob does not exist.
        /// </summary>
        public async Task DeleteBlobAsync(string blobUrl)
        {
            if (string.IsNullOrEmpty(blobUrl))
                return;

            // URL format: https://{account}.blob.core.windows.net/{container}/{blobname}
            // Extract the blob name by stripping the container prefix from the path.
            Uri uri;
            if (!Uri.TryCreate(blobUrl, UriKind.Absolute, out uri))
                return;

            // AbsolutePath is "/{container}/{blobname}" — split into at most 2 segments
            var pathParts = uri.AbsolutePath.TrimStart('/').Split('/', 2);
            if (pathParts.Length < 2)
                return;

            var blobName = pathParts[1];
            var blobClient = _containerClient.GetBlobClient(blobName);
            await blobClient.DeleteIfExistsAsync();
        }
    }
}
