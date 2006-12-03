//
//  AudioSegmentNode.m
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

#import "AudioSegmentNode.h"


@implementation AudioSegmentNode

+ (id)audioSegmentNodeFrom:(double)start to:(double)end
{
	return [[[AudioSegmentNode alloc] initWithStartTime:start endTime:end type:AudioSegmentNodeTypeAudio] autorelease];
}

+ (id)silenceSegmentNodeFrom:(double)start to:(double)end
{
	return [[[AudioSegmentNode alloc] initWithStartTime:start endTime:end type:AudioSegmentNodeTypeSilence] autorelease];
}

+ (id)collectionSegmentNode
{
	return [[[AudioSegmentNode alloc] initWithStartTime:0.0 endTime:0.0 type:AudioSegmentNodeTypeCollection] autorelease];
}

- (id)initWithStartTime:(double)start endTime:(double)end type:(AudioSegmentNodeType)type
{
	if (self = [super init]) {
		nodeType = type;
		startTime = start;
		endTime = end;
		childNodes = [[SkipList alloc] init];
	}
	
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	AudioSegmentNode  *copy = (AudioSegmentNode *)NSCopyObject(self, 0, zone);
	childNodes = [[SkipList alloc] init];
	return copy;
}

- (void)dealloc
{
	[childNodes release];
	[super dealloc];
}


- (id)initWithCoder:(NSCoder *)coder
{
	if (self = [super init]) {
		if ([coder allowsKeyedCoding]) {
			nodeType = [coder decodeIntForKey:@"nodeType"];
			startTime = [coder decodeDoubleForKey:@"startTime"];
			endTime = [coder decodeDoubleForKey:@"endTime"];
			doesSplit = [coder decodeBoolForKey:@"doesSplit"];
			childNodes = [[coder decodeObjectForKey:@"childNodes"] retain];
		} else {
			[NSException raise:NSInvalidArchiveOperationException format:@"Only supports NSKeyedArchiver coders"];
		}
	}
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if ([coder allowsKeyedCoding]) {
        [coder encodeInt:nodeType forKey:@"nodeType"];
        [coder encodeDouble:startTime forKey:@"startTime"];
        [coder encodeDouble:endTime forKey:@"endTime"];
        [coder encodeBool:doesSplit forKey:@"doesSplit"];
        [coder encodeObject:childNodes forKey:@"childNodes"];
	} else {
        [NSException raise:NSInvalidArchiveOperationException format:@"Only supports NSKeyedArchiver coders"];
	}
}


- (NSString *)description
{
	NSString	*type = @"";
	switch (nodeType) {
		case AudioSegmentNodeTypeAudio: type = @"Audio"; break;
		case AudioSegmentNodeTypeSilence: type = @"Silence"; break;
		case AudioSegmentNodeTypeCollection: type = @"Collection"; break;
	}
	
	return [NSString stringWithFormat:@"nodeType = %@, numChildren = %d, startTime = %.2f, endTime = %.2f",
		type, [self numberOfChildren], [self startTime], [self endTime]];
}


- (NSComparisonResult)compare:(AudioSegmentNode *)node
{
	if (startTime < node->startTime) {
		return NSOrderedAscending;
	} else {
		return NSOrderedDescending;
	}
}

- (AudioSegmentNodeType)nodeType
{
	return nodeType;
}

- (double)startTime
{
	return startTime;
}

- (double)endTime
{
	return endTime;
}

- (double)duration
{
	return endTime - startTime;
}

- (void)setDoesSplit:(BOOL)flag
{
	doesSplit = flag;
}

- (BOOL)doesSplit
{
	return doesSplit;
}

- (int)numberOfChildren
{
	return [childNodes count];
}

- (AudioSegmentNode *)childAtIndex:(int)index
{
	return (AudioSegmentNode *)[childNodes objectAtIndex:index];
}

- (int)indexOfChild:(AudioSegmentNode *)child
{
	return [childNodes indexOfObjectIdenticalTo:child];
}

// adds the given node to this node's children. this node is set as new parent
- (void)addNodeToChildren:(AudioSegmentNode *)node
{
	if (node) {
		// if this is not a collection node yet, make it one
		if (nodeType != AudioSegmentNodeTypeCollection) {
			AudioSegmentNode	*nodeCopy = [[self copy] autorelease];
			[childNodes addObject:nodeCopy];
			nodeType = AudioSegmentNodeTypeCollection;
		}
		
		// check if there is some overlap here
		BOOL overlapped = NO;
		for (int i = 0; i < [childNodes count]; i++) {
			AudioSegmentNode *n = (AudioSegmentNode *)[childNodes objectAtIndex:i];
			if ((node->nodeType == AudioSegmentNodeTypeSilence)&& (n->nodeType == AudioSegmentNodeTypeSilence) && [n overlapsWith:node]) {
				n->startTime = MIN(n->startTime, node->startTime);
				n->endTime = MAX(n->endTime, node->endTime);
				overlapped = YES;
				break;
			}
		}
		if (!overlapped) {
			[childNodes addObject:node];
		}
		
		// update collection node start/end times
		startTime = ((AudioSegmentNode *)[childNodes firstObject])->startTime;
		endTime = ((AudioSegmentNode *)[childNodes lastObject])->endTime;
	}
}

