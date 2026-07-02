#!/bin/bash
set -e

# Run DB migrations
superset db upgrade

# Create an admin user (idempotent — ignores error if it already exists)
superset fab create-admin \
    --username admin \
    --firstname Admin \
    --lastname User \
    --email admin@example.com \
    --password admin || true

# Load default roles/permissions
superset init

# Start the web server
/usr/bin/run-server.sh
