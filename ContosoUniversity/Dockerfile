# ── Stage 1: Build ───────────────────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Copy project file and restore dependencies first for better layer caching
COPY ["ContosoUniversity.csproj", "./"]
RUN dotnet restore "ContosoUniversity.csproj"

# Copy remaining source code (obj/ excluded via .dockerignore)
COPY . .

# Remove any Windows-generated obj/ artifacts copied from host, then publish fresh
# --no-restore is intentionally omitted: COPY . . may overwrite the Linux obj/ from restore above
RUN rm -rf obj && dotnet publish "ContosoUniversity.csproj" -c Release -o /app/publish

# ── Stage 2: Runtime ──────────────────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app

# Create a non-root user for security (Debian-style commands for dotnet/aspnet base image)
RUN groupadd --system --gid 1001 appgroup && \
    useradd  --system --uid 1001 --gid appgroup --no-create-home appuser

# Copy published output from build stage
COPY --from=build /app/publish .

# Set ownership
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# ASP.NET Core 8+ defaults to port 8080 when running as non-root
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

ENTRYPOINT ["dotnet", "ContosoUniversity.dll"]
