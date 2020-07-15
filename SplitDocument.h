//
//  SplitDocument.h
//  AudioSlicer
//
//  Created by Bernd Heller on Thu Feb 05 2004.
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
#import "AudioSegmentTree.h"
#import "OutlineViewController.h"
#import "IntervalSlider.h"
#import "SplitDocumentToolbar.h"
#import "ProgressPanel.h"

@interface SplitDocument : NSDocument {
	IBOutlet OutlineViewController		*outlineViewController;
	IBOutlet NSOutlineView				*outlineView;
	
	IBOutlet NSTextField				*minSilenceField;
	IBOutlet NSTextField				*maxSilenceField;
	IBOutlet IntervalSlider				*silenceRangeSlider;
	
	IBOutlet NSTextField				*playBeforeSilenceField;
	IBOutlet NSTextField				*playAfterSilenceField;
	
	IBOutlet NSView						*exportPanelView;
	
	IBOutlet NSPanel					*renameSeriallyPanel;
	IBOutlet NSTextField				*renameSeriallyStartName;
	
	IBOutlet NSPanel					*breakDownSlicesPanel;
	
	SplitDocumentToolbar				*toolbar;
	
	AudioFile							*audioFile;
	AudioSegmentTree					*audioSegmentTree;
	NSMutableArray						*genreList;
	
	double								playSilenceIntervalBefore;
	double								playSilenceIntervalAfter;
	double								relativeSilenceSplitPoint;
	
	NSUInteger							documentID;
	BOOL								documentWasModifiedDuringOpen;
	
	double								continuousControlStartValue1;
	double								continuousControlStartValue2;
	NSNotificationQueue					*continuousControlsUndoQueue;
	
	ProgressPanel						*progressPanel;
}

- (NSUInteger)documentID;

- (IBAction)modalOK:(id)sender;
- (IBAction)modalCancel:(id)sender;

- (IBAction)exportSplitted:(id)sender;
- (IBAction)joinSelection:(id)sender;
- (IBAction)splitSelection:(id)sender;
- (IBAction)collapseSelection:(id)sender;
- (IBAction)expandSelection:(id)sender;
- (IBAction)renameSlicesSerially:(id)sender;
- (IBAction)renumberSlicesSerially:(id)sender;
- (IBAction)breakDownSlices:(id)sender;
- (IBAction)breakDownSlicesAgain:(id)sender;

- (IBAction)playPrevSilence:(id)sender;
- (IBAction)playNextSilence:(id)sender;

- (IBAction)setSilenceRange:(id)sender;
- (IBAction)setPlaySilenceInterval:(id)sender;

- (void)setPlaySilenceIntervalBefore:(double)before;
- (double)playSilenceIntervalBefore;
- (void)setPlaySilenceIntervalAfter:(double)after;
- (double)playSilenceIntervalAfter;

- (void)playSilence:(AudioSegmentNode *)silenceSegment;
- (void)playTitle:(AudioSegmentNode *)titleSegment;
- (void)playSlice:(AudioSlice *)slice;

- (NSMutableArray *)selection;
- (NSMutableArray *)sliceSelection;
- (NSMutableArray *)genreList;
- (NSArray *)exportFilenameFormats;

@end
