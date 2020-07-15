//
//  IntervalSliderCell.h
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

#import <Foundation/Foundation.h>


@class IntervalSlider;

@interface IntervalSliderCell : NSSliderCell {
	double			intervalStart;
	double			intervalEnd;
	
	BOOL			logarithmicScale;
	
	BOOL			trackingStartKnob;
	BOOL			trackingEndKnob;
	BOOL			trackingBar;
	CGFloat			trackingBarGrabPosition;
}

- (double)intervalStart;
- (void)setIntervalStart:(double)start;
- (double)intervalEnd;
- (void)setIntervalEnd:(double)end;
- (BOOL)logarithmicScale;
- (void)setLogarithmicScale:(BOOL)flag;

- (NSRect)startKnobRect;
- (NSRect)endKnobRect;
- (NSRect)barRect;

- (NSSize)knobSizeForControlSize;

- (double)pixelToValue:(CGFloat)pixel;
- (CGFloat)valueToPixel:(double)value;

+ (NSImage *)startKnobImageOn;
+ (NSImage *)startKnobImageOff;
+ (NSImage *)startKnobImageHighlighted;
+ (NSImage *)endKnobImageOn;
+ (NSImage *)endKnobImageOff;
+ (NSImage *)endKnobImageHighlighted;

@end
