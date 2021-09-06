#!/bin/bash

# Remove local remote script if already present
rm -f remote.sh

# Download remote script
if ! wget https://raw.githubusercontent.com/szaimen/nextcloud-easy-test/main/remote.sh; then
    echo "Failed to download the remote script."
    exit 1
fi

# Execute it
if ! bash remote.sh; then
    exit 1
fi

# Run the default CMD script
exec "$@"
