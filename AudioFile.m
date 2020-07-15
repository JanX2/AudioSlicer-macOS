//
//  AudioFile.m
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

#import "AudioFile.h"
#import "AudioFileMP3.h"
#import "ProgressPanel.h"


NSString	*AudioFileProgressChangedNotification = @"AudioFileProgressChangedNotification";
NSString	*AudioFileAnalyzingFinishedNotification = @"AudioFileAnalyzingFinishedNotification";


@interface AudioFile (Private)

- (void)decoderThread:(id)obj;
- (void)audioThread:(id)obj;
- (void)audioThreadFinished:(NSNotification *)notification;
- (void)analyzerThread:(id)obj;
- (void)analyzerThreadFinished:(NSNotification *)notification;

- (void)openAudioUnitForChannels:(int)channels sampleRate:(float)speed;
- (void)closeAudioUnit;
- (OSStatus)renderAudioWithFlags:(AudioUnitRenderActionFlags)renderFlags buffer:(AudioBuffer *)ioData numFrames:(UInt32)numFrames;
static OSStatus coreAudioRenderProc(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData);

@end

#pragma mark -

@implementation AudioFile

+ (size_t)uniqueFileIDForFile:(NSString *)path
{
	return [[[[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:NO] objectForKey:NSFileSize] unsignedLongValue];
}

#pragma mark -

+ (id)audioFileWithPath:(NSString *)path
{
	if ([[[path pathExtension] lowercaseString] isEqualToString:@"mp3"]) {
		return [[[AudioFileMP3 alloc] initWithPath:path] autorelease];
	}
	
	[NSException raise:NSGenericException format:@"unsupported filetype"];
	return nil;
}

- (id)initWithPath:(NSString *)path
{
	if (self = [super init]) {
		filePath = [path copy];
		uniqueFileID = [AudioFile uniqueFileIDForFile:filePath];
		
		delegate = nil;
		audioBuffer = [(PCMAudioBuffer *)[PCMAudioBuffer alloc] initWithLength:(SAMPLE_SIZE * 48000)];
		audioVolume = 1.0;
		overlayBeepFrequency = 2000.0;
		overlayBeepVolume = 0.4;
		
		[self openFile];
	}
	
	return self;
}

- (void)dealloc
{
	[audioBuffer release];
	
	[self closeFile];
	[filePath release];
	
	[audioSegmentTree release];
	
	[super dealloc];
}

#pragma mark -

- (id)initWithCoder:(NSCoder *)coder
{
	if ([coder allowsKeyedCoding]) {
		if (self = [self initWithPath:[coder decodeObjectForKey:@"filePath"]]) {
			duration = [coder decodeDoubleForKey:@"duration"];
			uniqueFileID = [coder decodeInt64ForKey:@"uniqueFileID"];
			audioVolume = [coder decodeFloatForKey:@"audioVolume"];
			
			if ([coder containsValueForKey:@"seekIndexVersion"] && [coder decodeIntForKey:@"seekIndexVersion"] == 1) {
				seekIndex = [[coder decodeObjectForKey:@"seekIndex"] retain];
			} else {
				// this is the old binary structure, must convert from big endian to host endianess
				uint32_t seekIndexSize = [coder decodeIntForKey:@"seekIndexSize"];
				seekIndexSize = CFSwapInt32BigToHost(seekIndexSize);
				
				NSUInteger bufSize;
				const uint8_t *buf = [coder decodeBytesForKey:@"seekIndex" returnedLength:&bufSize];
				typedef struct {
					mad_timer_t			time;
					size_t				byteOffset;
				} oldSeekIndexEntry;
				oldSeekIndexEntry *ptr = (oldSeekIndexEntry *)buf;
				
				// read out the old format and convert to the new one
				seekIndex = [[SeekIndex alloc] initWithCapacity:seekIndexSize];
				for (uint32_t i = 0; i < seekIndexSize; i++) {
					mad_timer_t time;
					time.seconds = CFSwapInt32BigToHost(ptr[i].time.seconds);
					time.fraction = CFSwapInt32BigToHost(ptr[i].time.fraction);
					uint32_t byteOffset = CFSwapInt32BigToHost(ptr[i].byteOffset);
					[seekIndex addOffset:byteOffset
							forTimeIndex:[MADDecoderProcessor timerToSeconds:time]];
				}
				
				// this is the old code that did the encoding/decoding of the binary format
				/*			unsigned int	bufSize;
				const uint8_t   *buf;
				seekIndexSize = [coder decodeIntForKey:@"seekIndexSize"];
				seekIndex = realloc(seekIndex, sizeof(SeekIndexEntry) * seekIndexSize);
				buf = [coder decodeBytesForKey:@"seekIndex" returnedLength:&bufSize];
				memcpy(seekIndex, buf, bufSize);*/
				/*        [coder encodeBytes:(const uint8_t *)seekIndex length:(sizeof(SeekIndexEntry) * seekIndexSize) forKey:@"seekIndex"];
				[coder encodeInt:seekIndexSize forKey:@"seekIndexSize"];*/
			}
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
        [coder encodeObject:filePath forKey:@"filePath"];
        [coder encodeInt64:uniqueFileID forKey:@"uniqueFileID"];
        [coder encodeDouble:duration forKey:@"duration"];
        [coder encodeFloat:audioVolume forKey:@"audioVolume"];
		
		// save new seekIndex version
        [coder encodeInt:1 forKey:@"seekIndexVersion"];
        [coder encodeObject:seekIndex forKey:@"seekIndex"];
	} else {
        [NSException raise:NSInvalidArchiveOperationException format:@"Only supports NSKeyedArchiver coders"];
	}
}

#pragma mark -

- (void)setDelegate:(id)obj
{
	delegate = obj;
}

- (id)delegate
{
	return delegate;
}

- (NSString *)filePath
{
	return filePath;
}

- (size_t)uniqueFileID
{
	return uniqueFileID;
}

- (void)fileHasMovedToPath:(NSString *)path
{
	[filePath release];
	filePath = [path copy];
	
	[self closeFile];
	[self openFile];
}

- (BOOL)hasFileChanged
{
	return ([AudioFile uniqueFileIDForFile:filePath] != uniqueFileID);
}

- (AudioSegmentTree *)audioSegmentTree
{
	return audioSegmentTree;
}

#pragma mark -

- (void)analyzeSilencesLongerThan:(double)time quieterThan:(double)volume
{
	silenceDurationThreshold = time;
	silenceVolumeThreshold = volume * SAMPLE_MAX_VALUE;
	
	decoderThreadRunning = YES;
	[NSThread detachNewThreadSelector:@selector(analyzerThread:) toTarget:self withObject:nil];
}

- (void)abortAnalyzing
{
	abortDecoding = YES;
}

- (BOOL)writeToFile:(NSString *)path from:(double)start to:(double)end
{
	if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
		[[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
	}
	
	NSFileHandle	*file = [[NSFileHandle fileHandleForWritingAtPath:path] retain];
	if (file) {
		[file truncateFileAtOffset:0];
		
		if (start < 0.0) {
			start = 0.0;
		}
		if (end > duration) {
			end = duration;
		}
		[self doWriteAudioToFile:file from:start to:end];
		NSLog(@"wrote slice %.1f-%.1f to %@", start, end, path);
		
		[file closeFile];
		[file release];
		
		return YES;
	}
	
	return NO;
}

- (void)startPlayingFrom:(double)start to:(double)end
{
	[self startPlayingFrom:start to:end overlayBeepAt:0.0 beepDuration:0.0];
}

- (void)startPlayingFrom:(double)start to:(double)end overlayBeepAt:(double)beepStart beepDuration:(double)beepDuration
{
	[self abortPlaying];
	
	[audioBuffer reset];
	
	stopAudio = NO;
	abortDecoding = NO;
	audioThreadRunning = NO;
	decoderThreadRunning = NO;
	
	overlayBeepStartTime = beepStart;
	overlayBeepEndTime = beepStart + beepDuration;
	overlayBeepPhase = 0.0;
	
	if (start < 0.0) {
		start = 0.0;
	}
	if (end > duration) {
		end = duration;
	}
	decoderFromTime = start;
	decoderToTime = end;
	
	decoderThreadRunning = YES;
	[NSThread detachNewThreadSelector:@selector(decoderThread:) toTarget:self withObject:nil];
	while ([self getAudioChannels] == 0 || [self getAudioSampleRate] == 0) {
		[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	}
	
	audioThreadRunning = YES;
	[self openAudioUnitForChannels:[self getAudioChannels] sampleRate:[self getAudioSampleRate]];
	[self setAudioVolume:audioVolume];
	AudioOutputUnitStart(audioUnit);
	[NSThread detachNewThreadSelector:@selector(audioThread:) toTarget:self withObject:[NSRunLoop currentRunLoop]];
}

- (void)stopPlaying
{
	stopAudio = YES;
	AudioOutputUnitStop(audioUnit);
}

- (void)resumePlaying
{
	stopAudio = NO;
	AudioOutputUnitStart(audioUnit);
}

- (void)abortPlaying
{
	while (audioThreadRunning || decoderThreadRunning) {
		abortDecoding = YES;
		[audioBuffer abortWrite];
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
	}
}

- (double)audioVolume
{
	return audioVolume;
}

- (void)setAudioVolume:(double)vol
{
	audioVolume = vol;
	AudioUnitSetParameter(audioUnit, kHALOutputParam_Volume, kAudioUnitScope_Global, 0, audioVolume, 0);
}

#pragma mark -

- (void)foundSilenceFrom:(double)start to:(double)end
{
	// don't allow a silence at the beginning to be treated as such
	if (start > 0.0) {
		[audioSegmentTree addSilenceSegmentFrom:start to:end];
	}
}

- (BOOL)canContinueDecoding
{
	return (abortDecoding == NO);
}

- (int)getNextOverlayedBeepSampleAtTime:(double)time
{
	if (time > overlayBeepStartTime && time < overlayBeepEndTime) {
		overlayBeepPhase += overlayBeepFrequency / [self getAudioSampleRate];
		if (overlayBeepPhase > 1.0) {
			overlayBeepPhase -= 1.0;
		}
		return (int)((overlayBeepVolume * SAMPLE_MAX_VALUE) * sin(overlayBeepPhase * M_PI * 2.0));
	}
	
	return 0;
}

- (void)writePCMData:(void *)dataPtr length:(size_t)length
{
	[audioBuffer writeData:dataPtr length:length];
}

#pragma mark -

- (NSString *)fileExtension
{
	// to be implemented in subclass
	return @"";
}

- (BOOL)openFile
{
	// to be implemented in subclass
	return NO;
}

- (void)closeFile
{
	// to be implemented in subclass
}


- (double)progressMinValue
{
	// to be implemented in subclass
	return -1.0;
}

- (double)progressMaxValue
{
	// to be implemented in subclass
	return -1.0;
}

- (double)progressValue
{
	// to be implemented in subclass
	return -1.0;
}

- (void)sendProgressChangedNotification
{
	[[NSNotificationCenter defaultCenter] postNotificationName:AudioFileProgressChangedNotification object:self];
}

- (SeekIndex *)seekIndex
{
	return seekIndex;
}


- (BOOL)doAnalyzeAudio
{
	// to be implemented in subclass
	return NO;
}

- (void)doDecodeToAudioBufferFrom:(double)start to:(double)end
{
	// to be implemented in subclass
}

- (void)doWriteAudioToFile:(NSFileHandle *)file from:(double)start to:(double)end
{
	// to be implemented in subclass
}


- (double)getAudioDuration
{
	// to be implemented in subclass
	return 0.0;
}

- (int)getAudioSampleRate
{
	// to be implemented in subclass
	return 0.0;
}

- (int)getAudioChannels
{
	// to be implemented in subclass
	return 0;
}

@end

#pragma mark -

@implementation AudioFile (AudioFileTag)

+ (NSDictionary *)readTagsFromFile:(NSString *)path
{
	if ([[[path pathExtension] lowercaseString] isEqualToString:@"mp3"]) {
		return [AudioFileMP3 readTagsFromFile:path];
	}
	
	[NSException raise:NSGenericException format:@"unsupported filetype"];
	return nil;
}

+ (BOOL)writeTags:(NSDictionary *)tagDict toFile:(NSString *)path
{
	if ([[[path pathExtension] lowercaseString] isEqualToString:@"mp3"]) {
		return [AudioFileMP3 writeTags:tagDict toFile:path];
	}
	
	[NSException raise:NSGenericException format:@"unsupported filetype"];
	return NO;
}

+ (NSArray *)genreList
{
	return nil;
}

@end

#pragma mark -

@implementation AudioFile (Private)

- (void)decoderThread:(id)obj
{
	NSLog(@"decoderThread started");
	[self release];
	
	NSAutoreleasePool   *pool = [[NSAutoreleasePool alloc] init];
	[self doDecodeToAudioBufferFrom:decoderFromTime to:decoderToTime];
    [pool release];
	
	[self retain];
	decoderThreadRunning = NO;
	NSLog(@"decoderThread ended");
}

- (void)audioThread:(id)obj
{
	NSLog(@"audioThread started");
	NSAutoreleasePool   *pool = [[NSAutoreleasePool alloc] init];
	[self release];
	
	while (decoderThreadRunning || ![audioBuffer isEmpty]) {
		if (abortDecoding) {
			NSLog(@"aborting in audiothread");
			break;
		}
		[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
	}
	[self closeAudioUnit];
	
	[self retain];
	
	[self performSelectorOnMainThread:@selector(audioThreadFinished:) withObject:nil waitUntilDone:NO];
	
	[pool release];
	NSLog(@"audioThread ended");
}

- (void)audioThreadFinished:(NSNotification *)notification
{
	[delegate audioFileDidFinishPlaying:self];
	audioThreadRunning = NO;
}

- (void)analyzerThread:(id)obj
{
	NSAutoreleasePool   *pool = [[NSAutoreleasePool alloc] init];
	
	audioSegmentTree = [[AudioSegmentTree alloc] init];
	seekIndex = [[SeekIndex alloc] init];
	if ([self doAnalyzeAudio]) {
		duration = [self getAudioDuration];
		[audioSegmentTree setDuration:duration];
		[audioSegmentTree createAudioSegmentsBetweenSilences];
		
		[[audioSegmentTree sliceAtIndex:0] setAttributesFromTags:[AudioFile readTagsFromFile:filePath]];
		if ([[audioSegmentTree sliceAtIndex:0] title] == nil) {
			[[audioSegmentTree sliceAtIndex:0] setTitle:[[filePath lastPathComponent] stringByDeletingPathExtension]];
		}
	} else {
		[audioSegmentTree release];
		audioSegmentTree = nil;
		[seekIndex release];
		seekIndex = nil;
	}
	
	[self performSelectorOnMainThread:@selector(analyzerThreadFinished:) withObject:nil waitUntilDone:NO];
	
    [pool release];
}

- (void)analyzerThreadFinished:(NSNotification *)notification
{
	[delegate audioFileDidFinishAnalyzing:self];
	decoderThreadRunning = NO;
	[[NSNotificationCenter defaultCenter] postNotificationName:AudioFileAnalyzingFinishedNotification object:self];
}

#pragma mark -

- (void)openAudioUnitForChannels:(int)channels sampleRate:(float)speed
{
	AudioStreamBasicDescription		format;
	ComponentDescription			desc;
	Component						comp;
	AURenderCallbackStruct			callback;
	
	desc.componentType			= kAudioUnitType_Output;
	desc.componentSubType		= kAudioUnitSubType_DefaultOutput;
	desc.componentManufacturer  = kAudioUnitManufacturer_Apple;
	desc.componentFlags			= 0;
	desc.componentFlagsMask		= 0;
	
	comp = FindNextComponent(0, &desc);
	if (comp == NULL) {
		NSLog(@"FindNextComponent() failed");
		return;
	}
	
	if (OpenAComponent(comp, &audioUnit) != noErr) {
		NSLog(@"OpenAComponent() failed");
		return;
	}
	
	if (AudioUnitInitialize(audioUnit) != 0) {
		NSLog(@"AudioUnitInitialize() failed");
		CloseComponent(audioUnit);
		return;
	}
	
	callback.inputProc			= coreAudioRenderProc;
	callback.inputProcRefCon	= self;
	
	if (AudioUnitSetProperty(audioUnit, kAudioUnitProperty_SetRenderCallback,
							 kAudioUnitScope_Input, 0,
							 &callback, sizeof(callback)) != 0) {
		NSLog(@"AudioUnitSetProperty(kAudioUnitProperty_SetRenderCallback) failed");
		AudioUnitUninitialize(audioUnit);
		CloseComponent(audioUnit);
		return;
	}
	
	format.mSampleRate			= speed;
	format.mFormatID			= kAudioFormatLinearPCM;
	format.mFormatFlags			= kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsBigEndian | kLinearPCMFormatFlagIsPacked;
	format.mBytesPerPacket		= channels * 2;
	format.mFramesPerPacket		= 1;
	format.mBytesPerFrame		= format.mBytesPerPacket;
	format.mChannelsPerFrame	= channels;
	format.mBitsPerChannel		= 16;
	
	if (AudioUnitSetProperty(audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &format, sizeof(format)) != 0) {
		NSLog(@"AudioUnitSetProperty(kAudioUnitProperty_StreamFormat) failed");
		return;
	}
}

- (void)closeAudioUnit
{
	AudioOutputUnitStop(audioUnit);
	
	if (AudioUnitUninitialize(audioUnit) != 0) {
		NSLog(@"AudioUnitUninitialize() failed");
	}
	
	if (CloseComponent(audioUnit) != noErr) {
		NSLog(@"CloseComponent() failed");
	}
}

- (OSStatus)renderAudioWithFlags:(AudioUnitRenderActionFlags)renderFlags buffer:(AudioBuffer *)ioData numFrames:(UInt32)numFrames
{
	if (stopAudio || abortDecoding) {
		// just empty buffer, but return silence
		[audioBuffer readDataInto:ioData->mData length:ioData->mDataByteSize];
		bzero(ioData->mData, ioData->mDataByteSize);
	} else {
		size_t   len = [audioBuffer readDataInto:ioData->mData length:ioData->mDataByteSize];
		if (len < ioData->mDataByteSize) {
			bzero(ioData->mData + len, ioData->mDataByteSize - len);
		}
	}
	
	return 0;
}

static OSStatus
coreAudioRenderProc(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData)
{
	return [(AudioFile *)inRefCon renderAudioWithFlags:*ioActionFlags buffer:&ioData->mBuffers[0] numFrames:inNumberFrames];
}

@end

