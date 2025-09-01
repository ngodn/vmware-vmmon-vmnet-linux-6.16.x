# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains patched VMware Workstation 17.6.4 kernel modules with Linux kernel 6.16.1+ compatibility fixes. It provides two Linux kernel modules:

- **vmmon** (vmmon-only/): Virtual Machine Monitor module - handles virtualization core functionality
- **vmnet** (vmnet-only/): Virtual Network module - provides virtual networking capabilities

The modules have been pre-patched to work with modern Linux kernels by fixing deprecated APIs and build system changes.

## Build System and Common Commands

### Quick Installation (Recommended)
```bash
# Automated installation with all fixes applied
./repack_and_patch.sh
```

### Manual Build Process
```bash
# Create module tarballs from pre-patched sources
make tarballs

# Full installation (creates tarballs and installs)
make install

# Clean build artifacts
make clean
```

### Low-Level Manual Installation
```bash
cd modules/17.6.4/source
tar -cf vmmon.tar vmmon-only
tar -cf vmnet.tar vmnet-only
sudo cp vmmon.tar vmnet.tar /usr/lib/vmware/modules/source/
sudo vmware-modconfig --console --install-all
```

### Testing and Verification
```bash
# Check if modules are loaded
lsmod | grep -E "(vmmon|vmnet)"

# Manual module loading if needed
sudo modprobe vmmon
sudo modprobe vmnet

# Restart VMware services
sudo systemctl restart vmware
# or
sudo /etc/init.d/vmware restart
```

## Code Architecture

### Module Structure
```
modules/17.6.4/source/
├── vmmon-only/          # Virtual Machine Monitor module
│   ├── autoconf/        # Build-time configuration detection
│   ├── bootstrap/       # Module initialization and loading
│   ├── common/          # Shared functionality (APIC, CPU, memory management)
│   ├── include/         # Headers for VMware-specific definitions
│   └── linux/          # Linux-specific driver implementation
└── vmnet-only/          # Virtual Network module
    ├── bridge.c         # Network bridging functionality
    ├── driver.c         # Main driver entry point
    ├── hub.c           # Virtual hub implementation
    ├── netif.c         # Network interface handling
    ├── smac.c          # Switching and MAC address handling
    └── userif.c        # User-space interface
```

### Key Components

**vmmon module:**
- `linux/driver.c` - Main Linux driver interface and device file operations
- `linux/hostif.c` - Host interface layer, handles memory management and system calls
- `common/` - Cross-platform virtualization core (APIC, CPU management, memory tracking)
- `bootstrap/` - VMM loader and initialization

**vmnet module:**
- `driver.c` - Main driver with network device registration
- `bridge.c` - Bridge network packets between VMs and host
- `hub.c` - Virtual network hub for VM-to-VM communication
- `userif.c` - User-space API for VMware tools

### Build System Details

Both modules use a dual Makefile system:
- `Makefile` - Main makefile that detects kernel build system
- `Makefile.kernel` - Used with kernel's kbuild system (modern kernels)
- `Makefile.normal` - Standalone build system (older kernels)

The build system automatically detects whether to use kbuild or standalone compilation based on kernel version and available build infrastructure.

### Kernel Compatibility Fixes Applied

The following fixes have been pre-applied for kernel 6.16.1+ compatibility:

1. **Build System**: `EXTRA_CFLAGS` → `ccflags-y`
2. **Timer API**: `del_timer_sync()` → `timer_delete_sync()`
3. **MSR API**: `rdmsrl_safe()` → `rdmsrq_safe()`
4. **Module Init**: Direct `init_module()` function → `module_init()` macro

These fixes are already integrated into the source code, so no additional patching is required.

### Important File Locations

- Module source: `modules/17.6.4/source/{vmmon-only,vmnet-only}/`
- Build artifacts: Created in source directories during compilation
- Installation target: `/usr/lib/vmware/modules/source/`
- Runtime modules: `/lib/modules/$(uname -r)/misc/`

### Development Notes

- The modules are version-locked to VMware Workstation 17.6.4
- Kernel headers for the target kernel must be installed before building
- Build process requires root privileges for installation steps only
- Original VMware modules are automatically backed up during installation
- Secure Boot may prevent unsigned module loading

## Prerequisites

- Linux kernel headers: `linux-headers-$(uname -r)` or equivalent
- Build tools: `build-essential`, `gcc`, `make`
- VMware Workstation 17.6.4 must be installed
- Root access for module installation

## Troubleshooting

Common build failures:
- Missing kernel headers: Install `linux-headers-$(uname -r)`
- Secure Boot enabled: Disable in BIOS or sign kernel modules
- Version mismatch: Ensure VMware 17.6.4 is installed
- Permission issues: Only installation requires root, not compilation