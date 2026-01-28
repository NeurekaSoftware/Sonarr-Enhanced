# Multi-stage Dockerfile for building Sonarr from source

# Stage 0: Clone Sonarr source
FROM alpine:latest AS source

ARG SONARR_GIT_TAG=main
ARG SONARR_REPO=https://github.com/Sonarr/Sonarr

WORKDIR /source

# Install git
RUN apk add --no-cache git

# Clone Sonarr repository
# Use SONARR_GIT_TAG to checkout specific version (e.g., v5.0.0) or branch (e.g., main)
RUN echo "Cloning Sonarr from ${SONARR_REPO} at tag/branch: ${SONARR_GIT_TAG}" && \
    git clone --depth 1 --branch ${SONARR_GIT_TAG} ${SONARR_REPO} sonarr

# Copy patches and build files from build context
COPY Patches /source/Patches
COPY .dockerignore* /source/sonarr/

# Stage 1: Build frontend
FROM node:20.11.1-alpine AS frontend-build

WORKDIR /src

# Copy Sonarr source from previous stage
COPY --from=source /source/sonarr /src

# Install yarn
RUN corepack enable && \
    corepack prepare yarn@1.22.19 --activate

# Install dependencies with cache mount for faster rebuilds

# Install dependencies with cache mount for faster rebuilds
RUN --mount=type=cache,target=/usr/local/share/.cache/yarn \
    yarn install --frozen-lockfile --network-timeout 120000

# Build frontend
RUN yarn run build --env production

# Stage 2: Build backend
FROM mcr.microsoft.com/dotnet/sdk:6.0-alpine AS backend-build

ARG FRAMEWORK=net6.0
ARG TARGETARCH
ARG SONARR_VERSION
ARG BRANCH=main

WORKDIR /src

# Copy Sonarr source from source stage
COPY --from=source /source/sonarr /src
COPY --from=source /source/Patches /src/Patches

# Install git and sed for patch application and version updates
RUN apk add --no-cache git sed

# Set runtime identifier based on target architecture
# Docker uses amd64/arm64, .NET uses x64/arm64
RUN case "${TARGETARCH:-amd64}" in \
        amd64) echo "linux-musl-x64" > /tmp/rid ;; \
        arm64) echo "linux-musl-arm64" > /tmp/rid ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    echo "Building for architecture: ${TARGETARCH:-amd64} (RID: $(cat /tmp/rid))"

# Apply patches BEFORE restore to ensure modified files are included
RUN if [ -d "Patches" ]; then \
        echo "Applying patches..." && \
        for patch in Patches/*.patch; do \
            if [ -f "$patch" ]; then \
                echo "Applying patch: $patch" && \
                git apply --whitespace=nowarn "$patch" || exit 1; \
            fi \
        done \
    fi

# Configure NuGet to limit parallel downloads to avoid file descriptor exhaustion
ENV DOTNET_SYSTEM_NET_HTTP_SOCKETSHTTPHANDLER_MAXCONNECTIONSPERSERVER=4 \
    NUGET_CONCURRENCY_LIMIT=4

# Restore packages separately with limited concurrency to avoid "too many open files"
# This layer will be cached unless project files or dependencies change
# Use BuildKit cache mount for NuGet packages to speed up rebuilds
RUN --mount=type=cache,target=/root/.nuget/packages \
    RID=$(cat /tmp/rid) && \
    dotnet restore src/Sonarr.sln \
    -p:Configuration=Release \
    -p:Platform=Posix \
    -p:RuntimeIdentifiers=${RID} \
    --disable-parallel

# Copy built frontend from previous stage
COPY --from=frontend-build /src/_output /src/_output

# Update version information in Directory.Build.props
RUN if [ -n "$SONARR_VERSION" ]; then \
        echo "Updating version info to: $SONARR_VERSION (branch: $BRANCH)" && \
        sed -i "s/<AssemblyVersion>[0-9.*]\+<\/AssemblyVersion>/<AssemblyVersion>$SONARR_VERSION<\/AssemblyVersion>/g" src/Directory.Build.props && \
        sed -i "s/<AssemblyConfiguration>[\$()A-Za-z-]\+<\/AssemblyConfiguration>/<AssemblyConfiguration>$BRANCH<\/AssemblyConfiguration>/g" src/Directory.Build.props && \
        echo "Updated Directory.Build.props:" && \
        grep -A 2 "AssemblyVersion\|AssemblyConfiguration" src/Directory.Build.props; \
    else \
        echo "WARNING: SONARR_VERSION not set, using default version from Directory.Build.props"; \
    fi

# Build the application using msbuild (matching official build process)
# Then copy UI files and create final directory structure
# Use cache mount to access NuGet packages restored earlier
RUN --mount=type=cache,target=/root/.nuget/packages \
    RID=$(cat /tmp/rid) && \
    dotnet msbuild src/Sonarr.sln \
    -p:Configuration=Release \
    -p:Platform=Posix \
    -p:RuntimeIdentifiers=${RID} \
    -t:PublishAllRids \
    -maxcpucount:1 && \
    cp -r _output/UI _output/${FRAMEWORK}/${RID}/publish/ && \
    mkdir -p /app/sonarr/bin && \
    mv _output/${FRAMEWORK}/${RID}/publish/* /app/sonarr/bin/

# Create package_info file in the parent directory of bin/
RUN if [ -n "$SONARR_VERSION" ]; then \
        echo "Creating package_info file..." && \
        printf "PackageVersion=%s\nPackageAuthor=Neureka.Dev\nBranch=%s\nUpdateMethod=Docker\n" \
            "$SONARR_VERSION" "$BRANCH" > /app/sonarr/package_info && \
        echo "package_info contents:" && \
        cat /app/sonarr/package_info; \
    fi

# Stage 3: Runtime
FROM mcr.microsoft.com/dotnet/runtime:6.0-alpine

# Install required runtime dependencies
RUN apk add --no-cache \
    icu-libs \
    libintl \
    sqlite-libs \
    ca-certificates \
    xmlstarlet \
    wget \
    tzdata \
    su-exec

# Create sonarr user and directories
RUN addgroup -g 1000 sonarr && \
    adduser -u 1000 -G sonarr -h /config -D sonarr && \
    mkdir -p /app/sonarr /config && \
    chown -R sonarr:sonarr /app /config

# Copy application from build stage
COPY --from=backend-build --chown=sonarr:sonarr /app/sonarr /app/sonarr

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set environment variables
ENV SONARR__ANALYTICS_ENABLED=False \
    SONARR__BRANCH=main \
    SONARR__INSTANCE_NAME=Sonarr \
    XDG_CONFIG_HOME=/config/xdg \
    COMPlus_EnableDiagnostics=0 \
    TMPDIR=/run/sonarr-temp \
    PUID=1000 \
    PGID=1000 \
    TZ=Etc/UTC

# Expose ports
EXPOSE 8989

# Declare volume
VOLUME /config

# Set working directory
WORKDIR /app/sonarr

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:8989/ping || exit 1

# Run Sonarr via entrypoint script
ENTRYPOINT ["/entrypoint.sh"]
CMD ["-nobrowser", "-data=/config"]
