//
//  AudioFileMP3Tag.m
//  AudioSlicer
//
//  Created by Bernd Heller on Mon Mar 01 2004.
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

#import "AudioFileMP3.h"

#include <tag.h>
#include <mpegfile.h>
#include <id3v2tag.h>
#include <id3v2frame.h>
#include <id3v2header.h>
#include <id3v1tag.h>
#include <id3v1genres.h>
#include <textidentificationframe.h>
#include <commentsframe.h>

@implementation AudioFileMP3 (AudioFileTag)

#define HAS_TAG(tagID) (!tag->frameListMap()[tagID].isEmpty())

#define GET_STR_TAG(tagID) [NSString stringWithUTF8String:(tag->frameListMap()[tagID].front()->toString().toCString(true))]
#define READ_STR_TAG(tagID, dictKey) \
if (HAS_TAG(tagID)) { \
	[tagDict setObject:GET_STR_TAG(tagID) forKey:dictKey]; \
}
#define GET_INT_TAG(tagID) [NSNumber numberWithInt:(tag->frameListMap()[tagID].front()->toString().toInt())]
#define READ_INT_TAG(tagID, dictKey) \
if (HAS_TAG(tagID)) { \
	[tagDict setObject:GET_INT_TAG(tagID) forKey:dictKey]; \
}

#define SET_STR_TAG(tagID, str) \
{ \
	TagLib::String s([str UTF8String], TagLib::String::UTF8); \
	if (!HAS_TAG(tagID)) { \
		tag->addFrame(new TagLib::ID3v2::TextIdentificationFrame(tagID, TagLib::String::Latin1)); \
	} \
	if (![str canBeConvertedToEncoding:NSISOLatin1StringEncoding]) { \
		((TagLib::ID3v2::TextIdentificationFrame *)(tag->frameListMap()[tagID].front()))->setTextEncoding(TagLib::String::UTF16); \
	} \
	tag->frameListMap()[tagID].front()->setText(s); \
}
#define WRITE_STR_TAG(tagID, dictKey) \
if ([tagDict objectForKey:dictKey] != nil) { \
	SET_STR_TAG(tagID, ((NSString *)[tagDict objectForKey:dictKey])); \
}
#define WRITE_INT_TAG(tagID, dictKey) \
if ([tagDict objectForKey:dictKey] != nil) { \
	SET_STR_TAG(tagID, [(NSNumber *)[tagDict objectForKey:dictKey] stringValue]); \
}

+ (NSDictionary *)readTagsFromFile:(NSString *)path
{
	NSMutableDictionary	*tagDict = [[[NSMutableDictionary alloc] init] autorelease];
	
	TagLib::MPEG::File	*f = new TagLib::MPEG::File([path fileSystemRepresentation]);
	TagLib::ID3v2::Tag	*tag = f->ID3v2Tag();
	
	READ_STR_TAG("TIT2", @"Title");
	READ_STR_TAG("TPE1", @"Artist");
	READ_STR_TAG("TALB", @"Album");
	READ_STR_TAG("TCOM", @"Composer");
	READ_INT_TAG("TDRC", @"Year");
	
	if (!tag->genre().isNull()) {
		[tagDict setObject:[NSString stringWithUTF8String:(tag->genre().toCString(true))] forKey:@"Genre"];
	}
	
	if (HAS_TAG("TRCK")) {
		NSArray	 *arr = [GET_STR_TAG("TRCK") componentsSeparatedByString:@"/"];
		if ([arr count] > 0) {
			[tagDict setObject:[NSNumber numberWithInt:[[arr objectAtIndex:0] intValue]] forKey:@"TrackNumber"];
		}
		if ([arr count] > 1) {
			[tagDict setObject:[NSNumber numberWithInt:[[arr objectAtIndex:1] intValue]] forKey:@"TrackCount"];
		}
	}
	
	if (HAS_TAG("TPOS")) {
		NSArray	 *arr = [GET_STR_TAG("TPOS") componentsSeparatedByString:@"/"];
		if ([arr count] > 0) {
			[tagDict setObject:[NSNumber numberWithInt:[[arr objectAtIndex:0] intValue]] forKey:@"CdNumber"];
		}
		if ([arr count] > 1) {
			[tagDict setObject:[NSNumber numberWithInt:[[arr objectAtIndex:1] intValue]] forKey:@"CdCount"];
		}
	}
	
	TagLib::ID3v2::FrameList commentFrameList = tag->frameListMap()["COMM"];
	for (TagLib::ID3v2::FrameList::ConstIterator it = commentFrameList.begin(); it != commentFrameList.end(); it++) {
		TagLib::ID3v2::CommentsFrame *frame = static_cast<TagLib::ID3v2::CommentsFrame *>(*it);
		if (frame->description().isEmpty()) {
			[tagDict setObject:[NSString stringWithUTF8String:(frame->text().toCString(true))] forKey:@"Comment"];
			break;
		}
	}
	
	delete f;
	
	return tagDict;
}

