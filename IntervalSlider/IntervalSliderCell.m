//
//  IntervalSliderCell.m
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

#import "IntervalSliderCell.h"
#import "IntervalSlider.h"


@implementation IntervalSliderCell

- (id)init
{
	if (self = [super init]) {
		logarithmicScale = NO;
		intervalStart = [self minValue];
		intervalEnd = [self maxValue];
	}
	
	return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
    [super initWithCoder:coder];
	
    if ([coder allowsKeyedCoding]) {
        intervalStart = [coder decodeDoubleForKey:@"intervalStart"];
        intervalEnd = [coder decodeDoubleForKey:@"intervalEnd"];
        logarithmicScale = [coder decodeBoolForKey:@"logarithmicScale"];
    } else {
        [coder decodeValueOfObjCType:@encode(double) at:&intervalStart];
        [coder decodeValueOfObjCType:@encode(double) at:&intervalEnd];
        [coder decodeValueOfObjCType:@encode(BOOL) at:&logarithmicScale];
    }
	
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
	
    if ([coder allowsKeyedCoding]) {
        [coder encodeDouble:intervalStart forKey:@"intervalStart"];
        [coder encodeDouble:intervalEnd forKey:@"intervalEnd"];
        [coder encodeBool:logarithmicScale forKey:@"logarithmicScale"];
    } else {
        [coder encodeValueOfObjCType:@encode(double) at:&intervalStart];
        [coder encodeValueOfObjCType:@encode(double) at:&intervalEnd];
        [coder encodeValueOfObjCType:@encode(BOOL) at:&logarithmicScale];
    }
}

#pragma mark -

- (void)setMinValue:(double)value
{
	if (intervalStart < value) {
		intervalStart = value;
	}
	if (intervalEnd < value) {
		intervalEnd = value;
	}
	[super setMinValue:value];
}

- (void)setMaxValue:(double)value
{
	if (intervalStart > value) {
		intervalStart = value;
	}
	if (intervalEnd > value) {
		intervalEnd = value;
	}
	[super setMaxValue:value];
}

- (double)intervalStart
{
	return intervalStart;
}

- (void)setIntervalStart:(double)start
{
	if (start < [self minValue]) {
		start = [self minValue];
	}
	if (start > [self maxValue]) {
		start = [self maxValue];
	}
	if (start > intervalEnd) {
		start = intervalEnd;
	}
	if (intervalStart != start) {
		intervalStart = start;
		[[self controlView] setNeedsDisplay:YES];
	}
}

- (double)intervalEnd
{
	return intervalEnd;
}

- (void)setIntervalEnd:(double)end
{
	if (end < [self minValue]) {
		end = [self minValue];
	}
	if (end > [self maxValue]) {
		end = [self maxValue];
	}
	if (end < intervalStart) {
		end = intervalStart;
	}
	if (intervalEnd != end) {
		intervalEnd = end;
		[[self controlView] setNeedsDisplay:YES];
	}
}

- (BOOL)logarithmicScale
{
	return logarithmicScale;
}

- (void)setLogarithmicScale:(BOOL)flag
{
	logarithmicScale = flag;
}

#pragma mark -

- (BOOL)startTrackingAt:(NSPoint)startPoint inView:(NSView *)controlView
{
	if (NSMouseInRect(startPoint, [self startKnobRect], NO)) {
		trackingStartKnob = YES;
		trackingEndKnob = NO;
		trackingBar = NO;
		[self drawKnob];
		return YES;
	} else if (NSMouseInRect(startPoint, [self endKnobRect], NO)) {
		trackingStartKnob = NO;
		trackingEndKnob = YES;
		trackingBar = NO;
		[self drawKnob];
		return YES;
	} else if (NSMouseInRect(startPoint, [self barRect], NO)) {
		if (NSMouseInRect(startPoint, NSUnionRect([self startKnobRect], [self endKnobRect]), NO)) {
			// between knobs
			trackingStartKnob = NO;
			trackingEndKnob = NO;
			trackingBar = YES;
			return YES;
		} else {
			// outside knobs
			double  length = intervalEnd - intervalStart;
			if (startPoint.x < [self startKnobRect].origin.x) {
				// left of start knob
				[self setIntervalStart:(intervalStart - length)];
				[self setIntervalEnd:(intervalStart + length)];
			} else {
				// right of end knob
				[self setIntervalEnd:(intervalEnd + length)];
				[self setIntervalStart:(intervalEnd - length)];
			}
			return NO;
		}
	} else {
		return NO;
	}
}

