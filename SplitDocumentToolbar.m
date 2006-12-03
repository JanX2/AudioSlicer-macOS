//
//  SplitDocumentToolbar.m
//  AudioSlicer
//
//  Created by Bernd Heller on Sun Mar 07 2004.
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

#import "SplitDocumentToolbar.h"
#import "SplitDocument.h"

@interface SplitDocumentToolbar (Private)
- (void)prevNextSilenceControlClicked:(id)sender;
@end

static NSString		*SplitDocumentToolbarIdentifier = @"SplitDocumentToolbarIdentifier";
static NSString		*SplitDocumentToolbarInfoButtonItemIdentifier = @"SplitDocumentToolbarInfoButtonItemIdentifier";
static NSString		*SplitDocumentToolbarSaveButtonItemIdentifier = @"SplitDocumentToolbarSaveButtonItemIdentifier";
static NSString		*SplitDocumentToolbarExportButtonItemIdentifier = @"SplitDocumentToolbarExportButtonItemIdentifier";
static NSString		*SplitDocumentToolbarPreferencesButtonItemIdentifier = @"SplitDocumentToolbarPreferencesButtonItemIdentifier";
static NSString		*SplitDocumentToolbarVolumeSliderItemIdentifier = @"SplitDocumentToolbarVolumeSliderItemIdentifier";
static NSString		*SplitDocumentToolbarPrevNextSilenceButtonItemIdentifier = @"SplitDocumentToolbarPrevNextSilenceButtonItemIdentifier";

@implementation SplitDocumentToolbar

- (id)initWithDocument:(SplitDocument *)doc
{
	if (self = [super init]) {
		document = doc;
		documentToolbar = [[NSToolbar alloc] initWithIdentifier:SplitDocumentToolbarIdentifier];
		
		[documentToolbar setAllowsUserCustomization:YES];
		[documentToolbar setAutosavesConfiguration:YES];
		[documentToolbar setDisplayMode:NSToolbarDisplayModeIconOnly];
		
		[documentToolbar setDelegate:self];
		[[document windowForSheet] setToolbar:documentToolbar];
	}
	
	return self;
}

- (void)unbind
{
	[volumeSlider unbind:@"value"];
}

- (void)dealloc
{
	[volumeSlider release];
	[documentToolbar release];
	[super dealloc];
}

