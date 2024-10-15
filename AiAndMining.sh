#!/bin/bash

# Check if 'screen' is installed, and install it if not
if ! command -v screen &> /dev/null; then
    echo "screen is not installed. Installing..."
    sudo apt-get update && sudo apt-get install -y screen
else
    echo "screen is already installed."
fi

# Check if the screen session 'nosana' is already running
if screen -list | grep -q "nosana"; then
    echo "Screen session 'nosana' is already running."
else
    echo "Starting screen session 'nosana'."
    # Start the script in a new screen session named 'nosana'
    screen -S nosana -d -m bash -c '
    # Initialize mining state based on the current miner status
    if miner status | grep -q "QUEUED"; then
        MINING_STATE="stopped"
    else
        MINING_STATE="started"
    fi
    echo "$(date +'%Y-%m-%d %H:%M:%S') V1.1"
    while true; do
        # Fetch the live logs from the container
        docker logs --tail 10 nosana-node > /tmp/nosana-log-check.log
        
        # Check if the log shows that the machine is busy
        if grep -q "Running container" /tmp/nosana-log-check.log; then
            if [ "$MINING_STATE" == "started" ]; then
                echo
            else
                echo "$(date +'%Y-%m-%d %H:%M:%S') BUSY!! I CAN NOT MINE NOW, stopping mining"
                miner stop
                MINING_STATE="started"
            fi
        else
            if [ "$MINING_STATE" == "stopped" ]; then
                echo
            else
                echo "$(date +'%Y-%m-%d %H:%M:%S') SLEEPING, CAN MINE NOW, starting mining"
                miner start
                MINING_STATE="stopped"
            fi
        fi

        # Sleep for 30 seconds before checking again
        sleep 30
    done
    '
fi
