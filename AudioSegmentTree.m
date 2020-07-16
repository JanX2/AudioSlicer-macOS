//
//  AudioSegmentTree.m
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

#import "AudioSegmentTree.h"

NSString *AudioSegmentTreeDidChangeNotification = @"AudioSegmentTreeDidChangeNotification";

@interface AudioSegmentTree (Private)
- (void)treeDidChange;
@end

@implementation AudioSegmentTree

- (id)init
{
	if (self = [super init]) {
		minSilenceDuration = 1.0;
		maxSilenceDuration = 60.0;
		rootNode = [[AudioSegmentNode collectionSegmentNode] retain];
		slices = [[NSMutableArray alloc] init];
		
		undoManager = nil;
		
		// create initial single split segment
		[slices addObject:[AudioSlice audioSliceWithTree:self leftSilenceSegment:nil rightSilenceSegment:nil]];
		[[self sliceAtIndex:0] setExpandedInOutlineView:YES];
	}
	
	return self;
}

- (void)dealloc
{
	[[self undoManager] removeAllActionsWithTarget:self];
	
	[slices release];
	[rootNode release];
	
	[super dealloc];
}


- (id)initWithCoder:(NSCoder *)coder
{
	if (self = [super init]) {
		if ([coder allowsKeyedCoding]) {
			duration = [coder decodeDoubleForKey:@"duration"];
			minSilenceDuration = [coder decodeDoubleForKey:@"minSilenceDuration"];
			maxSilenceDuration = [coder decodeDoubleForKey:@"maxSilenceDuration"];
			rootNode = [[coder decodeObjectForKey:@"rootNode"] retain];
			slices = [[coder decodeObjectForKey:@"slices"] retain];
			[self calculateMinMaxSilenceDurations];
		} else {
			[NSException raise:NSInvalidArchiveOperationException format:@"Only supports NSKeyedArchiver coders"];
		}
	}
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if ([coder allowsKeyedCoding]) {
        [coder encodeDouble:duration forKey:@"duration"];
        [coder encodeDouble:minSilenceDuration forKey:@"minSilenceDuration"];
        [coder encodeDouble:maxSilenceDuration forKey:@"maxSilenceDuration"];
        [coder encodeObject:rootNode forKey:@"rootNode"];
        [coder encodeObject:slices forKey:@"slices"];
	} else {
        [NSException raise:NSInvalidArchiveOperationException format:@"Only supports NSKeyedArchiver coders"];
	}
}

#pragma mark -

- (void)setUndoManager:(NSUndoManager *)manager
{
	undoManager = manager;
}

- (NSUndoManager *)undoManager
{
	return undoManager;
}

#pragma mark -

- (void)setSilenceRangeMin:(double)min max:(double)max
{
	if (min != minSilenceDuration || max != maxSilenceDuration) {
		[[[self undoManager] prepareWithInvocationTarget:self] setSilenceRangeMin:minSilenceDuration max:maxSilenceDuration];
		[[self undoManager] setActionName:@"Change Silence Range"];
		
		minSilenceDuration = min;
		maxSilenceDuration = max;
		[self reorder];
	}
}

- (void)setMinSilenceDuration:(double)min
{
	if (min != minSilenceDuration) {
		[[[self undoManager] prepareWithInvocationTarget:self] setMinSilenceDuration:minSilenceDuration];
		[[self undoManager] setActionName:@"Change Minimum Silence"];
		
		minSilenceDuration = min;
		[self reorder];
	}
}

- (double)minSilenceDuration
{
	return minSilenceDuration;
}

- (void)setMaxSilenceDuration:(double)max
{
	if (max != maxSilenceDuration) {
		[[[self undoManager] prepareWithInvocationTarget:self] setMaxSilenceDuration:maxSilenceDuration];
		[[self undoManager] setActionName:@"Change Maximum Silence"];
		
		maxSilenceDuration = max;
		[self reorder];
	}
}

