#include "efi_min.h"

#define FRAMEBUFFER_BASE 0x80400000u
#define FRAMEBUFFER_WIDTH 480u
#define FRAMEBUFFER_HEIGHT 800u
#define FRAMEBUFFER_STRIDE_BYTES 1920u
#define FRAMEBUFFER_STRIDE_PIXELS (FRAMEBUFFER_STRIDE_BYTES / 4u)

static const EFI_CHAR16 banner[] = {
	'N', 'o', 'k', 'i', 'a', ' ', 'f', 'a', 'm', 'e', ' ',
	'm', 'i', 'n', 'i', 'm', 'a', 'l', ' ', 'A', 'R', 'M', ' ',
	'U', 'E', 'F', 'I', ' ', 'p', 'a', 'y', 'l', 'o', 'a', 'd',
	'\r', '\n', 0
};

static const uint32_t colors[] = {
	0x00ff0000u,
	0x0000ff00u,
	0x000000ffu,
	0x00ffffffu,
	0x00000000u,
	0x00ff00ffu,
	0x0000ffffu,
	0x00ffff00u,
};

static void paint_framebuffer(uint32_t phase)
{
	volatile uint32_t *fb = (volatile uint32_t *)FRAMEBUFFER_BASE;
	const uint32_t bar_width = FRAMEBUFFER_WIDTH / 8u;

	for (uint32_t y = 0; y < FRAMEBUFFER_HEIGHT; y++) {
		for (uint32_t x = 0; x < FRAMEBUFFER_WIDTH; x++) {
			uint32_t bar = x / bar_width;
			uint32_t color = colors[(bar + phase) & 7u];

			if (x < 8u || x >= FRAMEBUFFER_WIDTH - 8u ||
			    y < 8u || y >= FRAMEBUFFER_HEIGHT - 8u)
				color = 0x00ffffffu;

			if (((x + y + phase * 32u) & 63u) < 4u)
				color ^= 0x00ffffffu;

			fb[y * FRAMEBUFFER_STRIDE_PIXELS + x] = color;
		}
	}
}

EFI_STATUS EFIAPI EfiMain(EFI_HANDLE image_handle, EFI_SYSTEM_TABLE *system_table)
{
	(void)image_handle;

	if (system_table != NULL && system_table->ConOut != NULL &&
	    system_table->ConOut->OutputString != NULL)
		system_table->ConOut->OutputString(system_table->ConOut, banner);

	if (system_table != NULL && system_table->BootServices != NULL &&
	    system_table->BootServices->SetWatchdogTimer != NULL)
		system_table->BootServices->SetWatchdogTimer(0, 0, 0, NULL);

	for (uint32_t phase = 0;; phase++) {
		paint_framebuffer(phase);

		if (system_table != NULL && system_table->BootServices != NULL &&
		    system_table->BootServices->Stall != NULL)
			system_table->BootServices->Stall(500000);
	}

	return EFI_SUCCESS;
}
