#!/bin/bash

# VMware Workstation 17.6.4 - Repack and Install Script
# For Linux Kernel 6.16.x Compatibility (All Variants)
#
# This script automatically detects the kernel's build compiler and applies
# the appropriate compilation strategy for maximum compatibility
#
# Supports:
# - GCC-built kernels (standard Ubuntu, Debian, etc.)
# - Clang-built kernels (Xanmod, some custom builds)
# - Mixed environments
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

print_status "VMware Workstation 17.6.4 - Linux Kernel 6.16.x Compatibility"
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

# Detect kernel compiler
print_status "🔍 Detecting kernel build environment..."

KERNEL_BUILD_DIR="/lib/modules/$(uname -r)/build"
KERNEL_MAKEFILE="$KERNEL_BUILD_DIR/Makefile"

if [ ! -f "$KERNEL_MAKEFILE" ]; then
    print_error "Kernel build directory not found. Please install kernel headers:"
    echo "  Ubuntu/Debian: sudo apt install linux-headers-\$(uname -r)"
    echo "  Fedora/RHEL: sudo dnf install kernel-devel"
    echo "  Arch: sudo pacman -S linux-headers"
    exit 1
fi

# Try to detect compiler from various sources
KERNEL_COMPILER=""
COMPILER_VERSION=""

# Method 1: Check /proc/version
if grep -q "clang" /proc/version 2>/dev/null; then
    KERNEL_COMPILER="clang"
    COMPILER_VERSION=$(grep -o "clang version [0-9.]*" /proc/version | head -1)
elif grep -q "gcc" /proc/version 2>/dev/null; then
    KERNEL_COMPILER="gcc"
    COMPILER_VERSION=$(grep -o "gcc version [0-9.]*" /proc/version | head -1)
fi

# Method 2: Try to compile a test module to see what compiler the kernel expects
if [ -z "$KERNEL_COMPILER" ]; then
    print_status "Testing kernel build environment..."
    
    TEST_DIR=$(mktemp -d)
    cat > "$TEST_DIR/test.c" << 'EOF'
#include <linux/module.h>
#include <linux/kernel.h>

static int __init test_init(void) { return 0; }
static void __exit test_exit(void) { }

module_init(test_init);
module_exit(test_exit);
MODULE_LICENSE("GPL");
EOF

    cat > "$TEST_DIR/Makefile" << 'EOF'
obj-m := test.o
KDIR := /lib/modules/$(shell uname -r)/build
all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules 2>&1 | head -20
EOF

    cd "$TEST_DIR"
    BUILD_OUTPUT=$(make 2>&1 || true)
    cd - > /dev/null
    
    if echo "$BUILD_OUTPUT" | grep -q "clang"; then
        KERNEL_COMPILER="clang"
        COMPILER_VERSION=$(echo "$BUILD_OUTPUT" | grep -o "clang version [0-9.]*" | head -1)
    elif echo "$BUILD_OUTPUT" | grep -q "gcc"; then
        KERNEL_COMPILER="gcc"
        COMPILER_VERSION=$(echo "$BUILD_OUTPUT" | grep -o "gcc.*[0-9.]*" | head -1)
    fi
    
    rm -rf "$TEST_DIR"
fi

# Default to GCC if still unknown
if [ -z "$KERNEL_COMPILER" ]; then
    KERNEL_COMPILER="gcc"
    COMPILER_VERSION="unknown version"
    print_warning "Could not detect kernel compiler, defaulting to GCC"
fi

print_success "🔍 Detected kernel compiler: $KERNEL_COMPILER ($COMPILER_VERSION)"

# Determine compilation strategy
USE_CLANG=false
CLANG_VERSION=""
NEED_LLD=false

