#include "efi_min.h"

#define FRAMEBUFFER_BASE 0x80400000u
#define FRAMEBUFFER_WIDTH 480u
#define FRAMEBUFFER_HEIGHT 800u
#define FRAMEBUFFER_STRIDE_BYTES 1920u
#define FRAMEBUFFER_STRIDE_PIXELS (FRAMEBUFFER_STRIDE_BYTES / 4u)

#define PIXEL_RGB_RESERVED_8BIT_PER_COLOR 0u
#define PIXEL_BGR_RESERVED_8BIT_PER_COLOR 1u
#define PIXEL_BIT_MASK 2u

typedef struct {
	uint32_t RedMask;
	uint32_t GreenMask;
	uint32_t BlueMask;
	uint32_t ReservedMask;
} EFI_PIXEL_BITMASK;

typedef struct {
	uint32_t Version;
	uint32_t HorizontalResolution;
	uint32_t VerticalResolution;
	uint32_t PixelFormat;
	EFI_PIXEL_BITMASK PixelInformation;
	uint32_t PixelsPerScanLine;
} EFI_GRAPHICS_OUTPUT_MODE_INFORMATION;

typedef struct {
	uint32_t MaxMode;
	uint32_t Mode;
	EFI_GRAPHICS_OUTPUT_MODE_INFORMATION *Info;
	EFI_UINTN SizeOfInfo;
	uint64_t FrameBufferBase;
	EFI_UINTN FrameBufferSize;
} EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE;

typedef struct {
	void *QueryMode;
	void *SetMode;
	void *Blt;
	EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE *Mode;
} EFI_GRAPHICS_OUTPUT_PROTOCOL;

typedef struct {
	volatile uint32_t *base;
	uint32_t width;
	uint32_t height;
	uint32_t stride_pixels;
	uint32_t pixel_format;
	EFI_PIXEL_BITMASK masks;
	uint32_t using_gop;
} FRAMEBUFFER;

static EFI_GUID gop_guid = {
	0x9042a9de,
	0x23dc,
	0x4a38,
	{ 0x96, 0xfb, 0x7a, 0xde, 0xd0, 0x80, 0x51, 0x6a }
};

static const EFI_CHAR16 banner[] = {
	'N', 'o', 'k', 'i', 'a', ' ', 'f', 'a', 'm', 'e', ' ',
	'G', 'O', 'P', ' ', 'p', 'r', 'o', 'b', 'e', ' ', 'A', 'R', 'M', ' ',
	'U', 'E', 'F', 'I',
	'\r', '\n', 0
};

static const EFI_CHAR16 gop_found[] = {
	'G', 'O', 'P', ':', ' ', 'f', 'o', 'u', 'n', 'd', '\r', '\n', 0
};

static const EFI_CHAR16 gop_missing[] = {
	'G', 'O', 'P', ':', ' ', 'm', 'i', 's', 's', 'i', 'n', 'g', ',', ' ',
	'u', 's', 'i', 'n', 'g', ' ', 'h', 'a', 'r', 'd', 'c', 'o', 'd', 'e', 'd',
	' ', 'f', 'r', 'a', 'm', 'e', 'b', 'u', 'f', 'f', 'e', 'r', '\r', '\n', 0
};

static const EFI_CHAR16 gop_mode_prefix[] = {
	'G', 'O', 'P', ' ', 'm', 'o', 'd', 'e', ' ', 0
};

static const EFI_CHAR16 fb_prefix[] = {
	'F', 'B', ' ', 'b', 'a', 's', 'e', ' ', 0
};

static const EFI_CHAR16 crlf[] = { '\r', '\n', 0 };

static void print_string(EFI_SYSTEM_TABLE *system_table, const EFI_CHAR16 *string)
{
	if (system_table != NULL && system_table->ConOut != NULL &&
	    system_table->ConOut->OutputString != NULL)
		system_table->ConOut->OutputString(system_table->ConOut, string);
}

static void print_hex32(EFI_SYSTEM_TABLE *system_table, uint32_t value)
{
	EFI_CHAR16 text[] = {
		'0', 'x', '0', '0', '0', '0', '0', '0', '0', '0', 0
	};
	static const char digits[] = "0123456789abcdef";

	for (uint32_t i = 0; i < 8; i++)
		text[2 + i] = (EFI_CHAR16)digits[(value >> ((7 - i) * 4)) & 0xfu];
	print_string(system_table, text);
}

static void print_hex64(EFI_SYSTEM_TABLE *system_table, uint64_t value)
{
	print_hex32(system_table, (uint32_t)(value >> 32));
	print_hex32(system_table, (uint32_t)value);
}

static uint32_t bit_pos(uint32_t mask)
{
	for (uint32_t i = 0; i < 32; i++) {
		if (mask & (1u << i))
			return i;
	}
	return 0;
}

static uint32_t pixel_from_masks(EFI_PIXEL_BITMASK masks, uint8_t r, uint8_t g, uint8_t b)
{
	uint32_t pixel = 0;

	if (masks.RedMask != 0)
		pixel |= ((uint32_t)r << bit_pos(masks.RedMask)) & masks.RedMask;
	if (masks.GreenMask != 0)
		pixel |= ((uint32_t)g << bit_pos(masks.GreenMask)) & masks.GreenMask;
	if (masks.BlueMask != 0)
		pixel |= ((uint32_t)b << bit_pos(masks.BlueMask)) & masks.BlueMask;
	return pixel;
}

