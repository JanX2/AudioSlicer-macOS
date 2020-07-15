//
//  OutlineViewController.h
//  AudioSlicer
//
//  Created by Bernd Heller on Fri Feb 13 2004.
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

#import <Cocoa/Cocoa.h>

#import "AudioFile.h"
#import "AudioSegmentOutlineView.h"

@class SplitDocument;

@interface OutlineViewController : NSObject {
	IBOutlet AudioSegmentOutlineView	*outlineView;
	IBOutlet SplitDocument				*document;
	
	AudioFile							*audioFile;
	AudioSegmentTree					*audioSegmentTree;
	BOOL								suppressModelDidChangeNotification;
	
	id									itemPlaying;
	
	NSFont								*normalFont;
	NSFont								*boldFont;
}

- (id)initWithDocument:(SplitDocument *)doc outlineView:(AudioSegmentOutlineView *)view;

- (void)setAudioFile:(AudioFile *)file audioSegmentTree:(AudioSegmentTree *)tree;
- (void)reloadOutlineView;

- (AudioSegmentNode *)prevSilence;
- (AudioSegmentNode *)nextSilence;

- (NSMutableArray *)selectedItems;
- (NSMutableArray *)selectedSlices;
- (void)selectItems:(NSArray *)selection;

- (BOOL)canJoinSelectedItems;
- (BOOL)canSplitSelectedItems;
- (void)joinSelectedItems;
- (void)splitSelectedItems;

- (BOOL)canCollapseSelectedItems;
- (BOOL)canExpandSelectedItems;
- (void)collapseSelectedItems;
- (void)expandSelectedItems;

- (void)splitButtonClicked:(id)sender;
- (void)playButtonClicked:(id)sender;

// NSOutlineViewDataSource

- (NSInteger)outlineView:(NSOutlineView *)view numberOfChildrenOfItem:(id)item;
- (id)outlineView:(NSOutlineView *)view child:(NSInteger)index ofItem:(id)item;
- (BOOL)outlineView:(NSOutlineView *)view isItemExpandable:(id)item;
- (id)outlineView:(NSOutlineView *)view objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item;
- (void)outlineView:(NSOutlineView *)view setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item;

// NSOutlineView delegate

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item;
- (void)outlineView:(NSOutlineView *)view willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item;
- (void)outlineViewItemDidExpand:(NSNotification *)notification;
- (void)outlineViewItemDidCollapse:(NSNotification *)notification;

- (NSColor *)outlineView:(NSOutlineView *)view backgroundColorForRow:(NSInteger)rowIndex;
- (BOOL)outlineView:(NSOutlineView *)view keyDown:(NSEvent *)keyEvent;

// MP3File delegate

- (void)audioFileDidFinishPlaying:(AudioFile *)audioFile;

@end
