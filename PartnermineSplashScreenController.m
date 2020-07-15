//
//  PartnermineSplashScreenController.m
//  AudioSlicer
//
//  Created by Bernd Heller on Sat Jul 02 2005.
//  Copyright (c) 2005 Bernd Heller. All rights reserved.
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

#import "PartnermineSplashScreenController.h"


@implementation PartnermineSplashScreenController

+ (id)sharedSplashScreenController
{
	static PartnermineSplashScreenController		*sharedController = nil;
	
	if (sharedController == nil) {
		sharedController = [[PartnermineSplashScreenController alloc] init];
	}
	
	return sharedController;
}

- (id)init
{
	if (self = [super initWithWindowNibName:@"PartnermineSplashScreen"]) {
		[self window];
	}
	
	return self;
}

- (void)dealloc
{
	[super dealloc];
}

- (void)showSplashScreen
{
	[[self window] center];
	[self showWindow:self];
	modalSession = [NSApp beginModalSessionForWindow:[self window]];
	NSInteger result;
	while ((result = [NSApp runModalSession:modalSession]) == NSRunContinuesResponse);
	[NSApp endModalSession:modalSession];
	
	if (result == NSRunAbortedResponse) {
		// aborted, do nothing
	} else {
		// open website
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://partnermine.com/"]];
	}
	
	[[self window] orderOut:self];
}

- (IBAction)ok:(id)sender
{
	[NSApp stopModal];
}

- (IBAction)cancel:(id)sender
{
	[NSApp abortModal];
}

@end
