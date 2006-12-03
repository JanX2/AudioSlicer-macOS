//
//  InspectorController.m
//  AudioSlicer
//
//  Created by Bernd Heller on Thu Feb 28 2004.
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

#import "InspectorController.h"
#import "SplitDocument.h"


@implementation InspectorController

+ (id)sharedInspectorController
{
	static InspectorController		*sharedController = nil;
	
	if (sharedController == nil) {
		sharedController = [[InspectorController alloc] init];
	}
	
	return sharedController;
}

+ (void)initialize
{
	[InspectorController setKeys:[NSArray arrayWithObjects:@"currentDocument", @"currentSelection", nil]
						 triggerChangeNotificationsForDependentKey:@"genreList"];
}

- (id)init
{
	if (self = [super initWithWindowNibName:@"Inspector"]) {
		[self setWindowFrameAutosaveName:@"InspectorPanel"];
		[self documentWindowChanged:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(documentWindowChanged:)
													 name:NSWindowDidBecomeMainNotification
												   object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(documentWindowChanged:)
													 name:NSWindowDidResignMainNotification
												   object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(selectionChanged:)
													 name:NSOutlineViewSelectionDidChangeNotification
												   object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(selectionChanged:)
													 name:NSOutlineViewSelectionIsChangingNotification
												   object:nil];
		
		[self window];
	}
	
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

#pragma mark -

- (void)windowDidLoad
{
	[(NSPanel *)[self window] setBecomesKeyOnlyIfNeeded:YES];
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)sender
{
	return [currentDocument undoManager];
}

#pragma mark -

- (void)showInspector
{
	[self showWindow:self];
}

- (void)hideInspector
{
	[[self window] orderOut:self];
}

- (void)toggleInspector
{
	if ([[self window] isVisible]) {
		[self hideInspector];
	} else {
		[self showInspector];
	}
}

- (void)documentWindowChanged:(NSNotification *)notification
{
	NSWindow	*window = [notification object];
	
	if (window == nil) {
		window = [NSApp mainWindow];
	}
	currentDocument = [[window windowController] document];
	[self selectionChanged:nil];
}

- (void)selectionChanged:(NSNotification *)notification
{
	NSMutableArray  *selection = [currentDocument selection];
	
	if ([selection count] == 0) {
		// empty selection
		[self setCurrentSelection:nil];
		[self setInspectorMode:InspectorModeEmptySelection];
		[[self window] setTitle:@"Inspector - Empty"];
	} else {
		NSMutableArray  *audioSlices = [currentDocument sliceSelection];
		
		if ([audioSlices count] > 0) {
			// we only inspect the AudioSlice objects
			[self setCurrentSelection:audioSlices];
			[self setInspectorMode:InspectorModeSliceSelection];
			[[self window] setTitle:@"Inspector - Slices"];
		} else {
			// there are no AudioSlice objects in here
			[self setCurrentSelection:selection];
			[self setInspectorMode:InspectorModeNotApplicable];
			[[self window] setTitle:@"Inspector - Segments"];
		}
	}
}

- (void)setCurrentSelection:(NSMutableArray *)selection
{
	[currentSelection release];
	currentSelection = [selection retain];
}

- (NSMutableArray *)currentSelection
{
	return currentSelection;
}

- (void)setInspectorMode:(InspectorMode)mode
{
	inspectorMode = mode;
}

- (InspectorMode)inspectorMode
{
	// modification to make it fit to tableview indexes
	return inspectorMode - 1;
}

#pragma mark -

- (NSMutableArray *)genreList
{
	return [currentDocument genreList];
}

@end

