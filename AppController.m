//
//  AppController.m
//  AudioSlicer
//
//  Created by Bernd Heller on Sun Feb 08 2004.
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

#import "AppController.h"
#import "InspectorController.h"
#import "PreferencesController.h"
#import "ZeroToEmptyStringTransformer.h"
#import "ClippingNumberFormatter.h"

#import "PCMAudioBuffer.h"

@implementation AppController

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// we use a slightly modified NumberFormatter that clips too small/big values to the limits without error message
	[ClippingNumberFormatter poseAsClass:[NSNumberFormatter class]];
	
	// register value transformers
	ZeroToEmptyStringTransformer	*zeroToEmptyStringTransformer = [[[ZeroToEmptyStringTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:zeroToEmptyStringTransformer
									forName:@"ZeroToEmptyStringTransformer"];
	
	// set user defaults
	[PreferencesController setDefaults];
	
	// give inspector a chance to show itself if user prefs say so
	[InspectorController sharedInspectorController];
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
	return NO;
}

- (IBAction)showInspector:(id)sender
{
	[[InspectorController sharedInspectorController] showInspector];
}

- (IBAction)toggleInspector:(id)sender
{
	[[InspectorController sharedInspectorController] toggleInspector];
}

- (IBAction)showPreferences:(id)sender
{
	[[PreferencesController sharedPreferencesController] showPreferences];
}

- (IBAction)showHelp:(id)sender
{
	NSString *manualPDFPath = [[NSBundle mainBundle] pathForResource:@"AudioSlicer_User_Guide.pdf" ofType:nil];
	[[NSWorkspace sharedWorkspace] openFile:manualPDFPath];
}

@end
