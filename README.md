# agent-docs

An automated documentation synchronization tool that maintains up-to-date copies of documentation from popular open source projects.

## Overview

This repository automatically syncs documentation from upstream open source projects on a daily schedule, ensuring you always have access to the latest documentation without manual intervention.

## Features

- **Automated Daily Sync**: Documentation is automatically updated daily via GitHub Actions
- **Selective Sync**: Uses Git sparse-checkout to sync only documentation files, reducing repository size
- **Multiple Projects**: Easily extensible to sync documentation from multiple projects
- **Sync Metadata**: Each synced directory includes metadata about the source and last sync time
- **Manual Trigger**: Supports manual workflow dispatch for on-demand updates

## Current Projects

- **FastAPI**: Syncs English documentation from the FastAPI repository (excluding images)

## How It Works

1. A GitHub Actions workflow runs daily at 6 AM UTC
2. The workflow uses the `sync-repo.sh` script to:
   - Clone upstream repositories using sparse-checkout
   - Copy only the specified documentation directories
   - Add sync metadata to track sources and timestamps
3. Changes are automatically committed and pushed to this repository

## Repository Structure

```
agent-docs/
├── .github/
│   └── workflows/
│       └── sync-docs.yml    # GitHub Actions workflow
├── docs/
│   └── fastapi/             # Synced FastAPI documentation
├── scripts/
│   └── sync-repo.sh         # Sync script
└── README.md
```

## Adding New Documentation Sources

To add documentation from a new project, update the `.github/workflows/sync-docs.yml` file with a new sync step following the existing pattern.

## Manual Sync

You can manually trigger a documentation sync:
1. Go to the Actions tab in this repository
2. Select "Sync Documentation" workflow
3. Click "Run workflow"

## Note

This repository is read-only for documentation content. All documentation files are automatically synced from their upstream sources. To contribute to the documentation, please submit changes to the original project repositories.