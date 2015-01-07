/*
** gl_hqresize.cpp
** Contains high quality upsampling functions.
** So far Scale2x/3x/4x as described in http://scale2x.sourceforge.net/
** are implemented.
**
**---------------------------------------------------------------------------
** Copyright 2008 Benjamin Berkels
** All rights reserved.
**
** Redistribution and use in source and binary forms, with or without
** modification, are permitted provided that the following conditions
** are met:
**
** 1. Redistributions of source code must retain the above copyright
**    notice, this list of conditions and the following disclaimer.
** 2. Redistributions in binary form must reproduce the above copyright
**    notice, this list of conditions and the following disclaimer in the
**    documentation and/or other materials provided with the distribution.
** 3. The name of the author may not be used to endorse or promote products
**    derived from this software without specific prior written permission.
**
** THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
** IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
** OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
** IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
** INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
** NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
** DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
** THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
** (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
** THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
**---------------------------------------------------------------------------
**
*/

#ifdef __APPLE__
#	include <AvailabilityMacros.h>
#	if MAC_OS_X_VERSION_MAX_ALLOWED >= 1060
#		define GZ_USE_LIBDISPATCH
#	endif // MAC_OS_X_VERSION_MAX_ALLOWED >= 1060
#endif // __APPLE__

#ifdef GZ_USE_LIBDISPATCH
#include <dispatch/dispatch.h>
#endif // GZ_USE_LIBDISPATCH

#include "gl/system/gl_system.h"
#include "gl/system/gl_interface.h"
#include "gl/renderer/gl_renderer.h"
#include "gl/textures/gl_texture.h"
#include "c_cvars.h"
#include "gl/hqnx/hqnx.h"
#include "gl/xbr/xbrz.h"

CUSTOM_CVAR(Int, gl_texture_hqresize, 0, CVAR_ARCHIVE | CVAR_GLOBALCONFIG | CVAR_NOINITCALL)
{
	if (self < 0 || self > 10)
		self = 0;
	GLRenderer->FlushTextures();
}

CUSTOM_CVAR(Int, gl_texture_hqresize_maxinputsize, 512, CVAR_ARCHIVE | CVAR_GLOBALCONFIG | CVAR_NOINITCALL)
{
	if (self > 1024) self = 1024;
	GLRenderer->FlushTextures();
}

CUSTOM_CVAR(Int, gl_texture_hqresize_targets, 7, CVAR_ARCHIVE | CVAR_GLOBALCONFIG | CVAR_NOINITCALL)
{
	GLRenderer->FlushTextures();
}

CVAR (Flag, gl_texture_hqresize_textures, gl_texture_hqresize_targets, 1);
CVAR (Flag, gl_texture_hqresize_sprites, gl_texture_hqresize_targets, 2);
CVAR (Flag, gl_texture_hqresize_fonts, gl_texture_hqresize_targets, 4);


static void scale2x(uint32* const input, uint32* const output, const size_t width, const size_t height)
{
	const size_t scaledWidth = 2 * width;

	for (size_t i = 0; i < width; ++i)
	{
		const size_t iMinus = (i > 0        ) ? (i - 1) : 0;
		const size_t iPlus  = (i < width - 1) ? (i + 1) : i;

		for (size_t j = 0; j < height; ++j)
		{
			const size_t jMinus = (j > 0         ) ? (j - 1) : 0;
			const size_t jPlus  = (j < height - 1) ? (j + 1) : j;

			const uint32 A = input[iMinus + width * jMinus];
			const uint32 B = input[iMinus + width * j     ];
			const uint32 C = input[iMinus + width * jPlus ];
			const uint32 D = input[i      + width * jMinus];
			const uint32 E = input[i      + width * j     ];
			const uint32 F = input[i      + width * jPlus ];
			const uint32 G = input[iPlus  + width * jMinus];
			const uint32 H = input[iPlus  + width * j     ];
			const uint32 I = input[iPlus  + width * jPlus ];

			if (B != H && D != F)
			{
				output[2 * i     + scaledWidth *  2 * j     ] = D == B ? D : E;
				output[2 * i     + scaledWidth * (2 * j + 1)] = B == F ? F : E;
				output[2 * i + 1 + scaledWidth *  2 * j     ] = D == H ? D : E;
				output[2 * i + 1 + scaledWidth * (2 * j + 1)] = H == F ? F : E;
			}
			else
			{
				output[2 * i     + scaledWidth *  2 * j     ] = E;
				output[2 * i     + scaledWidth * (2 * j + 1)] = E;
				output[2 * i + 1 + scaledWidth *  2 * j     ] = E;
				output[2 * i + 1 + scaledWidth * (2 * j + 1)] = E;
			}
		}
	}
}

