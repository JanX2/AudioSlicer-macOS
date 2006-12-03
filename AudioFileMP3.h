//
//  AudioFileMP3.h
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

#import <Foundation/Foundation.h>

#import "AudioFile.h"
#import "MADDecoder.h"
#import "MADDecoderThreaded.h"

@interface AudioFileMP3 : AudioFile <NSCoding> {
	// general file information
	NSFileHandle			*fileHandle;
	unsigned long			fileLength;
	void					*fileData;
	
	MADDecoder				*madDecoder;
	
	// analysis results
	int						audioChannels;
	int						audioSamplingFrequency;
	double					audioDuration;
}

@end


