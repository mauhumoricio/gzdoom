/*
 ** st_start.mm
 **
 **---------------------------------------------------------------------------
 ** Copyright 2015 Alexey Lysiuk
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

#include "d_main.h"
#include "i_system.h"
#include "st_start.h"
#include "v_text.h"
//#include "version.h"


// ---------------------------------------------------------------------------

/*
@interface VerticallyAlignedTextFieldCell : NSTextFieldCell
@end

@implementation VerticallyAlignedTextFieldCell

- (void)drawInteriorWithFrame:(NSRect)frame inView:(NSView *)view
{
	const NSInteger offset = floorf((NSHeight(frame)
		- ([[self font] ascender] - [[self font] descender])) / 2);
	const NSRect textRect = NSInsetRect(frame, 0.0, offset);

	[super drawInteriorWithFrame:textRect inView:view];
}

@end


@interface VerticallyAlignedTextField : NSTextField
@end

@implementation VerticallyAlignedTextField

- (instancetype)initWithFrame:(NSRect)frameRect
{
	[super initWithFrame:frameRect];

	[self setCell:[[VerticallyAlignedTextFieldCell alloc] init]];

	return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
	[[self backgroundColor] setFill];

	NSRectFill(dirtyRect);

	[super drawRect:dirtyRect];
}

@end
*/

// ---------------------------------------------------------------------------


static NSColor* RGB(const BYTE red, const BYTE green, const BYTE blue)
{
	return [NSColor colorWithRed:red   / 255.0f
						   green:green / 255.0f
							blue:blue  / 255.0f
						   alpha:1.0f];
}

static NSColor* RGB(const PalEntry color)
{
	return RGB(color.r, color.g, color.b);
}

static NSColor* RGB(const DWORD color)
{
	return RGB(PalEntry(color));
}


// ---------------------------------------------------------------------------


class FBasicStartupScreen : public FStartupScreen
{
public:
	FBasicStartupScreen(int maxProgress, bool showBar);
	~FBasicStartupScreen();

	virtual void Progress();

	virtual void NetInit(const char* message, int playerCount);
	virtual void NetProgress(int count);
	virtual void NetMessage(const char *format, ...);
	virtual void NetDone();
	virtual bool NetLoop(bool (*timerCallback)(void*), void* userData);

private:
	NSWindow*            m_window;
	NSTextView*          m_textView;
	NSProgressIndicator* m_progressBar;

	void AppendString(const char* message);
	void AppendString(PalEntry color, const char* message);

	static void PrintCallback(const char* message);
};


// ---------------------------------------------------------------------------


