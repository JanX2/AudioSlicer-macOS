//
//  SkipList.m
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

#import "SkipList.h"

@interface SkipList (Private)
- (int)randomLevel;
@end

@implementation SkipList

- (id)init
{
	if (self = [super init]) {
		randomBits = random();
		randomsLeft = BitsInRandom / 2;
		
		numElements = 0;
		level = 0;
		allocNewSkipListNodeOfLevel(header, MaxNumberOfLevels);
		for (int i = 0; i < MaxNumberOfLevels; i++) {
			header->forward[i] = nil;
		}
		
		lastNode = nil;
		
		lastFingeredObject = nil;
		lastFingeredIndex = 0;
	}
	
	return self;
}

- (void)dealloc
{
	[self emptyList];
	free(header);
	[super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
	SkipList	*copy = [[SkipList alloc] init];
	
	for (SkipListNode *n = header->forward[0]; n != nil; n = n->forward[0]) {
		[copy addObject:n->obj];
	}
	
	return copy;
}

- (id)initWithCoder:(NSCoder *)coder
{
	if (self = [self init]) {
		if ([coder allowsKeyedCoding]) {
			unsigned int	objCount = [coder decodeIntForKey:@"objectCount"];
			for (unsigned int i = 0; i < objCount; i++) {
				[self addObject:[coder decodeObjectForKey:[NSString stringWithFormat:@"obj%u", i]]];
			}
		} else {
			[NSException raise:NSInvalidArchiveOperationException format:@"Only supports NSKeyedArchiver coders"];
		}
	}
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if ([coder allowsKeyedCoding]) {
        [coder encodeInt:numElements forKey:@"objectCount"];
		unsigned int   i = 0;
		for (SkipListNode *n = header->forward[0]; n != nil; n = n->forward[0], i++) {
			[coder encodeObject:n->obj forKey:[NSString stringWithFormat:@"obj%u", i]];
		}
	} else {
        [NSException raise:NSInvalidArchiveOperationException format:@"Only supports NSKeyedArchiver coders"];
	}
}

- (NSString *)description
{
	NSMutableString	*desc = [NSMutableString stringWithFormat:@"SkipList (%u objects):\n", numElements];
	
	unsigned int   i = 0;
	for (SkipListNode *n = header->forward[0]; n != nil; n = n->forward[0], i++) {
		[desc appendFormat:@"%.4d: %@\n", i, n->obj];
	}
	
	return desc;
}


- (unsigned)count
{
	return numElements;
}

- (id)firstObject
{
	if (numElements == 0) {
		[NSException raise:NSRangeException format:@"index out of array bounds"];
		return nil;
	}
	
	return header->forward[0]->obj;
}

- (id)lastObject
{
	if (numElements == 0) {
		[NSException raise:NSRangeException format:@"index out of array bounds"];
		return nil;
	}
	
	return lastNode->obj;
}

- (id)objectAtIndex:(unsigned)index
{
	if (index < 0 || index > (numElements - 1)) {
		[NSException raise:NSRangeException format:@"index out of array bounds"];
		return nil;
	}
	
	unsigned int	i = 0;
	SkipListNode	*n = header->forward[0];
	
	if (lastFingeredObject && index >= lastFingeredIndex) {
		n = lastFingeredObject;
		i = lastFingeredIndex;
	}
	
	for ( ; n != nil; n = n->forward[0], i++) {
		if (i == index) {
			lastFingeredObject = n;
			lastFingeredIndex = i;
			return n->obj;
		}
	}
	
	return nil;
}

- (unsigned)indexOfObjectIdenticalTo:(id)anObject
{
	unsigned int	i = 0;
	for (SkipListNode *n = header->forward[0]; n != nil; n = n->forward[0], i++) {
		if (n->obj == anObject) {
			return i;
		}
	}
	
	return NSNotFound;
}


- (void)addObject:(id)anObject
{
	SkipListNode	*update[MaxNumberOfLevels];
	SkipListNode	*n, *p;
	int				i, l;
	
	// find insert position
	IMP		impComparator = [anObject methodForSelector:@selector(compare:)];
	for (n = header, i = level; i >= 0; i--) {
		while (n->forward[i] && (NSComparisonResult)impComparator(n->forward[i]->obj, @selector(compare:), anObject) == NSOrderedAscending) {
			n = n->forward[i];
		}
		update[i] = n;
	}
	n = n->forward[0];
	
	// get level for new node
    l = [self randomLevel];
    if (l > level) {
		l = ++level;
		update[l] = header;
	}
	
	// create new node
    allocNewSkipListNodeOfLevel(p, l);
    p->obj = [anObject retain];
	numElements++;
	
	// insert new node
	for (i = l; i >= 0; i--) {
		n = update[i];
		p->forward[i] = n->forward[i];
		n->forward[i] = p;
	}
	
	// update performance hints
	lastFingeredObject = nil;
	lastFingeredIndex = 0;
	
	if (p->forward[0] == nil) {
		lastNode = p;
	}
}

- (void)removeObject:(id)anObject
{
	SkipListNode	*update[MaxNumberOfLevels];
	SkipListNode	*n;
	int				i;
	
	// find insert position
	// we assume all elements are of same class
	IMP		impComparator = [anObject methodForSelector:@selector(compare:)];
	for (n = header, i = level; i >= 0; i--) {
		while (n->forward[i] && (NSComparisonResult)impComparator(n->forward[i]->obj, @selector(compare:), anObject) == NSOrderedAscending) {
			n = n->forward[i];
		}
		update[i] = n;
	}
	n = n->forward[0];
	
	// remove node
	if (n->obj == anObject) {
		if (n->forward[0] == nil) {
			lastNode = update[0];
		}
		
		for (i = 0; i <= level; i++) {
			if (update[i]->forward[i] != n) {
				break;
			} else {
				update[i]->forward[i] = n->forward[i];
			}
		}
		free(n);
		[anObject release];
		numElements--;
		
		while (i > 0 && header->forward[level] == nil) {
			level--;
		}
	}
	
	lastFingeredObject = nil;
	lastFingeredIndex = 0;
}


// append the given skiplist to this list, destructing the given list during this (ends up empty)
- (void)appendSkipList:(SkipList *)list
{
	SkipList		*list1 = self;
	SkipList		*list2 = list;
	
	if (list2->numElements == 0) {
		return;
	}
	
	list1->numElements += list2->numElements;
	list1->lastNode = list2->lastNode;
	
	if (list1->level < list2->level) {
		for (int i = list1->level + 1; i <= list2->level; i++) {
			list1->header->forward[i] = nil;
		}
		list1->level = list2->level;
	}
	
	SkipListNode	*n = list1->header;
	for (int i = list1->level; i >= 0; i--) {
		while (n->forward[i] != nil) {
			n = n->forward[i];
		}
		if (i <= list2->level) {
			n->forward[i] = list2->header->forward[i];
		}
	}
	
	// make appended lists appear empty, all elements were moved to this list
	for (int i = 0; i < MaxNumberOfLevels; i++) {
		list2->header->forward[i] = nil;
	}
	list2->numElements = 0;
	list2->level = 0;
}

- (SkipList *)splitSkipListAtObject:(id)splitObject
{
	SkipList		*list1 = self;
	SkipList		*list2 = [[SkipList alloc] init];
	SkipListNode	*n = list1->header;
	IMP				impComparator = [splitObject methodForSelector:@selector(compare:)];
	
	list2->level = list1->level;
	for (int i = list1->level; i >= 0; i--) {
		while (n->forward[i] && (NSComparisonResult)impComparator(n->forward[i]->obj, @selector(compare:), splitObject) == NSOrderedAscending) {
			n = n->forward[i];
		}
		list2->header->forward[i] = n->forward[i];
		n->forward[i] = nil;
	}
	
	unsigned int	count = 0;
	for (SkipListNode *p = header->forward[0]; p != nil; p = p->forward[0], count++);
	list2->numElements = list1->numElements - count;
	list1->numElements = count;
	list2->lastNode = (list2->numElements > 0) ? list1->lastNode : nil;
	list1->lastNode = (list1->numElements > 0) ? n : nil;
	
	while (list1->header->forward[list1->level] == nil && list1->level > 0) {
		list1->level--;
	}
	while (list2->header->forward[list2->level] == nil && list2->level > 0) {
		list2->level--;
	}
	
	return list2;
}

- (void)emptyList
{
	for (SkipListNode *n = header->forward[0]; n != nil; n = n->forward[0]) {
		[n->obj release];
		free(n);
	}
	
	for (int i = 0; i < MaxNumberOfLevels; i++) {
		header->forward[i] = nil;
	}
	numElements = 0;
	level = 0;
	
	lastFingeredObject = nil;
	lastFingeredIndex = 0;
	lastNode = nil;
}


- (void)startEnumeration
{
	enumerationNode = header;
}

- (id)nextObject
{
	if (enumerationNode) {
		enumerationNode = enumerationNode->forward[0];
		if (enumerationNode) {
			return enumerationNode->obj;
		}
	}
	
	return nil;
}

@end

@implementation SkipList (Private)

- (int)randomLevel
{
	int		l = 0;
	int		b;
	
	do {
		b = randomBits & 3;
		if (!b) l++;
		randomBits >>= 2;
		if (--randomsLeft == 0) {
			randomBits = random();
			randomsLeft = BitsInRandom / 2;
        }
    } while (!b);
	
    return MIN(l, MaxLevel);
}

@end
