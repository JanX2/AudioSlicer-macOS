//
//  AudioFileMP3.m
//  AudioSlicer
//
//  Created by Bernd Heller on Thu Feb 05 2004.
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

#include <unistd.h>
#include <sys/mman.h>


@implementation AudioFileMP3

- (id)initWithPath:(NSString *)path
{
	if (self = [super initWithPath:path]) {
		madDecoder = [[MADDecoderThreaded alloc] initWithAudioFile:self];
		//madDecoder = [[MADDecoder alloc] initWithAudioFile:self];
		if (fileData != nil) {
			[madDecoder setMP3Data:[NSData dataWithBytesNoCopy:fileData length:fileLength freeWhenDone:NO]];
		}
	}
	
	return self;
}

- (void)dealloc
{
	[madDecoder dealloc];
	[super dealloc];
}

- (id)initWithCoder:(NSCoder *)coder
{
	if ([coder allowsKeyedCoding]) {
		if (self = [super initWithCoder:coder]) {
			audioChannels = [coder decodeIntForKey:@"audioChannels"];
			audioSamplingFrequency = [coder decodeIntForKey:@"audioSamplingFrequency"];
			audioDuration = [coder decodeDoubleForKey:@"audioDuration"];
		}
		
		return self;
	} else {
		[NSException raise:NSInvalidArchiveOperationException format:@"Only supports NSKeyedArchiver coders"];
		return nil;
	}
	return nil;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if ([coder allowsKeyedCoding]) {
		[super encodeWithCoder:coder];
		[coder encodeInt:audioChannels forKey:@"audioChannels"];
		[coder encodeInt:audioSamplingFrequency forKey:@"audioSamplingFrequency"];
		[coder encodeDouble:audioDuration forKey:@"audioDuration"];
	} else {
        [NSException raise:NSInvalidArchiveOperationException format:@"Only supports NSKeyedArchiver coders"];
	}
}

#pragma mark -

- (NSString *)fileExtension
{
	return @"mp3";
}

- (BOOL)openFile
{
	if (fileHandle) {
		// already open
		return NO;
	}
	
	fileLength = [[[[NSFileManager defaultManager] fileAttributesAtPath:filePath traverseLink:NO] objectForKey:NSFileSize] unsignedLongValue];
	fileHandle = [[NSFileHandle fileHandleForReadingAtPath:filePath] retain];
	if (fileHandle) {
		fileData = mmap(0, fileLength, PROT_READ, MAP_SHARED, [fileHandle fileDescriptor], 0);
		if (!fileData) {
			return NO;
		}
	}
	
	return YES;
}

- (void)closeFile
{
	if (fileData) {
		munmap(fileData, fileLength);
		fileData = NULL;
	}
	
	[fileHandle closeFile];
	[fileHandle release];
	fileHandle = nil;
	fileLength = 0;
}

#pragma mark -

- (double)progressMinValue
{
	return 0;
}

- (double)progressMaxValue
{
	return fileLength;
}

- (double)progressValue
{
	return [madDecoder progressValue];
}

#pragma mark -

- (BOOL)doAnalyzeAudio
{
	int result = 0;
	
	result = [madDecoder analyzeSilencesWithVolumeThreshold:silenceVolumeThreshold
										  durationThreshold:silenceDurationThreshold];
	
	if (result < 0) {
		return NO;
	}
	
	audioDuration = [madDecoder audioDuration];
	audioChannels = [madDecoder audioChannels];
	audioSamplingFrequency = [madDecoder audioSamplingFrequency];
	
	return YES;
}

- (void)doDecodeToAudioBufferFrom:(double)start to:(double)end
{
	[madDecoder playAudioStartTime:start endTime:end];
}

- (void)doWriteAudioToFile:(NSFileHandle *)file from:(double)start to:(double)end
{
	[madDecoder splitDecodeToFile:file startTime:start endTime:end];
}

#pragma mark -

- (double)getAudioDuration
{
	return audioDuration;
}

- (int)getAudioSampleRate
{
	return audioSamplingFrequency;
}

- (int)getAudioChannels
{
	return audioChannels;
}

@end