FBasicStartupScreen::FBasicStartupScreen(int maxProgress, bool showBar)
: FStartupScreen(maxProgress)
, m_window([NSWindow alloc])
, m_textView([NSTextView alloc])
, m_progressBar(nil)
{
	if (showBar)
	{
		m_progressBar = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(4, 0, 504, 16)];
		[m_progressBar setIndeterminate:NO];
		[m_progressBar setMaxValue:maxProgress];
	}

	NSScrollView* scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 16, 512, 336)];
	[scrollView setBorderType:NSNoBorder];
	[scrollView setHasVerticalScroller:YES];
	[scrollView setHasHorizontalScroller:NO];
	[scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

	NSSize contentSize = [scrollView contentSize];

	[m_textView initWithFrame:NSMakeRect(0, 0, contentSize.width, contentSize.height)];
	[m_textView setEditable:NO];
	[m_textView setBackgroundColor:RGB(70, 70, 70)];
	[m_textView setMinSize:NSMakeSize(0.0, contentSize.height)];
	[m_textView setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
	[m_textView setVerticallyResizable:YES];
	[m_textView setHorizontallyResizable:NO];
	[m_textView setAutoresizingMask:NSViewWidthSizable];
	[scrollView setDocumentView:m_textView];

	NSTextContainer* textContainer = [m_textView textContainer];
	[textContainer setContainerSize:NSMakeSize(contentSize.width, FLT_MAX)];
	[textContainer setWidthTracksTextView:YES];

	NSTextField* titleText = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 352, 512, 32)];
	//VerticallyAlignedTextField* titleText = [[VerticallyAlignedTextField alloc] initWithFrame:NSMakeRect(0, 352, 512, 32)];
	[titleText setStringValue:[NSString stringWithUTF8String:DoomStartupInfo.Name]];
	[titleText setAlignment:NSCenterTextAlignment];
	[titleText setTextColor:RGB(DoomStartupInfo.FgColor)];
	[titleText setBackgroundColor:RGB(DoomStartupInfo.BkColor)];
	[titleText setFont:[NSFont fontWithName:@"Trebuchet MS Bold" size:18.0f]];
	[titleText setSelectable:NO];
	[titleText setBordered:NO];

	//NSString* const title = [NSString stringWithFormat:@"%s %s - Console", GAMESIG, GetVersionString()];

	[m_window initWithContentRect:NSMakeRect(0, 0, 512, 384)
						styleMask:NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask
						  backing:NSBackingStoreBuffered
							defer:NO];
	[m_window setTitle:@"Console"];
	[m_window center];

	NSView* contentView = [m_window contentView];
	[contentView addSubview:m_progressBar];
	[contentView addSubview:scrollView];
	[contentView addSubview:titleText];

	[m_window makeKeyAndOrderFront:nil];
	//[m_window makeFirstResponder:m_textView];

#ifdef _DEBUG
	AppendString("----------------------------------------------------------------\n");
	AppendString("1234567890 !@#$%^&*() ,<.>/?;:'\" [{]}\\| `~-_=+ "
		"This is very very very long message needed to trigger word wrapping...\n\n");
	AppendString("Multiline...\n\tmessage...\n\t\twith...\n\t\t\ttabs.\n\n");
	
	AppendString(TEXTCOLOR_BRICK "TEXTCOLOR_BRICK\n" TEXTCOLOR_TAN "TEXTCOLOR_TAN\n");
	AppendString(TEXTCOLOR_GRAY "TEXTCOLOR_GRAY & TEXTCOLOR_GREY\n");
	AppendString(TEXTCOLOR_GREEN "TEXTCOLOR_GREEN\n" TEXTCOLOR_BROWN "TEXTCOLOR_BROWN\n");
	AppendString(TEXTCOLOR_GOLD "TEXTCOLOR_GOLD\n" TEXTCOLOR_RED "TEXTCOLOR_RED\n");
	AppendString(TEXTCOLOR_BLUE "TEXTCOLOR_BLUE\n" TEXTCOLOR_ORANGE "TEXTCOLOR_ORANGE\n");
	AppendString(TEXTCOLOR_WHITE "TEXTCOLOR_WHITE\n" TEXTCOLOR_YELLOW "TEXTCOLOR_YELLOW\n");
	AppendString(TEXTCOLOR_UNTRANSLATED "TEXTCOLOR_UNTRANSLATED\n");
	AppendString(TEXTCOLOR_BLACK "TEXTCOLOR_BLACK\n" TEXTCOLOR_LIGHTBLUE "TEXTCOLOR_LIGHTBLUE\n");
	AppendString(TEXTCOLOR_CREAM "TEXTCOLOR_CREAM\n" TEXTCOLOR_OLIVE "TEXTCOLOR_OLIVE\n");
	AppendString(TEXTCOLOR_DARKGREEN "TEXTCOLOR_DARKGREEN\n" TEXTCOLOR_DARKRED "TEXTCOLOR_DARKRED\n");
	AppendString(TEXTCOLOR_DARKBROWN "TEXTCOLOR_DARKBROWN\n" TEXTCOLOR_PURPLE "TEXTCOLOR_PURPLE\n");
	AppendString(TEXTCOLOR_DARKGRAY "TEXTCOLOR_DARKGRAY\n" TEXTCOLOR_CYAN "TEXTCOLOR_CYAN\n");
	AppendString(TEXTCOLOR_NORMAL "TEXTCOLOR_NORMAL\n" TEXTCOLOR_BOLD "TEXTCOLOR_BOLD\n");
	AppendString(TEXTCOLOR_CHAT "TEXTCOLOR_CHAT\n" TEXTCOLOR_TEAMCHAT "TEXTCOLOR_TEAMCHAT\n");
	AppendString("----------------------------------------------------------------\n");
