//
//  MADDecoderProcessor.m
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

#import "MADDecoderProcessor.h"
#import "MADDecoder.h"

static enum mad_flow mad_input_callback(void *data, struct mad_stream *stream);
static enum mad_flow mad_header_callback(void *data, struct mad_header const *header);
static enum mad_flow mad_filter_callback(void *data, struct mad_stream const *stream, struct mad_frame *frame);
static enum mad_flow mad_output_callback(void *data, struct mad_header const *header, struct mad_pcm *pcm);
static enum mad_flow mad_error_callback(void *data, struct mad_stream *stream, struct mad_frame *frame);


@implementation MADDecoderProcessor

+ (double)timerToSeconds:(mad_timer_t)timer
{
	return mad_timer_count(timer, MAD_UNITS_MILLISECONDS) / 1000.0;
}

+ (mad_timer_t)secondsToTimer:(double)secs
{
	mad_timer_t		timer;
	unsigned long   s = (unsigned long)secs;
	unsigned long   ms = (unsigned long)((secs - s) * 1000.0);
	mad_timer_set(&timer, s, ms, 1000);
	return timer;
}


#pragma mark -


- (id)initWithDecoder:(MADDecoder *)aDecoder startTime:(double)start endTime:(double)end;
{
	if (self = [super init]) {
		decoder = [aDecoder retain];
		
		decodeStartTime = [MADDecoderProcessor secondsToTimer:start];
		decodeStopTime = [MADDecoderProcessor secondsToTimer:end];
		
		[self reset];
	}
	
	return self;
}

- (void)reset
{
	currentBufferPosition = 0;
	
	currentTime = mad_timer_zero;
	nextCurrentTime = mad_timer_zero;
	
	badFrameCount = 0;
	maxBadFrameCount = 500;
	frameResyncing = NO;
}

- (void)dealloc
{
	[decoder release];
	[super dealloc];
}

- (uint32_t)currentBufferPosition
{
	return currentBufferPosition;
}

- (double)currentTime
{
	return [MADDecoderProcessor timerToSeconds:currentTime];
}

- (int)runDecoder
{
	int result = 0;
	
	mad_decoder_init(&decoderStruct, self,
					 mad_input_callback, mad_header_callback,
					 mad_filter_callback, mad_output_callback,
					 mad_error_callback, 0 /* message */);
	result = mad_decoder_run(&decoderStruct, MAD_DECODER_MODE_SYNC);
	mad_decoder_finish(&decoderStruct);
	
	return result;
}

- (enum mad_flow)madInputForStream:(struct mad_stream *)stream
{
	return MAD_FLOW_CONTINUE;
}

- (enum mad_flow)madHeader:(struct mad_header const *)header
{
	struct mad_stream *stream = &(decoderStruct.sync->stream);
	currentBufferPosition = stream->this_frame - (uint8_t *)[[decoder mp3Data] bytes];
	[decoder setProgressValue:(double)currentBufferPosition];
	
	currentTime = nextCurrentTime;
	mad_timer_add(&nextCurrentTime, header->duration);
	
	[decoder setAudioChannels:MAD_NCHANNELS(header)];
	[decoder setAudioSamplingFrequency:header->samplerate];
	
	return MAD_FLOW_CONTINUE;
}

- (enum mad_flow)madFilterForStream:(struct mad_stream const *)stream atFrame:(struct mad_frame *)frame
{
	return MAD_FLOW_CONTINUE;
}

- (enum mad_flow)madOutputWithHeader:(struct mad_header const *)header pcm:(struct mad_pcm *)pcm
{
	return MAD_FLOW_CONTINUE;
}

