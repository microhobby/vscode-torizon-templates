#!/bin/bash

# Check if flutter-elinux is available
if ! command -v flutter-elinux &> /dev/null; then
    echo "flutter-elinux not found. Installing..."
    
    # Clone the repository
    git clone https://github.com/sony/flutter-elinux.git
    
    # Move to /opt/ with sudo
    sudo mv flutter-elinux /opt/
    
    # Add to PATH in .bashrc if not already present
    if ! grep -q "/opt/flutter-elinux/bin" "$HOME/.bashrc"; then
        echo 'export PATH=$PATH:/opt/flutter-elinux/bin' >> "$HOME/.bashrc"
        echo "Added flutter-elinux to PATH in .bashrc"
        
        # Source .bashrc to make the changes take effect in current session
        source "$HOME/.bashrc"
    fi
    
    echo "Installation complete."
else
    echo "flutter-elinux is already present"
    flutter-elinux --version
fi
