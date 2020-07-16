//
//  MADDecoderThreaded.m
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

#import "MADDecoderThreaded.h"

#include <sys/types.h>
#include <sys/sysctl.h>

static void *runProcessorThreaded(void *processor);

@implementation MADDecoderThreaded

- (id)initWithAudioFile:(AudioFile *)anAudioFile
{
	if (self = [super initWithAudioFile:anAudioFile]) {
		numProcessors = 0;
		processors = NULL;
		processorThreads = NULL;
		progressValues = NULL;
		
		syncLock = [[NSLock alloc] init];
	}
	
	return self;
}

- (void)dealloc
{
	if (processors != NULL) {
		free(processors);
		processors = NULL;
	}
	if (processorThreads != NULL) {
		free(processorThreads);
		processorThreads = NULL;
	}
	if (progressValues != NULL) {
		free(progressValues);
		progressValues = NULL;
	}
	
	[syncLock release];
	
	[super dealloc];
}


#pragma mark -


- (int)analyzeSilencesWithVolumeThreshold:(int)volumeThreshold durationThreshold:(double)durationThreshold
{
	// set up the processors
	numProcessors = [self numProcessorCores];
	processors = (MADDecoderSilenceAnalyzer **) malloc(sizeof(MADDecoderSilenceAnalyzer *) * numProcessors);
	processorThreads = (pthread_t *) malloc(sizeof(pthread_t) * numProcessors);
	progressValues = (double *) malloc(sizeof(double) * numProcessors);
	
	// split up the work among the processors
	for (NSUInteger i = 0; i < numProcessors; i++) {
		uint32_t start = (([mp3Data length] / numProcessors) * i);
		uint32_t end = start + ([mp3Data length] / numProcessors);
		processors[i] = [[MADDecoderSilenceAnalyzer alloc] initWithDecoder:self startByteOffset:start endByteOffset:end];
		[processors[i] setSilenceVolumeThreshold:volumeThreshold];
		[processors[i] setSilenceDurationThreshold:durationThreshold];
		progressValues[i] = 0.0;
	}
	
	// run all processors
	for (NSUInteger i = 0; i < numProcessors; i++) {
		int err = pthread_create(&(processorThreads[i]), NULL, runProcessorThreaded, processors[i]);
		if (err < 0) {
			NSLog(@"failed to create thread %ld for silence processor", (long)i);
		}
	}
	
	// wait for all processors to finish
	int result = 0;
	for (NSUInteger i = 0; i < numProcessors; i++) {
		void *exitCode;
		int err = pthread_join(processorThreads[i], &exitCode);
		if (err < 0) {
			NSLog(@"failed to wait for thread %ld with silence processor", i);
		}
		
		if (result == 0) {
			if (exitCode != NULL) {
				result = (int)exitCode;
			}
		}
	}
	
	// gather total file duration from last processor
	audioDuration = [processors[numProcessors - 1] currentTime];
	
	// clean up
	for (NSUInteger i = 0; i < numProcessors; i++) {
		[processors[i] release];
	}
	free(processors);
	processors = NULL;
	free(processorThreads);
	processorThreads = NULL;
	free(progressValues);
	progressValues = NULL;
	
	return result;
}

- (void)decodingErrorOverflow
{
	[syncLock lock];
	
	// stop all threads
	[audioFile abortAnalyzing];
	[super decodingErrorOverflow];
	
	[syncLock unlock];
}


#pragma mark -


- (void)setProgressValue:(double)value
{
	// store the progress value depending on what thread submits it
	if (processorThreads != NULL) {
		for (NSUInteger i = 0; i < numProcessors; i++) {
			if (pthread_equal(pthread_self(), processorThreads[i]) != 0) {
				value -= [processors[i] decodeStartByteOffset];
				progressValues[i] = value;
				break;
			}
		}
	} else {
		// we are not running threaded, so fall back to simple progress
		progressValue = value;
	}
	
	// we must make sure to not send progress too often, so we only send it statistically every 100th time
	if (((double)rand() / RAND_MAX) < 0.01) {
		[audioFile performSelectorOnMainThread:@selector(sendProgressChangedNotification) withObject:nil waitUntilDone:NO];
	}
}

- (double)progressValue
{
	if (processorThreads != NULL) {
		double p = 0.0;
		for (NSUInteger i = 0; i < numProcessors; i++) {
			p += progressValues[i];
		}
		
		return p;
	} else {
		// we are not running threaded, so fall back to simple progress
		return progressValue;
	}
}

- (void)foundSilenceFrom:(double)start to:(double)end
{
	[syncLock lock];
	[super foundSilenceFrom:start to:end];
	[syncLock unlock];
}

- (NSUInteger)numProcessorCores
{
	NSUInteger count = 1;
	size_t len = sizeof(count);
	if (sysctlbyname("hw.ncpu", &count, &len, NULL, 0) != 0) {
		return 1;
	} else {
		return count;
	}
}


@end


#pragma mark -


void *runProcessorThreaded(void *processor)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSInteger result = [(MADDecoderProcessor *)processor runDecoder];
	
	[pool release];
	
	return (void *)result;
}