static void scale3x(uint32* const input, uint32* const output, const size_t width, const size_t height)
{
	const size_t scaledWidth = 3 * width;

	for (size_t i = 0; i < width; ++i)
	{
		const int iMinus = (i > 0        ) ? (i - 1) : 0;
		const int iPlus  = (i < width - 1) ? (i + 1) : i;

		for (size_t j = 0; j < height; ++j)
		{
			const size_t jMinus = (j > 0          ) ? (j - 1) : 0;
			const size_t jPlus  = (j < height - 1 ) ? (j + 1) : j;

			const uint32 A = input[iMinus + width * jMinus];
			const uint32 B = input[iMinus + width * j     ];
			const uint32 C = input[iMinus + width * jPlus ];
			const uint32 D = input[i      + width * jMinus];
			const uint32 E = input[i      + width * j     ];
			const uint32 F = input[i      + width * jPlus ];
			const uint32 G = input[iPlus  + width * jMinus];
			const uint32 H = input[iPlus  + width * j     ];
			const uint32 I = input[iPlus  + width * jPlus ];

			if (B != H && D != F)
			{
				output[3 * i     + scaledWidth *  3 * j     ] = D == B ? D : E;
				output[3 * i     + scaledWidth * (3 * j + 1)] = (D == B && E != C) || (B == F && E != A) ? B : E;
				output[3 * i     + scaledWidth * (3 * j + 2)] = B == F ? F : E;
				output[3 * i + 1 + scaledWidth *  3 * j     ] = (D == B && E != G) || (D == H && E != A) ? D : E;
				output[3 * i + 1 + scaledWidth * (3 * j + 1)] = E;
				output[3 * i + 1 + scaledWidth * (3 * j + 2)] = (B == F && E != I) || (H == F && E != C) ? F : E;
				output[3 * i + 2 + scaledWidth *  3 * j     ] = D == H ? D : E;
				output[3 * i + 2 + scaledWidth * (3 * j + 1)] = (D == H && E != I) || (H == F && E != G) ? H : E;
				output[3 * i + 2 + scaledWidth * (3 * j + 2)] = H == F ? F : E;
			}                                       
			else
			{
				output[3 * i     + scaledWidth *  3 * j     ] = E;
				output[3 * i     + scaledWidth * (3 * j + 1)] = E;
				output[3 * i     + scaledWidth * (3 * j + 2)] = E;
				output[3 * i + 1 + scaledWidth *  3 * j     ] = E;
				output[3 * i + 1 + scaledWidth * (3 * j + 1)] = E;
				output[3 * i + 1 + scaledWidth * (3 * j + 2)] = E;
				output[3 * i + 2 + scaledWidth *  3 * j     ] = E;
				output[3 * i + 2 + scaledWidth * (3 * j + 1)] = E;
				output[3 * i + 2 + scaledWidth * (3 * j + 2)] = E;
			}
		}
	}
}

static void scale4x(uint32* const input, uint32* const output, const size_t width, const size_t height)
{
	const size_t  width2x = 2 * width;
	const size_t height2x = 2 * height;

	uint32* const buffer2x = new uint32[width2x * height2x];

	scale2x(input,    buffer2x, width,   height  );
	scale2x(buffer2x, output,   width2x, height2x);

	delete[] buffer2x;
}


static const size_t BYTES_PER_PIXEL = sizeof(uint32);

typedef void (*ScaleFunction)(const size_t scale, const size_t width, const size_t height, uint32* const input, uint32* const output);


static void scaleNx(const size_t scale, const size_t width, const size_t height, uint32* const input, uint32* const output)
{
	void (*function)(uint32* const input, uint32* const output, const size_t width, const size_t height) = NULL;

	switch (scale)
	{
		case  2: function = scale2x;     break;
		case  3: function = scale3x;     break;
		case  4: function = scale4x;     break;
		default: assert(!"Wrong scale"); return;
	}

	function(input, output, width, height);
}

static void hqNx(const size_t scale, const size_t width, const size_t height, uint32* const input, uint32* const output)
{
	static bool isInitialized = false;

	if (!isInitialized)
	{
		InitLUTs();
		isInitialized = true;
	}

	CImage image;
	image.SetImage(reinterpret_cast<unsigned char*>(input), static_cast<int>(width), static_cast<int>(height), 32);
	image.Convert32To17();

	void (*function)(int* input, unsigned char* output, int width, int height, int pitch) = NULL;

	switch (scale)
	{
		case  2: function = hq2x_32;     break;
		case  3: function = hq3x_32;     break;
		case  4: function = hq4x_32;     break;
		default: assert(!"Wrong scale"); return;
	}

	function(reinterpret_cast<int*>(image.m_pBitmap), reinterpret_cast<unsigned char*>(output),
		static_cast<int>(width), static_cast<int>(height), static_cast<int>(width * scale * BYTES_PER_PIXEL));
}

