# VMware Workstation 17.6.4 - Linux Kernel 6.16.1 Compatibility Fixes

![VMware](https://img.shields.io/badge/VMware-Workstation_17.6.4-blue)
![Kernel](https://img.shields.io/badge/Linux_Kernel-6.16.1-green)
![Status](https://img.shields.io/badge/Status-✅_WORKING-success)

This repository contains **fully patched and working** VMware host modules with all necessary fixes applied to make VMware Workstation 17.6.4 compatible with Linux kernel 6.16.1 and potentially newer kernels.

### **Fixed Issues:**

1. **Build System Changes**: `EXTRA_CFLAGS` deprecated → **Fixed with `ccflags-y`**
2. **Kernel API Changes**: 
   - `del_timer_sync()` → **Fixed with `timer_delete_sync()`**
   - `rdmsrl_safe()` → **Fixed with `rdmsrq_safe()`**
3. **Module Init Deprecation**: `init_module()` deprecated → **Fixed with `module_init()` macro**
4. **Header File Issues**: Missing includes → **Fixed with proper include paths**


## Installation

### Prerequisites

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install build-essential linux-headers-$(uname -r) git

# Fedora/RHEL  
sudo dnf install kernel-devel kernel-headers gcc make git

# Arch Linux
sudo pacman -S linux-headers base-devel git
```

### Step 1: Clone This Pre-Patched Repository

```bash
# Clone this repository with all kernel 6.16.1 fixes already applied
git clone https://github.com/ngodn/vmware-vmmon-vmnet-linux-6.16.x.git
cd vmware-vmmon-vmnet-linux-6.16.x
```

### Step 2: Install Patched Modules (Automated)

**Option A: Use the automated script (Recommended)**

```bash
# Run the automated installation script
./repack_and_patch.sh
```

**Option B: Manual installation**

```bash
# Navigate to source directory
cd modules/17.6.4/source

# Create VMware module tarballs from patched sources
tar -cf vmmon.tar vmmon-only
tar -cf vmnet.tar vmnet-only

# Replace VMware's original modules with patched versions  
sudo cp -v vmmon.tar vmnet.tar /usr/lib/vmware/modules/source/

# Compile and install the modules
sudo vmware-modconfig --console --install-all
```

### Step 3: Verify Installation

If successful, you should see:
```
Starting VMware services:
   Virtual machine monitor                                             done
   Virtual machine communication interface                             done
   VM communication interface socket family                            done
   Virtual ethernet                                                    done
   VMware Authentication Daemon                                        done
   Shared Memory Available                                             done
```

## Technical Details

### **All Kernel 6.16.1 Fixes Applied**

| Issue | Old Code | New Code | Status |
|-------|----------|----------|---------|
| **Build System** | `EXTRA_CFLAGS` | `ccflags-y` | ✅ **Fixed** |
| **Timer API** | `del_timer_sync()` | `timer_delete_sync()` | ✅ **Fixed** |
| **MSR API** | `rdmsrl_safe()` | `rdmsrq_safe()` | ✅ **Fixed** |
| **Module Init** | `init_module()` function | `module_init()` macro | ✅ **Fixed** |

### Files Modified and Fixed

- ✅ `vmmon-only/Makefile.kernel` - Build system compatibility
- ✅ `vmnet-only/Makefile.kernel` - Build system compatibility  
- ✅ `vmmon-only/Makefile` - Build system compatibility
- ✅ `vmnet-only/Makefile` - Build system compatibility
- ✅ `vmmon-only/linux/driver.c` - Timer API usage
- ✅ `vmmon-only/linux/hostif.c` - Timer and MSR API usage
- ✅ `vmnet-only/driver.c` - Module initialization system

### Compilation Test Results

**vmmon module:**
```bash
✅ CC [M]  linux/driver.o
✅ CC [M]  linux/hostif.o  
✅ CC [M]  common/*.o
✅ LD [M]  vmmon.o
✅ LD [M]  vmmon.ko
```

**vmnet module:**
```bash
✅ CC [M]  driver.o
✅ CC [M]  hub.o userif.o netif.o bridge.o procfs.o
✅ LD [M]  vmnet.o  
✅ LD [M]  vmnet.ko
```

## Troubleshooting

### Issue: Secure Boot Enabled
**Error**: `Could not open /dev/vmmon: No such file or directory`

**Solution**: Disable Secure Boot in BIOS/UEFI settings or sign the kernel modules.

### Issue: Missing Kernel Headers
**Error**: Build fails with missing header files

**Solution**: 
```bash
# Reinstall kernel headers
sudo apt install --reinstall linux-headers-$(uname -r)  # Ubuntu/Debian
sudo dnf install kernel-devel kernel-headers             # Fedora/RHEL
```

### Issue: Wrong Kernel Headers Version
**Error**: Version mismatch during compilation

**Solution**: Ensure headers match your running kernel:
```bash
uname -r  # Check running kernel version
ls /lib/modules/  # Check available module directories
```

### Issue: VMware Services Won't Start
**Error**: VMware services fail to start after module installation

**Solution**:
```bash
# Manually load the modules
sudo modprobe vmmon
sudo modprobe vmnet

# Restart VMware services
sudo systemctl restart vmware
# or
sudo /etc/init.d/vmware restart
```

## Future Kernel Compatibility

For future kernel updates, monitor these potential breaking changes:

1. **Timer subsystem**: Further timer API modifications
2. **Memory management**: Page allocation/deallocation changes  
3. **Network stack**: Networking API updates (affects vmnet)
4. **Build system**: Makefile and compilation flag changes

When new kernels are released, you may need to:
1. Update the API compatibility fixes in the source code
2. Run `./repack_and_patch.sh` to reinstall with the updated fixes

## Contributing

This repository contains fully working patches for kernel 6.16.1. If you encounter issues with newer kernels or have improvements:

1. Fork this repository
2. Create a feature branch: `git checkout -b fix/kernel-6.17`
3. Apply your fixes and test thoroughly
4. Submit a pull request with detailed description

## References

- [mkubecek/vmware-host-modules](https://github.com/mkubecek/vmware-host-modules) - Community patches (inspiration)
- [Linux Kernel Documentation](https://www.kernel.org/doc/html/latest/) - Kernel API changes
- [VMware Knowledge Base](https://kb.vmware.com/) - Official VMware documentation

## Disclaimer

These patches are community-maintained and not officially supported by VMware/Broadcom. Use at your own risk. Always backup your system before applying kernel module patches.

## License

This project follows the same license terms as the original VMware kernel modules and community patches.

---

## **Tested Configuration:**
- **OS**: Ubuntu 24.04.3 LTS (Noble Numbat)
- **Kernel**: 6.16.1-x64v3-t2-noble-xanmod1  
- **VMware**: Workstation Pro 17.6.4 build-24832109
- **Date**: August 2025
- **Status**: ✅ **WORKING** - All modules compile and load successfully