- (double)maxSilenceDuration
{
	return maxSilenceDuration;
}

- (void)setDuration:(double)d
{
	duration = d;
}

- (double)duration
{
	return duration;
}

#pragma mark -

- (void)setSplitPointAtNode:(AudioSegmentNode *)node
{
	[self setSplitPointAtNode:node withSlice:nil];
}

- (void)setSplitPointAtNode:(AudioSegmentNode *)node withSlice:(AudioSlice *)slice
{
	NSInteger				i = [self indexOfSliceForAudioSegment:node];
	AudioSlice		*s1 = (AudioSlice *)[slices objectAtIndex:i];
	AudioSlice		*s2;
	
	[[[self undoManager] prepareWithInvocationTarget:self] clearSplitPointAtNode:node];
	
	if (slice) {
		s2 = slice;
		[s2 setLeftSilenceSegment:node];
		[s2 setRightSilenceSegment:[s1 rightSilenceSegment]];
	} else {
		// find a new title
		NSString	*newTitle = nil;
		NSArray		*strArr = [[s1 title] componentsSeparatedByString:@" Copy"];
		if  ([strArr count] == 1) {
			newTitle = [NSString stringWithFormat:@"%@ Copy", [s1 title]];
		} else if ([strArr count] > 1) {
			newTitle = [NSString stringWithFormat:@"%@ Copy %ld", [strArr objectAtIndex:0], [[strArr lastObject] integerValue] + 1];
		}
		
		s2 = [s1 copy];
		[s2 setLeftSilenceSegment:node];
		[s2 setRightSilenceSegment:[s1 rightSilenceSegment]];
		[s2 setTitle:newTitle];
		
		// make autonumbering happen
		[s2 setTrackNumber:0];
		[s2 setTrackCount:0];
	}
	
	[s1 setRightSilenceSegment:node];
	[s2 setExpandedInOutlineView:[s1 expandedInOutlineView]];
	[node setDoesSplit:YES];
	
	if (i + 1 > [slices count] - 1) {
		[slices addObject:s2];
	} else {
		[slices insertObject:s2 atIndex:(i + 1)];
	}
	
	[[self undoManager] setActionName:@"Split Slices"];
	[self treeDidChange];
}

- (void)clearSplitPointAtNode:(AudioSegmentNode *)node
{
	NSInteger			i = [self indexOfSliceForAudioSegment:node];
	AudioSlice	*s1 = (AudioSlice *)[slices objectAtIndex:i];
	AudioSlice	*s2 = (AudioSlice *)[slices objectAtIndex:(i + 1)];
	
	[[[self undoManager] prepareWithInvocationTarget:self] setSplitPointAtNode:node withSlice:s2];
	
	[s1 setExpandedInOutlineView:([s1 expandedInOutlineView] || [s2 expandedInOutlineView])];
	[s1 setRightSilenceSegment:[s2 rightSilenceSegment]];
	[slices removeObject:s2];
	[node setDoesSplit:NO];
	
	[[self undoManager] setActionName:@"Join Slices"];
	[self treeDidChange];
}

#pragma mark -

- (NSInteger)numberOfSlices
{
	return [slices count];
}

- (AudioSlice *)sliceAtIndex:(NSInteger)index
{
	return [slices objectAtIndex:index];
}

- (NSInteger)indexOfSlice:(AudioSlice *)slice
{
	return [slices indexOfObjectIdenticalTo:slice];
}

- (NSInteger)numberOfAudioSegmentsInSlice:(AudioSlice *)slice
{
	AudioSegmentNode	*left = [slice leftSilenceSegment];
	AudioSegmentNode	*right = [slice rightSilenceSegment];
	NSInteger					leftIndex = left ? [rootNode indexOfChild:left] : 0;
	NSInteger					rightIndex = right ? [rootNode indexOfChild:right] : ([rootNode numberOfChildren] - 1);
	NSInteger					count = rightIndex - leftIndex + 1;
	
	if ([left doesSplit]) {
		count--;
	}
	if ([right doesSplit]) {
		count--;
	}
	
	return count;
}