#ifdef GZ_USE_LIBDISPATCH
CVAR(Bool, gl_texture_hqresize_multithread, true, CVAR_ARCHIVE | CVAR_GLOBALCONFIG);

CUSTOM_CVAR(Int, gl_texture_hqresize_mt_width, 16, CVAR_ARCHIVE | CVAR_GLOBALCONFIG)
{
	if (self < 2)    self = 2;
	if (self > 1024) self = 1024;
}

CUSTOM_CVAR(Int, gl_texture_hqresize_mt_height, 4, CVAR_ARCHIVE | CVAR_GLOBALCONFIG)
{
	if (self < 2)    self = 2;
	if (self > 1024) self = 1024;
}
#endif // GZ_USE_LIBDISPATCH

static void xbrzNx(const size_t scale, const size_t width, const size_t height, uint32* const input, uint32* const output)
{
#ifdef GZ_USE_LIBDISPATCH
	const size_t thresholdWidth  = gl_texture_hqresize_mt_width;
	const size_t thresholdHeight = gl_texture_hqresize_mt_height;

	if (   NULL != dispatch_get_global_queue
		&& NULL != dispatch_apply
		&& gl_texture_hqresize_multithread
		&& width  > thresholdWidth
		&& height > thresholdHeight)
	{
		const dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

		dispatch_apply(height / thresholdHeight + 1, queue, ^(size_t sliceY)
		{
			xbrz::scale(scale, input, output,
				static_cast<int>(width), static_cast<int>(height), xbrz::ScalerCfg(),
				sliceY * thresholdHeight, (sliceY + 1) * thresholdHeight);
		});
	}
	else
#endif // GZ_USE_LIBDISPATCH
	{
		xbrz::scale(scale, input, output, static_cast<int>(width), static_cast<int>(height));
	}
}


//===========================================================================
// 
// [BB] Upsamples the texture in input, frees input and returns
//  the upsampled buffer.
//
//===========================================================================
unsigned char *gl_CreateUpsampledTextureBuffer ( const FTexture *inputTexture, unsigned char *inputBuffer, const int inWidth, const int inHeight, int &outWidth, int &outHeight, bool hasAlpha )
{
	// [BB] Make sure that outWidth and outHeight denote the size of
	// the returned buffer even if we don't upsample the input buffer.
	outWidth = inWidth;
	outHeight = inHeight;

	// [BB] Don't resample if the width or height of the input texture is bigger than gl_texture_hqresize_maxinputsize.
	if ( ( inWidth > gl_texture_hqresize_maxinputsize ) || ( inHeight > gl_texture_hqresize_maxinputsize ) )
		return inputBuffer;

	// [BB] Don't try to upsample textures based off FCanvasTexture.
	if ( inputTexture->bHasCanvas )
		return inputBuffer;

	// [BB] Don't upsample non-shader handled warped textures. Needs too much memory and time
	if (gl.shadermodel == 2 || (gl.shadermodel == 3 && inputTexture->bWarped))
		return inputBuffer;

	switch (inputTexture->UseType)
	{
	case FTexture::TEX_Sprite:
	case FTexture::TEX_SkinSprite:
		if (!(gl_texture_hqresize_targets & 2)) return inputBuffer;
		break;

	case FTexture::TEX_FontChar:
		if (!(gl_texture_hqresize_targets & 4)) return inputBuffer;
		break;

	default:
		if (!(gl_texture_hqresize_targets & 1)) return inputBuffer;
		break;
	}

	if (inputBuffer)
	{
		outWidth = inWidth;
		outHeight = inHeight;
		int type = gl_texture_hqresize;
		// hqNx does not preserve the alpha channel so fall back to ScaleNx for such textures
		if (hasAlpha && type > 3 && type < 7)
		{
			type -= 3;
		}

		struct Scaler
		{
			size_t        factor;
			ScaleFunction function;
		};

		static const Scaler SCALERS[] =
		{
			{ 0, NULL    },
			{ 2, scaleNx },
			{ 3, scaleNx },
			{ 4, scaleNx },
			{ 2, hqNx    },
			{ 3, hqNx    },
			{ 4, hqNx    },
			{ 2, xbrzNx  },
			{ 3, xbrzNx  },
			{ 4, xbrzNx  },
			{ 5, xbrzNx  },
		};

		if (type > 0)
		{
			const Scaler& scaler = SCALERS[type];
			const size_t scale = scaler.factor;

			uint32* const output = new uint32[scale * inWidth * scale * inHeight];
			scaler.function(scale, inWidth, inHeight, reinterpret_cast<uint32*>(inputBuffer), output);

			outWidth  = static_cast<int>(scaler.factor * inWidth );
			outHeight = static_cast<int>(scaler.factor * inHeight);

			delete[] inputBuffer;

			return reinterpret_cast<unsigned char*>(output);
		}
	}

	return inputBuffer;
}
