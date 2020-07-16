//
//  OutlineViewController.m
//  AudioSlicer
//
//  Created by Bernd Heller on Fri Feb 13 2004.
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

#import "OutlineViewController.h"
#import "SplitDocument.h"
#import "TimeFormatter.h"
#import "SegmentTitleCell.h"

@interface OutlineViewController (Private)
- (NSString *)secondsToHMSString:(double)time;
- (void)modelDidChange:(NSNotification *)notification;
@end

@implementation OutlineViewController

- (id)initWithDocument:(SplitDocument *)doc outlineView:(AudioSegmentOutlineView *)view
{
	if (self = [super init]) {
		outlineView = view;
		document = doc;
		
		[self awakeFromNib];
	}
	
	return self;
}

- (void)awakeFromNib
{
	normalFont = [[NSFont systemFontOfSize:[NSFont smallSystemFontSize]] retain];
	boldFont = [[NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]] retain];
	
	[[[outlineView tableColumnWithIdentifier:@"startTime"] dataCell] setFormatter:[[[TimeFormatter alloc] init] autorelease]];
	[[[outlineView tableColumnWithIdentifier:@"endTime"] dataCell] setFormatter:[[[TimeFormatter alloc] init] autorelease]];
	[[[outlineView tableColumnWithIdentifier:@"duration"] dataCell] setFormatter:[[[TimeFormatter alloc] init] autorelease]];
	
	SegmentTitleCell	*newTitleCell = [[[SegmentTitleCell alloc] init] autorelease];
	[newTitleCell setEditable:YES];
	[newTitleCell setScrollable:YES];
	[newTitleCell setWraps:NO];
	[[outlineView tableColumnWithIdentifier:@"title"] setDataCell:newTitleCell];
	
	[outlineView setAutosaveTableColumns:YES];
	[outlineView setAutosaveName:@"OutlineView"];
	[outlineView setAutosaveName:[NSString stringWithFormat:@"OutlineView-%lu", [document documentID]]];
	
	[outlineView setTarget:self];
	[outlineView setDoubleAction:@selector(playButtonClicked:)];
	
	suppressModelDidChangeNotification = NO;
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(modelDidChange:)
												 name:AudioSegmentTreeDidChangeNotification
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(modelDidChange:)
												 name:AudioSliceDidChangeNotification
											   object:nil];
}

- (void)dealloc
{
	[outlineView saveTableColumnsWithAutosaveName:@"OutlineView"];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[normalFont release];
	[boldFont release];
	
	[super dealloc];
}

- (void)setAudioFile:(AudioFile *)file audioSegmentTree:(AudioSegmentTree *)tree
{
	itemPlaying = nil;
	
	audioSegmentTree = tree;
	audioFile = file;
	[audioFile setDelegate:self];
	
	[self reloadOutlineView];
}

- (void)reloadOutlineView
{
	[outlineView removeAllToolTips];
	[outlineView reloadData];
	
	NSInteger		i;
	NSInteger		itemCount = [self outlineView:outlineView numberOfChildrenOfItem:nil];
	for (i = 0; i < itemCount; i++) {
		id  item = [self outlineView:outlineView child:i ofItem:nil];
		if ([self outlineView:outlineView isItemExpandable:item]) {
			if ([(AudioSlice *)item expandedInOutlineView]) {
				[outlineView expandItem:item];
			} else {
				[outlineView collapseItem:item];
			}
		}
	}
	
	[outlineView sizeLastColumnToFit];
}

#pragma mark -

- (AudioSegmentNode *)prevSilence
{
	NSInteger		row;
	
	if ([outlineView selectedRow] == -1) {
		row = [outlineView numberOfRows];
	} else {
		row = [outlineView selectedRow] - 1;
	}
	
	for ( ; row >= 0; row--) {
		id		item = [outlineView itemAtRow:row];
		if ([item isMemberOfClass:[AudioSegmentNode class]]) {
			if ([item nodeType] == AudioSegmentNodeTypeSilence) {
				return item;
			}
		}
	}
	
	return nil;
}

