# Sonarr Enhanced

A custom build of [Sonarr](https://github.com/Sonarr/Sonarr) with several enhancements.

## Patches

This repository automatically builds Sonarr from the official source code, applying a set of small, focused patches as part of the build process.

| Patch | Description | Tracking |
| :---: | ----------- | :--------------------: |
| `HighPriorityImports.patch` | Runs download processing and imports at elevated priority to prevent delays caused by background tasks. | N/A |
| `BypassQueueLimit.patch` | Removes the default three-task limit for download processing and imports, allowing all eligible tasks to run immediately. | N/A |
| `FixVideoStreamIndex.patch` | Fixes use of global stream indexes in ffprobe calls, preventing full-file scans during media analysis. | [#8363](https://github.com/Sonarr/Sonarr/pull/8363) |

## Quick Start

Simply replace your `linuxserver/sonarr` image with `ghcr.io/neurekasoftware/sonarr-enhanced:latest`

## Support

This is a community maintained build of Sonarr.

For general Sonarr usage and documentation, see the official [Sonarr wiki](https://wiki.servarr.com/sonarr).

Build or patch-specific issues should be reported by opening an issue in this repository, while all other Sonarr issues should be filed as a [bug report](https://github.com/Sonarr/Sonarr/issues) directly with Sonarr on GitHub.
