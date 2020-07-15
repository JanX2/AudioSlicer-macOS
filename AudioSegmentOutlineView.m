//
//  AudioSegmentOutlineView.m
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

#import "AudioSegmentOutlineView.h"
#import "AudioSegmentNode.h"

@interface AudioSegmentOutlineView (Private)
- (void)columnMenuItemClicked:(id)sender;
- (void)tableColumnsDidChange:(NSNotification *)notification;
- (void)storeTableColumnsToDefaultsUsingName:(NSString *)name;
- (void)restoreTableColumnsFromDefaultsUsingName:(NSString *)name;
- (void)initializeTableColumns;
@end

@implementation AudioSegmentOutlineView

- (id)initWithFrame:(NSRect)frameRect
{
	if (self = [super initWithFrame:frameRect]) {
		[super setAutosaveTableColumns:NO];
		[self setAutosaveTableColumns:YES];
	}
	
	return self;
}

- (void)awakeFromNib
{
	[super setAutosaveTableColumns:NO];
	[self setAutosaveTableColumns:YES];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[allTableColumns release];
	[super dealloc];
}

#pragma mark -

- (void)keyDown:(NSEvent *)theEvent
{
	if ([[self delegate] outlineView:self keyDown:theEvent] == NO) {
		[super keyDown:theEvent];
	}
}

- (void)drawRow:(NSInteger)rowIndex clipRect:(NSRect)clipRect
{
	if (![self isRowSelected:rowIndex]) {
		NSColor		*bg = [(id <NSOutlineViewDelegate>)[self delegate] outlineView:self backgroundColorForRow:rowIndex];
		if (bg) {
			[NSGraphicsContext saveGraphicsState];
			[bg set];
			NSRectClip(clipRect);
			
			NSRect  rowRect = [self rectOfRow:rowIndex];
			NSEraseRect(rowRect);
			NSRectFill(rowRect);
			[NSGraphicsContext restoreGraphicsState];
		}
	}
	
	[super drawRow:rowIndex clipRect:clipRect];
}

- (void)drawGridInClipRect:(NSRect)aRect
{
	NSRange		rows = [self rowsInRect:aRect];
	NSInteger			rowIndex;
	
	for (rowIndex = rows.location; rowIndex < rows.location + rows.length; rowIndex++) {
		if ([self levelForRow:rowIndex + 1] <= 0) {
			NSRect  rowRect = [self rectOfRow:rowIndex];
			[super drawGridInClipRect:rowRect];
		}
	}
}

- (void)textDidEndEditing:(NSNotification *)aNotification
{
	if ([[[aNotification userInfo] objectForKey:@"NSTextMovement"] integerValue] == NSReturnTextMovement) {
		NSDictionary  *userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithInteger:NSOtherTextMovement]
															  forKey:@"NSTextMovement"];
		[super textDidEndEditing:[NSNotification notificationWithName:[aNotification name]
															   object:[aNotification object]
															 userInfo:userInfo]];
		[[self window] makeFirstResponder:self];
	} else {
		[super textDidEndEditing:aNotification];
	}
}

#pragma mark -

- (void)setAutosaveTableColumns:(BOOL)flag
{
	if (autosaveColumns == flag) {
		return;
	}
	
	autosaveColumns = flag;
	
	NSNotificationCenter	*center = [NSNotificationCenter defaultCenter];
	if (autosaveColumns) {
		[center addObserver:self selector:@selector(tableColumnsDidChange:) name:NSOutlineViewColumnDidMoveNotification object:nil];
		[center addObserver:self selector:@selector(tableColumnsDidChange:) name:NSOutlineViewColumnDidResizeNotification object:nil];
		[self restoreTableColumnsFromDefaultsUsingName:[self autosaveName]];
	} else {
		[center removeObserver:self name:NSOutlineViewColumnDidMoveNotification object:nil];
		[center removeObserver:self name:NSOutlineViewColumnDidResizeNotification object:nil];
	}
}

- (void)setAutosaveName:(NSString *)name
{
	[super setAutosaveName:name];
	[self restoreTableColumnsFromDefaultsUsingName:[self autosaveName]];
}

- (void)setColumnHidden:(BOOL)hidden withIdentifier:(NSString *)identifier
{
	if ([self isColumnHiddenWithIdentifier:identifier] != hidden) {
		NSTableColumn   *column = [allTableColumns objectForKey:identifier];
		if (hidden) {
			[self removeTableColumn:column];
		} else {
			[self addTableColumn:column];
		}
		[self storeTableColumnsToDefaultsUsingName:[self autosaveName]];
	}
}

- (BOOL)isColumnHiddenWithIdentifier:(NSString *)identifier
{
	return ([self columnWithIdentifier:identifier] < 0);
}

- (NSMenu *)columnsMenu
{
	NSMenu			*menu = [[[NSMenu alloc] initWithTitle:@"Columns"] autorelease];
	NSMutableArray  *menuItems = [NSMutableArray arrayWithCapacity:[allTableColumns count]];
	NSEnumerator	*columns = [allTableColumns objectEnumerator];
	NSTableColumn   *column;
	NSMenuItem		*item;
	
	while (column = [columns nextObject]) {
		if (![[[column headerCell] title] isEqualToString:@""]) {
			item = [[[NSMenuItem alloc] initWithTitle:[[column headerCell] title]
											   action:@selector(columnMenuItemClicked:)
										keyEquivalent:@""] autorelease];
			[item setRepresentedObject:[column identifier]];
			[item setTarget:self];
			[item setState:([self isColumnHiddenWithIdentifier:[column identifier]] ? NSOffState : NSOnState)];
			[menuItems addObject:item];
		}
	}
	
	[menu setAutoenablesItems:NO];
	[menuItems sortUsingDescriptors:[NSArray arrayWithObject:[[[NSSortDescriptor alloc] initWithKey:@"title"
																						  ascending:YES] autorelease]]];
	for (NSUInteger	 i = 0; i < [menuItems count]; i++) {
		[menu addItem:[menuItems objectAtIndex:i]];
	}
	
	return menu;
}