- (AudioSegmentNode *)nextSilence
{
	NSInteger		row;
	
	if ([outlineView selectedRow] == -1) {
		row = 0;
	} else {
		row = [outlineView selectedRow] + 1;
	}
	
	for ( ; row < [outlineView numberOfRows]; row++) {
		id		item = [outlineView itemAtRow:row];
		if ([item isMemberOfClass:[AudioSegmentNode class]]) {
			if ([item nodeType] == AudioSegmentNodeTypeSilence) {
				return item;
			}
		}
	}
	
	return nil;
}

#pragma mark -

- (NSMutableArray *)selectedItems
{
	NSIndexSet		*selection = [outlineView selectedRowIndexes];
	NSMutableArray  *items = [NSMutableArray arrayWithCapacity:[selection count]];
	NSUInteger		currentIndex = [selection firstIndex];
	while (currentIndex != NSNotFound) {
		[items addObject:[outlineView itemAtRow:currentIndex]];
		currentIndex = [selection indexGreaterThanIndex:currentIndex];
	}
	
	return items;
}

- (NSMutableArray *)selectedSlices
{
	NSMutableArray  *selectedSlices = [[[NSMutableArray alloc] init] autorelease];
	NSEnumerator	*arrEnum = [[self selectedItems] objectEnumerator];
	id				item;
	
	while (item = [arrEnum nextObject]) {
		if ([item isMemberOfClass:[AudioSlice class]]) {
			[selectedSlices addObject:item];
		}
	}
	
	return selectedSlices;
}

- (void)selectItems:(NSArray *)selection
{
	NSMutableIndexSet   *selectionIndex = [[[NSMutableIndexSet alloc] init] autorelease];
	NSEnumerator		*items = [selection objectEnumerator];
	id					item;
	
	while (item = [items nextObject]) {
		NSInteger		row = [outlineView rowForItem:item];
		if (row >= 0) {
			[selectionIndex addIndex:row];
		}
	}
	
	[outlineView selectRowIndexes:selectionIndex byExtendingSelection:NO];
}

#pragma mark -

- (BOOL)canJoinSelectedItems
{
	NSIndexSet		*selection = [outlineView selectedRowIndexes];
	NSUInteger	currentIndex = [selection firstIndex];
	while (currentIndex != NSNotFound) {
		id  item = [outlineView itemAtRow:currentIndex];
		if ([item isMemberOfClass:[AudioSegmentNode class]] && [item nodeType] == AudioSegmentNodeTypeSilence && [item doesSplit]) {
			return YES;
		}
		currentIndex = [selection indexGreaterThanIndex:currentIndex];
	}
	return NO;
}

- (BOOL)canSplitSelectedItems
{
	NSIndexSet		*selection = [outlineView selectedRowIndexes];
	NSUInteger	currentIndex = [selection firstIndex];
	while (currentIndex != NSNotFound) {
		id  item = [outlineView itemAtRow:currentIndex];
		if ([item isMemberOfClass:[AudioSegmentNode class]] && [item nodeType] == AudioSegmentNodeTypeSilence && ![item doesSplit]) {
			return YES;
		} else if ([item isMemberOfClass:[AudioSlice class]]) {
			if ([audioSegmentTree numberOfAudioSegmentsInSlice:item] > 1) {
				return YES;
			}
		}
		currentIndex = [selection indexGreaterThanIndex:currentIndex];
	}
	return NO;
}

- (void)joinSelectedItems
{
	NSEnumerator	*selectedItems = [[self selectedItems] objectEnumerator];
	id				item;
	
	suppressModelDidChangeNotification = YES;
	while (item = [selectedItems nextObject]) {
		if ([item isMemberOfClass:[AudioSegmentNode class]] && [item nodeType] == AudioSegmentNodeTypeSilence && [item doesSplit]) {
			[audioSegmentTree clearSplitPointAtNode:item];
		}
	}
	suppressModelDidChangeNotification = NO;
	[self reloadOutlineView];
}

