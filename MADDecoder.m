//
//  MADDecoder.m
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

#import "MADDecoder.h"
#import "MADDecoderProcessor.h"


@implementation MADDecoder


- (id)initWithAudioFile:(AudioFile *)anAudioFile
{
	if (self = [super init]) {
		audioFile = anAudioFile;
	}
	
	return self;
}

- (void)dealloc
{
	[mp3Data release];
	[super dealloc];
}


#pragma mark -


- (int)analyzeSilencesWithVolumeThreshold:(int)volumeThreshold durationThreshold:(double)durationThreshold
{
	progressValue = 0.0;
	decodingErrorOverflowFlag = NO;
	MADDecoderProcessor *processor = [[MADDecoderSilenceAnalyzer alloc] initWithDecoder:self startTime:0.0 endTime:AudioFileEndTime];
	[(MADDecoderSilenceAnalyzer *)processor setSilenceVolumeThreshold:volumeThreshold];
	[(MADDecoderSilenceAnalyzer *)processor setSilenceDurationThreshold:durationThreshold];
	
	int result = [processor runDecoder];
	
	audioDuration = [processor currentTime];
	
	[processor release];
	processor = nil;
	
	return result;
}

- (int)splitDecodeToFile:(NSFileHandle *)file startTime:(double)start endTime:(double)end
{
	progressValue = 0.0;
	decodingErrorOverflowFlag = NO;
	MADDecoderProcessor *processor = [[MADDecoderFileSplitter alloc] initWithDecoder:self startTime:start endTime:end];
	[(MADDecoderFileSplitter *)processor setSplitFile:file];
	int result = [processor runDecoder];
	return result;
}

- (int)playAudioStartTime:(double)start endTime:(double)end
{
	progressValue = 0.0;
	decodingErrorOverflowFlag = NO;
	MADDecoderProcessor *processor = [[MADDecoderAudioPlayer alloc] initWithDecoder:self startTime:start endTime:end];
	int result = [processor runDecoder];
	[processor release];
	processor = nil;
	
	return result;
}


#pragma mark -


- (void)setMP3Data:(NSData *)data
{
	[mp3Data autorelease];
	mp3Data = [data retain];
}

- (NSData *)mp3Data
{
	return mp3Data;
}


#pragma mark -


- (SeekIndex *)seekIndex
{
	return [audioFile seekIndex];
}

- (int)getNextOverlayedBeepSampleAtTime:(double)time
{
	return [audioFile getNextOverlayedBeepSampleAtTime:time];
}

- (void)writePCMData:(void *)dataPtr length:(unsigned long)length
{
	[audioFile writePCMData:dataPtr length:length];
}

- (BOOL)canContinueDecoding
{
	return [audioFile canContinueDecoding];
}

- (void)foundSilenceFrom:(double)start to:(double)end
{
	[audioFile foundSilenceFrom:start to:end];
}

- (void)decodingErrorOverflow
{
	if (decodingErrorOverflowFlag == NO) {
		NSLog(@"Too many decoding errors. Stopping now.");
		NSRunAlertPanel(@"Too many decoding errors",
						@"There were too many errors while decoding this file. Maybe it's corrupted or not an MP3 file at all.",
						@"OK", nil, nil);
		decodingErrorOverflowFlag = YES;
	}
}


#pragma mark -


- (void)setProgressValue:(double)value
{
	progressValue = value;
	[audioFile performSelectorOnMainThread:@selector(sendProgressChangedNotification) withObject:nil waitUntilDone:NO];
}

- (double)progressValue
{
	return progressValue;
}

- (double)audioDuration
{
	return audioDuration;
}

- (void)setAudioChannels:(int)channels
{
	audioChannels = channels;
}

- (int)audioChannels
{
	return audioChannels;
}

- (void)setAudioSamplingFrequency:(int)frequency
{
	audioSamplingFrequency = frequency;
}

- (int)audioSamplingFrequency
{
	return audioSamplingFrequency;
}


@end

