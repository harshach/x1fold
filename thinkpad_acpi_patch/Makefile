KVER ?= $(shell uname -r)
KDIR ?= /usr/lib/modules/$(KVER)/build

# Need the dual_accel_detect.h header from the kernel source tree
EXTRA_CFLAGS := -I$(KDIR)/drivers/platform/x86

obj-m := thinkpad_acpi.o

all:
	make -C $(KDIR) M=$(PWD) modules

clean:
	make -C $(KDIR) M=$(PWD) clean

install: all
	@echo "Backing up original module..."
	@ORIG=$$(find /usr/lib/modules/$(KVER) -name thinkpad_acpi.ko* | head -1); \
	if [ -n "$$ORIG" ] && [ ! -f "$$ORIG.bak" ]; then \
		sudo cp "$$ORIG" "$$ORIG.bak"; \
		echo "  Backed up $$ORIG → $$ORIG.bak"; \
	fi
	@echo "Installing patched module..."
	sudo cp thinkpad_acpi.ko $$(dirname $$(find /usr/lib/modules/$(KVER) -name thinkpad_acpi.ko* | head -1))/thinkpad_acpi.ko
	sudo depmod -a $(KVER)
	@echo "Done. Reload with: sudo modprobe -r thinkpad_acpi && sudo modprobe thinkpad_acpi"

uninstall:
	@ORIG=$$(find /usr/lib/modules/$(KVER) -name thinkpad_acpi.ko.bak | head -1); \
	if [ -n "$$ORIG" ]; then \
		sudo cp "$$ORIG" "$${ORIG%.bak}"; \
		sudo rm "$$ORIG"; \
		sudo depmod -a $(KVER); \
		echo "Restored original module."; \
	else \
		echo "No backup found. Nothing to restore."; \
	fi
