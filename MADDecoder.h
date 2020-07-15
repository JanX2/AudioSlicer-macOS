//
//  MADDecoder.h
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

#import <Cocoa/Cocoa.h>

#import "AudioFile.h"

@interface MADDecoder : NSObject {
	AudioFile				*audioFile;
	NSData					*mp3Data;
	
	BOOL					decodingErrorOverflowFlag;
	double					progressValue;
	
	// meta data gathered during processing
	int						audioChannels;
	int						audioSamplingFrequency;
	double					audioDuration;
}

- (id)initWithAudioFile:(AudioFile *)anAudioFile;
- (void)dealloc;

- (int)analyzeSilencesWithVolumeThreshold:(int)volumeThreshold durationThreshold:(double)durationThreshold;
- (int)splitDecodeToFile:(NSFileHandle *)file startTime:(double)start endTime:(double)end;
- (int)playAudioStartTime:(double)start endTime:(double)end;

- (void)setMP3Data:(NSData *)data;
- (NSData *)mp3Data;

- (SeekIndex *)seekIndex;
- (int)getNextOverlayedBeepSampleAtTime:(double)time;
- (void)writePCMData:(void *)dataPtr length:(size_t)length;
- (BOOL)canContinueDecoding;
- (void)foundSilenceFrom:(double)start to:(double)end;
- (void)decodingErrorOverflow;

- (void)setProgressValue:(double)value;
- (double)progressValue;
- (double)audioDuration;

- (void)setAudioChannels:(int)channels;
- (int)audioChannels;
- (void)setAudioSamplingFrequency:(int)frequency;
- (int)audioSamplingFrequency;

@end