- (AudioSegmentNode *)audioSegmentAtIndex:(NSInteger)index inSlice:(AudioSlice *)slice
{
	AudioSegmentNode	*left = [slice leftSilenceSegment];
	NSInteger					leftIndex = left ? [rootNode indexOfChild:left] : 0;
	
	return [rootNode childAtIndex:(leftIndex + index)];
}

- (NSInteger)numberOfAudioSegments
{
	return [rootNode numberOfChildren];
}

- (AudioSegmentNode *)audioSegmentAtIndex:(NSInteger)index
{
	return [rootNode childAtIndex:index];
}

- (NSInteger)indexOfSliceForAudioSegment:(AudioSegmentNode *)node
{
	double		splitStartTime = [node startTime];
	double		splitEndTime = [node endTime];
	
	for (NSInteger i = 0; i < [slices count]; i++) {
		AudioSlice			*s = (AudioSlice *)[slices objectAtIndex:i];
		AudioSegmentNode	*left = [s leftSilenceSegment];
		AudioSegmentNode	*right = [s rightSilenceSegment];
		
		if ((splitStartTime > (left ? [left endTime] : 0.0)) && (splitEndTime <= (right ? [right endTime] : duration))) {
			return i;
		}
	}
	
	[NSException raise:NSInternalInconsistencyException format:@"indexOfSliceForAudioSegment: didn't find node in any split segment"];
	return -1;
}

#pragma mark -

- (double)shortestSilenceInTree
{
	return shortestSilence;
}

- (double)longestSilenceInTree
{
	return longestSilence;
}

#pragma mark -

- (void)addSilenceSegmentFrom:(double)start to:(double)end
{
	[rootNode addNodeToChildren:[AudioSegmentNode silenceSegmentNodeFrom:start to:end]];
}

- (void)addAudioSegmentFrom:(double)start to:(double)end
{
	[rootNode addNodeToChildren:[AudioSegmentNode audioSegmentNodeFrom:start to:end]];
}

#pragma mark -

- (void)createAudioSegmentsBetweenSilences
{
	if ([rootNode numberOfChildren] > 0) {
		AudioSegmentNode	*firstNode = [rootNode childAtIndex:0];
		if ([firstNode startTime] > 0.0) {
			// insert initial audio segment
			[self addAudioSegmentFrom:0.0 to:[firstNode startTime]];
		}
		
		for (NSUInteger i = 0; i < ([rootNode numberOfChildren] - 1); i++) {
			AudioSegmentNode	*thisNode = [rootNode childAtIndex:i];
			AudioSegmentNode	*nextNode = [rootNode childAtIndex:(i + 1)];
			
			if ([thisNode nodeType] == AudioSegmentNodeTypeSilence) {
				if (nextNode && [nextNode nodeType] == AudioSegmentNodeTypeSilence) {
					// insert audio segment
					[self addAudioSegmentFrom:[thisNode endTime] to:[nextNode startTime]];
				}
			}
		}
		
		AudioSegmentNode	*lastNode = [rootNode childAtIndex:([rootNode numberOfChildren] - 1)];
		if ([lastNode endTime] < duration) {
			// insert final audio segment
			[self addAudioSegmentFrom:[lastNode endTime] to:duration];
		}
	} else {
		// create single audio segment
		[self addAudioSegmentFrom:0.0 to:duration];
	}
	
	[self calculateMinMaxSilenceDurations];
}