- (void)loadTableColumnsWithAutosaveName:(NSString *)name
{
	[self restoreTableColumnsFromDefaultsUsingName:name];
}

- (void)saveTableColumnsWithAutosaveName:(NSString *)name
{
	[self storeTableColumnsToDefaultsUsingName:name];
}

@end

#pragma mark -

@implementation AudioSegmentOutlineView (Private)

- (void)columnMenuItemClicked:(id)sender
{
	NSMenuItem  *item = (NSMenuItem *)sender;
	NSString	*identifier = [item representedObject];
	
	[sender setState:([sender state] == NSOnState) ? NSOffState : NSOnState];
	[self setColumnHidden:([sender state] == NSOffState) withIdentifier:identifier];
}

- (void)tableColumnsDidChange:(NSNotification *)notification
{
	if (!isRestoringFromDefaults) {
		[self storeTableColumnsToDefaultsUsingName:[self autosaveName]];
	}
}

- (void)storeTableColumnsToDefaultsUsingName:(NSString *)name
{
	if ([self autosaveName] == nil || [[self autosaveName] isEqualToString:@""] || autosaveColumns == NO) {
		return;
	}
	
	[self initializeTableColumns];
	
	NSMutableArray  *columnIdentifiers = [NSMutableArray arrayWithCapacity:[allTableColumns count]];
	NSMutableArray  *columnWidths = [NSMutableArray arrayWithCapacity:[allTableColumns count]];
	NSEnumerator	*columns = [[self tableColumns] objectEnumerator];
	NSTableColumn   *column;
	
	while (column = [columns nextObject]) {
		[columnIdentifiers addObject:[column identifier]];
		[columnWidths addObject:@([column width])];
	}
	
	NSUserDefaults  *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:columnIdentifiers forKey:[NSString stringWithFormat:@"%@-Identifiers", [self autosaveName]]];
	[defaults setObject:columnWidths forKey:[NSString stringWithFormat:@"%@-Widths", [self autosaveName]]];
}

- (void)restoreTableColumnsFromDefaultsUsingName:(NSString *)name
{
	if ([self autosaveName] == nil || [[self autosaveName] isEqualToString:@""] || autosaveColumns == NO) {
		return;
	}
	
	[self initializeTableColumns];
	
	NSUserDefaults  *defaults = [NSUserDefaults standardUserDefaults];
	
	if ([defaults objectForKey:[NSString stringWithFormat:@"%@-Identifiers", [self autosaveName]]] &&
		[defaults objectForKey:[NSString stringWithFormat:@"%@-Widths", [self autosaveName]]]) {
		NSEnumerator	*identifiers;
		NSEnumerator	*widths;
		NSTableColumn   *column;
		NSString		*identifier;
		NSInteger				colIndex;
		CGFloat			width;
		
		isRestoringFromDefaults = YES;
		
		// remove all titled columns
		NSUInteger columnIndex = 0;
		NSMutableIndexSet *columnIndexesToRemove = [NSMutableIndexSet indexSet];
		for (NSTableColumn *column in self.tableColumns) {
			if (column != [self outlineTableColumn] && ![[[column headerCell] title] isEqualToString:@""]) {
				[columnIndexesToRemove addIndex:columnIndex];
			}
			
			columnIndex += 1;
		}
		
		[columnIndexesToRemove enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
			[self removeTableColumn:self.tableColumns[idx]];
		}];
		
		// re-add all columns in prefs
		identifiers = [[defaults objectForKey:[NSString stringWithFormat:@"%@-Identifiers", [self autosaveName]]] objectEnumerator];
		while (identifier = [identifiers nextObject]) {
			column = [allTableColumns objectForKey:identifier];   
			if ([self columnWithIdentifier:identifier] < 0) {
				[self addTableColumn:column];
			}
		}
		
		// set column widths
		identifiers = [[defaults objectForKey:[NSString stringWithFormat:@"%@-Identifiers", [self autosaveName]]] objectEnumerator];
		widths = [[defaults objectForKey:[NSString stringWithFormat:@"%@-Widths", [self autosaveName]]] objectEnumerator];
		while (identifier = [identifiers nextObject]) {
			column = [allTableColumns objectForKey:identifier];   
			@try {
				width = [[widths nextObject] doubleValue];
			} @catch(NSException *e) {
				width = 0.0;
			}
			if (width > 0.0) {
				[column setWidth:width];
			}
		}
		
		// reorder columns
		colIndex = 0;
		identifiers = [[defaults objectForKey:[NSString stringWithFormat:@"%@-Identifiers", [self autosaveName]]] objectEnumerator];
		while (identifier = [identifiers nextObject]) {
			[self moveColumn:[self columnWithIdentifier:identifier] toColumn:colIndex++];
		}
		
		isRestoringFromDefaults = NO;
	}
	
	[[self cornerView] setMenu:[self columnsMenu]];
	[(NSPopUpButton *)[self cornerView] setTitle:@""];
}

- (void)initializeTableColumns
{
	if (allTableColumns == nil || [allTableColumns count] == 0) {
		[allTableColumns release];
		
		// store all table columns in a dictionary referenced by identifier
		allTableColumns = [[NSMutableDictionary alloc] init];
		NSEnumerator	*columns = [[self tableColumns] objectEnumerator];
		NSTableColumn   *column;
		while (column = [columns nextObject]) {
			[allTableColumns setObject:column forKey:[column identifier]];
		}
	}
}

@end
