//
//  IntervalSliderInspector.m
//  IntervalSlider
//
//  Created by Bernd Heller on Wed Mar 03 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "IntervalSliderInspector.h"
#import "IntervalSlider.h"

@implementation IntervalSliderInspector

- (id)init
{
    if (self = [super init]) {
		[NSBundle loadNibNamed:@"IntervalSliderInspector" owner:self];
	}
	
    return self;
}

- (BOOL)wantsButtons
{
    return NO;
}

- (void)ok:(id)sender
{
	if (sender == startValueField) {
		[[self object] setIntervalStart:[startValueField doubleValue]];
	} else if (sender == endValueField) {
		[[self object] setIntervalEnd:[endValueField doubleValue]];
	} else if (sender == logarithmicCheckbox) {
		[[self object] setLogarithmicScale:([logarithmicCheckbox state] == NSOnState)];
	}
	
    [super ok:sender];
}

- (void)revert:(id)sender
{
	[startValueField setDoubleValue:[[self object] intervalStart]];
	[endValueField setDoubleValue:[[self object] intervalEnd]];
	[logarithmicCheckbox setState:[[self object] logarithmicScale] ? NSOnState : NSOffState];
	
    [super revert:sender];
}

@end
