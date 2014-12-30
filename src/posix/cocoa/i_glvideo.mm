/*
 ** i_glvideo.mm
 **
 **---------------------------------------------------------------------------
 ** Copyright 2012-2014 Alexey Lysiuk
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

#import <AppKit/NSOpenGL.h>

#include "sdlglvideo.h"


SDLGLFB::SDLGLFB(void*, const int width, const int height, int, int, const bool fullscreen)
: DFrameBuffer(width, height)
, m_Lock(-1)
, m_UpdatePending(false)
, m_fullscreen(fullscreen)
, m_supportsGamma(true)
{
}

SDLGLFB::~SDLGLFB()
{
}


bool SDLGLFB::Lock(bool buffered)
{
	m_Lock++;

	Buffer = MemBuffer;

	return true;
}

void SDLGLFB::Unlock() 	
{ 
	if (m_UpdatePending && 1 == m_Lock)
	{
		Update();
	}
	else if (--m_Lock <= 0)
	{
		m_Lock = 0;
	}
}

bool SDLGLFB::IsLocked()
{ 
	return m_Lock > 0;
}


bool SDLGLFB::IsFullscreen()
{
	return m_fullscreen;
}

void SDLGLFB::SetVSync(bool vsync)
{
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1050
	const long value = vsync ? 1 : 0;
#else // 10.5 or newer
	const GLint value = vsync ? 1 : 0;
#endif // prior to 10.5

	[[NSOpenGLContext currentContext] setValues:&value
								   forParameter:NSOpenGLCPSwapInterval];
}


bool SDLGLFB::CanUpdate()
{
	if (m_Lock != 1)
	{
		if (m_Lock > 0)
		{
			m_UpdatePending = true;
			--m_Lock;
		}

		return false;
	}

	return true;
}

void SDLGLFB::SetGammaTable(WORD *tbl)
{
	// TODO !!!
}

void SDLGLFB::SwapBuffers()
{
	[[NSOpenGLContext currentContext] flushBuffer];
}