if [ "$KERNEL_COMPILER" = "clang" ]; then
    print_status "Clang-built kernel detected - checking for matching Clang compiler..."
    
    # Extract major version from kernel compiler
    KERNEL_CLANG_MAJOR=$(echo "$COMPILER_VERSION" | grep -o "[0-9]*" | head -1)
    
    # Check for available Clang versions
    AVAILABLE_CLANG=""
    for version in 19 18 17 16 15; do
        if command -v "clang-$version" >/dev/null 2>&1; then
            AVAILABLE_CLANG="clang-$version"
            CLANG_VERSION="$version"
            break
        fi
    done
    
    if [ -n "$AVAILABLE_CLANG" ]; then
        USE_CLANG=true
        print_success "Found compatible Clang: $AVAILABLE_CLANG"
        
        # Check if we need LLD linker
        if command -v "ld.lld-$CLANG_VERSION" >/dev/null 2>&1; then
            NEED_LLD=true
            print_status "LLVM linker available: ld.lld-$CLANG_VERSION"
        elif command -v "ld.lld" >/dev/null 2>&1; then
            NEED_LLD=true
            print_status "LLVM linker available: ld.lld"
        fi
    else
        print_warning "No compatible Clang found, will try to install..."
        
        # Try to install matching Clang
        if command -v apt >/dev/null 2>&1; then
            print_status "Installing Clang $KERNEL_CLANG_MAJOR..."
            if sudo apt update && sudo apt install -y "clang-$KERNEL_CLANG_MAJOR" "lld-$KERNEL_CLANG_MAJOR" 2>/dev/null; then
                USE_CLANG=true
                CLANG_VERSION="$KERNEL_CLANG_MAJOR"
                AVAILABLE_CLANG="clang-$KERNEL_CLANG_MAJOR"
                NEED_LLD=true
                print_success "Successfully installed Clang $KERNEL_CLANG_MAJOR"
            else
                print_warning "Could not install matching Clang, falling back to GCC (may fail)"
                USE_CLANG=false
            fi
        else
            print_warning "Cannot auto-install Clang on this system, falling back to GCC"
            USE_CLANG=false
        fi
    fi
else
    print_status "GCC-built kernel detected - using system GCC"
fi

# Apply C code fixes that are compatible with both GCC and Clang
print_status "📝 Applying C code compatibility fixes..."

# Fix function prototypes (compatible with both GCC and Clang)
VMNET_DRIVER_C="modules/17.6.4/source/vmnet-only/driver.c"
SMAC_COMPAT_C="modules/17.6.4/source/vmnet-only/smac_compat.c"

# Check and fix VNetFreeInterfaceList() if needed (only declaration and definition, not calls)
if grep -q "^VNetFreeInterfaceList()$" "$VMNET_DRIVER_C"; then
    print_status "Fixing VNetFreeInterfaceList() prototype in driver.c..."
    # Fix only the function definition (line that starts with the function name)
    sed -i '/^VNetFreeInterfaceList()$/s/VNetFreeInterfaceList()/VNetFreeInterfaceList(void)/' "$VMNET_DRIVER_C"
    # Fix only the static declaration
    sed -i 's/static void VNetFreeInterfaceList();/static void VNetFreeInterfaceList(void);/' "$VMNET_DRIVER_C"
    print_success "Fixed function prototype in driver.c"
fi

# Check and fix SMACL_GetUptime() if needed
if grep -q "SMACL_GetUptime()" "$SMAC_COMPAT_C"; then
    print_status "Fixing SMACL_GetUptime() prototype in smac_compat.c..."
    sed -i 's/SMACL_GetUptime()/SMACL_GetUptime(void)/g' "$SMAC_COMPAT_C"
    print_success "Fixed function prototype in smac_compat.c"
fi

# Navigate to source directory
cd modules/17.6.4/source

# Clean any previous builds
print_status "🧹 Cleaning previous builds..."
cd vmmon-only && make clean >/dev/null 2>&1 || true
cd ../vmnet-only && make clean >/dev/null 2>&1 || true
cd ..

# Compile modules based on detected environment
print_status "🔨 Compiling VMware kernel modules..."

COMPILE_SUCCESS=true

if [ "$USE_CLANG" = true ]; then
    print_status "Using Clang compilation strategy..."
    
    # Set up Clang environment
    export CC="$AVAILABLE_CLANG"
    if [ "$NEED_LLD" = true ]; then
        if command -v "ld.lld-$CLANG_VERSION" >/dev/null 2>&1; then
            export LD="ld.lld-$CLANG_VERSION"
        else
            export LD="ld.lld"
        fi
        print_status "Using LLVM linker: $LD"
    fi
    
    # Compile vmmon
    print_status "Compiling vmmon with Clang..."
    cd vmmon-only
    if make CC="$CC" ${LD:+LD="$LD"} -j$(nproc) >/dev/null 2>&1; then
        print_success "vmmon compiled successfully with Clang"
    else
        print_error "vmmon compilation failed with Clang"
        COMPILE_SUCCESS=false
    fi
    
    # Compile vmnet
    cd ../vmnet-only
    if [ "$COMPILE_SUCCESS" = true ]; then
        print_status "Compiling vmnet with Clang..."
        if make CC="$CC" ${LD:+LD="$LD"} -j$(nproc) >/dev/null 2>&1; then
            print_success "vmnet compiled successfully with Clang"
        else
            print_error "vmnet compilation failed with Clang"
            COMPILE_SUCCESS=false
        fi
    fi
    
    cd ..
