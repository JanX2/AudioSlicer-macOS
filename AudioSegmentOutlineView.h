//
//  AudioSegmentOutlineView.h
//  AudioSlicer
//
//  Created by Bernd Heller on Thu Feb 26 2004.
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


@interface AudioSegmentOutlineView : NSOutlineView {
	BOOL					autosaveColumns;
	NSMutableDictionary		*allTableColumns;
	BOOL					isRestoringFromDefaults;
}

- (void)setColumnHidden:(BOOL)hidden withIdentifier:(NSString *)identifier;
- (BOOL)isColumnHiddenWithIdentifier:(NSString *)identifier;

- (NSMenu *)columnsMenu;

- (void)loadTableColumnsWithAutosaveName:(NSString *)name;
- (void)saveTableColumnsWithAutosaveName:(NSString *)name;

@end


@class NSObject;

@interface NSObject (AudioSegmentOutlineViewDelegate)
- (NSColor *)outlineView:(NSOutlineView *)view backgroundColorForRow:(NSInteger)rowIndex;
- (BOOL)outlineView:(NSOutlineView *)view keyDown:(NSEvent *)keyEvent;
@end
