#include "efi_min.h"

#include <stdbool.h>

#define PIXEL_RGB_RESERVED_8BIT_PER_COLOR 0u
#define PIXEL_BGR_RESERVED_8BIT_PER_COLOR 1u
#define PIXEL_BIT_MASK 2u
#define PIXEL_BLT_ONLY 3u

static const bool GOP_BLT_ENABLED = true;
static const bool GOP_DIRECT_ENABLED = true;
static const uint32_t GOP_BLT_DELAY_US = 3000000;
static const uint32_t GOP_DIRECT_DELAY_US = 3000000;
static const uintptr_t DCACHE_LINE_BYTES = 32;

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

typedef struct EFI_GRAPHICS_OUTPUT_PROTOCOL EFI_GRAPHICS_OUTPUT_PROTOCOL;

typedef struct {
	uint8_t Blue;
	uint8_t Green;
	uint8_t Red;
	uint8_t Reserved;
} EFI_GRAPHICS_OUTPUT_BLT_PIXEL;

typedef enum {
	EfiBltVideoFill,
	EfiBltVideoToBltBuffer,
	EfiBltBufferToVideo,
	EfiBltVideoToVideo,
	EfiGraphicsOutputBltOperationMax,
} EFI_GRAPHICS_OUTPUT_BLT_OPERATION;

typedef EFI_STATUS (EFIAPI *EFI_GRAPHICS_OUTPUT_PROTOCOL_BLT)(
	EFI_GRAPHICS_OUTPUT_PROTOCOL *self,
	EFI_GRAPHICS_OUTPUT_BLT_PIXEL *blt_buffer,
	EFI_GRAPHICS_OUTPUT_BLT_OPERATION blt_operation,
	EFI_UINTN source_x,
	EFI_UINTN source_y,
	EFI_UINTN destination_x,
	EFI_UINTN destination_y,
	EFI_UINTN width,
	EFI_UINTN height,
	EFI_UINTN delta);

struct EFI_GRAPHICS_OUTPUT_PROTOCOL {
	void *QueryMode;
	void *SetMode;
	EFI_GRAPHICS_OUTPUT_PROTOCOL_BLT Blt;
	EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE *Mode;
};

typedef struct {
	EFI_GRAPHICS_OUTPUT_PROTOCOL *gop;
	uint32_t width;
	uint32_t height;
	uint32_t stride_pixels;
	uint32_t pixel_format;
	EFI_PIXEL_BITMASK masks;
	uint64_t framebuffer_base;
	uint64_t framebuffer_size;
} GOP_INFO;

static EFI_GUID gop_guid = {
	0x9042a9de,
	0x23dc,
	0x4a38,
	{ 0x96, 0xfb, 0x7a, 0xde, 0xd0, 0x80, 0x51, 0x6a }
};

static const EFI_CHAR16 banner[] = {
	'N', 'o', 'k', 'i', 'a', ' ', 'f', 'a', 'm', 'e', ' ',
	'G', 'O', 'P', ' ', 'B', 'L', 'T', ' ', 'p', 'r', 'o', 'b', 'e',
	'\r', '\n', 0
};

static const EFI_CHAR16 gop_found[] = {
	'G', 'O', 'P', ':', ' ', 'f', 'o', 'u', 'n', 'd', '\r', '\n', 0
};

static const EFI_CHAR16 gop_missing[] = {
	'G', 'O', 'P', ':', ' ', 'm', 'i', 's', 's', 'i', 'n', 'g', '\r', '\n', 0
};

static const EFI_CHAR16 gop_mode_prefix[] = {
	'G', 'O', 'P', ' ', 'm', 'o', 'd', 'e', ' ', 0
};

static const EFI_CHAR16 fb_prefix[] = {
	'F', 'B', ' ', 'b', 'a', 's', 'e', ' ', 0
};

static const EFI_CHAR16 blt_disabled[] = {
	'G', 'O', 'P', ' ', 'B', 'L', 'T', ':', ' ', 'd', 'i', 's',
	'a', 'b', 'l', 'e', 'd', '\r', '\n', 0
};

static const EFI_CHAR16 blt_enabled[] = {
	'G', 'O', 'P', ' ', 'B', 'L', 'T', ':', ' ', 'e', 'n', 'a',
	'b', 'l', 'e', 'd', '\r', '\n', 0
};

static const EFI_CHAR16 blt_missing[] = {
	'G', 'O', 'P', ' ', 'B', 'L', 'T', ':', ' ', 'm', 'i', 's', 's', 'i',
	'n', 'g', '\r', '\n', 0
};

