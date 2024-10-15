#!/bin/bash

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

# Start the screen session and run the mining script inside it
echo "Starting a new 'nosana' screen session..."
screen -dmS nosana bash -c '
if miner status | grep -q "QUEUED"; then
    MINING_STATE="stopped"
else
    MINING_STATE="started"
fi
echo "$(date +'%Y-%m-%d %H:%M:%S') V1.1"

while true; do
    docker logs --tail 10 nosana-node > /tmp/nosana-log-check.log

    if grep -q "Running container" /tmp/nosana-log-check.log; then
        if [ "$MINING_STATE" == "started" ]; then
            :  # Do nothing, already busy
        else
            echo "$(date +'%Y-%m-%d %H:%M:%S') BUSY!! I CAN NOT MINE NOW, stopping mining"
            miner stop
            MINING_STATE="started"
        fi
    else
        if [ "$MINING_STATE" == "stopped" ]; then
            :  # Do nothing, already ready to mine
        else
            echo "$(date +'%Y-%m-%d %H:%M:%S') SLEEPING, CAN MINE NOW, starting mining"
            miner start
            MINING_STATE="stopped"
        fi
    fi
    sleep 30
done
'

if screen -list | grep -q "nosana"; then
    echo "Screen session 'nosana' is successfully running."
else
    echo "Failed to start the 'nosana' screen session."
fi

echo "Use 'screen -r nosana' to reconnect to the session."