- (enum mad_flow)madErrorForStream:(struct mad_stream *)stream atFrame:(struct mad_frame *)frame
{
	if (badFrameCount > maxBadFrameCount) {
		[decoder decodingErrorOverflow];
		return MAD_FLOW_BREAK;
	}
	
	switch (stream->error) {
		case MAD_ERROR_LOSTSYNC:
			if (!strncmp((const char *) stream->this_frame, "ID3", 3)) {
				const uint8_t *id3SizeFields = (stream->this_frame + 6);
				uint32_t id3TagSize = 10; // ID3 tag header size
				id3TagSize += (id3SizeFields[0] << (3 * 7));
				id3TagSize += (id3SizeFields[1] << (2 * 7));
				id3TagSize += (id3SizeFields[2] << (1 * 7));
				id3TagSize += (id3SizeFields[3] << (0 * 7));
				NSLog(@"skipping ID3v2 frame of size %lu", id3TagSize);
				mad_stream_skip(stream, id3TagSize);
				return MAD_FLOW_CONTINUE;   // continue decoding normally
			} else if (!strncmp((const char *) stream->this_frame, "TAG", 3)) {
				NSLog(@"skipping ID3v1 frame");
				mad_stream_skip(stream, 128);
				return MAD_FLOW_CONTINUE;   // continue decoding normally
			} else {
				badFrameCount++;
				return MAD_FLOW_IGNORE;		// skip the rest of the current frame
			}
			
		case MAD_ERROR_BADCRC:
			NSLog(@"bad crc error 0x%04x (%s) at byte offset %u",
				  stream->error, mad_stream_errorstr(stream), stream->this_frame - (uint8_t *)[[decoder mp3Data] bytes]);
			badFrameCount++;
			return MAD_FLOW_IGNORE;      // skip the rest of the current frame
			
		case MAD_ERROR_BADDATAPTR:
			if (!frameResyncing) {
				NSLog(@"frame resyncing error 0x%04x (%s) at byte offset %u",
					  stream->error, mad_stream_errorstr(stream), stream->this_frame - (uint8_t *)[[decoder mp3Data] bytes]);
				badFrameCount++;
			}
			return MAD_FLOW_CONTINUE;    // continue decoding normally
			
		default:
			NSLog(@"decoding error 0x%04x (%s) at byte offset %u",
				  stream->error, mad_stream_errorstr(stream), stream->this_frame - (uint8_t *)[[decoder mp3Data] bytes]);
			badFrameCount++;
			return MAD_FLOW_CONTINUE;    // continue decoding normally
    }
}

@end


#pragma mark -


@implementation MADDecoderFileAnalyzer

- (enum mad_flow)madInputForStream:(struct mad_stream *)stream
{
	if (currentBufferPosition > 0) {
		return MAD_FLOW_STOP;
	}
	
	mad_stream_buffer(stream, [[decoder mp3Data] bytes], [[decoder mp3Data] length]);
	mad_stream_options(stream, MAD_OPTION_HALFSAMPLERATE);
	return MAD_FLOW_CONTINUE;
}

- (enum mad_flow)madHeader:(struct mad_header const *)header
{
	enum mad_flow result = [super madHeader:header];
	if (result != MAD_FLOW_CONTINUE) {
		return result;
	}
	
	return MAD_FLOW_IGNORE;
}

@end


#pragma mark -


@implementation MADDecoderFileSplitter

- (void)reset
{
	[super reset];
	splitFile = nil;
}

- (void)dealloc
{
	[splitFile release];
	[super dealloc];
}

- (void)setSplitFile:(NSFileHandle *)file
{
	splitFile = [file retain];
}

- (enum mad_flow)madInputForStream:(struct mad_stream *)stream
{
	if (currentBufferPosition > 0) {
		return MAD_FLOW_STOP;
	}
	
	SeekIndexEntry entry = [[decoder seekIndex] entryForTimeIndex:[MADDecoderProcessor timerToSeconds:decodeStartTime]];
	
	mad_stream_buffer(stream, [[decoder mp3Data] bytes] + entry.byteOffset, [[decoder mp3Data] length] - entry.byteOffset);
	nextCurrentTime = [MADDecoderProcessor secondsToTimer:entry.time];
	currentBufferPosition = entry.byteOffset;
	
	frameResyncing = YES;
	
	return MAD_FLOW_CONTINUE;
}

- (enum mad_flow)madHeader:(struct mad_header const *)header
{
	enum mad_flow result = [super madHeader:header];
	if (result != MAD_FLOW_CONTINUE) {
		return result;
	}
	
	if (mad_timer_compare(currentTime, decodeStartTime) < 0) {
		// we are before start time
		return MAD_FLOW_IGNORE;
	} else {
		// we are after start time
		if (mad_timer_compare(currentTime, decodeStopTime) <= 0) {
			// we are in play section
			return MAD_FLOW_CONTINUE;
		} else {
			// we are after play section
			NSLog(@"stopping at %.2f", [MADDecoderProcessor timerToSeconds:currentTime]);
			return MAD_FLOW_STOP;
		}
	}
}

