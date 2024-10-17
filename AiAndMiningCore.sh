#!/bin/bash

# Get the current directory
CURRENT_DIR=$(pwd)

# Initialize mining state based on the current miner status
if miner status | grep -q "QUEUED"; then
    MINING_STATE="stopped"
else
    MINING_STATE="started"
fi
echo "$(date +'%Y-%m-%d %H:%M:%S') V1.1"  # Initial version log

while true; do
    # Fetch the live logs from the container
    if ! docker logs --tail 10 nosana-node > /tmp/nosana-log-check.log 2>/dev/null; then
        echo "$(date +'%Y-%m-%d %H:%M:%S') Error: Unable to fetch logs from 'nosana-node'. Retrying..."
        sleep 5  # Wait before retrying
        continue  # Skip the rest of the loop and retry
    fi

    # Check if the log shows that the machine is busy
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

    # Sleep for 30 seconds before checking again
    sleep 30
done
