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

# Cleanup existing scripts
echo "Cleaning up existing scripts..."
rm -f "$CURRENT_DIR/AiAndMiningCore.sh" "$CURRENT_DIR/testgrid.sh"

# Kill existing screen session 'nosana'
if screen -list | grep -q "nosana"; then
    echo "Killing existing 'nosana' screen session..."
    screen -S nosana -X quit
fi

# Start a new 'nosana' screen session for the testgrid script
echo "Starting a new 'nosana' screen session..."
wget -O "$CURRENT_DIR/testgrid.sh" https://nosana.io/testgrid.sh
chmod +x "$CURRENT_DIR/testgrid.sh"
screen -dmS nosana bash "$CURRENT_DIR/testgrid.sh"

# Check if 'nosana' session started correctly
if screen -list | grep -q "nosana"; then
    echo "Screen session 'nosana' is successfully running."
else
    echo "Failed to start the 'nosana' screen session."
fi

# Kill existing screen session 'nosana2'
if screen -list | grep -q "nosana2"; then
    echo "Killing existing 'nosana2' screen session..."
    screen -S nosana2 -X quit
fi

# Start a new 'nosana2' screen session for the AiAndMiningCore script
echo "Starting a new 'nosana2' screen session..."
wget -O "$CURRENT_DIR/AiAndMiningCore.sh" https://github.com/Pukerud/Nosana/releases/download/test/AiAndMiningCore.sh
chmod +x "$CURRENT_DIR/AiAndMiningCore.sh"
screen -dmS nosana2 bash "$CURRENT_DIR/AiAndMiningCore.sh"

# Check if 'nosana2' session started correctly
if screen -list | grep -q "nosana2"; then
    echo "Screen session 'nosana2' is successfully running."
else
    echo "Failed to start the 'nosana2' screen session."
fi

echo "Use 'screen -r nosana' to reconnect to the Core session."
echo "Use 'screen -r nosana2' to reconnect to the testgrid session."
