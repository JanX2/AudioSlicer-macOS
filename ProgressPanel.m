//
//  ProgressPanel.m
//  AudioSlicer
//
//  Created by Bernd Heller on Thu Feb 26 2004.
//  Copyright (c) 2004-2006 Bernd Heller. All rights reserved.
//  
//  This file is part of AudioSlicer.
//  
//  AudioSlicer is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//  
//  AudioSlicer is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//  
//  You should have received a copy of the GNU General Public License
//  along with AudioSlicer; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307, USA

#import "ProgressPanel.h"


@implementation ProgressPanel

+ (id)progressPanelWithTitle:(NSString *)title messageText:(NSString *)message minValue:(double)min maxValue:(double)max
{
	ProgressPanel	*panel = [[ProgressPanel alloc] init];
	
	[panel setTitle:title];
	[panel setMessageText:message];
	[panel setMinValue:min maxValue:max];
	
	return [panel autorelease];
}


- (id)init
{
	if (self = [super initWithWindowNibName:@"ProgressPanel"]) {
		modalSession = nil;
		[self window];
	}
	
	return self;
}

- (void)dealloc
{
	[self close];
	[super dealloc];
}

- (void)windowDidLoad
{
	[progressIndicator setIndeterminate:NO];
	[progressIndicator setDoubleValue:0.0];
}

- (void)setTitle:(NSString *)title
{
	[titleTextField setStringValue:title];
	[[self window] setTitle:title];
}

- (void)setMessageText:(NSString *)message
{
	[messageTextField setStringValue:message];
}

- (void)setMinValue:(double)min maxValue:(double)max
{
	if (min < 0 || max < 0) {
		[self setIndeterminate:YES];
		[self startAnimation];
	} else {
		[self setIndeterminate:NO];
		[progressIndicator setMinValue:min];
		[progressIndicator setMaxValue:max];
	}
}

- (void)setProgress:(double)progress
{
	[progressIndicator setDoubleValue:progress];
}

- (void)setIndeterminate:(BOOL)flag
{
	[progressIndicator setIndeterminate:flag];
}

- (void)startAnimation
{
	[progressIndicator startAnimation:self];
}

- (void)stopAnimation
{
	[progressIndicator stopAnimation:self];
}


- (void)beginModalPanel
{
	shouldCancel = NO;
	[[self window] center];
	modalSession = [NSApp beginModalSessionForWindow:[self window]];
}

- (void)beginModalSheetForWindow:(NSWindow *)window
{
	shouldCancel = NO;
	[NSApp beginSheet:[self window] modalForWindow:window modalDelegate:nil didEndSelector:nil contextInfo:nil];
	modalSession = [NSApp beginModalSessionForWindow:[self window]];
}

- (void)endModalPanel
{
	[NSApp abortModal];
	if (modalSession) {
		[NSApp endModalSession:modalSession];
		modalSession = nil;
	}
	[[self window] orderOut:nil];
}

- (void)endModalSheet
{
	if (modalSession) {
		[NSApp abortModal];
		[NSApp endModalSession:modalSession];
		modalSession = nil;
		[[self window] orderOut:nil];
		[NSApp endSheet:[self window]];
	}
}

- (void)runModal
{
	if (modalSession) {
		[NSApp runModalSession:modalSession];
	}
}

- (void)runModalForWindow
{
	shouldCancel = NO;
	[[self window] center];
	[NSApp runModalForWindow:[self window]];
}

- (BOOL)shouldCancel
{
	return shouldCancel;
}


- (IBAction)cancel:(id)sender
{
	shouldCancel = YES;
}

@end
