#!/bin/bash

# Get the current directory
CURRENT_DIR=$(pwd)

# Check if 'screen' is installed, and install it if not
if ! command -v screen &> /dev/null; then
    echo "screen is not installed. Installing..."
    sudo apt-get update && sudo apt-get install -y screen
else
    echo "screen is already installed."
fi

# Kill any previous screen session with the name 'nosana'
if screen -list | grep -q "nosana"; then
    echo "Killing existing 'nosana' screen session..."
    screen -S nosana -X quit
fi

# Start a new screen session and run the AiAndMiningCore.sh script
echo "Starting a new 'nosana' screen session..."
screen -dmS nosana "$CURRENT_DIR/AiAndMiningCore.sh"

# Check if the screen session started correctly
if screen -list | grep -q "nosana"; then
    echo "Screen session 'nosana' is successfully running."
else
    echo "Failed to start the 'nosana' screen session."
fi

echo "Use 'screen -r nosana' to reconnect to the session."
