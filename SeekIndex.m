//
//  SeekIndex.m
//  AudioSlicer
//
//  Created by Bernd Heller on 01.10.06.
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

#import "SeekIndex.h"


@implementation SeekIndex

- (id)initWithCapacity:(uint32_t)capacity
{
	if (self = [super init]) {
		allocedEntries = capacity;
		entries = (SeekIndexEntry *) malloc(allocedEntries * sizeof(SeekIndexEntry));
		numEntries = 0;
		
		syncLock = [[NSLock alloc] init];
	}
	
	return self;
}

- (id)init
{
	return [self initWithCapacity:1000];
}

- (void)dealloc
{
	if (entries != NULL) {
		free(entries);
		entries = NULL;
	}
	
	[syncLock release];
	
	[super dealloc];
}


#pragma mark -


- (id)initWithCoder:(NSCoder *)coder
{
	if ([coder allowsKeyedCoding]) {
		NSArray *entriesArr = [coder decodeObjectForKey:@"entries"];
		uint32_t count = [entriesArr count];
		if (self = [self initWithCapacity:count]) {
			for (uint32_t i = 0; i < count; i++) {
				NSDictionary *entryDict = [entriesArr objectAtIndex:i];
				entries[i].time = [[entryDict objectForKey:@"time"] unsignedLongValue];
				entries[i].byteOffset = [[entryDict objectForKey:@"offset"] doubleValue];
			}
			numEntries = count;
		}
		
		return self;
	} else {
		[NSException raise:NSInvalidArchiveOperationException format:@"Only supports NSKeyedArchiver coders"];
		return nil;
	}
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if ([coder allowsKeyedCoding]) {
        NSMutableArray *entriesArr = [NSMutableArray arrayWithCapacity:numEntries];
		for (uint32_t i = 0; i < numEntries; i++) {
			NSDictionary *entryDict = [NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithUnsignedLong:entries[i].byteOffset], @"offset",
				[NSNumber numberWithDouble:entries[i].time], @"time",
				nil];
			[entriesArr addObject:entryDict];
		}
		[coder encodeObject:entriesArr forKey:@"entries"];
	} else {
        [NSException raise:NSInvalidArchiveOperationException format:@"Only supports NSKeyedArchiver coders"];
	}
}


#pragma mark -


- (void)addOffset:(uint32_t)offset forTimeIndex:(double)time
{
	[syncLock lock];
	
	// enlarge index if necessary
	if (numEntries + 1 >= allocedEntries) {
		allocedEntries *= 2;
		entries = (SeekIndexEntry *) realloc(entries, allocedEntries * sizeof(SeekIndexEntry));
	}
	
	// check for duplicates
	for (uint32_t i = 0; i < numEntries; i++) {
		if (entries[i].time == time) {
			// already inserted
			[syncLock unlock];
			return;
		}
	}
	
	// insert new index entry
	entries[numEntries].time = time;
	entries[numEntries].byteOffset = offset;
	numEntries++;
	
	[syncLock unlock];
}

- (SeekIndexEntry)entryForTimeIndex:(double)time
{
	static SeekIndexEntry zeroEntry = {0.0, 0};
	
	[syncLock lock];
	
	// find closest time index that is BEFORE the given time
	double diff = (double)LONG_MAX;
	uint32_t bestEntryIndex = 0;
	BOOL found = NO;
	for (uint32_t i = 0; i < numEntries; i++) {
		if (entries[i].time <= time) {
			double d = time - entries[i].time;
			if (d < diff) {
				diff = d;
				bestEntryIndex = i;
				found = YES;
			}
		}
	}
	
	SeekIndexEntry result;
	if (found) {
		result = entries[bestEntryIndex];
	} else {
		result = zeroEntry;
	}
	
	[syncLock unlock];
	
	return result;
}

- (uint32_t)offsetForTimeIndex:(double)time
{
	return [self entryForTimeIndex:time].byteOffset;
}

@end