- (void)splitSelectedItems
{
	NSEnumerator	*selectedItems = [[self selectedItems] objectEnumerator];
	id				item;
	
	suppressModelDidChangeNotification = YES;
	while (item = [selectedItems nextObject]) {
		if ([item isMemberOfClass:[AudioSegmentNode class]] && [item nodeType] == AudioSegmentNodeTypeSilence && ![item doesSplit]) {
			[audioSegmentTree setSplitPointAtNode:item];
		} else if ([item isMemberOfClass:[AudioSlice class]]) {
			for (NSInteger j = [audioSegmentTree numberOfAudioSegmentsInSlice:item] - 1; j >= 0; j--) {
				AudioSegmentNode	*s = [audioSegmentTree audioSegmentAtIndex:j inSlice:item];
				if ([s nodeType] == AudioSegmentNodeTypeSilence && ![s doesSplit]) {
					[audioSegmentTree setSplitPointAtNode:s];
				}
			}
		}
	}
	suppressModelDidChangeNotification = NO;
	[self reloadOutlineView];
}

#pragma mark -

- (BOOL)canCollapseSelectedItems
{
	NSIndexSet		*selection = [outlineView selectedRowIndexes];
	NSUInteger	currentIndex = [selection firstIndex];
	while (currentIndex != NSNotFound) {
		id  item = [outlineView itemAtRow:currentIndex];
		if ([outlineView isExpandable:item] && [outlineView isItemExpanded:item]) {
			return YES;
		}
		currentIndex = [selection indexGreaterThanIndex:currentIndex];
	}
	return NO;
}

- (BOOL)canExpandSelectedItems
{
	NSIndexSet		*selection = [outlineView selectedRowIndexes];
	NSUInteger	currentIndex = [selection firstIndex];
	while (currentIndex != NSNotFound) {
		id  item = [outlineView itemAtRow:currentIndex];
		if ([outlineView isExpandable:item] && ![outlineView isItemExpanded:item]) {
			return YES;
		}
		currentIndex = [selection indexGreaterThanIndex:currentIndex];
	}
	return NO;
}

- (void)collapseSelectedItems
{
	NSEnumerator	*selectedItems = [[self selectedItems] objectEnumerator];
	id				item;
	while (item = [selectedItems nextObject]) {
		if ([outlineView isExpandable:item]) {
			[outlineView collapseItem:item];
		}
	}
}

- (void)expandSelectedItems
{
	NSEnumerator	*selectedItems = [[self selectedItems] objectEnumerator];
	id				item;
	while (item = [selectedItems nextObject]) {
		if ([outlineView isExpandable:item]) {
			[outlineView expandItem:item];
		}
	}
}

#pragma mark -

- (void)splitButtonClicked:(id)sender
{
	AudioSegmentNode	*s = (AudioSegmentNode *)[outlineView itemAtRow:[outlineView selectedRow]];
	if (s == nil) {
		return;
	}
	
	if ([s doesSplit]) {
		// join at segment
		[audioSegmentTree clearSplitPointAtNode:s];
	} else {
		// split at segment
		[audioSegmentTree setSplitPointAtNode:s];
	}
	
	[outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:[outlineView rowForItem:s]] byExtendingSelection:NO];
	[outlineView scrollRowToVisible:[outlineView rowForItem:s]];
}

- (void)playButtonClicked:(id)sender
{
	id  item = [outlineView itemAtRow:[outlineView selectedRow]];
	if (item == nil) {
		return;
	}
	
	if (item == itemPlaying) {
		// stop playing
		[audioFile abortPlaying];
		itemPlaying = nil;
	} else {
		// start playing an item
		if (itemPlaying) {
			[audioFile abortPlaying];
			itemPlaying = nil;
		}
		
		itemPlaying = item;
		if ([item isMemberOfClass:[AudioSegmentNode class]]) {
			if ([item nodeType] == AudioSegmentNodeTypeSilence) {
				[document playSilence:item];
			} else {
				[document playTitle:item];
			}
		} else {
			[document playSlice:item];
		}
	}
	
	[outlineView reloadItem:item];
}

