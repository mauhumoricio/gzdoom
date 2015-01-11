//-----------------------------------------------------------------------------
//
// Copyright (C) 1993-1996 by id Software, Inc.
//
// This source is available for distribution and/or modification
// only under the terms of the DOOM Source Code License as
// published by id Software. All rights reserved.
//
// The source is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// FITNESS FOR A PARTICULAR PURPOSE. See the DOOM Source Code License
// for more details.
//
//-----------------------------------------------------------------------------

/*
 ** i_system.mm
 **
 **---------------------------------------------------------------------------
 ** Copyright 2012-2015 Alexey Lysiuk
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

#include "i_common.h"

#include <fnmatch.h>
#include <unistd.h>
#include <sys/stat.h>

#include "d_ticcmd.h"
#include "doomdef.h"
#include "doomerrors.h"
#include "doomstat.h"
#include "g_game.h"
#include "gameconfigfile.h"
#include "i_sound.h"
#include "i_system.h"
#include "x86.h"


EXTERN_CVAR(String, language)

DWORD LanguageIDs[4];


int (*I_GetTime)(bool saveMS);
int (*I_WaitForTic)(int);
void (*I_FreezeTime)(bool frozen);


void I_Tactile (int /*on*/, int /*off*/, int /*total*/)
{
}


ticcmd_t emptycmd;

ticcmd_t *I_BaseTiccmd(void)
{
    return &emptycmd;
}


void I_BeginRead(void)
{
}

void I_EndRead(void)
{
}


void I_WaitVBL (int count)
{
    // I_WaitVBL is never used to actually synchronize to the
    // vertical blank. Instead, it's used for delay purposes.
    usleep (1000000 * count / 70);
}


//
// SetLanguageIDs
//
void SetLanguageIDs ()
{
	size_t langlen = strlen(language);

	DWORD lang = (langlen < 2 || langlen > 3) ?
		MAKE_ID('e','n','u','\0') :
		MAKE_ID(language[0],language[1],language[2],'\0');

	LanguageIDs[3] = LanguageIDs[2] = LanguageIDs[1] = LanguageIDs[0] = lang;
}


void I_InitTimer();
void I_ShutdownTimer();

void I_Init (void)
{
	CheckCPUID (&CPU);
	DumpCPUInfo (&CPU);

	atterm (I_ShutdownSound);
    I_InitSound ();
	I_InitTimer ();
}

static int has_exited;

void I_Quit (void)
{
    has_exited = 1;		/* Prevent infinitely recursive exits -- killough */

    if (demorecording)
		G_CheckDemoStatus();

	C_DeinitConsole();

	I_ShutdownTimer();
}


extern FILE* Logfile;
bool gameisdead;

void STACK_ARGS I_FatalError (const char *error, ...)
{
    static bool alreadyThrown = false;
    gameisdead = true;

    if (!alreadyThrown)		// ignore all but the first message -- killough
    {
		alreadyThrown = true;
		char errortext[MAX_ERRORTEXT];
		int index;
		va_list argptr;
		va_start (argptr, error);
		index = vsnprintf (errortext, MAX_ERRORTEXT, error, argptr);
		va_end (argptr);

		extern void Mac_I_FatalError(const char*);
		Mac_I_FatalError(errortext);
		
		// Record error to log (if logging)
		if (Logfile)
		{
			fprintf (Logfile, "\n**** DIED WITH FATAL ERROR:\n%s\n", errortext);
			fflush (Logfile);
		}

		fprintf (stderr, "%s\n", errortext);
		exit (-1);
    }

    if (!has_exited)	// If it hasn't exited yet, exit now -- killough
    {
		has_exited = 1;	// Prevent infinitely recursive exits -- killough
		exit(-1);
    }
}

void STACK_ARGS I_Error (const char *error, ...)
{
    va_list argptr;
    char errortext[MAX_ERRORTEXT];

    va_start (argptr, error);
    vsprintf (errortext, error, argptr);
    va_end (argptr);

    throw CRecoverableError (errortext);
}


void I_SetIWADInfo()
{
}


