//
//  PCMAudioBuffer.m
//  AudioSlicer
//
//  Created by Bernd Heller on Wed Feb 11 2004.
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

#import "PCMAudioBuffer.h"


@interface PCMAudioBuffer (PrivateTest)
- (void)test;
- (void)testReaderThread:(id)obj;
- (void)testWriterThread:(id)obj;
@end

@implementation PCMAudioBuffer

+ (void)test
{
	PCMAudioBuffer  *testBuffer = [(PCMAudioBuffer *)[PCMAudioBuffer alloc] initWithLength:10000];
	[testBuffer test];
	[testBuffer release];
}

- (id)initWithLength:(size_t)bufLength
{
	if (self = [super init]) {
		buffer = malloc(bufLength);
		length = bufLength;
		semaphore = [[NSLock alloc] init];
		
		[self reset];
	}
	
	return self;
}

- (void)dealloc
{
	free(buffer);
	[semaphore release];
	[super dealloc];
}

- (void)reset
{
	abortWrite = NO;
	readPtr = buffer;
	writePtr = buffer;
	bytesInBuffer = 0;
	[semaphore unlock];
}

- (BOOL)isEmpty
{
	return (bytesInBuffer == 0);
}

- (size_t)readDataInto:(void *)buf length:(size_t)len
{
	size_t		readLength = 0;
	
	if ([semaphore tryLock] == NO) {
		return 0;
	}
	
	while (len > 0 && bytesInBuffer > 0) {
		size_t   numBytes = 0;
		if (readPtr >= writePtr) {
			numBytes = MIN(((buffer + length) - readPtr), len);
		} else {
			numBytes = MIN((writePtr - readPtr), len);
		}
		memcpy(buf, readPtr, numBytes);
		bytesInBuffer -= numBytes;
		readPtr += numBytes;
		if (readPtr >= (buffer + length)) {
			readPtr = buffer + (readPtr - (buffer + length));
		}
		
		len -= numBytes;
		buf += numBytes;
		readLength += numBytes;
	}
	
	[semaphore unlock];
	
	return readLength;
}

- (void)writeData:(void *)buf length:(size_t)len
{
	while (len > 0 && !abortWrite) {
		[semaphore lock];
		
		if (bytesInBuffer < length) {
			size_t   numBytes = 0;
			if (readPtr <= writePtr) {
				numBytes = MIN(len, ((buffer + length) - writePtr));
			} else {
				numBytes = MIN(len, (readPtr - writePtr));
			}
			memcpy(writePtr, buf, numBytes);
			bytesInBuffer += numBytes;
			writePtr += numBytes;
			if (writePtr >= (buffer + length)) {
				writePtr = buffer + (writePtr - (buffer + length));
			}
			
			len -= numBytes;
			buf += numBytes;
		}
		
		[semaphore unlock];
		
		while (len > 0 && !abortWrite && bytesInBuffer == length) {
			[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
		}
	}
}

- (void)abortWrite
{
	abortWrite = YES;
}

@end

@implementation PCMAudioBuffer (PrivateTest)

- (void)test
{
	[NSThread detachNewThreadSelector:@selector(testWriterThread:) toTarget:self withObject:nil];
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
	[NSThread detachNewThreadSelector:@selector(testReaderThread:) toTarget:self withObject:nil];
}

- (void)testReaderThread:(id)obj
{
	size_t				len;
	void				*ptr = malloc(1024);
	
	while (1) {
		@autoreleasepool {
			if ((len = [self readDataInto:ptr length:1024])) {
				NSLog(@"read from buffer: (%zu) %@", len, [NSString stringWithCString:ptr length:len]);
				for (NSInteger i = 1; i < len; i++) {
					char	c1 = ((char *)ptr)[i - 1];
					char	c2 = ((char *)ptr)[i];
					NSAssert((c1 + 1 == c2) || (c1 == '8' && c2 == '1'), @"ERROR");
				}
			}
		}
	}
}

- (void)testWriterThread:(id)obj
{
	size_t				len = 8;
	void				*ptr = "12345678";
	
	@autoreleasepool {
		for (NSInteger i = 0; i < 100000; i++) {
			[self writeData:ptr length:len];
			NSLog(@"wrote to buffer: (%zu) %@", len, [NSString stringWithCString:ptr length:len]);
		}
	}
}

@end