else
    print_status "Using GCC compilation strategy..."
    
    # For GCC, we'll try VMware's standard approach first
    print_status "Attempting standard VMware compilation..."
    
    # Create tarballs first
    tar -cf vmmon.tar vmmon-only
    tar -cf vmnet.tar vmnet-only
    
    # Backup original modules
    BACKUP_DIR="/usr/lib/vmware/modules/source/backup-$(date +%Y%m%d-%H%M%S)"
    if [ -f "/usr/lib/vmware/modules/source/vmmon.tar" ] || [ -f "/usr/lib/vmware/modules/source/vmnet.tar" ]; then
        print_status "Backing up original modules to $BACKUP_DIR"
        sudo mkdir -p "$BACKUP_DIR"
        sudo cp /usr/lib/vmware/modules/source/vmmon.tar "$BACKUP_DIR/" 2>/dev/null || true
        sudo cp /usr/lib/vmware/modules/source/vmnet.tar "$BACKUP_DIR/" 2>/dev/null || true
    fi
    
    # Install tarballs
    sudo cp vmmon.tar vmnet.tar /usr/lib/vmware/modules/source/
    
    # Try VMware's modconfig
    print_status "Running VMware modconfig..."
    if sudo vmware-modconfig --console --install-all >/dev/null 2>&1; then
        print_success "VMware modconfig completed successfully"
        COMPILE_SUCCESS=true
    else
        print_warning "VMware modconfig failed, trying manual GCC compilation..."
        
        # Manual GCC compilation fallback
        cd vmmon-only
        if make CC=gcc -j$(nproc) >/dev/null 2>&1; then
            print_success "vmmon compiled successfully with GCC"
            cd ../vmnet-only
            if make CC=gcc -j$(nproc) >/dev/null 2>&1; then
                print_success "vmnet compiled successfully with GCC"
                
                # Manual installation
                print_status "Installing modules manually..."
                sudo mkdir -p /lib/modules/$(uname -r)/misc/
                sudo cp ../vmmon-only/vmmon.ko /lib/modules/$(uname -r)/misc/
                sudo cp vmnet.ko /lib/modules/$(uname -r)/misc/
                sudo depmod -a
                COMPILE_SUCCESS=true
            else
                COMPILE_SUCCESS=false
            fi
        else
            COMPILE_SUCCESS=false
        fi
        cd ..
    fi
fi

# Check compilation results
if [ "$COMPILE_SUCCESS" = false ]; then
    print_error "Module compilation failed!"
    echo
    echo "Troubleshooting steps:"
    echo "1. Ensure kernel headers are installed: sudo apt install linux-headers-\$(uname -r)"
    echo "2. Check if Secure Boot is disabled"
    echo "3. For Clang kernels, ensure matching Clang version is installed"
    exit 1
fi

# Test module loading
print_status "🧪 Testing module loading..."

# Unload any existing modules
sudo rmmod vmnet vmmon 2>/dev/null || true

# Load modules
if sudo modprobe vmmon && sudo modprobe vmnet; then
    print_success "✅ Modules loaded successfully!"
    
    # Verify modules are running
    if lsmod | grep -q vmmon && lsmod | grep -q vmnet; then
        print_success "✅ All VMware modules are running!"
        
        # Start VMware services
        print_status "🚀 Starting VMware services..."
        if sudo systemctl restart vmware 2>/dev/null || sudo /etc/init.d/vmware restart 2>/dev/null; then
            print_success "✅ VMware services started successfully!"
        else
            print_warning "Could not restart VMware services automatically"
            echo "Try: sudo systemctl restart vmware"
        fi
        
        echo
        echo "🎉 Installation Complete!"
        echo "✅ Kernel compiler detected: $KERNEL_COMPILER"
        echo "✅ Applied compatibility fixes for kernel 6.16.x"
        echo "✅ Modules compiled and loaded successfully"
        echo "✅ VMware Workstation is ready to use"
        echo
        echo "You can now launch VMware Workstation."
        
    else
        print_warning "Modules compiled but not properly loaded"
        echo "Try: sudo modprobe vmmon && sudo modprobe vmnet"
    fi
else
    print_error "Failed to load modules"
    exit 1
fi

# Return to original directory
cd ../../..

print_success "Script completed successfully!"
echo
echo "This script automatically detected your kernel's compiler and applied"
echo "the appropriate fixes for maximum 6.16.x kernel compatibility."