static const EFI_CHAR16 blt_delay[] = {
	'G', 'O', 'P', ' ', 'B', 'L', 'T', ' ', 'd', 'e', 'l', 'a', 'y', ':',
	' ', '3', 's', '\r', '\n', 0
};

static const EFI_CHAR16 direct_enabled[] = {
	'G', 'O', 'P', ' ', 'd', 'i', 'r', 'e', 'c', 't', ':', ' ', 'e', 'n',
	'a', 'b', 'l', 'e', 'd', '\r', '\n', 0
};

static const EFI_CHAR16 direct_disabled[] = {
	'G', 'O', 'P', ' ', 'd', 'i', 'r', 'e', 'c', 't', ':', ' ', 'd', 'i',
	's', 'a', 'b', 'l', 'e', 'd', '\r', '\n', 0
};

static const EFI_CHAR16 direct_delay[] = {
	'G', 'O', 'P', ' ', 'd', 'i', 'r', 'e', 'c', 't', ' ', 'd', 'e', 'l',
	'a', 'y', ':', ' ', 'C', 'o', 'n', 'O', 'u', 't', ' ', '3', 's', ' ',
	'a', 'f', 't', 'e', 'r', ' ', 'B', 'L', 'T', '\r', '\n', 0
};

static const EFI_CHAR16 post_blt_conout[] = {
	'P', 'o', 's', 't', '-', 'B', 'L', 'T', ' ', 'C', 'o', 'n', 'O', 'u',
	't', ':', ' ', 'O', 'K', ';', ' ', 'd', 'i', 'r', 'e', 'c', 't', ' ',
	'i', 'n', ' ', '3', 's', '\r', '\n', 0
};

static const EFI_CHAR16 direct_store_start[] = {
	'D', 'i', 'r', 'e', 'c', 't', ' ', 's', 't', 'o', 'r', 'e', ':',
	' ', 's', 't', 'a', 'r', 't', '\r', '\n', 0
};

static const EFI_CHAR16 direct_gop_marker[] = {
	'D', 'i', 'r', 'e', 'c', 't', ' ', 'G', 'O', 'P', '-', 's', 't', 'r',
	'i', 'd', 'e', ' ', 'm', 'a', 'r', 'k', 'e', 'r', 0
};

static const EFI_CHAR16 direct_tight_marker[] = {
	'D', 'i', 'r', 'e', 'c', 't', ' ', 't', 'i', 'g', 'h', 't', '-', 's',
	't', 'r', 'i', 'd', 'e', ' ', 'm', 'a', 'r', 'k', 'e', 'r', 0
};

static const EFI_CHAR16 direct_skip[] = {
	' ', 's', 'k', 'i', 'p', '\r', '\n', 0
};

static const EFI_CHAR16 direct_offset[] = {
	' ', 'o', 'f', 'f', 's', 'e', 't', ' ', 0
};

static const EFI_CHAR16 direct_end[] = {
	' ', 'e', 'n', 'd', ' ', 0
};

static const EFI_CHAR16 direct_read[] = {
	' ', 'r', 'e', 'a', 'd', ' ', 0
};

static const EFI_CHAR16 direct_clean_read[] = {
	' ', 'c', 'l', 'e', 'a', 'n', ' ', 'r', 'e', 'a', 'd', ' ', 0
};

static const EFI_CHAR16 space[] = { ' ', 0 };

static const EFI_CHAR16 crlf[] = { '\r', '\n', 0 };

static void print_string(EFI_SYSTEM_TABLE *system_table, const EFI_CHAR16 *string)
{
	if (system_table != NULL && system_table->ConOut != NULL &&
	    system_table->ConOut->OutputString != NULL)
		system_table->ConOut->OutputString(system_table->ConOut, string);
}

static void print_decimal32(EFI_SYSTEM_TABLE *system_table, uint32_t value)
{
	EFI_CHAR16 text[11];
	uint32_t pos = 0;
	bool started = false;
	static const uint32_t divisors[] = {
		1000000000u, 100000000u, 10000000u, 1000000u, 100000u,
		10000u, 1000u, 100u, 10u, 1u,
	};

	for (uint32_t i = 0; i < sizeof(divisors) / sizeof(divisors[0]); i++) {
		uint32_t digit = 0;

		while (value >= divisors[i]) {
			value -= divisors[i];
			digit++;
		}
		if (digit != 0 || started || divisors[i] == 1u) {
			text[pos++] = (EFI_CHAR16)('0' + digit);
			started = true;
		}
	}
	text[pos] = 0;
	print_string(system_table, text);
}

