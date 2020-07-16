//
//  MADDecoderProcessor.h
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

#include <mad/mad.h>

@class MADDecoder;

@interface MADDecoderProcessor : NSObject {
	MADDecoder				*decoder;
	
	struct mad_decoder		decoderStruct;
	
	// decoding will always happen between these time points only
	mad_timer_t				decodeStartTime;
	mad_timer_t				decodeStopTime;
	
	// variables keeping the inner state of the decoding processing
	NSUInteger				currentBufferPosition;
	mad_timer_t				currentTime;
	mad_timer_t				nextCurrentTime;
	
	// error state
	BOOL					frameResyncing;
	int						badFrameCount;
	int						maxBadFrameCount;
}

+ (double)timerToSeconds:(mad_timer_t)timer;
+ (mad_timer_t)secondsToTimer:(double)secs;

- (id)initWithDecoder:(MADDecoder *)aDecoder startTime:(double)start endTime:(double)end;
- (void)reset;
- (void)dealloc;

- (NSUInteger)currentBufferPosition;
- (double)currentTime;

- (int)runDecoder;
- (enum mad_flow)madInputForStream:(struct mad_stream *)stream;
- (enum mad_flow)madHeader:(struct mad_header const *)header;
- (enum mad_flow)madFilterForStream:(struct mad_stream const *)stream atFrame:(struct mad_frame *)frame;
- (enum mad_flow)madOutputWithHeader:(struct mad_header const *)header pcm:(struct mad_pcm *)pcm;
- (enum mad_flow)madErrorForStream:(struct mad_stream *)stream atFrame:(struct mad_frame *)frame;

@end

@interface MADDecoderFileAnalyzer : MADDecoderProcessor
@end

@interface MADDecoderFileSplitter : MADDecoderProcessor {
	NSFileHandle	*splitFile;
}
- (void)setSplitFile:(NSFileHandle *)file;
@end

@interface MADDecoderAudioPlayer : MADDecoderFileSplitter
@end

@interface MADDecoderSilenceAnalyzer : MADDecoderProcessor {
	// alternatively decoding start/end points can be specified as byte offsets
	BOOL			useDecodeStartStopByteOffsets;
	NSUInteger		decodeStartByteOffset;
	NSUInteger		decodeStopByteOffset;
	
	double			silenceDurationThreshold;   // min secs a silence has to last to be recorded
	int				silenceVolumeThreshold;		// max volume level in pcm scale
	
	double			silenceStartTime;
	BOOL			inSilence;
	
	long			seekIndexLastSecond;
}
- (id)initWithDecoder:(MADDecoder *)aDecoder startByteOffset:(NSUInteger)start endByteOffset:(NSUInteger)end;
- (void)setSilenceVolumeThreshold:(int)threshold;
- (void)setSilenceDurationThreshold:(double)threshold;
- (NSUInteger)decodeStartByteOffset;
@end

