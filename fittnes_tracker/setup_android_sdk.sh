#!/bin/bash

# Create Android SDK directory
mkdir -p ~/Android/Sdk

# Add Android SDK to PATH
echo 'export ANDROID_HOME=$HOME/Android/Sdk' >> ~/.bashrc
echo 'export PATH=$PATH:$ANDROID_HOME/tools' >> ~/.bashrc
echo 'export PATH=$PATH:$ANDROID_HOME/platform-tools' >> ~/.bashrc

# Source the updated .bashrc
source ~/.bashrc 