static void print_decimal64(EFI_SYSTEM_TABLE *system_table, uint64_t value)
{
	EFI_CHAR16 text[21];
	uint32_t pos = 0;
	bool started = false;
	static const uint64_t divisors[] = {
		10000000000000000000ull, 1000000000000000000ull,
		100000000000000000ull, 10000000000000000ull,
		1000000000000000ull, 100000000000000ull,
		10000000000000ull, 1000000000000ull, 100000000000ull,
		10000000000ull, 1000000000ull, 100000000ull, 10000000ull,
		1000000ull, 100000ull, 10000ull, 1000ull, 100ull, 10ull, 1ull,
	};

	for (uint32_t i = 0; i < sizeof(divisors) / sizeof(divisors[0]); i++) {
		uint32_t digit = 0;

		while (value >= divisors[i]) {
			value -= divisors[i];
			digit++;
		}
		if (digit != 0 || started || divisors[i] == 1ull) {
			text[pos++] = (EFI_CHAR16)('0' + digit);
			started = true;
		}
	}
	text[pos] = 0;
	print_string(system_table, text);
}

static void dsb_sy(void)
{
	__asm__ volatile("dsb sy" ::: "memory");
}

static void clean_dcache_mva(uintptr_t address)
{
	__asm__ volatile("mcr p15, 0, %0, c7, c10, 1" :: "r"(address) : "memory");
}

static void clean_dcache_range(uintptr_t start, uintptr_t size)
{
	uintptr_t end;

	if (size == 0)
		return;

	end = start + size;
	start &= ~(DCACHE_LINE_BYTES - 1u);

	dsb_sy();
	for (uintptr_t address = start; address < end; address += DCACHE_LINE_BYTES)
		clean_dcache_mva(address);
	dsb_sy();
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
	uint32_t pixel = masks.ReservedMask;

	if (masks.RedMask != 0)
		pixel |= ((uint32_t)r << bit_pos(masks.RedMask)) & masks.RedMask;
	if (masks.GreenMask != 0)
		pixel |= ((uint32_t)g << bit_pos(masks.GreenMask)) & masks.GreenMask;
	if (masks.BlueMask != 0)
		pixel |= ((uint32_t)b << bit_pos(masks.BlueMask)) & masks.BlueMask;
	return pixel;
}

static uint32_t make_direct_pixel(GOP_INFO *info, uint8_t r, uint8_t g, uint8_t b)
{
	if (info->pixel_format == PIXEL_RGB_RESERVED_8BIT_PER_COLOR)
		return 0xff000000u | (uint32_t)r | ((uint32_t)g << 8) |
			((uint32_t)b << 16);
	if (info->pixel_format == PIXEL_BGR_RESERVED_8BIT_PER_COLOR)
		return 0xff000000u | (uint32_t)b | ((uint32_t)g << 8) |
			((uint32_t)r << 16);
	if (info->pixel_format == PIXEL_BIT_MASK)
		return pixel_from_masks(info->masks, r, g, b);
	return 0xff000000u | ((uint32_t)r << 16) | ((uint32_t)g << 8) |
		(uint32_t)b;
}

static EFI_GRAPHICS_OUTPUT_BLT_PIXEL blt_pixel(uint8_t r, uint8_t g, uint8_t b)
{
	EFI_GRAPHICS_OUTPUT_BLT_PIXEL pixel = {
		.Blue = b,
		.Green = g,
		.Red = r,
		.Reserved = 0,
	};

	return pixel;
}

static void blt_fill(GOP_INFO *info, EFI_UINTN x, EFI_UINTN y,
		     EFI_UINTN width, EFI_UINTN height, uint8_t r, uint8_t g,
		     uint8_t b)
{
	EFI_GRAPHICS_OUTPUT_BLT_PIXEL color = blt_pixel(r, g, b);

	if (info->gop == NULL || info->gop->Blt == NULL || width == 0 || height == 0)
		return;

	info->gop->Blt(info->gop, &color, EfiBltVideoFill, 0, 0, x, y, width,
		     height, 0);
}