- (BOOL)continueTracking:(NSPoint)lastPoint at:(NSPoint)currentPoint inView:(NSView *)controlView
{
	if (!NSEqualPoints(lastPoint, currentPoint) && NSMouseInRect(currentPoint, [self trackRect], NO)) {
		if (trackingStartKnob) {
			[self setIntervalStart:([self pixelToValue:(currentPoint.x - [self knobThickness])] + [self minValue])];
		}
		if (trackingEndKnob) {
			[self setIntervalEnd:([self pixelToValue:(currentPoint.x - [self knobThickness])] + [self minValue])];
		}
		if (trackingBar) {
			double  length = intervalEnd - intervalStart;
			double  diff = [self pixelToValue:(currentPoint.x - lastPoint.x)];
			if (diff > 0.0) {
				[self setIntervalEnd:(intervalEnd + diff)];
				[self setIntervalStart:(intervalEnd - length)];
			}
			if (diff < 0.0) {
				[self setIntervalStart:(intervalStart + diff)];
				[self setIntervalEnd:(intervalStart + length)];
			}
		}
	}
	
	return YES;
}

- (void)stopTracking:(NSPoint)lastPoint at:(NSPoint)stopPoint inView:(NSView *)controlView mouseIsUp:(BOOL)flag
{
	[self continueTracking:lastPoint at:stopPoint inView:controlView];
	trackingStartKnob = NO;
	trackingEndKnob = NO;
	[self drawKnob];
}

#pragma mark -

- (void)drawBarInside:(NSRect)aRect flipped:(BOOL)flipped
{
	aRect = [self barRect];
	NSDrawDarkBezel(aRect, aRect);
	
	aRect.origin.x = [self startKnobRect].origin.x + ([self knobThickness] / 2.0);
	aRect.size.width = (([self endKnobRect].origin.x + [self endKnobRect].size.width) - aRect.origin.x) - ([self knobThickness] / 2.0);
	NSDrawGroove(aRect, aRect);
}

- (void)drawKnob
{
	[[self controlView] lockFocus];
	
	NSRect  srcRect = NSZeroRect;
	NSRect  dstRect = NSZeroRect;
	NSImage *img;
	
	if ([(NSControl *)[self controlView] isEnabled] && [[(NSControl *)[self controlView] window] isKeyWindow]) {
		if (trackingStartKnob) {
			img = [IntervalSliderCell startKnobImageHighlighted];
		} else {
			img = [IntervalSliderCell startKnobImageOn];
		}
	} else {
		img = [IntervalSliderCell startKnobImageOff];
	}
	[img setSize:[self knobSizeForControlSize]];
	srcRect.size = [img size];
	dstRect = [self startKnobRect];
	dstRect.origin.y = (dstRect.size.height - srcRect.size.height) / 2.0;
	dstRect.size = srcRect.size;
	[img drawInRect:dstRect fromRect:srcRect operation:NSCompositeSourceOver fraction:1.0];
	
	if ([(NSControl *)[self controlView] isEnabled] && [[(NSControl *)[self controlView] window] isKeyWindow]) {
		if (trackingEndKnob) {
			img = [IntervalSliderCell endKnobImageHighlighted];
		} else {
			img = [IntervalSliderCell endKnobImageOn];
		}
	} else {
		img = [IntervalSliderCell endKnobImageOff];
	}
	[img setSize:[self knobSizeForControlSize]];
	srcRect.size = [img size];
	dstRect = [self endKnobRect];
	dstRect.origin.y = (dstRect.size.height - srcRect.size.height) / 2.0;
	dstRect.size = srcRect.size;
	[img drawInRect:dstRect fromRect:srcRect operation:NSCompositeSourceOver fraction:1.0];
	
	[[self controlView] unlockFocus];
}