- (void)reorder
{
	AudioSegmentNode	*thisNode;
	AudioSegmentNode	*inCollectionNode;
	BOOL				treeChanged = NO;
	
	[rootNode startEnumeration];
	while (thisNode = [rootNode nextObject]) {
		if ([thisNode nodeType] == AudioSegmentNodeTypeSilence) {
			// check if silence is too short or too long
			if ([thisNode duration] < minSilenceDuration || [thisNode duration] > maxSilenceDuration) {
				if (![thisNode doesSplit]) {
					[rootNode mergeChildWithNeighbours:thisNode];
					treeChanged = YES;
				}
			}
		}
		if ([thisNode nodeType] == AudioSegmentNodeTypeCollection) {
			// check the silences inside the collection, if they are the right duration now
			[thisNode startEnumeration];
			while (inCollectionNode = [thisNode nextObject]) {
				if ([inCollectionNode nodeType] == AudioSegmentNodeTypeSilence) {
					// check if silence is within limits
					if ([inCollectionNode duration] >= minSilenceDuration && [inCollectionNode duration] <= maxSilenceDuration) {
						[rootNode unmergeNode:inCollectionNode inChild:thisNode];
						treeChanged = YES;
					}
				}
			}
		}
	}
	
	if (treeChanged) {
		[self treeDidChange];
	}
}

- (void)calculateMinMaxSilenceDurations;
{
	AudioSegmentNode	*thisNode;
	AudioSegmentNode	*inCollectionNode;
	
	shortestSilence = 100000000.0;
	longestSilence = 0.0;
	
	[rootNode startEnumeration];
	while (thisNode = [rootNode nextObject]) {
		if ([thisNode nodeType] == AudioSegmentNodeTypeSilence) {
			// do longest/shortest silence stats
			double  d = [thisNode duration];
			if (d > longestSilence) {
				longestSilence = d;
			}
			if (d < shortestSilence) {
				shortestSilence = d;
			}
		} else if ([thisNode nodeType] == AudioSegmentNodeTypeCollection) {
			// check the silences inside the collection, if they are the right duration now
			[thisNode startEnumeration];
			while (inCollectionNode = [thisNode nextObject]) {
				if ([inCollectionNode nodeType] == AudioSegmentNodeTypeSilence) {
					// do longest/shortest silence stats
					double  d = [inCollectionNode duration];
					if (d > longestSilence) {
						longestSilence = d;
					}
					if (d < shortestSilence) {
						shortestSilence = d;
					}
				}
			}
		}
	}
}

- (NSString *)description
{
	NSMutableString *string = [[NSMutableString alloc] init];
	NSUInteger				i, j;
	
	[string appendFormat:@"Root node has %lu audio segment nodes:\n", [rootNode numberOfChildren]];
	for (i = 0; i < [rootNode numberOfChildren]; i++) {
		[string appendFormat:@"%lu: %@\n", i, [[rootNode childAtIndex:i] description]];
	}
	
	NSInteger		silences[200];
	for (i = 0; i < 200; i++) silences[i] = 0;
	for (i = 0; i < [rootNode numberOfChildren]; i++) {
		AudioSegmentNode	*node1 = [rootNode childAtIndex:i];
		if ([node1 nodeType] == AudioSegmentNodeTypeCollection) {
			for (j = 0; j < [node1 numberOfChildren]; j++) {
				AudioSegmentNode	*node2 = [node1 childAtIndex:j];
				if ([node2 nodeType] == AudioSegmentNodeTypeSilence) {
					silences[((NSInteger)([node2 duration] * 10.0))]++;
				}
			}
		} else {
			if ([node1 nodeType] == AudioSegmentNodeTypeSilence) {
				silences[((NSInteger)([node1 duration] * 10.0))]++;
			}
		}
	}
	NSUInteger		count = 0;
	for (i = 0; i < 200; i++) {
		NSLog(@"silences %.1f s - %.1f s: %lu", i/10.0, (i + 1)/10.0, silences[i]);
		count += silences[i];
	}
	NSLog(@"total silences: %lu", count);
	
	return [string autorelease];
}

@end

#pragma mark -

@implementation AudioSegmentTree (Private)

- (void)treeDidChange
{
	[[NSNotificationCenter defaultCenter] postNotificationName:AudioSegmentTreeDidChangeNotification
														object:self
													  userInfo:nil];
}

@end