static void paint_blt_pattern(GOP_INFO *info)
{
	const EFI_UINTN width = info->width;
	const EFI_UINTN height = info->height;
	const EFI_UINTN bar_width = width / 8u;
	const uint8_t colors[][3] = {
		{ 255, 0, 0 },
		{ 0, 255, 0 },
		{ 0, 0, 255 },
		{ 255, 255, 255 },
		{ 0, 0, 0 },
		{ 255, 0, 255 },
		{ 0, 255, 255 },
		{ 255, 255, 0 },
	};

	if (width < 12 || height < 12 || bar_width == 0)
		return;

	for (EFI_UINTN i = 0; i < 8; i++) {
		EFI_UINTN x = i * bar_width;
		EFI_UINTN next_x = (i == 7) ? width : (i + 1u) * bar_width;

		blt_fill(info, x, 0, next_x - x, height, colors[i][0],
			 colors[i][1], colors[i][2]);
	}

	blt_fill(info, 0, 0, width, 12, 0, 255, 0);
	blt_fill(info, 0, height - 12, width, 12, 0, 255, 0);
	blt_fill(info, 0, 0, 12, height, 0, 255, 0);
	blt_fill(info, width - 12, 0, 12, height, 0, 255, 0);

	for (EFI_UINTN x = 0; x < width; x += 60)
		blt_fill(info, x, 0, 2, height, 32, 32, 32);
	for (EFI_UINTN y = 0; y < height; y += 100)
		blt_fill(info, 0, y, width, 2, 32, 32, 32);

	if (width >= 96 && height >= 96)
		blt_fill(info, 32, 32, 64, 64, 255, 255, 255);
}

static bool direct_marker_fits(GOP_INFO *info, uint32_t stride, uint32_t x,
			       uint32_t y, uint64_t *start_byte, uint64_t *end_byte)
{
	if (info->framebuffer_base == 0 || info->framebuffer_base > UINTPTR_MAX ||
	    info->pixel_format == PIXEL_BLT_ONLY || stride < info->width ||
	    x + 64u > info->width || y + 64u > info->height)
		return false;

	*start_byte = ((uint64_t)y * stride + x) * 4ull;
	*end_byte = ((uint64_t)(y + 63u) * stride + x + 63u) * 4ull + 4ull;
	if (info->framebuffer_size != 0 && *end_byte > info->framebuffer_size)
		return false;
	return true;
}

static void test_direct_marker(EFI_SYSTEM_TABLE *system_table, GOP_INFO *info,
			       const EFI_CHAR16 *label, uint32_t stride, uint32_t x,
			       uint32_t y, uint8_t r, uint8_t g, uint8_t b)
{
	volatile uint32_t *base;
	uint64_t start_byte;
	uint64_t end_byte;
	uint32_t value;
	const uint32_t fill = make_direct_pixel(info, r, g, b);
	const uint32_t white = make_direct_pixel(info, 255, 255, 255);

	print_string(system_table, label);
	if (!direct_marker_fits(info, stride, x, y, &start_byte, &end_byte)) {
		print_string(system_table, direct_skip);
		return;
	}

	print_string(system_table, direct_offset);
	print_decimal64(system_table, start_byte);
	print_string(system_table, direct_end);
	print_decimal64(system_table, end_byte);
	print_string(system_table, crlf);

	base = (volatile uint32_t *)(uintptr_t)info->framebuffer_base;
	for (uint32_t yy = 0; yy < 64; yy++) {
		for (uint32_t xx = 0; xx < 64; xx++) {
			uint32_t color = fill;

			if (xx >= 16u && xx < 48u && yy >= 16u && yy < 48u)
				color = white;
			base[(y + yy) * stride + x + xx] = color;
		}
	}

	value = base[y * stride + x];
	print_string(system_table, label);
	print_string(system_table, direct_read);
	print_decimal32(system_table, value);
	print_string(system_table, crlf);

	for (uint32_t yy = 0; yy < 64; yy++) {
		uintptr_t row = (uintptr_t)&base[(y + yy) * stride + x];

		clean_dcache_range(row, 64u * 4u);
	}

	value = base[y * stride + x];
	print_string(system_table, label);
	print_string(system_table, direct_clean_read);
	print_decimal32(system_table, value);
	print_string(system_table, crlf);
}

