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
	NSWindow*     m_window;
	NSTextView*   m_textView;
	NSProgressIndicator* m_progressBar;

	//NSDictionary* m_defaultTextAttributes;

	void AppendString(const char* message);

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
		//[m_progressBar setControlTint:NSGraphiteControlTint];
		[m_progressBar setIndeterminate:NO];
		[m_progressBar setMaxValue:maxProgress];
	}

	//NSString* const title = [NSString stringWithFormat:@"%s %s - Console", GAMESIG, GetVersionString()];

	[m_window initWithContentRect:NSMakeRect(0, 0, 512, 384)
						styleMask:NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask
						  backing:NSBackingStoreBuffered
							defer:NO];
	[m_window setTitle:@"Console"];
	[m_window center];

	//NSView* contentView = [[NSView alloc] initWithFrame:[[m_window contentView] frame]];

	//NSScrollView* scrollView = [[NSScrollView alloc] initWithFrame:[[m_window contentView] frame]];
	NSScrollView* scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 16, 512, 336)];
	[scrollView setBorderType:NSNoBorder];
	[scrollView setHasVerticalScroller:YES];
	[scrollView setHasHorizontalScroller:NO];
	[scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

	NSSize contentSize = [scrollView contentSize];

//	NSColor* backgroundColor = [NSColor colorWithRed:0.28f
//											   green:0.28f
//												blue:0.28f
//											   alpha:1.00f];

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

	NSView* contentView = [m_window contentView];
	[contentView addSubview:m_progressBar];
	[contentView addSubview:scrollView];
	[contentView addSubview:titleText];

	[m_window makeKeyAndOrderFront:nil];
	[m_window makeFirstResponder:m_textView];

	AppendString("OMG!!!!1111!!!!!111111!!!!! <<<<<<<<<<<<< This is very very very long message for testing word wrap feature! >>>>>>>>>\n");
	AppendString("1");
	AppendString("2");
	AppendString("3");
	AppendString("\n");

	AppendString("\n\n\n\n\n\n\n\n");

	I_PrintToConsoleWindow = PrintCallback;
}

FBasicStartupScreen::~FBasicStartupScreen()
{
	//[m_window close];
	I_PrintToConsoleWindow = NULL;
}


void FBasicStartupScreen::Progress()
{
	if (CurPos < MaxPos)
	{
		[m_progressBar setDoubleValue:CurPos++];
	}

	[[NSRunLoop currentRunLoop] limitDateForMode:NSDefaultRunLoopMode];
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


void FBasicStartupScreen::AppendString(const char* const message)
{
	NSString* const text = [NSString stringWithUTF8String:message];

	NSFont* font = [NSFont systemFontOfSize:14.0f];
	//NSDictionary * fontAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:systemFont, NSFontAttributeName, nil];

//	NSColor* fontColor = [NSColor colorWithRed:0.88f
//										 green:0.88f
//										  blue:0.88f
//										 alpha:1.00f];
	//NSDictionary* attributes = [NSDictionary dictionaryWithObject:fontColor
	//													   forKey:NSForegroundColorAttributeName];

	NSDictionary* attributes = [NSDictionary dictionaryWithObjectsAndKeys:font,
		NSFontAttributeName, RGB(223, 223, 223), NSForegroundColorAttributeName, nil];

	NSAttributedString* const formattedText = [[NSAttributedString alloc] initWithString:text
																			  attributes:attributes];
	[[m_textView textStorage] appendAttributedString:formattedText];
	//[m_textView scrollRangeToVisible:NSMakeRange([[m_textView string] length], 0)];
	[m_textView scrollRangeToVisible:NSMakeRange(INT_MAX, 0)];

	//[m_textView setNeedsDisplay:YES];

	[[NSRunLoop currentRunLoop] limitDateForMode:NSDefaultRunLoopMode];
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


// ---------------------------------------------------------------------------


//void I_PrintStr (const char *cp)
//{
//	// Strip out any color escape sequences before writing to the log file
//	char * copy = new char[strlen(cp)+1];
//	const char * srcp = cp;
//	char * dstp = copy;
//
//	while (*srcp != 0)
//	{
//		if (*srcp!=0x1c && *srcp!=0x1d && *srcp!=0x1e && *srcp!=0x1f)
//		{
//			*dstp++=*srcp++;
//		}
//		else
//		{
//			if (srcp[1]!=0) srcp+=2;
//			else break;
//		}
//	}
//	*dstp=0;
//
//	fputs (copy, stdout);
//	delete [] copy;
//	fflush (stdout);
//
//	if (StartScreen)
//	{
//		static_cast<FBasicStartupScreen*>(StartScreen)->AppendString(cp);
//	}
//}
