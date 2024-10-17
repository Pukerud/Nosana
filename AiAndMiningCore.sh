#!/bin/bash

# Get the current directory
CURRENT_DIR=$(pwd)

# Function to strip ANSI escape sequences
strip_ansi() {
    sed -r 's/\x1B\[[0-9;]*[mGKH]//g'
}

# Initialize mining state based on the most recent Docker log entry
if docker logs --tail 1 nosana-node | strip_ansi | grep -q "QUEUED"; then
    MINING_STATE="stopped"
else
    MINING_STATE="started"
fi
echo "$(date +'%Y-%m-%d %H:%M:%S') V1.5"  # Updated version log

# Variables to control the timing for start and stop checks
STOP_CHECK_INTERVAL=1    # Check every 1 second for stopping mining
START_CHECK_INTERVAL=10  # Check every 10 seconds for starting mining

while true; do
    # Fetch the latest log entry from the container
    if ! docker logs --tail 1 nosana-node > /tmp/nosana-log-check.log 2>/dev/null; then
        echo "$(date +'%Y-%m-%d %H:%M:%S') Error: Unable to fetch logs from 'nosana-node'. Retrying..."
        sleep 1  # Wait for 1 second before retrying
        continue  # Skip the rest of the loop and retry
    fi

    # Read and clean the last log entry by removing ANSI sequences
    LAST_LOG_ENTRY=$(cat /tmp/nosana-log-check.log | strip_ansi)

    # Check if the cleaned log entry contains "QUEUED" anywhere
    if ! echo "$LAST_LOG_ENTRY" | grep -q "QUEUED"; then
        if [ "$MINING_STATE" == "started" ]; then
            echo "$(date +'%Y-%m-%d %H:%M:%S') BUSY!! I CAN NOT MINE NOW, stopping mining"
            miner stop
            MINING_STATE="stopped"
        fi
        sleep $STOP_CHECK_INTERVAL  # Check aggressively every 1 second
    else
        if [ "$MINING_STATE" == "stopped" ]; then
            echo "$(date +'%Y-%m-%d %H:%M:%S') SLEEPING, CAN MINE NOW, starting mining"
            miner start
            MINING_STATE="started"
        fi
        sleep $START_CHECK_INTERVAL  # Check less aggressively every 10 seconds
    fi
done
