#!/bin/sh
set -e

echo "trying to restore the database (if it exists)..."
/usr/local/bin/litestream restore -v -if-replica-exists /app/data/kuma.db

echo "starting replication and the application..."
exec /usr/local/bin/litestream replicate
