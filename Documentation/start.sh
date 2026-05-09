#!/bin/sh
# ==============================================================================
# Script Name: start_ubuntu.sh
# Description: Professional Chroot Environment Manager for Ubuntu (CLI Mode)
# Target OS:   Android (arm64)
# Device:      Redmi Note 9 Pro (Curtana)
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Configuration Variables
# ------------------------------------------------------------------------------
# Centralized variables make it easy to update paths without hunting through code.
UBUNTU_ROOT="/data/local/Ubuntu/rootfs"
HOST_SDCARD="/sdcard"
CHROOT_SDCARD="$UBUNTU_ROOT/media/sdcard"

# ------------------------------------------------------------------------------
# 2. Pre-Execution Validation
# ------------------------------------------------------------------------------
# Verify that the user executing the script has root (UID 0) privileges.
if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] Insufficient permissions. Please run this script as root (su)."
    exit 1
fi

# ------------------------------------------------------------------------------
# 3. Environment Functions
# ------------------------------------------------------------------------------

# Function: mount_env
# Purpose: Initializes necessary virtual filesystems and external storage.
mount_env() {
    echo "[INFO] Initializing Ubuntu chroot environment..."
    
    # Enable SUID on the Android /data partition to allow su/sudo inside Ubuntu
    busybox mount -o remount,dev,suid /data

    # Bind essential kernel and hardware interfaces
    echo "[INFO] Mounting virtual filesystems (/dev, /sys, /proc)..."
    busybox mount --bind /dev "$UBUNTU_ROOT/dev"
    busybox mount --bind /sys "$UBUNTU_ROOT/sys"
    busybox mount --bind /proc "$UBUNTU_ROOT/proc"
    
    # Mount devpts (pseudo-terminal master/slave) for terminal interaction
    busybox mount -t devpts devpts "$UBUNTU_ROOT/dev/pts"

    # Mount the Android shared storage inside the chroot
    echo "[INFO] Mounting internal storage to $CHROOT_SDCARD..."
    mkdir -p "$CHROOT_SDCARD"
    busybox mount --bind "$HOST_SDCARD" "$CHROOT_SDCARD"
}

# Function: unmount_env
# Purpose: Safely detaches all mounted filesystems to prevent resource locking.
unmount_env() {
    echo " "
    echo "[INFO] Teardown initiated. Unmounting filesystems..."

    # Use the lazy unmount flag (-l) to force detachment even if processes are lingering
    busybox umount -l "$CHROOT_SDCARD"
    busybox umount -l "$UBUNTU_ROOT/dev/pts"
    busybox umount -l "$UBUNTU_ROOT/dev"
    busybox umount -l "$UBUNTU_ROOT/sys"
    busybox umount -l "$UBUNTU_ROOT/proc"

    echo "[SUCCESS] Environment safely unmounted. Goodbye!"
}

# ------------------------------------------------------------------------------
# 4. Main Execution Flow
# ------------------------------------------------------------------------------

# Step 1: Setup the environment
mount_env

# Step 2: Enter the chroot
# The script will pause at this line while you are working inside Ubuntu.
# The '/bin/su - root' command ensures a full login shell is loaded.
echo "[SUCCESS] Entering Ubuntu shell. Type 'exit' to leave."
echo "=============================================================================="
busybox chroot "$UBUNTU_ROOT" /bin/su - minhaz

# Step 3: Cleanup the environment
# This executes immediately upon exiting the Ubuntu shell.
echo "=============================================================================="
unmount_env