#endif // _DEBUG

	I_PrintToConsoleWindow = PrintCallback;
}

FBasicStartupScreen::~FBasicStartupScreen()
{
#ifndef _DEBUG
	[m_window close];
#endif // !_DEBUG

	I_PrintToConsoleWindow = NULL;
}


void FBasicStartupScreen::Progress()
{
	if (CurPos < MaxPos)
	{
		++CurPos;
	}

	static unsigned int previousTime = I_MSTime();
	unsigned int currentTime = I_MSTime();

	if (currentTime - previousTime > 50)
	{
		previousTime = currentTime;

		[m_progressBar setDoubleValue:CurPos];

		[[NSRunLoop currentRunLoop] limitDateForMode:NSDefaultRunLoopMode];
	}
}


void FBasicStartupScreen::NetInit(const char* const message, const int playerCount)
{

}

void FBasicStartupScreen::NetProgress(const int count)
{

}

void FBasicStartupScreen::NetMessage(const char* const format, ...)
{

}

void FBasicStartupScreen::NetDone()
{

}

bool FBasicStartupScreen::NetLoop(bool (*timerCallback)(void*), void* const userData)
{
	return true;
}


void FBasicStartupScreen::AppendString(const char* message)
{
	PalEntry color(223, 223, 223);

	char buffer[1024]= {};
	size_t pos = 0;

	while (*message != '\0')
	{
		if ((TEXTCOLOR_ESCAPE == *message && 0 != pos)
			|| (pos == sizeof buffer - 1))
		{
			buffer[pos] = '\0';
			pos = 0;

			AppendString(color, buffer);
		}

		if (TEXTCOLOR_ESCAPE == *message)
		{
			const BYTE* colorID = reinterpret_cast<const BYTE*>(message) + 1;
			const EColorRange range = V_ParseFontColor(colorID, CR_UNTRANSLATED, CR_YELLOW);

			if (range != CR_UNDEFINED)
			{
				color = V_LogColorFromColorRange(range);
			}

			message = reinterpret_cast<const char*>(colorID);
		}
		else
		{
			buffer[pos++] = *message++;
		}
	}

	if (0 != pos)
	{
		buffer[pos] = '\0';

		AppendString(color, buffer);
	}

	//[m_textView scrollRangeToVisible:NSMakeRange([[m_textView string] length], 0)];
	[m_textView scrollRangeToVisible:NSMakeRange(INT_MAX, 0)];

	[[NSRunLoop currentRunLoop] limitDateForMode:NSDefaultRunLoopMode];
}

void FBasicStartupScreen::AppendString(PalEntry color, const char* message)
{
	NSString* const text = [NSString stringWithUTF8String:message];

	NSDictionary* const attributes = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSFont systemFontOfSize:14.0f], NSFontAttributeName,
		RGB(color), NSForegroundColorAttributeName,
		nil];

	NSAttributedString* const formattedText =
		[[NSAttributedString alloc] initWithString:text
										attributes:attributes];
	[[m_textView textStorage] appendAttributedString:formattedText];
}


void FBasicStartupScreen::PrintCallback(const char* const message)
{
	if (NULL != StartScreen)
	{
		static_cast<FBasicStartupScreen*>(StartScreen)->AppendString(message);
	}
}


// ---------------------------------------------------------------------------


static void DeleteStartupScreen()
{
	delete StartScreen;
	StartScreen = NULL;
}

FStartupScreen *FStartupScreen::CreateInstance(const int maxProgress)
{
	atterm(DeleteStartupScreen);
	return new FBasicStartupScreen(maxProgress, true);
}