static uint32_t make_pixel(FRAMEBUFFER *fb, uint8_t r, uint8_t g, uint8_t b)
{
	if (fb->pixel_format == PIXEL_RGB_RESERVED_8BIT_PER_COLOR)
		return (uint32_t)r | ((uint32_t)g << 8) | ((uint32_t)b << 16);
	if (fb->pixel_format == PIXEL_BGR_RESERVED_8BIT_PER_COLOR)
		return (uint32_t)b | ((uint32_t)g << 8) | ((uint32_t)r << 16);
	if (fb->pixel_format == PIXEL_BIT_MASK)
		return pixel_from_masks(fb->masks, r, g, b);
	return ((uint32_t)r << 16) | ((uint32_t)g << 8) | (uint32_t)b;
}

static void paint_framebuffer(FRAMEBUFFER *fb, uint32_t phase)
{
	const uint32_t bar_width = fb->width / 8u;
	const uint32_t border = fb->using_gop ?
		make_pixel(fb, 0, 255, 0) : make_pixel(fb, 255, 0, 0);
	const uint32_t ok_block = make_pixel(fb, 255, 255, 255);
	const uint32_t colors[] = {
		make_pixel(fb, 255, 0, 0),
		make_pixel(fb, 0, 255, 0),
		make_pixel(fb, 0, 0, 255),
		make_pixel(fb, 255, 255, 255),
		make_pixel(fb, 0, 0, 0),
		make_pixel(fb, 255, 0, 255),
		make_pixel(fb, 0, 255, 255),
		make_pixel(fb, 255, 255, 0),
	};

	for (uint32_t y = 0; y < fb->height; y++) {
		uint32_t bar = 0;
		uint32_t next_bar = bar_width;

		for (uint32_t x = 0; x < fb->width; x++) {
			if (x >= next_bar && bar < 7u) {
				bar++;
				next_bar += bar_width;
			}
			uint32_t color = colors[(bar + phase) & 7u];

			if (x < 12u || x >= fb->width - 12u ||
			    y < 12u || y >= fb->height - 12u)
				color = border;

			if (fb->using_gop && x >= 32u && x < 96u && y >= 32u && y < 96u)
				color = ok_block;

			if (((x + y + phase * 32u) & 63u) < 4u)
				color ^= make_pixel(fb, 255, 255, 255);

			fb->base[y * fb->stride_pixels + x] = color;
		}
	}
}

static FRAMEBUFFER get_framebuffer(EFI_SYSTEM_TABLE *system_table)
{
	FRAMEBUFFER fb = {
		.base = (volatile uint32_t *)FRAMEBUFFER_BASE,
		.width = FRAMEBUFFER_WIDTH,
		.height = FRAMEBUFFER_HEIGHT,
		.stride_pixels = FRAMEBUFFER_STRIDE_PIXELS,
		.pixel_format = PIXEL_BGR_RESERVED_8BIT_PER_COLOR,
		.masks = { 0 },
		.using_gop = 0,
	};
	EFI_GRAPHICS_OUTPUT_PROTOCOL *gop = NULL;

	if (system_table == NULL || system_table->BootServices == NULL ||
	    system_table->BootServices->LocateProtocol == NULL)
		return fb;

	if (system_table->BootServices->LocateProtocol(&gop_guid, NULL,
	    (void **)&gop) != EFI_SUCCESS || gop == NULL || gop->Mode == NULL ||
	    gop->Mode->Info == NULL || gop->Mode->FrameBufferBase == 0)
		return fb;

	fb.base = (volatile uint32_t *)(uintptr_t)gop->Mode->FrameBufferBase;
	fb.width = gop->Mode->Info->HorizontalResolution;
	fb.height = gop->Mode->Info->VerticalResolution;
	fb.stride_pixels = gop->Mode->Info->PixelsPerScanLine;
	fb.pixel_format = gop->Mode->Info->PixelFormat;
	fb.masks = gop->Mode->Info->PixelInformation;
	fb.using_gop = 1;

	print_string(system_table, gop_found);
	print_string(system_table, gop_mode_prefix);
	print_hex32(system_table, fb.width);
	print_string(system_table, (const EFI_CHAR16[]){ 'x', 0 });
	print_hex32(system_table, fb.height);
	print_string(system_table, (const EFI_CHAR16[]){ ' ', 's', 't', 'r', 'i', 'd', 'e', ' ', 0 });
	print_hex32(system_table, fb.stride_pixels);
	print_string(system_table, crlf);
	print_string(system_table, fb_prefix);
	print_hex64(system_table, gop->Mode->FrameBufferBase);
	print_string(system_table, crlf);

	return fb;
}

EFI_STATUS EFIAPI EfiMain(EFI_HANDLE image_handle, EFI_SYSTEM_TABLE *system_table)
{
	(void)image_handle;

	print_string(system_table, banner);

	if (system_table != NULL && system_table->BootServices != NULL &&
	    system_table->BootServices->SetWatchdogTimer != NULL)
		system_table->BootServices->SetWatchdogTimer(0, 0, 0, NULL);

	FRAMEBUFFER fb = get_framebuffer(system_table);

	if (!fb.using_gop)
		print_string(system_table, gop_missing);

	for (uint32_t phase = 0;; phase++) {
		paint_framebuffer(&fb, phase);

		if (system_table != NULL && system_table->BootServices != NULL &&
		    system_table->BootServices->Stall != NULL)
			system_table->BootServices->Stall(500000);
	}

	return EFI_SUCCESS;
}
