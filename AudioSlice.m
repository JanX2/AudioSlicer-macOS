//
//  AudioSlice.m
//  AudioSlicer
//
//  Created by Bernd Heller on Sat Feb 14 2004.
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

#import "AudioSlice.h"
#import "AudioSegmentTree.h"


NSString *AudioSliceDidChangeNotification = @"AudioSliceDidChangeNotification";

@interface AudioSlice (Private)
- (void)sliceDidChange;
@end


@implementation AudioSlice

+ (id)audioSliceWithTree:(AudioSegmentTree *)tree leftSilenceSegment:(AudioSegmentNode *)left rightSilenceSegment:(AudioSegmentNode *)right
{
	return [[[AudioSlice alloc] initWithTree:tree leftSilenceSegment:left rightSilenceSegment:right] autorelease];
}

- (id)initWithTree:(AudioSegmentTree *)tree leftSilenceSegment:(AudioSegmentNode *)left rightSilenceSegment:(AudioSegmentNode *)right
{
	if (self = [super init]) {
		audioSegmentTree = [tree retain];
		
		[self setLeftSilenceSegment:left];
		[self setRightSilenceSegment:right];
		[self setExpandedInOutlineView:NO];
		
		trackNumber = 0;
		trackCount = 0;
		cdNumber = 0;
		cdCount = 0;
		year = 0;
	}
	
	return self;
}

