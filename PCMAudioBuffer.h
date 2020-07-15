//
//  PCMAudioBuffer.h
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

#import <Foundation/Foundation.h>


@interface PCMAudioBuffer : NSObject {
	void				*buffer;
	size_t				length;
	size_t				bytesInBuffer;
	
	void				*readPtr;
	void				*writePtr;
	NSLock				*semaphore;
	
	BOOL				abortWrite;
}

+ (void)test;

- (id)initWithLength:(size_t)bufLength;
- (void)reset;
- (BOOL)isEmpty;

- (size_t)readDataInto:(void *)buf length:(size_t)len;
- (void)writeData:(void *)buf length:(size_t)len;
- (void)abortWrite;

@end