- (void)mergeChildWithNeighbours:(AudioSegmentNode *)node
{
	unsigned int		nodeIndex = [childNodes indexOfObjectIdenticalTo:node];
	AudioSegmentNode	*prevNode = (nodeIndex > 0) ? [childNodes objectAtIndex:(nodeIndex - 1)] : nil;
	AudioSegmentNode	*nextNode = (nodeIndex < ([childNodes count] - 1)) ? [childNodes objectAtIndex:(nodeIndex + 1)] : nil;
	
	if (node->nodeType != AudioSegmentNodeTypeCollection) {
		AudioSegmentNode	*nodeCopy = [[node copy] autorelease];
		[node->childNodes addObject:nodeCopy];
		node->nodeType = AudioSegmentNodeTypeCollection;
	}
	
	if (prevNode) {
		if (prevNode->nodeType == AudioSegmentNodeTypeCollection) {
			SkipList	*tmp = node->childNodes;
			node->childNodes = prevNode->childNodes;
			prevNode->childNodes = tmp;
			[node->childNodes appendSkipList:prevNode->childNodes];
			[childNodes removeObject:prevNode];
		} else {
			[node addNodeToChildren:prevNode];
			[childNodes removeObject:prevNode];
		}
	}
	if (nextNode) {
		if (nextNode->nodeType == AudioSegmentNodeTypeCollection) {
			[node->childNodes appendSkipList:nextNode->childNodes];
			[childNodes removeObject:nextNode];
		} else {
			[node addNodeToChildren:nextNode];
			[childNodes removeObject:nextNode];
		}
	}
	
	node->startTime = ((AudioSegmentNode *)[node->childNodes firstObject])->startTime;
	node->endTime = ((AudioSegmentNode *)[node->childNodes lastObject])->endTime;
}

- (void)unmergeNode:(AudioSegmentNode *)node inChild:(AudioSegmentNode *)child
{
	AudioSegmentNode	*leftNode = nil;
	AudioSegmentNode	*middleNode = nil;
	AudioSegmentNode	*rightNode = nil;
	
	SkipList			*leftChildren = child->childNodes;
	SkipList			*rightChildren = [child->childNodes splitSkipListAtObject:node];
	
	middleNode = [rightChildren firstObject];
	child->nodeType = middleNode->nodeType;
	child->startTime = middleNode->startTime;
	child->endTime = middleNode->endTime;
	child->childNodes = [[SkipList alloc] init];
	[rightChildren removeObject:middleNode];
	
	if ([leftChildren count] > 0) {
		if ([leftChildren count] > 1) {
			leftNode = [AudioSegmentNode collectionSegmentNode];
			[leftNode->childNodes release];
			leftNode->childNodes = leftChildren;
			leftNode->startTime = ((AudioSegmentNode *)[leftNode->childNodes firstObject])->startTime;
			leftNode->endTime = ((AudioSegmentNode *)[leftNode->childNodes lastObject])->endTime;
		} else if ([leftChildren count] == 1) {
			leftNode = [[leftChildren firstObject] retain];
			[leftChildren release];
		}
		[self addNodeToChildren:leftNode];
	}
	
	if ([rightChildren count] > 0) {
		if ([rightChildren count] > 1) {
			rightNode = [AudioSegmentNode collectionSegmentNode];
			[rightNode->childNodes release];
			rightNode->childNodes = rightChildren;
			rightNode->startTime = ((AudioSegmentNode *)[rightNode->childNodes firstObject])->startTime;
			rightNode->endTime = ((AudioSegmentNode *)[rightNode->childNodes lastObject])->endTime;
		} else {
			rightNode = [[rightChildren firstObject] retain];
			[rightChildren release];
		}
		[self addNodeToChildren:rightNode];
	}
}


- (void)startEnumeration
{
	[childNodes startEnumeration];
}

- (AudioSegmentNode *)nextObject
{
	return (AudioSegmentNode *)[childNodes nextObject];
}


- (BOOL)overlapsWith:(AudioSegmentNode *)n
{
	AudioSegmentNode *first, *second;
	if (startTime <= n->startTime) {
		first = self;
		second = n;
	} else {
		first = n;
		second = self;
	}
	
	if (first->endTime >= second->startTime) {
		return YES;
	}
	
	return NO;
}

@end
