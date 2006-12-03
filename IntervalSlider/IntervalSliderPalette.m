//
//  IntervalSliderPalette.m
//  IntervalSlider
//
//  Created by Bernd Heller on Wed Mar 03 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "IntervalSliderPalette.h"

@implementation IntervalSliderPalette

- (void)finishInstantiate
{
    /* `finishInstantiate' can be used to associate non-view objects with
     * a view in the palette's nib.  For example:
     *   [self associateObject:aNonUIObject ofType:IBObjectPboardType
     *                withView:aView];
     */
}

@end

@implementation IntervalSlider (IntervalSliderPaletteInspector)

- (NSString *)inspectorClassName
{
	NSEvent*	event = [[NSApplication sharedApplication] currentEvent];
    NSString*   inspectorClassName = @"IntervalSliderInspector";
	
    if (!([event modifierFlags] & NSCommandKeyMask)) {
		// Get the inspector class name from our superclass.
        inspectorClassName = [super inspectorClassName];
	}
	
    return inspectorClassName;	
}

- (NSString *)editorClassName
{
	return @"IntervalSlider";
}

@end