static GOP_INFO get_gop_info(EFI_SYSTEM_TABLE *system_table)
{
	GOP_INFO info = { 0 };
	EFI_GRAPHICS_OUTPUT_PROTOCOL *gop = NULL;

	if (system_table == NULL || system_table->BootServices == NULL ||
	    system_table->BootServices->LocateProtocol == NULL)
		return info;

	if (system_table->BootServices->LocateProtocol(&gop_guid, NULL,
	    (void **)&gop) != EFI_SUCCESS || gop == NULL || gop->Mode == NULL ||
	    gop->Mode->Info == NULL)
		return info;

	info.gop = gop;
	info.width = gop->Mode->Info->HorizontalResolution;
	info.height = gop->Mode->Info->VerticalResolution;
	info.stride_pixels = gop->Mode->Info->PixelsPerScanLine;
	info.pixel_format = gop->Mode->Info->PixelFormat;
	info.masks = gop->Mode->Info->PixelInformation;
	info.framebuffer_base = gop->Mode->FrameBufferBase;
	info.framebuffer_size = gop->Mode->FrameBufferSize;

	print_string(system_table, gop_found);
	print_string(system_table, gop_mode_prefix);
	print_decimal32(system_table, info.width);
	print_string(system_table, (const EFI_CHAR16[]){ 'x', 0 });
	print_decimal32(system_table, info.height);
	print_string(system_table, (const EFI_CHAR16[]){ ' ', 's', 't', 'r', 'i', 'd', 'e', ' ', 0 });
	print_decimal32(system_table, info.stride_pixels);
	print_string(system_table, (const EFI_CHAR16[]){ ' ', 'f', 'o', 'r', 'm', 'a', 't', ' ', 0 });
	print_decimal32(system_table, info.pixel_format);
	print_string(system_table, crlf);
	print_string(system_table, fb_prefix);
	print_decimal64(system_table, info.framebuffer_base);
	print_string(system_table, space);
	print_string(system_table, (const EFI_CHAR16[]){ 's', 'i', 'z', 'e', ' ', 0 });
	print_decimal64(system_table, info.framebuffer_size);
	print_string(system_table, crlf);
	if (gop->Blt == NULL)
		print_string(system_table, blt_missing);
	else
		print_string(system_table, GOP_BLT_ENABLED ? blt_enabled : blt_disabled);
	if (GOP_BLT_ENABLED && gop->Blt != NULL)
		print_string(system_table, blt_delay);
	print_string(system_table, GOP_DIRECT_ENABLED ? direct_enabled : direct_disabled);
	if (GOP_DIRECT_ENABLED && info.framebuffer_base != 0 &&
	    info.pixel_format != PIXEL_BLT_ONLY)
		print_string(system_table, direct_delay);

	return info;
}

EFI_STATUS EFIAPI EfiMain(EFI_HANDLE image_handle, EFI_SYSTEM_TABLE *system_table)
{
	(void)image_handle;

	print_string(system_table, banner);

	GOP_INFO info = get_gop_info(system_table);

	if (info.gop == NULL)
		print_string(system_table, gop_missing);
	else if (GOP_BLT_ENABLED && info.gop->Blt != NULL && system_table != NULL &&
		 system_table->BootServices != NULL &&
		 system_table->BootServices->Stall != NULL)
		system_table->BootServices->Stall(GOP_BLT_DELAY_US);

	if (GOP_BLT_ENABLED && info.gop != NULL && info.gop->Blt != NULL)
		paint_blt_pattern(&info);

	if (GOP_DIRECT_ENABLED && info.gop != NULL && info.framebuffer_base != 0 &&
	    info.pixel_format != PIXEL_BLT_ONLY) {
		if (system_table != NULL && system_table->BootServices != NULL &&
		    system_table->BootServices->Stall != NULL)
			system_table->BootServices->Stall(GOP_DIRECT_DELAY_US);
		print_string(system_table, post_blt_conout);
		if (system_table != NULL && system_table->BootServices != NULL &&
		    system_table->BootServices->Stall != NULL)
			system_table->BootServices->Stall(GOP_DIRECT_DELAY_US);
		print_string(system_table, direct_store_start);
		uint32_t marker_x = info.width >= 128u ? info.width - 96u : 0;
		uint32_t marker_y = info.height >= 128u ? info.height - 96u : 0;

		test_direct_marker(system_table, &info, direct_gop_marker,
				   info.stride_pixels, marker_x, 64u,
				   0, 0, 255);
		test_direct_marker(system_table, &info, direct_tight_marker,
				   info.width, marker_x, marker_y,
				   255, 0, 0);
	}

	for (;;) {
		if (system_table != NULL && system_table->BootServices != NULL &&
		    system_table->BootServices->Stall != NULL)
			system_table->BootServices->Stall(500000);
	}

	return EFI_SUCCESS;
}
