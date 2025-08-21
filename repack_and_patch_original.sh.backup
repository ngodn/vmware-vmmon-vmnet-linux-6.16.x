#!/bin/bash

# VMware Workstation 17.6.4 - Repack and Install Script
# For Linux Kernel 6.16.1 Compatibility
#
# This script creates tarballs from the pre-patched VMware modules
# and installs them to make VMware Workstation work with kernel 6.16.1
#
# Usage: ./repack_and_patch.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root. It will use sudo when needed."
   exit 1
fi

print_status "VMware Workstation 17.6.4 - Linux Kernel 6.16.1 Compatibility"
echo "Target kernel: $(uname -r)"
echo

# Check if we're in the right directory
if [ ! -d "modules/17.6.4/source" ]; then
    print_error "Please run this script from the repository root directory"
    print_error "Expected to find: modules/17.6.4/source/"
    exit 1
fi

# Check if the patched modules exist
if [ ! -d "modules/17.6.4/source/vmmon-only" ] || [ ! -d "modules/17.6.4/source/vmnet-only" ]; then
    print_error "Patched module sources not found!"
    print_error "Expected: modules/17.6.4/source/vmmon-only and modules/17.6.4/source/vmnet-only"
    exit 1
fi

# Check if VMware is installed
if [ ! -d "/usr/lib/vmware" ]; then
    print_error "VMware Workstation is not installed!"
    print_error "Please install VMware Workstation 17.6.4 first."
    exit 1
fi

print_status "✅ All pre-patched modules found"
print_status "✅ VMware Workstation installation detected"
echo

# Navigate to source directory
cd modules/17.6.4/source

# Create tarballs from patched sources
print_status "Creating tarballs from patched module sources..."
tar -cf vmmon.tar vmmon-only
tar -cf vmnet.tar vmnet-only

print_success "Created vmmon.tar and vmnet.tar"

# Backup original modules if they exist
BACKUP_DIR="/usr/lib/vmware/modules/source/backup-$(date +%Y%m%d-%H%M%S)"
if [ -f "/usr/lib/vmware/modules/source/vmmon.tar" ] || [ -f "/usr/lib/vmware/modules/source/vmnet.tar" ]; then
    print_status "Backing up original modules to $BACKUP_DIR"
    sudo mkdir -p "$BACKUP_DIR"
    sudo cp /usr/lib/vmware/modules/source/vmmon.tar "$BACKUP_DIR/" 2>/dev/null || true
    sudo cp /usr/lib/vmware/modules/source/vmnet.tar "$BACKUP_DIR/" 2>/dev/null || true
    print_success "Original modules backed up"
fi

# Copy patched modules
print_status "Installing patched modules..."
sudo cp -v vmmon.tar vmnet.tar /usr/lib/vmware/modules/source/

# Compile and install
print_status "Compiling and installing kernel modules..."
print_warning "This may take a few minutes..."

if sudo vmware-modconfig --console --install-all; then
    print_success "VMware kernel modules installed successfully!"
    
    # Verify modules are loaded
    if lsmod | grep -q vmmon && lsmod | grep -q vmnet; then
        print_success "Modules are loaded and running!"
        echo
        echo "🎉 Installation complete!"
        echo "✅ Applied all kernel 6.16.1 compatibility fixes:"
        echo "   • Build system: EXTRA_CFLAGS → ccflags-y"
        echo "   • Timer API: del_timer_sync → timer_delete_sync"
        echo "   • MSR API: rdmsrl_safe → rdmsrq_safe"  
        echo "   • Module init: init_module() → module_init() macro"
        echo "✅ Modules compiled and loaded successfully"
        echo
        echo "You can now launch VMware Workstation."
    else
        print_warning "Modules compiled but may need manual loading"
        echo "Try: sudo modprobe vmmon && sudo modprobe vmnet"
    fi
else
    print_error "Failed to compile kernel modules"
    
    # Restore backup if available
    if [ -d "$BACKUP_DIR" ]; then
        print_status "Restoring backup modules..."
        sudo cp "$BACKUP_DIR"/* /usr/lib/vmware/modules/source/ 2>/dev/null || true
    fi
    
    echo
    echo "Check the compilation logs for more details."
    echo "Common issues:"
    echo "- Missing kernel headers: install linux-headers-\$(uname -r)"
    echo "- Secure Boot enabled: disable in BIOS or sign modules"
    echo "- Missing build tools: install build-essential/gcc/make"
    
    exit 1
fi

# Return to original directory
cd ../../..

print_success "Script completed successfully!"
echo
echo "For future kernel updates, you may need to run this script again"
echo "if VMware releases new module versions."