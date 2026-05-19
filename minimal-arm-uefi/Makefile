CLANG ?= clang
LLD_LINK ?= lld-link
LLVM_READOBJ ?= llvm-readobj

TARGET := thumbv7-windows-msvc
BUILD_DIR := build
OBJ := $(BUILD_DIR)/main.obj
EFI := $(BUILD_DIR)/minimal-arm-uefi.efi
EFI_ARMNT := $(BUILD_DIR)/minimal-arm-uefi-armnt.efi

CFLAGS := \
	--target=$(TARGET) \
	-std=c11 \
	-Os \
	-ffreestanding \
	-fshort-wchar \
	-fno-builtin \
	-fno-stack-protector \
	-fno-asynchronous-unwind-tables \
	-fno-unwind-tables \
	-mthumb \
	-Wall \
	-Wextra \
	-Werror

LDFLAGS := \
	/machine:arm \
	/subsystem:efi_application,1.0 \
	/entry:EfiMain \
	/nodefaultlib \
	/fixed:no

.PHONY: all clean inspect

all: $(EFI)

$(BUILD_DIR):
	mkdir -p $@

$(OBJ): main.c efi_min.h | $(BUILD_DIR)
	$(CLANG) $(CFLAGS) -c $< -o $@

$(EFI_ARMNT): $(OBJ)
	$(LLD_LINK) $(LDFLAGS) /out:$@ $<

$(EFI): $(EFI_ARMNT)
	cp $< $@
	python3 -c 'from pathlib import Path; p = Path("$@"); b = bytearray(p.read_bytes()); off = int.from_bytes(b[0x3c:0x40], "little"); assert b[off:off + 4] == b"PE\0\0"; assert b[off + 4:off + 6] == b"\xc4\x01"; b[off + 4:off + 6] = b"\xc2\x01"; p.write_bytes(b)'

inspect: $(EFI)
	file $(EFI)
	$(LLVM_READOBJ) -h $(EFI)

clean:
	rm -rf $(BUILD_DIR)
