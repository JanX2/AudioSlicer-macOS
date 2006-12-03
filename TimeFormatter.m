//
//  TimeFormatter.m
//  AudioSlicer
//
//  Created by Bernd Heller on Mon Mar 01 2004.
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

#import "TimeFormatter.h"


@implementation TimeFormatter

- (NSString *)stringForObjectValue:(id)anObject
{
	double  time = [anObject doubleValue];
	int		tenths, seconds, minutes, hours;
	
	time = round(time * 10.0) / 10.0;
	seconds = (int)time;
	
	hours = seconds / 3600;
	seconds -= hours * 3600;
	
	minutes = seconds / 60;
	seconds -= minutes * 60;
	
	tenths = rint((time - (hours * 3600.0) - (minutes * 60.0) - seconds) * 10.0);
	
	return [NSString stringWithFormat:@"%d:%02d'%02d.%1d", hours, minutes, seconds, tenths];
}

@end