#pragma mark -

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdent willBeInsertedIntoToolbar:(BOOL)willBeInserted
{
    NSToolbarItem   *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdent] autorelease];
	
    if ([itemIdent isEqualToString:SplitDocumentToolbarInfoButtonItemIdentifier]) {
		[toolbarItem setLabel:@"Info"];
		[toolbarItem setPaletteLabel:@"Info"];
		[toolbarItem setToolTip:@"Show/Hide Information Panel"];
		[toolbarItem setImage:[NSImage imageNamed:@"SplitDocumentToolbarInfoButton"]];
		
		[toolbarItem setTarget:nil];
		[toolbarItem setAction:@selector(toggleInspector:)];
	} else if ([itemIdent isEqualToString:SplitDocumentToolbarSaveButtonItemIdentifier]) {
		[toolbarItem setLabel:@"Save"];
		[toolbarItem setPaletteLabel:@"Save"];
		[toolbarItem setToolTip:@"Save Document"];
		[toolbarItem setImage:[NSImage imageNamed:@"SplitDocumentToolbarSaveButton"]];
		
		[toolbarItem setTarget:document];
		[toolbarItem setAction:@selector(saveDocument:)];
	} else if ([itemIdent isEqualToString:SplitDocumentToolbarExportButtonItemIdentifier]) {
		[toolbarItem setLabel:@"Export"];
		[toolbarItem setPaletteLabel:@"Export"];
		[toolbarItem setToolTip:@"Export Document Splitted"];
		[toolbarItem setImage:[NSImage imageNamed:@"SplitDocumentToolbarExportButton"]];
		
		[toolbarItem setTarget:document];
		[toolbarItem setAction:@selector(exportSplitted:)];
	} else if ([itemIdent isEqualToString:SplitDocumentToolbarPreferencesButtonItemIdentifier]) {
		[toolbarItem setLabel:@"Preferences"];
		[toolbarItem setPaletteLabel:@"Preferences"];
		[toolbarItem setToolTip:@"Show Preferences Panel"];
		[toolbarItem setImage:[NSImage imageNamed:@"SplitDocumentToolbarPreferencesButton"]];
		
		[toolbarItem setTarget:nil];
		[toolbarItem setAction:@selector(showPreferences:)];
	} else if ([itemIdent isEqualToString:SplitDocumentToolbarVolumeSliderItemIdentifier]) {
		[toolbarItem setLabel:@"Volume"];
		[toolbarItem setPaletteLabel:@"Volume"];
		[toolbarItem setToolTip:@"Adjust Play Volume"];
		
		if (volumeSlider == nil) {
			volumeSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(0, 0, 130, 16)];
			[volumeSlider setMinValue:0.0];
			[volumeSlider setMaxValue:2.0];
			[volumeSlider setDoubleValue:1.0];
			[volumeSlider setContinuous:YES];
			[[volumeSlider cell] setControlSize:NSSmallControlSize];
			
			[volumeSlider bind:@"value" toObject:self withKeyPath:@"document.audioFile.audioVolume" options:0];
		}
		
		[toolbarItem setView:volumeSlider];
		[toolbarItem setMinSize:[volumeSlider bounds].size];
		[toolbarItem setMaxSize:[volumeSlider bounds].size];
	} else if ([itemIdent isEqualToString:SplitDocumentToolbarPrevNextSilenceButtonItemIdentifier]) {
		[toolbarItem setLabel:@"Play Silence"];
		[toolbarItem setPaletteLabel:@"Play Silence"];
		[toolbarItem setToolTip:@"Play Previous/Next Silence"];
		
		NSSegmentedControl *prevNextSilenceControl = [[[NSSegmentedControl alloc] initWithFrame:NSMakeRect(0, 0, 72, 32)] autorelease];
		[prevNextSilenceControl setSegmentCount:2];
		[prevNextSilenceControl setImage:[NSImage imageNamed:@"SplitDocumentToolbarPrevSilenceButton"] forSegment:0];
		[prevNextSilenceControl setImage:[NSImage imageNamed:@"SplitDocumentToolbarNextSilenceButton"] forSegment:1];
		[prevNextSilenceControl setWidth:32 forSegment:0];
		[prevNextSilenceControl setWidth:32 forSegment:1];
		[[prevNextSilenceControl cell] setTag:0 forSegment:0];
		[[prevNextSilenceControl cell] setTag:1 forSegment:1];
		[prevNextSilenceControl setTarget:self];
		[prevNextSilenceControl setAction:@selector(prevNextSilenceControlClicked:)];
		[[prevNextSilenceControl cell] setTrackingMode:NSSegmentSwitchTrackingMomentary];
		
		[toolbarItem setView:prevNextSilenceControl];
		[toolbarItem setMinSize:[prevNextSilenceControl bounds].size];
		[toolbarItem setMaxSize:[prevNextSilenceControl bounds].size];
	} else {
		toolbarItem = nil;
	}
	
	return toolbarItem;
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    return [NSArray arrayWithObjects:
		SplitDocumentToolbarInfoButtonItemIdentifier,
		SplitDocumentToolbarPrevNextSilenceButtonItemIdentifier,
		NSToolbarSeparatorItemIdentifier,
		SplitDocumentToolbarVolumeSliderItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier,
		SplitDocumentToolbarExportButtonItemIdentifier,
		nil];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
    return [NSArray arrayWithObjects:
		SplitDocumentToolbarInfoButtonItemIdentifier,
		SplitDocumentToolbarSaveButtonItemIdentifier,
		SplitDocumentToolbarExportButtonItemIdentifier,
		SplitDocumentToolbarPreferencesButtonItemIdentifier,
		SplitDocumentToolbarVolumeSliderItemIdentifier,
		SplitDocumentToolbarPrevNextSilenceButtonItemIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier,
		NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarSpaceItemIdentifier,
		NSToolbarSeparatorItemIdentifier,
		nil];
}

@end

#pragma mark -

@implementation SplitDocumentToolbar (Private)

- (void)prevNextSilenceControlClicked:(id)sender
{
	switch ([[sender cell] tagForSegment:[sender selectedSegment]]) {
		case 0: [document playPrevSilence:sender];  break;
		case 1: [document playNextSilence:sender];  break;
	}
}

@end
