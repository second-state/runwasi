#!/bin/bash

if [ $# -ne 2 ]; then
    echo "Usage: $0 <target.so> <destination>"
    exit 1
fi

lib="$1"
destination="$2"

dependencies=$(ldd "$lib" | awk '{print $3}' | grep -v 'not found')
for dep in $dependencies; do
    if [ -f "$dep" ]; then
        cp "$dep" "$destination"
    fi
done