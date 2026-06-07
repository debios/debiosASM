# DebiOS Build Makefile
# Requirements: nasm, dd (or cat)
# Usage: make        -> builds debios.img
#        make clean  -> removes build artifacts
#        make run    -> builds and runs in QEMU

NASM    = nasm
QEMU    = qemu-system-i386
IMG     = debios.img
BOOT    = boot.bin
KERNEL  = kernel.bin
IMGSIZE = 1474560

.PHONY: all clean run

all: $(IMG)

$(BOOT): boot.asm
	$(NASM) -f bin -o $(BOOT) boot.asm

$(KERNEL): kernel.asm ui.asm apps.asm
	$(NASM) -f bin -o $(KERNEL) kernel.asm

$(IMG): $(BOOT) $(KERNEL)
	cat $(BOOT) $(KERNEL) > $(IMG)
	truncate -s $(IMGSIZE) $(IMG)

run: $(IMG)
	$(QEMU) -drive file=$(IMG),format=raw,if=floppy -boot a

clean:
	rm -f $(BOOT) $(KERNEL) $(IMG)
