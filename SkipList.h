//
//  SkipList.h
//  AudioSlicer
//
//  Created by Bernd Heller on Sat Feb 21 2004.
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


#define BitsInRandom 31
#define MaxNumberOfLevels 16
#define MaxLevel (MaxNumberOfLevels-1)
#define allocNewSkipListNodeOfLevel(ptr, level) { (ptr) = (SkipListNode *)malloc(sizeof(SkipListNode)); }

typedef struct SkipListNode {
	id						obj;
	struct SkipListNode		*forward[MaxNumberOfLevels];
} SkipListNode;

@interface SkipList : NSObject <NSCopying, NSCoding> {
	SkipListNode	*header;
	NSInteger		level;
	NSUInteger		numElements;
	
	SkipListNode	*enumerationNode;
	
	// hints for performance optimization
	SkipListNode	*lastNode;
	SkipListNode	*lastFingeredObject;
	NSUInteger		lastFingeredIndex;
	
	NSInteger		randomsLeft;
	NSInteger		randomBits;
}


- (NSString *)description;

- (NSUInteger)count;
- (id)firstObject;
- (id)lastObject;
- (id)objectAtIndex:(NSUInteger)index;
- (NSUInteger)indexOfObjectIdenticalTo:(id)anObject;

- (void)addObject:(id)anObject;
- (void)removeObject:(id)anObject;

- (void)appendSkipList:(SkipList *)list;
- (SkipList *)splitSkipListAtObject:(id)splitObject;
- (void)emptyList;

- (void)startEnumeration;
- (id)nextObject;

@end