- (float)knobThickness
{
	return [self knobSizeForControlSize].width;
}

- (NSRect)startKnobRect
{
	NSRect			rect;
	
	rect.size.width = [self knobThickness];
	rect.size.height = [self trackRect].size.height;
	rect.origin.x = [self valueToPixel:(intervalStart - [self minValue])];
	rect.origin.y = 0.0;
	
	return rect;
}

- (NSRect)endKnobRect
{
	NSRect			rect;
	
	rect.size.width = [self knobThickness];
	rect.size.height = [self trackRect].size.height;
	rect.origin.x = [self valueToPixel:(intervalEnd - [self minValue])] + rect.size.width;
	rect.origin.y = 0.0;
	
	return rect;
}

- (NSRect)barRect
{
	NSRect  rect = [self trackRect];
	
	rect.origin.y = rect.size.height / 3.0;
	rect.size.height /= 3.0;
	
	return rect;
}

- (NSSize)knobSizeForControlSize
{
	NSSize  newSize = [[IntervalSliderCell startKnobImageOn] size];
	float   aspectRatio = newSize.height / newSize.width;
	
	newSize.height = [self trackRect].size.height;
	newSize.width = newSize.height / aspectRatio;
	
	return newSize;
}

#pragma mark -

- (double)pixelToValue:(float)pixel
{
	if (logarithmicScale) {
		double	scale = ([self trackRect].size.width - (2 * [self knobThickness])) / ([self maxValue] - [self minValue]);
		return expm1(pixel / scale);
	} else {
		double	scale = ([self trackRect].size.width - (2 * [self knobThickness])) / ([self maxValue] - [self minValue]);
		return pixel / scale;
	}
}

- (float)valueToPixel:(double)value
{
	if (logarithmicScale) {
		double	scale = ([self trackRect].size.width - (2 * [self knobThickness])) / ([self maxValue] - [self minValue]);
		return log1p(value) * scale;
	} else {
		double	scale = ([self trackRect].size.width - (2 * [self knobThickness])) / ([self maxValue] - [self minValue]);
		return value * scale;
	}
}

#pragma mark -

+ (NSImage *)startKnobImageOn
{
	static NSImage  *img = nil;
	if (img == nil) {
		img = [[NSImage alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"IntervalSliderLeftKnob-On" ofType:@"tiff"]];
		[img setFlipped:YES];
		[img setScalesWhenResized:YES];
	}
	return img;
}

+ (NSImage *)startKnobImageOff
{
	static NSImage  *img = nil;
	if (img == nil) {
		img = [[NSImage alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"IntervalSliderLeftKnob-Off" ofType:@"tiff"]];
		[img setFlipped:YES];
		[img setScalesWhenResized:YES];
	}
	return img;
}

+ (NSImage *)startKnobImageHighlighted
{
	static NSImage  *img = nil;
	if (img == nil) {
		img = [[NSImage alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"IntervalSliderLeftKnob-Highlight" ofType:@"tiff"]];
		[img setFlipped:YES];
		[img setScalesWhenResized:YES];
	}
	return img;
}

+ (NSImage *)endKnobImageOn
{
	static NSImage  *img = nil;
	if (img == nil) {
		img = [[NSImage alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"IntervalSliderRightKnob-On" ofType:@"tiff"]];
		[img setFlipped:YES];
		[img setScalesWhenResized:YES];
	}
	return img;
}

+ (NSImage *)endKnobImageOff
{
	static NSImage  *img = nil;
	if (img == nil) {
		img = [[NSImage alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"IntervalSliderRightKnob-Off" ofType:@"tiff"]];
		[img setFlipped:YES];
		[img setScalesWhenResized:YES];
	}
	return img;
}

+ (NSImage *)endKnobImageHighlighted
{
	static NSImage  *img = nil;
	if (img == nil) {
		img = [[NSImage alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForResource:@"IntervalSliderRightKnob-Highlight" ofType:@"tiff"]];
		[img setFlipped:YES];
		[img setScalesWhenResized:YES];
	}
	return img;
}

@end
