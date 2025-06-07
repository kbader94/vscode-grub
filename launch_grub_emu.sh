#!/bin/bash

# Define variables
IMAGE="qemu_disk.img"
SIZE="1G"
MOUNT_POINT="/mnt/qemu_dir"
QEMU_OUTPUT="/tmp/qemu_output.txt"
PWD_FILE_NAME=".pwd"
QEMU_PID_FILE="$(dirname "$0")/qemu.pid"
VNC_PID_FILE="$(dirname "$0")/vnc.pid"
TIMEOUT="15"

# Get sudo password
current_dir=$(pwd)
# Use pwd file if it exists
if [ -f "$current_dir/$PWD_FILE_NAME" ]; then
    # RISKY BUSINESS: this will expose your password. use at your own risk!
    SUDO_PASSWORD=$(<"$current_dir/$PWD_FILE_NAME")
else
    # Prompt for a password with custom title and icon
    SUDO_PASSWORD=$(zenity --password --title="Password required" --text="Please enter your password:" --width=300 --height=150 --window-icon=info)
    if [[ $SUDO_PASSWORD -eq "" ]]; then
        echo "Password required"
        exit 1
    fi
fi

# Kill any process using the disk image
if lsof | grep -q "$IMAGE"; then
    echo "$IMAGE is currently in use. Trying to identify the process..."
    process_id=$(lsof | grep "$IMAGE" | awk '{print $2}' | head -n 1)
    if [[ ! -z $process_id ]]; then
       echo "Killing Process ID $process_id because it's using $IMAGE.."
       echo $SUDO_PASSWORD | sudo -S kill -9 $process_id
       sleep 0.5 # otherwise disk image is not freed in time
    fi
fi

# Create a QEMU disk image
echo "Creating QEMU disk image..."
qemu-img create -f raw $IMAGE $SIZE
if [ ! $? -eq 0 ]; then
    echo "Could not create Qemu disk img"
    exit 3
fi

# Setup loop device
echo "Setting up loop device..."
LOOP_DEVICE=$(echo $SUDO_PASSWORD | sudo -S losetup --find --show --partscan $IMAGE)
if [ ! $? -eq 0 ]; then
    echo "Error creating loop device"
    exit 4
else
    echo "Loop device assigned: $LOOP_DEVICE"
fi

# Create a single primary ext2 partition for the rootfs using sudo
echo "Partitioning rootfs"
echo $SUDO_PASSWORD | sudo -S parted $LOOP_DEVICE mklabel msdos
echo $SUDO_PASSWORD | sudo -S parted -a optimal $LOOP_DEVICE mkpart primary ext2 1MiB 100%
if [ ! $? -eq 0 ]; then
    echo "Error partitioning $LOOP_DEVICE"
    exit 5
fi

# Inform the OS of partition table changes
echo $SUDO_PASSWORD | sudo -S partprobe $LOOP_DEVICE

# Format the partition using sudo
PARTITION="${LOOP_DEVICE}p1"
echo "Formatting the partition $PARTITION with ext2..."
echo $SUDO_PASSWORD | sudo -S mkfs.ext2 $PARTITION
if [ ! $? -eq 0 ]; then
    echo "Error formatting $PARTITION"
    exit 6
fi

# Mount the partition using sudo
echo "Mounting the partition..."
echo $SUDO_PASSWORD | sudo -S mkdir -p $MOUNT_POINT
echo $SUDO_PASSWORD | sudo -S mount $PARTITION $MOUNT_POINT
if [ ! $? -eq 0 ]; then
    echo "Error mounting $PARTITION"
    exit 7
fi

# Copy GRUB fonts using sudo
echo "Copying GRUB fonts..."
FONT_SOURCE="/boot/grub/fonts"
FONT_DESTINATION="$MOUNT_POINT/boot/grub/fonts"
echo $SUDO_PASSWORD | sudo -S mkdir -p $FONT_DESTINATION
echo $SUDO_PASSWORD | sudo -S cp $FONT_SOURCE/* $FONT_DESTINATION

# Install GRUB using sudo
echo "Installing GRUB..."
echo $SUDO_PASSWORD | sudo -S $PWD/grub/grub-install --directory=$PWD/grub/grub-core --boot-directory=$MOUNT_POINT/boot --target=i386-pc --recheck $LOOP_DEVICE
if [ ! $? -eq 0 ]; then
    echo "Error installing GRUB"
    exit 8
fi

# Create a basic grub.cfg for testing using sudo
echo "Creating a basic grub.cfg file..."
GRUB_DIR="$MOUNT_POINT/boot/grub"
echo $SUDO_PASSWORD | sudo -S mkdir -p $GRUB_DIR
echo '

# minimal modules required for grub test
insmod all_video
insmod video
insmod video_fb
insmod gfxterm
loadfont /boot/grub/fonts/unicode.pf2
terminal_output console

menuentry "Test entry one" {
    set root=(hd0,1)
    linux /vmlinuz root=/dev/sda1 ro quiet
    initrd /initrd.img
}
menuentry "Test entry two" {
    set root=(hd0,1)
    linux /vmlinuz root=/dev/sda1 ro quiet
    initrd /initrd.img
}' | sudo tee $GRUB_DIR/grub.cfg

# Cleanup: Unmount and detach loop device using sudo
echo "Cleaning up..."
echo $SUDO_PASSWORD | sudo -S umount $MOUNT_POINT
echo $SUDO_PASSWORD | sudo -S losetup -d $LOOP_DEVICE

# Launch QEMU and capture output using setsid
nohup setsid qemu-system-i386 \
  -drive file=$IMAGE,format=raw \
  -device virtio-scsi-pci,id=scsi0 \
  -S -s \
  -vnc :0 \
  > "$QEMU_OUTPUT" 2>&1 &

QEMU_PID=$!
echo $QEMU_PID > "$QEMU_PID_FILE"
echo "QEMU started with PID: $QEMU_PID"

# Monitor QEMU output to detect when it is started or if an error occurs
echo "Waiting for QEMU to start..."
start_time=$(date +%s)
echo "Waiting for QEMU VNC port to become active..."
while true; do
    if ss -tln | grep -q ":5900"; then
        echo "QEMU VNC server is active on port 5900."
        break
    fi

    current_time=$(date +%s)
    elapsed_time=$((current_time - start_time))
    if [ "$elapsed_time" -ge "$TIMEOUT" ]; then
        echo "Error: QEMU VNC server did not start within $TIMEOUT seconds."
        cat "$QEMU_OUTPUT"
        exit 10
    fi

    sleep 1
done

# Launch tigervncviewer using setsid
nohup setsid /usr/bin/xtigervncviewer 127.0.0.1:5900 > /tmp/vncviewer_output.log 2>&1 < /dev/null &
VNC_PID=$!
# Write the PID to the .pid file
echo $VNC_PID > "$VNC_PID_FILE"

# Start the monitoring script in the background
nohup "$(dirname "$0")/.monitor_debug_process.sh" "$VNC_PID" "$QEMU_PID" > /tmp/monitor_output.log 2>&1 &
MONITOR_PID=$!
echo "Monitoring script started with PID: $MONITOR_PID"

# Success
sleep 1 # otherwise the script ends before vncviewer is open
echo "GRUB installation complete. Disk image is ready to be used with QEMU."
exit 0