- (enum mad_flow)madFilterForStream:(struct mad_stream const *)stream atFrame:(struct mad_frame *)frame
{
	frameResyncing = NO;
	
	if (stream->next_frame) {
		[splitFile writeData:[NSData dataWithBytes:stream->this_frame length:(stream->next_frame - stream->this_frame)]];
	} else {
		[splitFile writeData:[NSData dataWithBytes:stream->this_frame length:(stream->bufend - stream->this_frame)]];
	}
	
	return MAD_FLOW_IGNORE;
}

@end


#pragma mark -


@implementation MADDecoderAudioPlayer

- (enum mad_flow)madFilterForStream:(struct mad_stream const *)stream atFrame:(struct mad_frame *)frame
{
	frameResyncing = NO;
	return MAD_FLOW_CONTINUE;
}

- (enum mad_flow)madOutputWithHeader:(struct mad_header const *)header pcm:(struct mad_pcm *)pcm
{
	unsigned int		nsamples = pcm->length;
	mad_fixed_t const   *left_ch = pcm->samples[0];
	mad_fixed_t const   *right_ch = pcm->samples[1];
	size_t				pcmBufLength = nsamples * MAD_NCHANNELS(header) * SAMPLE_SIZE;
	unsigned char		*pcmBuf = malloc(pcmBufLength);
	unsigned char		*bufPtr = pcmBuf;
	int					sample;
	
	while (nsamples--) {
		int		overlayBeepSample = [decoder getNextOverlayedBeepSampleAtTime:[MADDecoderProcessor timerToSeconds:currentTime]];
		sample = ((*left_ch++) >> (MAD_F_FRACBITS + 1 - 16)) + overlayBeepSample;
		*bufPtr++ = (sample >> 8) & 0xff;
		*bufPtr++ = sample & 0xff;
		if (MAD_NCHANNELS(header) == 2) {
			sample = ((*right_ch++) >> (MAD_F_FRACBITS + 1 - 16)) + overlayBeepSample;
			*bufPtr++ = (sample >> 8) & 0xff;
			*bufPtr++ = sample & 0xff;
		}
	}
	[decoder writePCMData:pcmBuf length:pcmBufLength];
	free(pcmBuf);
	
	if ([decoder canContinueDecoding] == NO) {
		NSLog(@"aborting in deocderthread");
		return MAD_FLOW_STOP;
	}
	
	return MAD_FLOW_CONTINUE;
}

@end


#pragma mark -


@implementation MADDecoderSilenceAnalyzer

- (id)initWithDecoder:(MADDecoder *)aDecoder startByteOffset:(uint32_t)start endByteOffset:(uint32_t)end
{
	if (self = [super initWithDecoder:aDecoder startTime:0.0 endTime:0.0]) {
		useDecodeStartStopByteOffsets = YES;
		decodeStartByteOffset = start;
		decodeStopByteOffset = end;
		
		[self reset];
	}
	
	return self;
}

- (void)reset
{
	[super reset];
	
	silenceStartTime = 0.0;
	inSilence = NO;
	seekIndexLastSecond = -1;
}

- (void)dealloc
{
	[super dealloc];
}

- (void)setSilenceVolumeThreshold:(NSInteger)threshold
{
	silenceVolumeThreshold = threshold;
}

- (void)setSilenceDurationThreshold:(double)threshold
{
	silenceDurationThreshold = threshold;
}

- (uint32_t)decodeStartByteOffset
{
	return decodeStartByteOffset;
}

- (enum mad_flow)madInputForStream:(struct mad_stream *)stream
{
	if (currentBufferPosition > 0) {
		return MAD_FLOW_STOP;
	}
	
	mad_stream_buffer(stream, [[decoder mp3Data] bytes], [[decoder mp3Data] length]);
	mad_stream_options(stream, MAD_OPTION_HALFSAMPLERATE);
	
	return MAD_FLOW_CONTINUE;
}

