# VMware Workstation 17.6.4 - Linux Kernel 6.16.1 Compatibility
# Simple Makefile for easy installation

.PHONY: all tarballs install clean help

all: install

help:
	@echo "VMware Workstation 17.6.4 - Linux Kernel 6.16.1 Compatibility"
	@echo ""
	@echo "Available targets:"
	@echo "  install    - Create tarballs and install VMware modules (default)"
	@echo "  tarballs   - Create vmmon.tar and vmnet.tar from patched sources"
	@echo "  clean      - Clean build artifacts"
	@echo "  help       - Show this help message"
	@echo ""
	@echo "Quick start:"
	@echo "  make install"

tarballs:
	@echo "Creating tarballs from patched sources..."
	cd modules/17.6.4/source && \
	tar -cf vmmon.tar vmmon-only && \
	tar -cf vmnet.tar vmnet-only
	@echo "✅ Created vmmon.tar and vmnet.tar"

install: tarballs
	@echo "Installing patched VMware modules..."
	./repack_and_patch.sh

clean:
	@echo "Cleaning build artifacts..."
	cd modules/17.6.4/source && \
	rm -f vmmon.tar vmnet.tar && \
	make clean -C vmmon-only 2>/dev/null || true && \
	make clean -C vmnet-only 2>/dev/null || true
	@echo "✅ Cleaned"