+ (BOOL)writeTags:(NSDictionary *)tagDict toFile:(NSString *)path
{
	TagLib::MPEG::File	*f = new TagLib::MPEG::File([path fileSystemRepresentation]);
	TagLib::ID3v2::Tag	*tag = f->ID3v2Tag(true);
	
	WRITE_STR_TAG("TIT2", @"Title");
	WRITE_STR_TAG("TPE1", @"Artist");
	WRITE_STR_TAG("TALB", @"Album");
	WRITE_STR_TAG("TCOM", @"Composer");
	WRITE_INT_TAG("TDRC", @"Year");
	
	if ([tagDict objectForKey:@"Genre"] != nil) {
		tag->setGenre(TagLib::String([[tagDict objectForKey:@"Genre"] UTF8String], TagLib::String::UTF8));
	}
	
	NSMutableArray *arr = [NSMutableArray arrayWithCapacity:2];
	[arr removeAllObjects];
	if ([tagDict objectForKey:@"TrackNumber"] != nil) {
		[arr addObject:[tagDict objectForKey:@"TrackNumber"]];
	} else {
		[arr addObject:@""];
	}
	if ([tagDict objectForKey:@"TrackCount"] != nil) {
		[arr addObject:[tagDict objectForKey:@"TrackCount"]];
	} else {
		[arr addObject:@""];
	}
	SET_STR_TAG("TRCK", [arr componentsJoinedByString:@"/"]);
	
	[arr removeAllObjects];
	if ([tagDict objectForKey:@"CdNumber"] != nil) {
		[arr addObject:[tagDict objectForKey:@"CdNumber"]];
	} else {
		[arr addObject:@""];
	}
	if ([tagDict objectForKey:@"CdCount"] != nil) {
		[arr addObject:[tagDict objectForKey:@"CdCount"]];
	} else {
		[arr addObject:@""];
	}
	SET_STR_TAG("TPOS", [arr componentsJoinedByString:@"/"]);
	
	NSString *comment = [tagDict objectForKey:@"Comment"];
	if (comment == nil) comment = @"";
	TagLib::ID3v2::CommentsFrame *frame = 0;
	TagLib::ID3v2::FrameList commentFrameList = tag->frameListMap()["COMM"];
	for (TagLib::ID3v2::FrameList::ConstIterator it = commentFrameList.begin(); it != commentFrameList.end(); it++) {
		frame = static_cast<TagLib::ID3v2::CommentsFrame *>(*it);
		if (frame->description().isEmpty()) {
			break;
		} else {
			frame = 0;
		}
	}
	if (frame == 0) {
		frame = new TagLib::ID3v2::CommentsFrame(TagLib::String::Latin1);
		tag->addFrame(frame);
	}
	if (![comment canBeConvertedToEncoding:NSISOLatin1StringEncoding]) {
		frame->setTextEncoding(TagLib::String::UTF16);
	}
	TagLib::String commStr([comment UTF8String], TagLib::String::UTF8);
	frame->setText(commStr);
	
	f->save();
	
	delete f;
	
	return YES;
}

+ (NSArray *)genreList
{
	NSMutableArray *genreArr = [[NSMutableArray alloc] initWithCapacity:200];
	
	TagLib::StringList list = TagLib::ID3v1::genreList();
	for (uint i = 0; i < list.size(); i++) {
		[genreArr addObject:[NSString stringWithUTF8String:(list[i].toCString(true))]];
	}
	
	[genreArr sortUsingSelector:@selector(compare:)];
	
	return genreArr;
}

@end
