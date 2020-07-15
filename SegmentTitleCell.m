//
//  SegmentTitleCell.m
//  AudioSlicer
//
//  Created by Bernd Heller on Sun Mar 07 2004.
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

#import "SegmentTitleCell.h"


@interface SegmentTitleCell (Private)
- (NSString *)shortenedString:(NSAttributedString *)str maxWidth:(double)width;
@end

@implementation SegmentTitleCell

+ (NSColor *)ratePatternColor
{
	static NSImage  *patternImage = nil;
	
	if (patternImage == nil) {
		patternImage = [[NSImage alloc] initWithSize:NSMakeSize(2.0, 2.0)];
		[patternImage lockFocus];
		[[NSColor darkGrayColor] set];
		NSRectFill(NSMakeRect(0.0, 0.0, 1.0, 2.0));
		[[NSColor lightGrayColor] set];
		NSRectFill(NSMakeRect(1.0, 0.0, 1.0, 2.0));
		[patternImage unlockFocus];
	}
	
	return [NSColor colorWithPatternImage:patternImage];
}

- (void)setRateDisplay:(double)rate
{
	rateDisplay = rate;
}

- (double)rateDisplay
{
	return rateDisplay;
}


- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSString	*originalStr = [self stringValue];
	[self setStringValue:[self shortenedString:[self attributedStringValue] maxWidth:NSWidth(cellFrame) - 4.0]];
	[super drawInteriorWithFrame:cellFrame inView:controlView];
	[self setStringValue:originalStr];
	
	NSRect		rateDisplayRect;
	double		maxWidth = 100.0;
	rateDisplayRect.size.height = [[self font] xHeight];
	rateDisplayRect.size.width = rateDisplay * maxWidth;
	rateDisplayRect.origin.y = cellFrame.origin.y + ((cellFrame.size.height - rateDisplayRect.size.height) / 2.0);
	rateDisplayRect.origin.x = cellFrame.origin.x + cellFrame.size.width - maxWidth;
	
	[NSGraphicsContext saveGraphicsState];
	[[SegmentTitleCell ratePatternColor] set];
	NSRectFill(rateDisplayRect);
	[NSGraphicsContext restoreGraphicsState];
}

@end

@implementation SegmentTitleCell (Private)

- (NSString *)shortenedString:(NSAttributedString *)str maxWidth:(double)width
{
	if ([str size].width > width) {
		NSMutableAttributedString   *shortStr = [str mutableCopy];
		NSFont						*font = [str attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
		NSInteger					charsToDelete = ([shortStr length] - (width / ([font maximumAdvancement].width / 3)) + 1) + 3;
		NSRange						deleteRange = NSMakeRange(([shortStr length] - charsToDelete) / 2, charsToDelete);
		
		[shortStr replaceCharactersInRange:deleteRange withString:@"..."];
		
		return [shortStr string];
	} else {
		return [str string];
	}
}

@end
