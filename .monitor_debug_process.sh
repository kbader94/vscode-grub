#!/bin/bash

# Arguments
VNC_PID=$1
QEMU_PID=$2

echo "watching VNC @ $VNC_PID"
echo "watching QEMU @ $QEMU_PID"

# Function to check if a process is running
is_running() {
    ps -p $1 > /dev/null 2>&1
    return $?
}

# Monitor both VNC Viewer and QEMU processes
while true; do
    if ! is_running $VNC_PID; then
        echo "VNC Viewer process $VNC_PID has terminated."
        if is_running $QEMU_PID; then
            echo "Sending SIGTERM to QEMU process $QEMU_PID..."
            kill $QEMU_PID
        fi
        exit 0
    fi

    if ! is_running $QEMU_PID; then
        echo "QEMU process $QEMU_PID has terminated."
        if is_running $VNC_PID; then
            echo "Sending SIGTERM to VNC Viewer process $VNC_PID..."
            kill $VNC_PID
        fi
        exit 0
    fi

    sleep 1
done