#pragma mark -

- (NSInteger)outlineView:(NSOutlineView *)view numberOfChildrenOfItem:(id)item
{
	if (item == nil) {
		// root level, return number of Slices plus number of silences between
		return MAX(0, ([audioSegmentTree numberOfSlices] * 2) - 1);
	} else {
		// item is a AudioSlice
		return [audioSegmentTree numberOfAudioSegmentsInSlice:item];
	}
}

- (id)outlineView:(NSOutlineView *)view child:(NSInteger)index ofItem:(id)item
{
	if (item == nil) {
		// root level, return Slice or a silence AudioSegmentNode
		if (index % 2 == 0) {
			return [audioSegmentTree sliceAtIndex:index/2];
		} else {
			return [[audioSegmentTree sliceAtIndex:index/2] rightSilenceSegment];
		}
	} else {
		// inside a AudioSlice, return an AudioSegmentNode
		if ([[item leftSilenceSegment] doesSplit]) {
			index++;
		}
		return [audioSegmentTree audioSegmentAtIndex:index inSlice:item];
	}
}

- (BOOL)outlineView:(NSOutlineView *)view isItemExpandable:(id)item
{
	if ([item isMemberOfClass:[AudioSlice class]]) {
		// item is a split segment
		return YES;
	} else {
		// item is a top level splitting silence
		return NO;
	}
}

- (id)outlineView:(NSOutlineView *)view objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	if ([[tableColumn identifier] isEqualToString:@"title"]) {
		if ([item isMemberOfClass:[AudioSlice class]]) {
			// AudioSlice
			return [item title];
		} else {
			// AudioSegmentNode
			if ([item nodeType] == AudioSegmentNodeTypeSilence) {
				if ([view levelForItem:item] == 0) {
					return @"Split Silence";
				} else {
					return @"Silence";
				}
			} else {
				return @"Audio Content";
			}
		}
	} else {
		NSArray *numericKeys = [NSArray arrayWithObjects:@"year", @"trackNumber", @"trackCount", @"cdNumber", @"cdCount", nil];
		id		object = nil;
		@try {
			object = [item valueForKey:[tableColumn identifier]];
		} @catch(NSException *exception) {
		}
		if ([numericKeys indexOfObject:[tableColumn identifier]] != NSNotFound) {
			NSValueTransformer  *transformer = [NSValueTransformer valueTransformerForName:@"ZeroToEmptyStringTransformer"];
			object = [transformer transformedValue:object];
		}
		return object;
	}
	
	return nil;
}

- (void)outlineView:(NSOutlineView *)view setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	NSArray *numericKeys = [NSArray arrayWithObjects:@"year", @"trackNumber", @"trackCount", @"cdNumber", @"cdCount", nil];
	if ([numericKeys indexOfObject:[tableColumn identifier]] != NSNotFound) {
		NSValueTransformer  *transformer = [NSValueTransformer valueTransformerForName:@"ZeroToEmptyStringTransformer"];
		object = [transformer reverseTransformedValue:object];
	}
	@try {
		[item setValue:object forKey:[tableColumn identifier]];
	} @catch(NSException *exception) {
	}
}

#pragma mark -

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	if ([item isMemberOfClass:[AudioSlice class]]) {
		return YES;
	} else {
		return NO;
	}
}

