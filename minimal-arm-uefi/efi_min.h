#ifndef EFI_MIN_H
#define EFI_MIN_H

#include <stdint.h>
#include <stddef.h>

typedef void *EFI_HANDLE;
typedef uintptr_t EFI_STATUS;
typedef uintptr_t EFI_UINTN;
typedef uint16_t EFI_CHAR16;
typedef uint8_t EFI_BOOLEAN;

#define EFI_SUCCESS ((EFI_STATUS)0)
#define EFIAPI

typedef struct {
    uint32_t Data1;
    uint16_t Data2;
    uint16_t Data3;
    uint8_t Data4[8];
} EFI_GUID;

typedef struct {
	uint64_t signature;
	uint32_t revision;
	uint32_t header_size;
	uint32_t crc32;
	uint32_t reserved;
} EFI_TABLE_HEADER;

typedef struct EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL;

typedef EFI_STATUS (EFIAPI *EFI_TEXT_RESET)(
	EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *self,
	EFI_BOOLEAN extended_verification);
typedef EFI_STATUS (EFIAPI *EFI_TEXT_STRING)(
	EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *self,
	const EFI_CHAR16 *string);

struct EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL {
	EFI_TEXT_RESET Reset;
	EFI_TEXT_STRING OutputString;
	void *TestString;
	void *QueryMode;
	void *SetMode;
	void *SetAttribute;
	void *ClearScreen;
	void *SetCursorPosition;
	void *EnableCursor;
	void *Mode;
};

typedef EFI_STATUS (EFIAPI *EFI_STALL)(uint32_t microseconds);
typedef EFI_STATUS (EFIAPI *EFI_SET_WATCHDOG_TIMER)(
	EFI_UINTN timeout,
	uint64_t watchdog_code,
	EFI_UINTN data_size,
	EFI_CHAR16 *watchdog_data);
typedef EFI_STATUS (EFIAPI *EFI_LOCATE_PROTOCOL)(
	EFI_GUID *protocol,
	void *registration,
	void **interface);

typedef struct {
	EFI_TABLE_HEADER Hdr;
	void *RaiseTPL;
	void *RestoreTPL;
	void *AllocatePages;
	void *FreePages;
	void *GetMemoryMap;
	void *AllocatePool;
	void *FreePool;
	void *CreateEvent;
	void *SetTimer;
	void *WaitForEvent;
	void *SignalEvent;
	void *CloseEvent;
	void *CheckEvent;
	void *InstallProtocolInterface;
	void *ReinstallProtocolInterface;
	void *UninstallProtocolInterface;
	void *HandleProtocol;
	void *Reserved;
	void *RegisterProtocolNotify;
	void *LocateHandle;
	void *LocateDevicePath;
	void *InstallConfigurationTable;
	void *LoadImage;
	void *StartImage;
	void *Exit;
	void *UnloadImage;
	void *ExitBootServices;
	void *GetNextMonotonicCount;
	EFI_STALL Stall;
	EFI_SET_WATCHDOG_TIMER SetWatchdogTimer;
	void *ConnectController;
	void *DisconnectController;
	void *OpenProtocol;
	void *CloseProtocol;
	void *OpenProtocolInformation;
	void *ProtocolsPerHandle;
	void *LocateHandleBuffer;
	EFI_LOCATE_PROTOCOL LocateProtocol;
	void *InstallMultipleProtocolInterfaces;
	void *UninstallMultipleProtocolInterfaces;
	void *CalculateCrc32;
	void *CopyMem;
	void *SetMem;
	void *CreateEventEx;
} EFI_BOOT_SERVICES;

typedef struct {
	EFI_TABLE_HEADER Hdr;
	EFI_CHAR16 *FirmwareVendor;
	uint32_t FirmwareRevision;
	EFI_HANDLE ConsoleInHandle;
	void *ConIn;
	EFI_HANDLE ConsoleOutHandle;
	EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *ConOut;
	EFI_HANDLE StandardErrorHandle;
	EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL *StdErr;
	void *RuntimeServices;
	EFI_BOOT_SERVICES *BootServices;
	EFI_UINTN NumberOfTableEntries;
	void *ConfigurationTable;
} EFI_SYSTEM_TABLE;

#endif
