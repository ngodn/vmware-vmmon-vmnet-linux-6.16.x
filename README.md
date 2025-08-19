# VMware Workstation 17.6.4 - Linux Kernel 6.16.1 Compatibility Fixes

![VMware](https://img.shields.io/badge/VMware-Workstation_17.6.4-blue)
![Kernel](https://img.shields.io/badge/Linux_Kernel-6.16.1-green)
![Status](https://img.shields.io/badge/Status-Working-success)

This repository contains **pre-patched** VMware host modules with all necessary fixes applied to make VMware Workstation 17.6.4 compatible with Linux kernel 6.16.1 and potentially newer kernels.

VMware Workstation 17.6.4 fails to compile kernel modules (vmmon and vmnet) on Linux kernel 6.16.1 due to:

1. **Missing header files**: `driver-config.h`, `vm_basic_defs.h`, `includeCheck.h`
2. **Build system changes**: `EXTRA_CFLAGS` deprecated in favor of `ccflags-y`
3. **API changes**: 
   - `del_timer_sync()` replaced with `timer_delete_sync()`
   - `rdmsrl_safe()` replaced with `rdmsrq_safe()`

### Error Messages
```
fatal error: driver-config.h: No such file or directory
fatal error: vm_basic_defs.h: No such file or directory
error: implicit declaration of function 'del_timer_sync'
error: implicit declaration of function 'rdmsrl_safe'
```

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
# Clone this repository with all kernel 6.16 fixes already applied
# Replace YOUR_USERNAME with your actual GitHub username
git clone https://github.com/ngodn/vmware-vmmon-vmnet-linux-6.16.x.git
cd vmware-vmmon-vmnet-linux-6.16.x
```

### Step 2: Create and Install Patched Modules

```bash
# Create VMware module tarballs
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

## Technical Details

### Kernel API Changes in 6.16

| Old API | New API | Reason |
|---------|---------|---------|
| `EXTRA_CFLAGS` | `ccflags-y` | Kernel build system modernization |
| `del_timer_sync()` | `timer_delete_sync()` | Timer subsystem API cleanup |
| `rdmsrl_safe()` | `rdmsrq_safe()` | MSR access function renaming |

### Files Modified

- `vmmon-only/Makefile*` - Build system compatibility
- `vmmon-only/linux/driver.c` - Timer API usage
- `vmmon-only/linux/hostif.c` - Timer and MSR API usage
- Various header files - API function declarations

## Future Kernel Compatibility

For future kernel updates, monitor these potential breaking changes:

1. **Timer subsystem**: Further timer API modifications
2. **Memory management**: Page allocation/deallocation changes
3. **Network stack**: Networking API updates (affects vmnet)
4. **Build system**: Makefile and compilation flag changes

## Contributing

This is a pre-patched fork ready for use. If you encounter issues with newer kernels or have improvements:

1. Fork this repository
2. Create a feature branch: `git checkout -b fix/kernel-6.17`
3. Apply your fixes and test thoroughly
4. Submit a pull request with detailed description

For manual patching of other repositories, see the **Technical Details** section below.

## References

- [mkubecek/vmware-host-modules](https://github.com/mkubecek/vmware-host-modules) - Original community patches
- [64kramsystem/vmware-host-modules-fork](https://github.com/64kramsystem/vmware-host-modules-fork) - Updated fork
- [Linux Kernel Documentation](https://www.kernel.org/doc/html/latest/) - Kernel API changes
- [VMware Knowledge Base](https://kb.vmware.com/) - Official VMware documentation

## Disclaimer

These patches are community-maintained and not officially supported by VMware/Broadcom. Use at your own risk. Always backup your system before applying kernel module patches.

## License

This project follows the same license terms as the original VMware kernel modules and community patches.

---

**Tested Configuration:**
- OS: Ubuntu 24.04.3 LTS (Noble Numbat)
- Kernel: 6.16.1-x64v3-t2-noble-xanmod1  
- VMware: Workstation Pro 17.6.4 build-24832109
- Date: August 2025

**Status**: ✅ Working - All modules compile and load successfully