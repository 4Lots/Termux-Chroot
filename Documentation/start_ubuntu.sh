#!/bin/sh
# ==============================================================================
# Ubuntu Chroot Launcher (Root-Agnostic & CLI Optimized)
# ==============================================================================

# 1. Professional Color Palette
RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[1;33m'
CYN='\033[0;36m'
NC='\033[0m' # No Color

# 2. Configuration Variables
UBUNTU_ROOT="/data/local/ubuntu/rootfs"
HOST_SDCARD="/sdcard"
CHROOT_SDCARD="$UBUNTU_ROOT/media/sdcard"

# 3. Dynamic Busybox Detection
# This finds busybox regardless of whether you use KernelSU, Magisk, or APatch.
BB_PATH=$(command -v busybox)

DEFAULT_USER="minhaz"
TARGET_USER="$DEFAULT_USER"

# ------------------------------------------------------------------------------
# 4. Argument Parsing
# ------------------------------------------------------------------------------
while getopts "u:h" opt; do
    case ${opt} in
        u ) TARGET_USER=$OPTARG ;;
        h ) echo "Usage: $0 [-u username]"; exit 0 ;;
        * ) echo "Usage: $0 [-u username]"; exit 1 ;;
    esac
done

# ------------------------------------------------------------------------------
# 5. Professional Logger Functions
# ------------------------------------------------------------------------------
log_info()    { echo -e "${CYN}[INFO]${NC} $1"; }
log_success() { echo -e "${GRN}[SUCCESS]${NC} $1"; }
log_warn()    { echo -e "${YLW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# ------------------------------------------------------------------------------
# 6. Environment Functions
# ------------------------------------------------------------------------------

mount_env() {
    log_info "Initializing Ubuntu chroot environment..."
    
    # Enable SUID for internal permissions (remounting /data)
    $BB_PATH mount -o remount,dev,suid /data 2>/dev/null || true

    log_info "Mounting virtual filesystems..."
    $BB_PATH mount --bind /dev "$UBUNTU_ROOT/dev"
    $BB_PATH mount --bind /sys "$UBUNTU_ROOT/sys"
    $BB_PATH mount --bind /proc "$UBUNTU_ROOT/proc"
    $BB_PATH mount -t devpts devpts "$UBUNTU_ROOT/dev/pts"
    
    # Check and Create /dev/shm
    if [ ! -d "$UBUNTU_ROOT/dev/shm" ]; then
        log_warn "Creating missing directory: /dev/shm"
        mkdir -p "$UBUNTU_ROOT/dev/shm"
    fi
    $BB_PATH mount -t tmpfs -o size=128M tmpfs "$UBUNTU_ROOT/dev/shm"

    # Check and Create /media/sdcard
    if [ ! -d "$CHROOT_SDCARD" ]; then
        log_warn "Creating missing directory: $CHROOT_SDCARD"
        mkdir -p "$CHROOT_SDCARD"
    fi
    log_info "Mounting internal storage ($HOST_SDCARD)..."
    $BB_PATH mount --bind "$HOST_SDCARD" "$CHROOT_SDCARD"
}

unmount_env() {
    echo ""
    log_info "Teardown initiated. Verifying filesystem states..."

    # Reverse order for clean unmounting
    MOUNTS="$CHROOT_SDCARD $UBUNTU_ROOT/dev/shm $UBUNTU_ROOT/dev/pts $UBUNTU_ROOT/dev $UBUNTU_ROOT/sys $UBUNTU_ROOT/proc"

    for mp in $MOUNTS; do
        if grep -q "$mp" /proc/mounts; then
            if $BB_PATH umount "$mp" 2>/dev/null; then
                log_success "Cleanly unmounted: $mp"
            else
                log_warn "Device busy: $mp. Attempting lazy unmount..."
                $BB_PATH umount -l "$mp" 2>/dev/null
            fi
        fi
    done
    log_success "Environment teardown complete."
}

# ------------------------------------------------------------------------------
# 7. Main Execution Flow
# ------------------------------------------------------------------------------

# Verify root privileges
if [ "$(id -u)" -ne 0 ]; then
    log_error "This script requires root. Please run 'su' first."
    exit 1
fi

# Ensure Busybox was actually found
if [ -z "$BB_PATH" ]; then
    log_error "Busybox binary not found in PATH. Please install Busybox."
    exit 1
else
    log_info "Using Busybox found at: $BB_PATH"
fi

# Set trap to ensure cleanup happens on exit/interruption
trap unmount_env EXIT HUP INT TERM

mount_env

echo -e "${GRN}==================================================================="
echo -e " Entering Ubuntu as User: ${YLW}$TARGET_USER${NC}"
echo -e "===================================================================${NC}"

# Start chroot with absolute Busybox path to survive the 'env -i' wipe
env -i \
    HOME="/home/$TARGET_USER" \
    TERM="$TERM" \
    PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    USER="$TARGET_USER" \
    $BB_PATH chroot "$UBUNTU_ROOT" /bin/su - "$TARGET_USER"
