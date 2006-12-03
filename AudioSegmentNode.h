//
//  AudioSegmentNode.h
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
#import "SkipList.h"

typedef enum {
	AudioSegmentNodeTypeSilence,
	AudioSegmentNodeTypeAudio,
	AudioSegmentNodeTypeCollection
} AudioSegmentNodeType;

@interface AudioSegmentNode : NSObject <NSCopying, NSCoding> {
	AudioSegmentNodeType	nodeType;
	double					startTime;
	double					endTime;
	
	BOOL					doesSplit;
	
	SkipList				*childNodes;
}

+ (id)audioSegmentNodeFrom:(double)start to:(double)end;
+ (id)silenceSegmentNodeFrom:(double)start to:(double)end;
+ (id)collectionSegmentNode;
- (id)initWithStartTime:(double)start endTime:(double)end type:(AudioSegmentNodeType)type;

- (id)initWithCoder:(NSCoder *)coder;
- (void)encodeWithCoder:(NSCoder *)coder;

- (NSComparisonResult)compare:(AudioSegmentNode *)node;

- (AudioSegmentNodeType)nodeType;
- (double)startTime;
- (double)endTime;
- (double)duration;

- (void)setDoesSplit:(BOOL)flag;
- (BOOL)doesSplit;

- (int)numberOfChildren;
- (AudioSegmentNode *)childAtIndex:(int)index;
- (int)indexOfChild:(AudioSegmentNode *)child;

- (void)addNodeToChildren:(AudioSegmentNode *)node;
- (void)mergeChildWithNeighbours:(AudioSegmentNode *)node;
- (void)unmergeNode:(AudioSegmentNode *)node inChild:(AudioSegmentNode *)child;

- (void)startEnumeration;
- (AudioSegmentNode *)nextObject;

- (BOOL)overlapsWith:(AudioSegmentNode *)n;

@end
