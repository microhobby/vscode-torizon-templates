#!/bin/bash

# Check if the environment variable is set
if [ -z "$APP_PATH" ]; then
  echo "Error: APP_PATH environment variable is not set."
  exit 1
fi

# Check RUNTIME variable
if [ "$RUNTIME" == "debug" ]; then
  echo "Running in Debug mode: Starting SSHD..."
  /usr/sbin/sshd -D
else
# Set library path
  export LD_LIBRARY_PATH=/opt/flutter-elinux/
  echo "Running in Release mode: Starting Flutter client..."
  /opt/flutter-embedded-linux/build/flutter-client --bundle="$APP_PATH" -f
fi

