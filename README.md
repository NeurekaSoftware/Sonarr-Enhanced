# <img width="24px" src="https://raw.githubusercontent.com/Sonarr/Sonarr/refs/heads/v5-develop/Logo/256.png" alt="Sonarr"></img> Sonarr Enhanced

A drop-in replacement for [Sonarr](https://github.com/Sonarr/Sonarr) that includes a small set of targeted fixes and performance improvements.

This Docker image is built automatically from the official Sonarr source and stays up to date with new Sonarr releases.

> [!IMPORTANT]  
> Sonarr Enhanced exists to improve performance and responsiveness during large searches, heavy download activity, and bulk import operations, without changing Sonarr’s core behavior.

## Quick Start

Replace your existing Sonarr image with: `ghcr.io/neurekasoftware/sonarr-enhanced:latest`

### Docker Compose

```yaml
services:
  sonarr:
    image: ghcr.io/neurekasoftware/sonarr-enhanced:latest
    container_name: sonarr
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
    volumes:
      - /path/to/sonarr/data:/config
    ports:
      - 8989:8989
    restart: unless-stopped
```

## Support

This is a community maintained build of Sonarr.

For general Sonarr usage and documentation, see the official [Sonarr wiki](https://wiki.servarr.com/sonarr).

Build or patch-specific issues should be reported by opening an issue in this repository, while all other Sonarr issues should be filed as a [bug report](https://github.com/Sonarr/Sonarr/issues) directly with Sonarr on GitHub.
