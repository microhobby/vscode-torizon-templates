#!/bin/bash

echo "🐚 SETUP XONSH"

# check if xonsh is on $HHOME/.local/bin
if [ -f "$HOME/.local/bin/xonsh" ]; then
    echo "xonsh is already installed, updating torizon-templates-utils ..."

    VARS_FILE="./.conf/repo-vars.json"

    if [ -f "$VARS_FILE" ]; then
        echo "Found repo-vars.json, attempting to use custom source..."

        repo=$(jq -r '.repo // empty' "$VARS_FILE")
        branch=$(jq -r '.branch // empty' "$VARS_FILE")
        tag_or_hash=$(jq -r '.tag // empty' "$VARS_FILE")

        if [ -z "$repo" ] || { [ -z "$branch" ] && [ -z "$tag_or_hash" ]; }; then
            echo "Invalid or incomplete config, falling back to package..."
        else
            if [ -e "$repo" ]; then
                repo="file://$(realpath "$repo")"
            fi

            if [ -n "$tag_or_hash" ]; then
                ref="$tag_or_hash"
            else
                ref="$branch"
            fi

            pipx runpip xonsh install --force-reinstall \
                "git+${repo}@${ref}#subdirectory=scripts/utils/pip"

            echo "Installed from custom repo ✅"
            exit 0
        fi
    fi

    # Fallback to package if no repo or branch/tag set
    echo "Using published package..."
    pipx runpip xonsh install --upgrade torizon-templates-utils

    echo "all ok ✅"
    exit 0
fi

# fail as soon as a command fails, and return the exit status
set -e

pipx install xonsh
pipx ensurepath
pipx inject xonsh distro
pipx inject xonsh shtab
pipx inject xonsh pyyaml
pipx inject xonsh psutil
pipx inject xonsh torizon-templates-utils
pipx inject xonsh GitPython
pipx inject xonsh python-lsp-server
pipx inject xonsh pylsp-rope

# add xonsh to the path if not already present
if ! grep -q "export PATH=\$PATH:\$HOME/.local/bin" ~/.bashrc; then
    echo "export PATH=\$PATH:\$HOME/.local/bin" >> ~/.bashrc
fi

# also for .xonshrc itself
if [ ! -f ~/.xonshrc ]; then
    touch ~/.xonshrc
fi
if ! grep -q "\$HOME/.local/bin" ~/.xonshrc; then
    echo "\$PATH.insert(0, '$HOME/.local/bin')" >> ~/.xonshrc
fi