- (enum mad_flow)madHeader:(struct mad_header const *)header
{
	enum mad_flow result = [super madHeader:header];
	if (result != MAD_FLOW_CONTINUE) {
		return result;
	}
	
	if ((!useDecodeStartStopByteOffsets && (mad_timer_compare(currentTime, decodeStartTime) < 0)) ||
		(useDecodeStartStopByteOffsets && (currentBufferPosition < decodeStartByteOffset))) {
		// we are before start time
		return MAD_FLOW_IGNORE;
	} else {
		// we are after start time
		if ((!useDecodeStartStopByteOffsets && (mad_timer_compare(currentTime, decodeStopTime) <= 0)) ||
			(useDecodeStartStopByteOffsets && (currentBufferPosition < decodeStopByteOffset))) {
			// we are in play section
			return MAD_FLOW_CONTINUE;
		} else {
			// we are after play section
			return MAD_FLOW_STOP;
		}
	}
}

- (enum mad_flow)madFilterForStream:(struct mad_stream const *)stream atFrame:(struct mad_frame *)frame
{
	if ([decoder canContinueDecoding] == NO) {
		return MAD_FLOW_BREAK;
	}
	
	//NSLog(@"thread %u: processsing buffer position %u", [[NSThread currentThread] hash], currentBufferPosition);
	
	// one pointer into the buffer every 30 seconds
	if ((currentTime.seconds - seekIndexLastSecond) > 30 && seekIndexLastSecond < currentTime.seconds) {
		//NSLog(@"offset %lu at time %.3f", (stream->this_frame - (uint8_t *)[[decoder mp3Data] bytes]), [MADDecoderProcessor timerToSeconds:currentTime]);
		[[decoder seekIndex] addOffset:(stream->this_frame - (uint8_t *)[[decoder mp3Data] bytes])
						  forTimeIndex:[MADDecoderProcessor timerToSeconds:currentTime]];
		seekIndexLastSecond = currentTime.seconds;
	}
	
	unsigned long avg = 0;
	mad_fixed_t *samples = (mad_fixed_t *)(frame->sbsample);
	int nsamples = MAD_NCHANNELS(&frame->header) * MAD_NSBSAMPLES(&frame->header) * 32;
	for (int i = 0; i < nsamples; i++) {
		avg += abs((int)(samples[i] >> (MAD_F_FRACBITS + 1 - 16)));
	}
	avg /= (nsamples / 32);
	
	// check silence hints
	//NSLog(@"check hints: %.2f = %d - ins=%d", [MADDecoder timerToSeconds:currentTime], avg, inSilence);
	if (inSilence && avg > silenceVolumeThreshold) {
		// silence ended
		inSilence = NO;
		if ([MADDecoderProcessor timerToSeconds:currentTime] - silenceStartTime > silenceDurationThreshold) {
			//NSLog(@"adding silence %.2f - %.2f", silenceStartTime, [MADDecoderProcessor timerToSeconds:currentTime]);
			[decoder foundSilenceFrom:silenceStartTime to:[MADDecoderProcessor timerToSeconds:currentTime]];
		}
	} else if (!inSilence && avg < silenceVolumeThreshold) {
		// silence started
		inSilence = YES;
		silenceStartTime = [MADDecoderProcessor timerToSeconds:currentTime];
	}
	
	return MAD_FLOW_IGNORE;
}

- (enum mad_flow)madErrorForStream:(struct mad_stream *)stream atFrame:(struct mad_frame *)frame
{
	switch (stream->error) {
		case MAD_ERROR_BADDATAPTR:
		case MAD_ERROR_BADHUFFDATA:
			// this type of error can happen often, because we are skimming the file
			return MAD_FLOW_CONTINUE;
			
		default:
			return [super madErrorForStream:stream atFrame:frame];
    }
}

@end


#pragma mark -


static enum mad_flow
mad_input_callback(void *data, struct mad_stream *stream)
{
	return [(MADDecoderProcessor *)data madInputForStream:stream];
}

static enum mad_flow
mad_header_callback(void *data, struct mad_header const *header)
{
	return [(MADDecoderProcessor *)data madHeader:header];
}

static enum mad_flow
mad_filter_callback(void *data, struct mad_stream const *stream, struct mad_frame *frame)
{
	return [(MADDecoderProcessor *)data madFilterForStream:stream atFrame:frame];
}

static enum mad_flow
mad_output_callback(void *data, struct mad_header const *header, struct mad_pcm *pcm)
{
	return [(MADDecoderProcessor *)data madOutputWithHeader:header pcm:pcm];
}

static enum mad_flow
mad_error_callback(void *data, struct mad_stream *stream, struct mad_frame *frame)
{
	return [(MADDecoderProcessor *)data madErrorForStream:stream atFrame:frame];
}

