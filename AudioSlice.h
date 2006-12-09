//
//  AudioSlice.h
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

#import <Foundation/Foundation.h>

@class AudioSegmentNode, AudioSegmentTree;


extern NSString *AudioSliceDidChangeNotification;

@interface AudioSlice : NSObject <NSCopying, NSCoding> {
	AudioSegmentTree	*audioSegmentTree;
	AudioSegmentNode	*leftSilenceSegment;
	AudioSegmentNode	*rightSilenceSegment;
	
	BOOL				expandedInOutlineView;
	
	// id3 information used for export
	NSString			*title;
	NSString			*artist;
	NSString			*album;
	NSString			*composer;
	NSString			*genre;
	NSString			*comment;
	int					year;
	int					trackNumber;
	int					trackCount;
	int					cdNumber;
	int					cdCount;
}

+ (id)audioSliceWithTree:(AudioSegmentTree *)tree leftSilenceSegment:(AudioSegmentNode *)left rightSilenceSegment:(AudioSegmentNode *)right;
- (id)initWithTree:(AudioSegmentTree *)tree leftSilenceSegment:(AudioSegmentNode *)left rightSilenceSegment:(AudioSegmentNode *)right;
- (id)copyWithZone:(NSZone *)zone;

- (id)initWithCoder:(NSCoder *)coder;
- (void)encodeWithCoder:(NSCoder *)coder;

- (NSUndoManager *)undoManager;

- (void)breakDownToAverageDuration:(double)averageDuration tolerance:(double)tolerance;

- (void)setLeftSilenceSegment:(AudioSegmentNode *)left;
- (AudioSegmentNode *)leftSilenceSegment;
- (void)setRightSilenceSegment:(AudioSegmentNode *)right;
- (AudioSegmentNode *)rightSilenceSegment;

- (double)startTime;
- (double)endTime;
- (double)duration;

- (void)setAttributesFromTags:(NSDictionary *)tagDict;
- (NSDictionary *)tagsFromAttributes;

- (void)setTitle:(NSString *)aTitle;
- (NSString *)title;
- (void)setArtist:(NSString *)anArtist;
- (NSString *)artist;
- (void)setAlbum:(NSString *)anAlbum;
- (NSString *)album;
- (void)setComposer:(NSString *)aComposer;
- (NSString *)composer;
- (void)setGenre:(NSString *)aGenre;
- (NSString *)genre;
- (void)setComment:(NSString *)aComment;
- (NSString *)comment;
- (void)setYear:(int)aYear;
- (int)year;
- (void)setTrackNumber:(int)track;
- (int)trackNumber;
- (void)setTrackCount:(int)count;
- (int)trackCount;
- (void)setCdNumber:(int)cd;
- (int)cdNumber;
- (void)setCdCount:(int)count;
- (int)cdCount;

- (void)setExpandedInOutlineView:(BOOL)flag;
- (BOOL)expandedInOutlineView;

@end
