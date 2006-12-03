//
//  AudioSegmentTree.h
//  AudioSlicer
//
//  Created by Bernd Heller on Sun Feb 15 2004.
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

#import <Foundation/Foundation.h>

#import "AudioSegmentNode.h"
#import "AudioSlice.h"

extern NSString *AudioSegmentTreeDidChangeNotification;

@interface AudioSegmentTree : NSObject <NSCoding> {
	NSMutableArray		*slices;
	AudioSegmentNode	*rootNode;
	double				duration;
	
	double				minSilenceDuration;
	double				maxSilenceDuration;
	
	double				shortestSilence;
	double				longestSilence;
	
	NSUndoManager		*undoManager;
}

- (id)initWithCoder:(NSCoder *)coder;
- (void)encodeWithCoder:(NSCoder *)coder;

- (void)setUndoManager:(NSUndoManager *)manager;
- (NSUndoManager *)undoManager;

- (void)setSilenceRangeMin:(double)min max:(double)max;
- (void)setMinSilenceDuration:(double)min;
- (double)minSilenceDuration;
- (void)setMaxSilenceDuration:(double)max;
- (double)maxSilenceDuration;
- (void)setDuration:(double)d;
- (double)duration;

- (void)setSplitPointAtNode:(AudioSegmentNode *)node;
- (void)setSplitPointAtNode:(AudioSegmentNode *)node withSlice:(AudioSlice *)slice;
- (void)clearSplitPointAtNode:(AudioSegmentNode *)node;

- (int)numberOfSlices;
- (AudioSlice *)sliceAtIndex:(int)index;
- (int)indexOfSlice:(AudioSlice *)slice;
- (int)numberOfAudioSegmentsInSlice:(AudioSlice *)slice;
- (AudioSegmentNode *)audioSegmentAtIndex:(int)index inSlice:(AudioSlice *)slice;
- (int)indexOfSliceForAudioSegment:(AudioSegmentNode *)node;

- (double)shortestSilenceInTree;
- (double)longestSilenceInTree;

- (void)addSilenceSegmentFrom:(double)start to:(double)end;
- (void)addAudioSegmentFrom:(double)start to:(double)end;
- (void)createAudioSegmentsBetweenSilences;
- (void)reorder;
- (void)calculateMinMaxSilenceDurations;

@end