- (void)dealloc
{
	[[self undoManager] removeAllActionsWithTarget:self];
	[audioSegmentTree release];
	
	[title release];
	[artist release];
	[album release];
	[composer release];
	[genre release];
	[comment release];
	
	[super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
	AudioSlice  *copy = (AudioSlice *) NSCopyObject(self, 0, zone);
	
	[copy->audioSegmentTree retain];
	
	copy->title = [title copy];
	copy->artist = [artist copy];
	copy->album = [album copy];
	copy->genre = [genre copy];
	copy->comment = [comment copy];
	
	return copy;
}


- (id)initWithCoder:(NSCoder *)coder
{
	if (self = [super init]) {
		if ([coder allowsKeyedCoding]) {
			audioSegmentTree = [[coder decodeObjectForKey:@"audioSegmentTree"] retain];
			leftSilenceSegment = [coder decodeObjectForKey:@"leftSilenceSegment"];
			rightSilenceSegment = [coder decodeObjectForKey:@"rightSilenceSegment"];
			expandedInOutlineView = [coder decodeBoolForKey:@"expandedInOutlineView"];
			title = [[coder decodeObjectForKey:@"title"] retain];
			artist = [[coder decodeObjectForKey:@"artist"] retain];
			album = [[coder decodeObjectForKey:@"album"] retain];
			composer = [[coder decodeObjectForKey:@"composer"] retain];
			genre = [[coder decodeObjectForKey:@"genre"] retain];
			comment = [[coder decodeObjectForKey:@"comment"] retain];
			year = [coder decodeIntForKey:@"year"];
			trackNumber = [coder decodeIntForKey:@"trackNumber"];
			trackCount = [coder decodeIntForKey:@"trackCount"];
			cdNumber = [coder decodeIntForKey:@"cdNumber"];
			cdCount = [coder decodeIntForKey:@"cdCount"];
		} else {
			[NSException raise:NSInvalidArchiveOperationException format:@"Only supports NSKeyedArchiver coders"];
		}
	}
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if ([coder allowsKeyedCoding]) {
        [coder encodeConditionalObject:audioSegmentTree forKey:@"audioSegmentTree"];
        [coder encodeConditionalObject:leftSilenceSegment forKey:@"leftSilenceSegment"];
        [coder encodeConditionalObject:rightSilenceSegment forKey:@"rightSilenceSegment"];
        [coder encodeBool:expandedInOutlineView forKey:@"expandedInOutlineView"];
        [coder encodeObject:title forKey:@"title"];
        [coder encodeObject:artist forKey:@"artist"];
        [coder encodeObject:album forKey:@"album"];
        [coder encodeObject:composer forKey:@"composer"];
        [coder encodeObject:genre forKey:@"genre"];
        [coder encodeObject:comment forKey:@"comment"];
        [coder encodeInt:year forKey:@"year"];
        [coder encodeInt:trackNumber forKey:@"trackNumber"];
        [coder encodeInt:trackCount forKey:@"trackCount"];
        [coder encodeInt:cdNumber forKey:@"cdNumber"];
        [coder encodeInt:cdCount forKey:@"cdCount"];
	} else {
        [NSException raise:NSInvalidArchiveOperationException format:@"Only supports NSKeyedArchiver coders"];
	}
}

#pragma mark -

- (void)setAudioSegmentTree:(AudioSegmentTree *)tree;
{
	audioSegmentTree = tree;
}

- (NSUndoManager *)undoManager
{
	return [audioSegmentTree undoManager];
}

#pragma mark -

- (void)breakDownToAverageDuration:(double)averageDuration tolerance:(double)tolerance
{
	int numAudioSegments = [audioSegmentTree numberOfAudioSegmentsInSlice:self];
	
	double duration = 0.0;
	int bestSplitSegmentIndex = -1;
	double bestSplitPointSilenceDuration;
	for (int i = 0; i < numAudioSegments; i++) {
		AudioSegmentNode *segment = [audioSegmentTree audioSegmentAtIndex:i inSlice:self];
		double segmentDuration = [segment duration];
		duration += segmentDuration;
		if ([segment isMemberOfClass:[AudioSegmentNode class]] && [segment nodeType] == AudioSegmentNodeTypeSilence && ![segment doesSplit]) {
			// try to find the longest silence in an interval +-tolerance around the ideal duration and split there
			if (duration >= (averageDuration * (1.0 - tolerance))) {
				if (bestSplitSegmentIndex < 0 || (bestSplitPointSilenceDuration <= segmentDuration)) {
					bestSplitSegmentIndex = i;
					bestSplitPointSilenceDuration = segmentDuration;
					//NSLog(@"considering segment %d (%.2f) for split", bestSplitSegmentIndex, bestSplitPointSilenceDuration);
				}
				
				if (duration >= (averageDuration * (1.0 + tolerance)) && (bestSplitSegmentIndex >= 0)) {
					// split at the best silence segment
					//NSLog(@"splitting after duration %.2f", duration);
					[audioSegmentTree setSplitPointAtNode:[audioSegmentTree audioSegmentAtIndex:bestSplitSegmentIndex inSlice:self]];
					
					// prepare for breaking up the rest in another loop iteration
					duration = 0.0;
					i = bestSplitSegmentIndex + 1;
					bestSplitSegmentIndex = -1;
				}
			}
		}
	}
}

#pragma mark -

- (void)setLeftSilenceSegment:(AudioSegmentNode *)left
{
	if (left == nil || [left nodeType] == AudioSegmentNodeTypeSilence) {
		leftSilenceSegment = left;
	} else {
        [NSException raise:NSInvalidArgumentException format:@"AudioSegmentNode was not of type Silence"];
	}
}

- (AudioSegmentNode *)leftSilenceSegment
{
	return leftSilenceSegment;
}

- (void)setRightSilenceSegment:(AudioSegmentNode *)right
{
	if (right == nil || [right nodeType] == AudioSegmentNodeTypeSilence) {
		rightSilenceSegment = right;
	} else {
        [NSException raise:NSInvalidArgumentException format:@"AudioSegmentNode was not of type Silence"];
	}
}

- (AudioSegmentNode *)rightSilenceSegment
{
	return rightSilenceSegment;
}

#pragma mark -

- (double)startTime
{
	return leftSilenceSegment ? [leftSilenceSegment endTime] : 0.0;
}

- (double)endTime
{
	return rightSilenceSegment ? [rightSilenceSegment startTime] : [audioSegmentTree duration];
}

- (double)duration
{
	return [self endTime] - [self startTime];
}

#pragma mark -

- (void)setAttributesFromTags:(NSDictionary *)tagDict
{
	[self setTitle:[tagDict objectForKey:@"Title"]];
	[self setArtist:[tagDict objectForKey:@"Artist"]];
	[self setAlbum:[tagDict objectForKey:@"Album"]];
	[self setComposer:[tagDict objectForKey:@"Composer"]];
	[self setGenre:[tagDict objectForKey:@"Genre"]];
	[self setComment:[tagDict objectForKey:@"Comment"]];
	[self setYear:[[tagDict objectForKey:@"Year"] intValue]];
	[self setTrackNumber:[[tagDict objectForKey:@"TrackNumber"] intValue]];
	[self setTrackCount:[[tagDict objectForKey:@"TrackCount"] intValue]];
	[self setCdNumber:[[tagDict objectForKey:@"CdNumber"] intValue]];
	[self setCdCount:[[tagDict objectForKey:@"CdCount"] intValue]];
}

- (NSDictionary *)tagsFromAttributes
{
	NSMutableDictionary		*tagDict = [[[NSMutableDictionary alloc] init] autorelease];
	
	[tagDict setObject:[NSNumber numberWithDouble:[self duration]] forKey:@"Duration"];
	
	if (title) {
		[tagDict setObject:title forKey:@"Title"];
	}
	if (artist) {
		[tagDict setObject:artist forKey:@"Artist"];
	}
	if (album) {
		[tagDict setObject:album forKey:@"Album"];
	}
	if (composer) {
		[tagDict setObject:composer forKey:@"Composer"];
	}
	if (genre) {
		[tagDict setObject:genre forKey:@"Genre"];
	}
	if (comment) {
		[tagDict setObject:comment forKey:@"Comment"];
	}
	if (year > 0) {
		[tagDict setObject:[NSNumber numberWithInt:year] forKey:@"Year"];
	}
	if ([self trackNumber] > 0) {
		[tagDict setObject:[NSNumber numberWithInt:[self trackNumber]] forKey:@"TrackNumber"];
	}
	if ([self trackCount] > 0) {
		[tagDict setObject:[NSNumber numberWithInt:[self trackCount]] forKey:@"TrackCount"];
	}
	if (cdNumber > 0) {
		[tagDict setObject:[NSNumber numberWithInt:cdNumber] forKey:@"CdNumber"];
	}
	if (cdCount > 0) {
		[tagDict setObject:[NSNumber numberWithInt:cdCount] forKey:@"CdCount"];
	}
	
	return tagDict;
}

#pragma mark -

- (void)setTitle:(NSString *)aTitle
{
	if (![title isEqualToString:aTitle]) {
		[[[self undoManager] prepareWithInvocationTarget:self] setTitle:title];
		if ([[self undoManager] isUndoing] || [[self undoManager] isRedoing]) {
			[[self undoManager] setActionName:[[self undoManager] undoActionName]];
		} else {
			[[self undoManager] setActionName:@"Change Title"];
		}
		
		[title release];
		title = [aTitle copy];
		[self sliceDidChange];
	}
}

- (NSString *)title
{
	return title;
}

- (void)setArtist:(NSString *)anArtist
{
	if (![artist isEqualToString:anArtist]) {
		[[[self undoManager] prepareWithInvocationTarget:self] setArtist:artist];
		[[self undoManager] setActionName:@"Change Artist"];
		
		[artist release];
		artist = [anArtist copy];
		[self sliceDidChange];
	}
}

- (NSString *)artist
{
	return artist;
}

- (void)setAlbum:(NSString *)anAlbum
{
	if (![album isEqualToString:anAlbum]) {
		[[[self undoManager] prepareWithInvocationTarget:self] setAlbum:album];
		[[self undoManager] setActionName:@"Change Album"];
		
		[album release];
		album = [anAlbum copy];
		[self sliceDidChange];
	}
}

- (NSString *)album
{
	return album;
}

- (void)setComposer:(NSString *)aComposer
{
	if (![composer isEqualToString:aComposer]) {
		[[[self undoManager] prepareWithInvocationTarget:self] setComposer:composer];
		[[self undoManager] setActionName:@"Change Composer"];
		
		[composer release];
		composer = [aComposer copy];
		[self sliceDidChange];
	}
}

- (NSString *)composer
{
	return composer;
}

- (void)setGenre:(NSString *)aGenre
{
	if (![genre isEqualToString:aGenre]) {
		[[[self undoManager] prepareWithInvocationTarget:self] setGenre:genre];
		[[self undoManager] setActionName:@"Change Genre"];
		
		[genre release];
		genre = [aGenre copy];
		[self sliceDidChange];
	}
}

- (NSString *)genre
{
	return genre;
}

- (void)setComment:(NSString *)aComment
{
	if (![comment isEqualToString:aComment]) {
		[[[self undoManager] prepareWithInvocationTarget:self] setComment:comment];
		[[self undoManager] setActionName:@"Change Comment"];
		
		[comment release];
		comment = [aComment copy];
		[self sliceDidChange];
	}
}

- (NSString *)comment
{
	return comment;
}

- (void)setYear:(int)aYear
{
	if (year != aYear) {
		[(typeof(self))[[self undoManager] prepareWithInvocationTarget:self] setYear:year];
		[[self undoManager] setActionName:@"Change Year"];
		
		year = aYear;
		[self sliceDidChange];
	}
}

- (int)year
{
	return year;
}

- (void)setTrackNumber:(int)track
{
	if (trackNumber != track) {
		[[[self undoManager] prepareWithInvocationTarget:self] setTrackNumber:trackNumber];
		if ([[self undoManager] isUndoing] || [[self undoManager] isRedoing]) {
			[[self undoManager] setActionName:[[self undoManager] undoActionName]];
		} else {
			[[self undoManager] setActionName:@"Change Track Number"];
		}
		
		trackNumber = track;
		[self sliceDidChange];
	}
}

- (int)trackNumber
{
	if (trackNumber > 0) {
		return trackNumber;
	} else {
		return [audioSegmentTree indexOfSlice:self] + 1;
	}
}

- (void)setTrackCount:(int)count
{
	if (trackCount != count) {
		[[[self undoManager] prepareWithInvocationTarget:self] setTrackCount:trackCount];
		[[self undoManager] setActionName:@"Change Track Count"];
		
		trackCount = count;
		[self sliceDidChange];
	}
}

- (int)trackCount
{
	if (trackCount > 0) {
		return trackCount;
	} else {
		return [audioSegmentTree numberOfSlices];
	}
}

- (void)setCdNumber:(int)cd
{
	if (cdNumber != cd) {
		[[[self undoManager] prepareWithInvocationTarget:self] setCdNumber:cdNumber];
		[[self undoManager] setActionName:@"Change CD Number"];
		
		cdNumber = cd;
		[self sliceDidChange];
	}
}

- (int)cdNumber
{
	return cdNumber;
}

- (void)setCdCount:(int)count
{
	if (cdCount != count) {
		[[[self undoManager] prepareWithInvocationTarget:self] setCdCount:cdCount];
		[[self undoManager] setActionName:@"Change CD Count"];
		
		cdCount = count;
		[self sliceDidChange];
	}
}

- (int)cdCount
{
	return cdCount;
}

#pragma mark -

- (void)setExpandedInOutlineView:(BOOL)flag
{
	expandedInOutlineView = flag;
}

- (BOOL)expandedInOutlineView
{
	return expandedInOutlineView;
}

@end

#pragma mark -

@implementation AudioSlice (Private)

- (void)sliceDidChange
{
	[[NSNotificationCenter defaultCenter] postNotificationName:AudioSliceDidChangeNotification
														object:self];
}

@end
