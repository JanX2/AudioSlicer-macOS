//
//  IntervalSliderInspector.h
//  IntervalSlider
//
//  Created by Bernd Heller on Wed Mar 03 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import <InterfaceBuilder/InterfaceBuilder.h>

@interface IntervalSliderInspector : IBInspector
{
	IBOutlet NSTextField	*startValueField;
	IBOutlet NSTextField	*endValueField;
	IBOutlet NSButton		*logarithmicCheckbox;
}

@end
