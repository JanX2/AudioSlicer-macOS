//
//  IntervalSliderPalette.h
//  IntervalSlider
//
//  Created by Bernd Heller on Wed Mar 03 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import <InterfaceBuilder/InterfaceBuilder.h>
#import "IntervalSlider.h"

@interface IntervalSliderPalette : IBPalette
{
}
@end

@interface IntervalSlider (IntervalSliderPaletteInspector)
- (NSString *)inspectorClassName;
@end
