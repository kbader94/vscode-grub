 # Define the PID file
PID_FILE="$(dirname "$0")/qemu.pid"

# Check if the .pid file exists
if [ ! -f "$PID_FILE" ]; then
    echo "Error: PID file not found."
    exit 1
fi

# Read the PID from the .pid file
PID=$(<"$PID_FILE")

kill $PID

rm $PID_FILE
