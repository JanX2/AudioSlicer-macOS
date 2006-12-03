//
//  IntervalSlider.m
//  AudioSlicer
//
//  Created by Bernd Heller on Fri Feb 27 2004.
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

#import "IntervalSlider.h"
#import "IntervalSliderCell.h"


@implementation IntervalSlider

+ (Class)cellClass
{
	return [IntervalSliderCell class];
}

- (id)initWithFrame:(NSRect)frameRect
{
	if (self = [super initWithFrame:frameRect]) {
		[self setCell:[[IntervalSliderCell alloc] init]];
		[self setIntervalStart:[self minValue]];
		[self setIntervalEnd:[self maxValue]];
		[self setLogarithmicScale:NO];
	}
	
	return self;
}

#pragma mark -

- (double)intervalStart
{
	return [[self cell] intervalStart];
}

- (void)setIntervalStart:(double)start
{
	[[self cell] setIntervalStart:start];
}

- (double)intervalEnd
{
	return [[self cell] intervalEnd];
}

- (void)setIntervalEnd:(double)end
{
	[[self cell] setIntervalEnd:end];
}

- (BOOL)logarithmicScale
{
	return [[self cell] logarithmicScale];
}

- (void)setLogarithmicScale:(BOOL)flag
{
	[[self cell] setLogarithmicScale:flag];
}

- (double)doubleValue
{
	return [self intervalEnd] - [self intervalStart];
}

@end
