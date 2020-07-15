//
//  PreferencesController.m
//  AudioSlicer
//
//  Created by Bernd Heller on Tue Mar 02 2004.
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

#import "PreferencesController.h"


@implementation PreferencesController

+ (id)sharedPreferencesController
{
	static PreferencesController		*sharedController = nil;
	
	if (sharedController == nil) {
		sharedController = [[PreferencesController alloc] init];
	}
	
	return sharedController;
}

+ (void)setDefaults
{
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithDouble:1.1],	@"SilenceDurationThreshold",
		[NSNumber numberWithInteger:3],			@"SilenceVolumeThreshold",
		[NSNumber numberWithBool:YES],		@"PlaySilenceBeep",
		[NSNumber numberWithDouble:2.0],	@"PlayBeforeSilenceDuration",
		[NSNumber numberWithDouble:2.0],	@"PlayAfterSilenceDuration",
		[NSNumber numberWithInteger:66],		@"RelativeSilenceSplitPoint",
		[NSArray arrayWithObjects:
			@"trackNumber", @"title",
			@"split", @"play",
			@"startTime", @"endTime", @"duration",
			nil],							@"OutlineView-Identifiers",
		[NSArray arrayWithObjects:
			[NSNumber numberWithDouble:40.0], [NSNumber numberWithDouble:240.0],
			[NSNumber numberWithDouble:0.0], [NSNumber numberWithDouble:0.0],
			[NSNumber numberWithDouble:70.0], [NSNumber numberWithDouble:70.0], [NSNumber numberWithDouble:70.0],
			nil],							@"OutlineView-Widths",
		[NSArray arrayWithObjects:
			@"[trackNumber] - [title]",
			@"[trackNumber] - [artist] - [title]",
			@"[album] - [trackNumber] - [artist] - [title]",
			@"[trackNumber] - [album] - [artist] - [title]",
			@"[trackNumber] - [artist] - [album] - [title]",
			nil],							@"ExportFilenameFormatsPreset",
		[NSArray array],					@"ExportFilenameFormatsCustom",
		@"[trackNumber] - [title]",			@"PreferredExportFilenameFormat",
		[NSNumber numberWithInteger:5],			@"BreakDownSlicesSegmentDurationMinutes",
		[NSNumber numberWithInteger:15],		@"BreakDownSlicesSegmentDurationTolerance",
		nil]];
}

- (id)init
{
	if (self = [super initWithWindowNibName:@"Preferences"]) {
		[self setWindowFrameAutosaveName:@"PreferencesPanel"];
		[self window];
	}
	
	return self;
}

- (void)dealloc
{
	[super dealloc];
}

#pragma mark -

- (void)showPreferences
{
	[self showWindow:self];
}

- (void)hidePreferences
{
	[[self window] orderOut:self];
}

#pragma mark -

- (BOOL)windowShouldClose:(id)sender
{
	if (![[self window] makeFirstResponder:[self window]]) {
		[[self window] endEditingFor:nil];
	}
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	return YES;
}

@end