- (void)outlineView:(NSOutlineView *)view willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	if ([[tableColumn identifier] isEqualToString:@"title"]) {
		[cell setRateDisplay:0.0];
		if ([item isMemberOfClass:[AudioSlice class]]) {
			[cell setFont:boldFont];
			[cell setTextColor:[NSColor blackColor]];
			[cell setAlignment:NSLeftTextAlignment];
			
			[outlineView addToolTipRect:[outlineView frameOfCellAtColumn:[outlineView columnWithIdentifier:[tableColumn identifier]]
																	 row:[outlineView rowForItem:item]]
								  owner:[item title]
							   userData:nil];
		} else {
			if ([view levelForItem:item] == 0) {
				[cell setFont:normalFont];
				[cell setTextColor:[NSColor darkGrayColor]];
				[cell setAlignment:NSRightTextAlignment];
			} else {
				[cell setFont:normalFont];
				[cell setTextColor:[NSColor blackColor]];
				[cell setAlignment:NSLeftTextAlignment];
				if ([item nodeType] == AudioSegmentNodeTypeSilence) {
					[cell setRateDisplay:([item duration] / [audioSegmentTree longestSilenceInTree])];
				}
			}
		}
	} else if ([[tableColumn identifier] isEqualToString:@"split"]) {
		if ([item isMemberOfClass:[AudioSegmentNode class]] && [item nodeType] == AudioSegmentNodeTypeSilence) {
			[cell setTarget:self];
			[cell setAction:@selector(splitButtonClicked:)];
			[cell setRepresentedObject:item];
			if ([item doesSplit]) {
				[cell setTitle:@"Join"];
			} else {
				[cell setTitle:@"Split"];
			}
		}
	} else if ([[tableColumn identifier] isEqualToString:@"play"]) {
		if (item == itemPlaying) {
			[cell setImage:[NSImage imageNamed:@"stop.tiff"]];
		} else {
			[cell setImage:[NSImage imageNamed:@"play.tiff"]];
		}
		[cell setTarget:self];
		[cell setAction:@selector(playButtonClicked:)];
		[cell setRepresentedObject:item];
	}
}

- (void)outlineViewItemDidExpand:(NSNotification *)notification
{
	AudioSlice  *item = (AudioSlice *)[[notification userInfo] objectForKey:@"NSObject"];
	[item setExpandedInOutlineView:YES];
	[outlineView sizeLastColumnToFit];
}

- (void)outlineViewItemDidCollapse:(NSNotification *)notification
{
	AudioSlice  *item = (AudioSlice *)[[notification userInfo] objectForKey:@"NSObject"];
	[item setExpandedInOutlineView:NO];
	[outlineView sizeLastColumnToFit];
}


- (NSColor *)outlineView:(NSOutlineView *)view backgroundColorForRow:(NSInteger)rowIndex
{
	id			item = [view itemAtRow:rowIndex];
	
	if ([item isMemberOfClass:[AudioSlice class]]) {
		return [NSColor colorWithCalibratedHue:219.0/360.0 saturation:0.20 brightness:0.99 alpha:1.0];
	} else if ([item isMemberOfClass:[AudioSegmentNode class]] && [item nodeType] == AudioSegmentNodeTypeSilence) {
		if ([view levelForItem:item] == 0) {
			return [NSColor whiteColor];
		} else {
			return [NSColor colorWithCalibratedHue:219.0/360.0 saturation:0.07 brightness:0.99 alpha:1.0];
		}
	}
	
	return [NSColor whiteColor];
}

- (BOOL)outlineView:(NSOutlineView *)view keyDown:(NSEvent *)keyEvent
{
	if ([[keyEvent characters] isEqualToString:@" "]) {
		[self playButtonClicked:self];
	}
	
	return NO;
}

#pragma mark -

- (void)audioFileDidFinishPlaying:(AudioFile *)audioFile
{
	id  item = itemPlaying;
	itemPlaying = nil;
	if (item) {
		[outlineView reloadItem:item];
	}
}

@end

#pragma mark -

@implementation OutlineViewController (Private)

- (NSString *)secondsToHMSString:(double)time
{
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

- (void)modelDidChange:(NSNotification *)notification
{
	if (suppressModelDidChangeNotification == YES) {
		return;
	}
	
	id  sender = [notification object];
	
	if ([[notification name] isEqualToString:AudioSegmentTreeDidChangeNotification]) {
		NSArray *selection = [self selectedItems];
		[self reloadOutlineView];
		[self selectItems:selection];
	} else if ([[notification name] isEqualToString:AudioSliceDidChangeNotification]) {
		[outlineView removeAllToolTips];
		[outlineView reloadItem:sender];
	}
}

@end
