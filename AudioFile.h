//
//  AudioFile.h
//  AudioSlicer
//
//  Created by Bernd Heller on Sat Feb 28 2004.
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
#import <CoreServices/CoreServices.h>
#import <AudioUnit/AudioUnit.h>
#import "AudioSegmentTree.h"
#import "PCMAudioBuffer.h"
#import "SeekIndex.h"

// if you want to play to end of file
#define AudioFileEndTime	1000000000.0

// we use 16 bit samples
#define SAMPLE_SIZE			(sizeof(unsigned char) * 2)
#define SAMPLE_MIN_VALUE	0
#define SAMPLE_MAX_VALUE	32767

extern NSString *AudioFileProgressChangedNotification;
extern NSString *AudioFileAnalyzingFinishedNotification;

@interface AudioFile : NSObject <NSCoding> {
	NSString			*filePath;
	size_t				uniqueFileID;
	double				duration;   // duration of audio in seconds
	AudioSegmentTree	*audioSegmentTree;
	SeekIndex			*seekIndex;
	
	// audio output
	AudioUnit			audioUnit;
	PCMAudioBuffer		*audioBuffer;
	float				audioVolume;
	
	// threading
	BOOL				decoderThreadRunning;
	BOOL				audioThreadRunning;
	BOOL				abortDecoding;
	BOOL				stopAudio;
	double				decoderFromTime;
	double				decoderToTime;
	
	// analysis settings
	double				silenceDurationThreshold;   // min secs a silence has to last to be recorded
	int					silenceVolumeThreshold;		// max volume level in pcm scale
	
	// attributes to generate the overlayed beep sound
	double				overlayBeepFrequency;
	double				overlayBeepVolume;  // value between 0.0 and 1.0
	double				overlayBeepStartTime;
	double				overlayBeepEndTime;
	double				overlayBeepPhase;
	
	// our delegate (not retained)
	id					delegate;
}

+ (size_t)uniqueFileIDForFile:(NSString *)path;

+ (id)audioFileWithPath:(NSString *)path;
- (id)initWithPath:(NSString *)path;

- (id)initWithCoder:(NSCoder *)coder;
- (void)encodeWithCoder:(NSCoder *)coder;

- (void)setDelegate:(id)obj;
- (id)delegate;
- (NSString *)filePath;
- (size_t)uniqueFileID;
- (void)fileHasMovedToPath:(NSString *)path;
- (BOOL)hasFileChanged;
- (AudioSegmentTree *)audioSegmentTree;

- (void)analyzeSilencesLongerThan:(double)time quieterThan:(double)volume;
- (void)abortAnalyzing;
- (BOOL)writeToFile:(NSString *)path from:(double)start to:(double)end;
- (void)startPlayingFrom:(double)start to:(double)end;
- (void)startPlayingFrom:(double)start to:(double)end overlayBeepAt:(double)beepStart beepDuration:(double)beepDuration;
- (void)stopPlaying;
- (void)resumePlaying;
- (void)abortPlaying;

- (double)audioVolume;
- (void)setAudioVolume:(double)vol;

// methods to be used by subclasses while decoding

- (void)foundSilenceFrom:(double)start to:(double)end;
- (BOOL)canContinueDecoding;
- (int)getNextOverlayedBeepSampleAtTime:(double)time;
- (void)writePCMData:(void *)dataPtr length:(size_t)length;

// methods to be implemented by subclasses

- (NSString *)fileExtension;

- (BOOL)openFile;
- (void)closeFile;

- (double)progressMinValue;
- (double)progressMaxValue;
- (double)progressValue;
- (void)sendProgressChangedNotification;

- (SeekIndex *)seekIndex;

- (BOOL)doAnalyzeAudio;
- (void)doDecodeToAudioBufferFrom:(double)start to:(double)end;
- (void)doWriteAudioToFile:(NSFileHandle *)file from:(double)start to:(double)end;

- (double)getAudioDuration;
- (int)getAudioSampleRate;
- (int)getAudioChannels;

@end

@interface AudioFile (AudioFileTag)

+ (NSDictionary *)readTagsFromFile:(NSString *)path;
+ (BOOL)writeTags:(NSDictionary *)tagDict toFile:(NSString *)path;
+ (NSArray *)genreList;

@end


@interface NSObject (AudioFileDelegate)

- (void)audioFileDidFinishAnalyzing:(AudioFile *)audioFile;
- (void)audioFileDidFinishPlaying:(AudioFile *)audioFile;

@end