void I_PrintStr(const char *cp)
{
	// Strip out any color escape sequences before writing to the log file
	char * copy = new char[strlen(cp)+1];
	const char * srcp = cp;
	char * dstp = copy;

	while (*srcp != 0)
	{
		if (*srcp!=0x1c && *srcp!=0x1d && *srcp!=0x1e && *srcp!=0x1f)
		{
			*dstp++=*srcp++;
		}
		else
		{
			if (srcp[1]!=0) srcp+=2;
			else break;
		}
	}
	*dstp=0;

	fputs (copy, stdout);
	delete [] copy;
	fflush (stdout);
}


int I_PickIWad(WadStuff* wads, int numwads, bool showwin, int defaultiwad)
{
	if (!showwin)
	{
		return defaultiwad;
	}

	I_SetMainWindowVisible(false);

	extern int I_PickIWad_Cocoa(WadStuff*, int, bool, int);
	const int result = I_PickIWad_Cocoa(wads, numwads, showwin, defaultiwad);

	I_SetMainWindowVisible(true);

	return result;
}


bool I_WriteIniFailed ()
{
	printf ("The config file %s could not be saved:\n%s\n", GameConfig->GetPathName(), strerror(errno));
	return false;
	// return true to retry
}


static const char *pattern;

#if MAC_OS_X_VERSION_MAX_ALLOWED < 1080
static int matchfile (struct dirent *ent)
#else
static int matchfile (const struct dirent *ent)
#endif
{
    return fnmatch (pattern, ent->d_name, FNM_NOESCAPE) == 0;
}

void *I_FindFirst (const char *filespec, findstate_t *fileinfo)
{
	FString dir;
	
	const char *slash = strrchr (filespec, '/');
	if (slash)
	{
		pattern = slash+1;
		dir = FString(filespec, slash-filespec+1);
	}
	else
	{
		pattern = filespec;
		dir = ".";
	}

    fileinfo->current = 0;
    fileinfo->count = scandir(dir.GetChars(), &fileinfo->namelist, matchfile, alphasort);
    if (fileinfo->count > 0)
    {
		return fileinfo;
    }
    return (void*)-1;
}

int I_FindNext (void *handle, findstate_t *fileinfo)
{
    findstate_t *state = (findstate_t *)handle;
    if (state->current < fileinfo->count)
    {
	    return ++state->current < fileinfo->count ? 0 : -1;
	}
	return -1;
}

int I_FindClose (void *handle)
{
	findstate_t *state = (findstate_t *)handle;
	if (handle != (void*)-1 && state->count > 0)
	{
		for(int i = 0;i < state->count;++i)
			free (state->namelist[i]);
		state->count = 0;
		free (state->namelist);
		state->namelist = NULL;
	}
	return 0;
}

int I_FindAttr (findstate_t *fileinfo)
{
	dirent *ent = fileinfo->namelist[fileinfo->current];
	struct stat buf;

	if (stat(ent->d_name, &buf) == 0)
	{
		return S_ISDIR(buf.st_mode) ? FA_DIREC : 0;
	}
	return 0;
}


static NSString* GetPasteboardStringType()
{
#if MAC_OS_X_VERSION_MAX_ALLOWED < 1060
	return NSStringPboardType;
#else // 10.6 or higher
	return NSAppKitVersionNumber < AppKit10_6
		? NSStringPboardType
		: NSPasteboardTypeString;
#endif // before 10.6
}

void I_PutInClipboard(const char* const string)
{
	NSPasteboard* const pasteBoard = [NSPasteboard generalPasteboard];
	[pasteBoard clearContents];
	[pasteBoard setString:[NSString stringWithUTF8String:string]
				  forType:GetPasteboardStringType()];
}

FString I_GetFromClipboard(bool)
{
	NSPasteboard* const pasteBoard = [NSPasteboard generalPasteboard];
	NSString* const value = [pasteBoard stringForType:GetPasteboardStringType()];

	return FString([value UTF8String]);
}


// Return a random seed, preferably one with lots of entropy.
unsigned int I_MakeRNGSeed()
{
	unsigned int seed;
	int file;

	// Try reading from /dev/urandom first, then /dev/random, then
	// if all else fails, use a crappy seed from time().
	seed = time(NULL);
	file = open("/dev/urandom", O_RDONLY);
	if (file < 0)
	{
		file = open("/dev/random", O_RDONLY);
	}
	if (file >= 0)
	{
		read(file, &seed, sizeof(seed));
		close(file);
	}
	return seed;
}
