//
//  SplitDocument.m
//  AudioSlicer
//
//  Created by Bernd Heller on Thu Feb 05 2004.
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

#import "SplitDocument.h"
#import "ProgressPanel.h"

#include <sys/time.h>
#include <sys/resource.h>


#define PROFILING_START \
{ \
	struct rusage	usage1, usage2; \
	NSLog(@"start sampling"); \
	getrusage(RUSAGE_SELF, &usage1); \
	
#define PROFILING_STOP \
	getrusage(RUSAGE_SELF, &usage2); \
	NSLog(@"stop sampling"); \
	double  tuser = usage2.ru_utime.tv_sec + (usage2.ru_utime.tv_usec / 1000000.0); \
	double  tsystem = usage2.ru_stime.tv_sec + (usage2.ru_stime.tv_usec / 1000000.0); \
	tuser -= usage1.ru_utime.tv_sec + (usage1.ru_utime.tv_usec / 1000000.0); \
	tsystem -= usage1.ru_stime.tv_sec + (usage1.ru_stime.tv_usec / 1000000.0); \
	NSLog(@"usage: system = %.1f, user = %.1f, total = %.1f", tsystem, tuser, tsystem + tuser); \
}


@interface SplitDocument (Private)
- (void)updateUI;
- (void)continuousControlFinished:(NSNotification *)notification;
- (NSString *)findLostAudioFile:(NSString *)lostPath uniqueID:(size_t)lostFileID;
- (void)exportPanelDidEnd:(NSOpenPanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
- (void)writeSplitFilesTo:(NSString *)dirPath hideExtension:(BOOL)hideExtension;
- (NSString *)filenameUsingFormat:(NSString *)format forSlice:(AudioSlice *)slice;
- (void)modelDidChange:(NSNotification *)notification;
- (void)progressDidChange:(NSNotification *)notification;
- (void)analyzingDidFinish:(NSNotification *)notification;
@end

NSString	*SplitDocumentContinuousControlFinishedNotification = @"SplitDocumentContinuousControlFinishedNotification";

#pragma mark -

@implementation SplitDocument

- (id)init
{
    if (self = [super init]) {
		NSUserDefaults		*defaults = [NSUserDefaults standardUserDefaults];
		playSilenceIntervalBefore = [[defaults objectForKey:@"PlayBeforeSilenceDuration"] doubleValue];
		playSilenceIntervalAfter = [[defaults objectForKey:@"PlayAfterSilenceDuration"] doubleValue];
		relativeSilenceSplitPoint = [[defaults objectForKey:@"RelativeSilenceSplitPoint"] doubleValue] / 100.0;
		audioFile = nil;
		audioSegmentTree = nil;
		
		continuousControlStartValue1 = -1.0;
		continuousControlStartValue2 = -1.0;
		continuousControlsUndoQueue = [[NSNotificationQueue alloc] initWithNotificationCenter:[NSNotificationCenter defaultCenter]];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(continuousControlFinished:)
													 name:SplitDocumentContinuousControlFinishedNotification
												   object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(modelDidChange:)
													 name:AudioSegmentTreeDidChangeNotification
												   object:nil];
    }
	
    return self;
}

- (void)dealloc
{
	[genreList release];
	
	[audioFile release];
	[audioSegmentTree release];
	
	[continuousControlsUndoQueue release];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[super dealloc];
}

- (NSString *)windowNibName
{
    return @"SplitDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
    [super windowControllerDidLoadNib:aController];
	[outlineViewController setAudioFile:audioFile audioSegmentTree:audioSegmentTree];
	
	[silenceRangeSlider setMinValue:[audioSegmentTree shortestSilenceInTree]];
	[silenceRangeSlider setMaxValue:[audioSegmentTree longestSilenceInTree]];
	
	genreList = (NSMutableArray *)[[[audioFile class] genreList] retain];
	
	toolbar = [[SplitDocumentToolbar alloc] initWithDocument:self];
	
	[[aController window] setDelegate:self];
	if (documentID == 0) {
		// give a document id for this new document, set frame like last window and auto-cascade
		documentID = (NSUInteger)[[NSDate date] timeIntervalSince1970];
		[aController setWindowFrameAutosaveName:[NSString stringWithFormat:@"DocumentWindow-%lu", documentID]];
		[self updateChangeCount:NSChangeDone];
		[[aController window] setFrameUsingName:@"DocumentWindow"];
		[aController setShouldCascadeWindows:YES];
	} else {
		[aController setWindowFrameAutosaveName:[NSString stringWithFormat:@"DocumentWindow-%lu", documentID]];
		[aController setShouldCascadeWindows:NO];
	}
	
	if (documentWasModifiedDuringOpen) {
		[self updateChangeCount:NSChangeDone];
	}
	
	[self updateUI];
	
#if 0
	[NSTimer scheduledTimerWithTimeInterval:0.1
									 target:self
								   selector:@selector(randomizeSelection:)
								   userInfo:nil
									repeats:YES];
#endif
}

#if 0
- (void)randomizeSelection:(void *)userInfo
{
	static NSInteger		row = 0;
	[outlineView selectRow:row byExtendingSelection:NO];
	[outlineViewController playButtonClicked:outlineView];
	row += 2;
	if (row > 25) {
		row -= 25;
	}
	return;
	
	row += ((NSInteger)(4.0 * ((double)rand() / RAND_MAX))) - 2;
	if (row < 0) {
		row = 20;
	}
	if (row > 20) {
		row = 0;
	}
	return;
	
	NSInteger		rowCount = [outlineView numberOfRows];
	NSInteger		count = 1;(NSInteger)(10.0 * ((double)rand() / RAND_MAX));
	[outlineView deselectAll:self];
	while (count--) {
		NSInteger		row = (NSInteger)(rowCount * ((double)rand() / RAND_MAX));
		[outlineView selectRow:row
		  byExtendingSelection:YES];
	}
	[outlineViewController playButtonClicked:outlineView];
}
#endif

- (void)windowDidResize:(NSNotification *)aNotification
{
	// save the default document size
	NSWindow	*window = [aNotification object];
	[window saveFrameUsingName:@"DocumentWindow"];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
	// stop playing
	[audioFile abortPlaying];
	
	// get rid of the KV-observing toolbar
	[toolbar unbind];
	[toolbar release];
	
	// save the default document size
	NSWindow	*window = [aNotification object];
	[window saveFrameUsingName:@"DocumentWindow"];
}

- (NSData *)dataRepresentationOfType:(NSString *)aType
{
	if ([aType isEqualToString:@"AudioSlicer Document"]) {
		NSMutableData   *data = [NSMutableData data];
		NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
		
		[archiver encodeInt64:documentID forKey:@"documentID"];
		[archiver encodeObject:audioFile forKey:@"audioFile"];
		[archiver encodeObject:audioSegmentTree forKey:@"audioSegmentTree"];
		[archiver encodeDouble:playSilenceIntervalBefore forKey:@"playSilenceIntervalBefore"];
		[archiver encodeDouble:playSilenceIntervalAfter forKey:@"playSilenceIntervalAfter"];
		
		[archiver finishEncoding];
		[archiver release];
		
		return data;
	} else {
		return nil;
	}
}

- (BOOL)loadDataRepresentation:(NSData *)data ofType:(NSString *)aType
{
	if ([aType isEqualToString:@"AudioSlicer Document"]) {
		NSKeyedUnarchiver   *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
		
		documentWasModifiedDuringOpen = NO;
		documentID = [unarchiver decodeInt64ForKey:@"documentID"];
		
		do {
			[audioFile release];
			audioFile = [[unarchiver decodeObjectForKey:@"audioFile"] retain];
			if ([audioFile hasFileChanged]) {
				// the file specified in the archived object could not be found or was changed, find it and try again
				NSString	*newPath = [self findLostAudioFile:[audioFile filePath] uniqueID:[audioFile uniqueFileID]];
				if (newPath) {
					[audioFile fileHasMovedToPath:newPath];
					documentWasModifiedDuringOpen = YES;
				} else {
					return NO;
				}
			} else {
				break;
			}
		} while (1);
		
		audioSegmentTree = [[unarchiver decodeObjectForKey:@"audioSegmentTree"] retain];
		[audioSegmentTree setUndoManager:[self undoManager]];
		[outlineViewController setAudioFile:audioFile audioSegmentTree:audioSegmentTree];
		
		playSilenceIntervalBefore = [unarchiver decodeDoubleForKey:@"playSilenceIntervalBefore"];
		playSilenceIntervalAfter = [unarchiver decodeDoubleForKey:@"playSilenceIntervalAfter"];
		
		[unarchiver finishDecoding];
		[unarchiver release];
		
		return YES;
	} else {
		return NO;
	}
}

- (BOOL)readFromFile:(NSString *)fileName ofType:(NSString *)docType
{
	if ([docType isEqualToString:@"MP3 Document"]) {
		NSUserDefaults  *defaults = [NSUserDefaults standardUserDefaults];
		audioFile = [[AudioFile audioFileWithPath:fileName] retain];
		
		progressPanel = [ProgressPanel progressPanelWithTitle:@"Analyzing File..."
												  messageText:@"Finding all silences in file"
													 minValue:[audioFile progressMinValue]
													 maxValue:[audioFile progressMaxValue]];
		
		// register for progress and finished notifications
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(progressDidChange:)
													 name:AudioFileProgressChangedNotification
												   object:audioFile];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(analyzingDidFinish:)
													 name:AudioFileAnalyzingFinishedNotification
												   object:audioFile];
		
		// kick off the analyzer thread
		[audioFile analyzeSilencesLongerThan:[[defaults objectForKey:@"SilenceDurationThreshold"] doubleValue]
								 quieterThan:([[defaults objectForKey:@"SilenceVolumeThreshold"] doubleValue] / 100.0)];
		
		// run modally now until thread finishes
		[progressPanel runModalForWindow];
		
		// unregister ourselves as observer
		[[NSNotificationCenter defaultCenter] removeObserver:self
														name:AudioFileProgressChangedNotification
													  object:audioFile];
		[[NSNotificationCenter defaultCenter] removeObserver:self
														name:AudioFileAnalyzingFinishedNotification
													  object:audioFile];
		
		audioSegmentTree = [[audioFile audioSegmentTree] retain];
		[audioSegmentTree setUndoManager:[self undoManager]];
		if (audioSegmentTree == nil) {
			return NO;
		}
		
		[self setFileType:@"AudioSlicer Document"];
		[self setFileName:nil];
		documentWasModifiedDuringOpen = YES;
		
		return YES;
	} else {
		return [super readFromFile:fileName ofType:docType];
	}
}

- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel
{
	if ([self fileName] == nil) {
		NSString	*suggestedFileName = [[[[audioFile filePath] lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"split"];
		[self setFileName:suggestedFileName];
	}
	
	return YES;
}

- (void)runModalSavePanelForSaveOperation:(NSSaveOperationType)saveOperation delegate:(id)delegate didSaveSelector:(SEL)didSaveSelector contextInfo:(void *)contextInfo
{
	[super runModalSavePanelForSaveOperation:(NSSaveOperationType)saveOperation
									delegate:self
							 didSaveSelector:@selector(document:didSave:contextInfo:)
								 contextInfo:[self fileName]];
}

- (void)document:(NSDocument *)doc didSave:(BOOL)didSave contextInfo:(void *)contextInfo
{
	if (!didSave) {
		[self setFileName:contextInfo];
	}
}

- (BOOL)validateMenuItem:(NSMenuItem *)anItem
{
	if ([anItem action] == @selector(joinSelection:)) {
		return [outlineViewController canJoinSelectedItems];
	}
	if ([anItem action] == @selector(splitSelection:)) {
		return [outlineViewController canSplitSelectedItems];
	}
	if ([anItem action] == @selector(collapseSelection:)) {
		return [outlineViewController canCollapseSelectedItems];
	}
	if ([anItem action] == @selector(expandSelection:)) {
		return [outlineViewController canExpandSelectedItems];
	}
	if ([anItem action] == @selector(renameSlicesSerially:)) {
		return ([[self sliceSelection] count] > 1);
	}
	if ([anItem action] == @selector(renumberSlicesSerially:)) {
		return ([[self sliceSelection] count] > 1);
	}
	if ([anItem action] == @selector(breakDownSlices:) || [anItem action] == @selector(breakDownSlicesAgain:)) {
		return ([[self sliceSelection] count] >= 1);
	}
	if ([anItem action] == @selector(playPrevSilence:)) {
		return YES;
	}
	if ([anItem action] == @selector(playNextSilence:)) {
		return YES;
	}
	
	return [super validateMenuItem:anItem];
}

#pragma mark -

- (NSUInteger)documentID
{
	return documentID;
}

- (IBAction)modalOK:(id)sender
{
	[NSApp stopModal];
}

- (IBAction)modalCancel:(id)sender
{
	[NSApp abortModal];
}

- (IBAction)exportSplitted:(id)sender
{
	NSOpenPanel		*exportPanel = [NSOpenPanel openPanel];
	
	[exportPanel setCanChooseFiles:NO];
	[exportPanel setCanChooseDirectories:YES];
	[exportPanel setAllowsMultipleSelection:NO];
	[exportPanel setCanCreateDirectories:YES];
	[exportPanel setCanSelectHiddenExtension:YES];
	
	[exportPanel setTitle:@"Export Splitted"];
	[exportPanel setMessage:@"Select Directory To Export Split Files To"];
	[exportPanel setPrompt:@"Export"];
	[exportPanel setNameFieldLabel:@"Export Split Files To:"];
	
	[exportPanel setAccessoryView:exportPanelView];
	
	[exportPanel beginSheetForDirectory:nil
								   file:nil
								  types:nil
						 modalForWindow:[self windowForSheet]
						  modalDelegate:self
						 didEndSelector:@selector(exportPanelDidEnd:returnCode:contextInfo:)
							contextInfo:nil];
}

- (IBAction)joinSelection:(id)sender
{
	[outlineViewController joinSelectedItems];
}

- (IBAction)splitSelection:(id)sender
{
	[outlineViewController splitSelectedItems];
}

- (IBAction)collapseSelection:(id)sender
{
	[outlineViewController collapseSelectedItems];
}

- (IBAction)expandSelection:(id)sender
{
	[outlineViewController expandSelectedItems];
}

- (IBAction)renameSlicesSerially:(id)sender
{
	[renameSeriallyStartName setStringValue:[[[self sliceSelection] objectAtIndex:0] title]];
	[NSApp beginSheet:renameSeriallyPanel
	   modalForWindow:[self windowForSheet]
		modalDelegate:nil
	   didEndSelector:nil
		  contextInfo:nil];
	
	if ([NSApp runModalForWindow:renameSeriallyPanel] == NSRunStoppedResponse) {
		// force end editing
		if (![renameSeriallyPanel makeFirstResponder:renameSeriallyPanel]) {
			[renameSeriallyPanel endEditingFor:nil];
		}
		
		NSString	*startName = [renameSeriallyStartName stringValue];
		NSRange		numberRange = [startName rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet]
															 options:NSBackwardsSearch];
		while (numberRange.location > 0 && [[NSCharacterSet decimalDigitCharacterSet] characterIsMember:[startName characterAtIndex:(numberRange.location - 1)]]) {
			numberRange.location--;
			numberRange.length++;
		}
		
		NSString	*prefix = [startName substringToIndex:numberRange.location];
		NSString	*suffix = [startName substringFromIndex:numberRange.location + numberRange.length];
		NSInteger	index = [[startName substringWithRange:numberRange] integerValue];
		NSString	*format = [NSString stringWithFormat:@"%%0%ldd", (long)[[NSUserDefaults standardUserDefaults] integerForKey:@"RenameSeriallyPaddingLength"]];
		
		NSEnumerator	*slices = [[self sliceSelection] objectEnumerator];
		AudioSlice		*slice;
		while (slice = [slices nextObject]) {
			[slice setTitle:[NSString stringWithFormat:@"%@%@%@",
				prefix,
				[NSString stringWithFormat:format, index++],
				suffix]];
		}
		[[self undoManager] setActionName:@"Rename Slices Serially"];
	}
	
	[NSApp endSheet:renameSeriallyPanel];
	[renameSeriallyPanel orderOut:self];
}

- (IBAction)renumberSlicesSerially:(id)sender
{
	NSEnumerator	*slices = [[self sliceSelection] objectEnumerator];
	AudioSlice		*slice;
	NSInteger				startTrack = [[[self sliceSelection] objectAtIndex:0] trackNumber];
	while (slice = [slices nextObject]) {
		[slice setTrackNumber:startTrack++];
	}
	[[self undoManager] setActionName:@"Renumber Tracks Serially"];
}

- (IBAction)breakDownSlices:(id)sender
{
	[NSApp beginSheet:breakDownSlicesPanel
	   modalForWindow:[self windowForSheet]
		modalDelegate:nil
	   didEndSelector:nil
		  contextInfo:nil];
	
	if ([NSApp runModalForWindow:breakDownSlicesPanel] == NSRunStoppedResponse) {
		// force end editing
		if (![breakDownSlicesPanel makeFirstResponder:breakDownSlicesPanel]) {
			[breakDownSlicesPanel endEditingFor:nil];
		}
		
		[self breakDownSlicesAgain:self];
	}
	
	[NSApp endSheet:breakDownSlicesPanel];
	[breakDownSlicesPanel orderOut:self];
}

- (IBAction)breakDownSlicesAgain:(id)sender
{
	double averageDuration = [[NSUserDefaults standardUserDefaults] integerForKey:@"BreakDownSlicesSegmentDurationMinutes"] * 60.0;
	double tolerance = [[NSUserDefaults standardUserDefaults] integerForKey:@"BreakDownSlicesSegmentDurationTolerance"]/100.0;
	
	NSMutableArray	*selectedSlices = [[[self sliceSelection] copy] autorelease];
	NSEnumerator	*slices = [selectedSlices objectEnumerator];
	AudioSlice		*slice;
	while (slice = [slices nextObject]) {
		[slice breakDownToAverageDuration:averageDuration tolerance:tolerance];
	}
	[[self undoManager] setActionName:@"Break Down Slices"];
}

#pragma mark -

- (IBAction)playPrevSilence:(id)sender
{
	AudioSegmentNode	*s = [outlineViewController prevSilence];
	if (s) {
		[outlineView selectRow:[outlineView rowForItem:s] byExtendingSelection:NO];
		[outlineView scrollRowToVisible:[outlineView selectedRow]];
		[outlineViewController playButtonClicked:outlineView];
	}
}

- (IBAction)playNextSilence:(id)sender
{
	AudioSegmentNode	*s = [outlineViewController nextSilence];
	if (s) {
		[outlineView selectRow:[outlineView rowForItem:s] byExtendingSelection:NO];
		[outlineView scrollRowToVisible:[outlineView selectedRow]];
		[outlineViewController playButtonClicked:outlineView];
	}
}


- (IBAction)setSilenceRange:(id)sender
{
	if (sender == minSilenceField) {
		[silenceRangeSlider setIntervalStart:[sender doubleValue]];
	} else if (sender == maxSilenceField) {
		[silenceRangeSlider setIntervalEnd:[sender doubleValue]];
	}
	
	if (continuousControlStartValue1 < 0.0) {
		[[self undoManager] disableUndoRegistration];
		continuousControlStartValue1 = [audioSegmentTree minSilenceDuration];
		continuousControlStartValue2 = [audioSegmentTree maxSilenceDuration];
	}
	[continuousControlsUndoQueue enqueueNotification:[NSNotification notificationWithName:SplitDocumentContinuousControlFinishedNotification object:sender]
										postingStyle:NSPostWhenIdle
										coalesceMask:(NSNotificationCoalescingOnName | NSNotificationCoalescingOnSender)
											forModes:nil];
	
	[audioSegmentTree setSilenceRangeMin:[silenceRangeSlider intervalStart] max:[silenceRangeSlider intervalEnd]];
	
	// keep selection
	id  selection = [outlineView itemAtRow:[outlineView selectedRow]];
	[outlineView reloadData];
	[outlineView selectRow:[outlineView rowForItem:selection] byExtendingSelection:NO];
	[outlineView scrollRowToVisible:[outlineView selectedRow]];
	
	[self updateUI];
}


- (IBAction)setPlaySilenceInterval:(id)sender
{
	[self setPlaySilenceIntervalBefore:[playBeforeSilenceField doubleValue]];
	[self setPlaySilenceIntervalAfter:[playAfterSilenceField doubleValue]];
}

- (void)setPlaySilenceIntervalBefore:(double)before
{
	if (playSilenceIntervalBefore != before) {
		[[[self undoManager] prepareWithInvocationTarget:self] setPlaySilenceIntervalBefore:playSilenceIntervalBefore];
		playSilenceIntervalBefore = before;
	}
}

- (double)playSilenceIntervalBefore
{
	return playSilenceIntervalBefore;
}

- (void)setPlaySilenceIntervalAfter:(double)after
{
	if (playSilenceIntervalAfter != after) {
		[[[self undoManager] prepareWithInvocationTarget:self] setPlaySilenceIntervalAfter:playSilenceIntervalAfter];
		playSilenceIntervalAfter = after;
	}
}

- (double)playSilenceIntervalAfter
{
	return playSilenceIntervalAfter;
}


- (void)playSilence:(AudioSegmentNode *)silenceSegment
{
	double  start = [silenceSegment startTime];
	double  end = [silenceSegment endTime];
	double  center = start + ([silenceSegment duration] / 2.0);
	
	if (playSilenceIntervalBefore == 0.0) {
		start = [silenceSegment endTime];
	} else {
		start -= playSilenceIntervalBefore;
	}
	if (playSilenceIntervalAfter == 0.0) {
		end = [silenceSegment startTime];
	} else {
		end += playSilenceIntervalAfter;
	}
	
	NSLog(@"playing silence from %.2f to %.2f", start, end);
	if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"PlaySilenceBeep"] boolValue]) {
		[audioFile startPlayingFrom:start to:end overlayBeepAt:(center - 0.05) beepDuration:0.1];
	} else {
		[audioFile startPlayingFrom:start to:end];
	}
}

- (void)playTitle:(AudioSegmentNode *)titleSegment
{
	double  start = [titleSegment startTime];
	double  end = [titleSegment endTime];
	
	NSLog(@"playing title from %.2f to %.2f", start, end);
	[audioFile startPlayingFrom:start to:end];
}

- (void)playSlice:(AudioSlice *)slice
{
	double  start = [slice leftSilenceSegment] ? [[slice leftSilenceSegment] endTime] : 0.0;
	double  end = [slice rightSilenceSegment] ? [[slice rightSilenceSegment] startTime] : AudioFileEndTime;
	
	NSLog(@"playing slice from %.2f to %.2f", start, end);
	[audioFile startPlayingFrom:start to:end];
}

#pragma mark -

- (NSMutableArray *)selection
{
	return [outlineViewController selectedItems];
}

- (NSMutableArray *)sliceSelection
{
	return [outlineViewController selectedSlices];
}

- (NSMutableArray *)genreList
{
	return genreList;
}

- (NSArray *)exportFilenameFormats
{
	NSUserDefaults  *defaults = [NSUserDefaults standardUserDefaults];
	NSArray			*customList = [defaults arrayForKey:@"ExportFilenameFormatsCustom"];
	NSArray			*presetList = [defaults arrayForKey:@"ExportFilenameFormatsPreset"];
	NSMutableArray  *joinedList = [[presetList mutableCopy] autorelease];
	
	[joinedList addObjectsFromArray:customList];
	
	return joinedList;
}

@end

#pragma mark -

@implementation SplitDocument (Private)

- (void)updateUI
{
	// first move sliders to the ends, so setting one isn't hindered by the other
	[silenceRangeSlider setIntervalStart:[silenceRangeSlider minValue]];
	[silenceRangeSlider setIntervalEnd:[silenceRangeSlider maxValue]];
	[silenceRangeSlider setIntervalStart:[audioSegmentTree minSilenceDuration]];
	[silenceRangeSlider setIntervalEnd:[audioSegmentTree maxSilenceDuration]];
	[minSilenceField setDoubleValue:[silenceRangeSlider intervalStart]];
	[maxSilenceField setDoubleValue:[silenceRangeSlider intervalEnd]];
	
	[playBeforeSilenceField setDoubleValue:[self playSilenceIntervalBefore]];
	[playAfterSilenceField setDoubleValue:[self playSilenceIntervalAfter]];
	
	[[self windowForSheet] update];
}

- (void)continuousControlFinished:(NSNotification *)notification
{
	[[self undoManager] enableUndoRegistration];
	
	if ([notification object] == silenceRangeSlider) {
		[(AudioSegmentTree *)[[self undoManager] prepareWithInvocationTarget:audioSegmentTree] setSilenceRangeMin:continuousControlStartValue1 max:continuousControlStartValue2];
		[[self undoManager] setActionName:@"Change Silence Range"];
	}
	
	continuousControlStartValue1 = -1.0;
}

- (NSString *)findLostAudioFile:(NSString *)lostPath uniqueID:(size_t)lostFileID
{
	while (1) {
		NSOpenPanel		*choosePanel = [NSOpenPanel openPanel];
		
		[choosePanel setCanChooseFiles:YES];
		[choosePanel setCanChooseDirectories:NO];
		[choosePanel setAllowsMultipleSelection:NO];
		[choosePanel setTitle:[NSString stringWithFormat:@"Find %@", [lostPath lastPathComponent]]];
		[choosePanel setMessage:[NSString stringWithFormat:@"Find lost file which was formerly located at %@", lostPath]];
		[choosePanel setPrompt:@"Choose"];
		[choosePanel setNameFieldLabel:@"Choose:"];
		
		NSInteger result = [choosePanel runModalForDirectory:[lostPath stringByDeletingLastPathComponent]
														file:nil
													   types:[NSArray arrayWithObject:[audioFile fileExtension]]];
		if (result == NSOKButton) {
			return [[choosePanel filenames] objectAtIndex:0];
		} else {
			return nil;
		}
	}
}

- (void)exportPanelDidEnd:(NSOpenPanel *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
	[sheet setAccessoryView:nil];
	
	if (returnCode == NSOKButton) {
		// add currently entered format to custom format list
		NSUserDefaults  *defaults = [NSUserDefaults standardUserDefaults];
		NSString		*chosenFormat = [defaults objectForKey:@"PreferredExportFilenameFormat"];
		NSMutableArray  *customFormats = [[[defaults arrayForKey:@"ExportFilenameFormatsCustom"] mutableCopy] autorelease];
		if ([customFormats indexOfObject:chosenFormat] == NSNotFound &&
			[[defaults arrayForKey:@"ExportFilenameFormatsPreset"] indexOfObject:chosenFormat] == NSNotFound) {
			// this implements a 10 object long fifo
			if ([customFormats count] >= 10) {
				[customFormats removeLastObject];
			}
			if ([customFormats count] == 0) {
				[customFormats addObject:chosenFormat];
			} else {
				[customFormats insertObject:chosenFormat atIndex:0];
			}
			[self willChangeValueForKey:@"exportFilenameFormats"];
			[defaults setObject:customFormats forKey:@"ExportFilenameFormatsCustom"];
			[self didChangeValueForKey:@"exportFilenameFormats"];
		}
		
		// export files
		NSArray		*selection = [sheet filenames];
		if ([selection count] == 1) {
			[self writeSplitFilesTo:[selection objectAtIndex:0] hideExtension:[sheet isExtensionHidden]];
		}
	}
}

- (void)writeSplitFilesTo:(NSString *)dirPath hideExtension:(BOOL)hideExtension
{
	BOOL			overwriteAll = NO;
	NSString		*chosenFormat = [[NSUserDefaults standardUserDefaults] objectForKey:@"PreferredExportFilenameFormat"];
	
	progressPanel = [ProgressPanel progressPanelWithTitle:@"Exporting Splitted..."
											  messageText:@""
												 minValue:0
												 maxValue:[audioSegmentTree numberOfSlices]];
	[progressPanel beginModalSheetForWindow:[self windowForSheet]];
	
	for (NSInteger i = 0; i < [audioSegmentTree numberOfSlices]; i++) {
		AudioSlice			*s = [audioSegmentTree sliceAtIndex:i];
		AudioSegmentNode	*left = [s leftSilenceSegment];
		AudioSegmentNode	*right = [s rightSilenceSegment];
		NSString			*filePath = [dirPath stringByAppendingPathComponent:[self filenameUsingFormat:chosenFormat forSlice:s]];
		double				start = 0.0;
		double				end = AudioFileEndTime;
		
		if (left) {
			start = [left endTime];
			start -= ([left duration] * (1.0 - relativeSilenceSplitPoint));
		}
		if (right) {
			end = [right startTime];
			end += ([right duration] * relativeSilenceSplitPoint);
		}
		
		[progressPanel setMessageText:[NSString stringWithFormat:@"Writing %@", [filePath lastPathComponent]]];
		[progressPanel setProgress:(i + 1)];
		[progressPanel runModal];
		if ([progressPanel shouldCancel]) {
			break;
		}
		
		if ([[NSFileManager defaultManager] fileExistsAtPath:filePath] && overwriteAll == NO) {
			NSInteger result = NSRunAlertPanel(@"File Exists", [NSString stringWithFormat:@"The File '%@' exists already. Do you really want to go on and overwrite it?", filePath],
										 @"Cancel", @"Overwrite All", @"Overwrite");
			if (result == NSAlertDefaultReturn) {
				break;
			} else if (result == NSAlertAlternateReturn) {
				overwriteAll = YES;
			}
		}
		[audioFile writeToFile:filePath from:start to:end];
		[AudioFile writeTags:[s tagsFromAttributes] toFile:filePath];
		[[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:hideExtension], NSFileExtensionHidden, nil]
													  atPath:filePath];
	}
	
	[progressPanel endModalSheet];
}

- (NSString *)filenameUsingFormat:(NSString *)format forSlice:(AudioSlice *)slice
{
	NSMutableString		*name = [[format mutableCopy] autorelease];
	NSUInteger			trackNumberDigits = [(NSString *)[NSString stringWithFormat:@"%ld", [slice trackCount]] length];
	NSUInteger			cdNumberDigits = [(NSString *)[NSString stringWithFormat:@"%ld", [slice cdCount]] length];
	NSString			*key;
	NSEnumerator		*keys = [[NSArray arrayWithObjects:@"title", @"artist", @"album", @"composer", @"genre", @"year",
														   @"trackNumber", @"trackCount", @"cdNumber", @"cdCount",
														   nil] objectEnumerator];
	
	while (key = [keys nextObject]) {
		id  replacement = [slice valueForKey:key];
		if (replacement) {
			if (trackNumberDigits > 0 && [key isEqualToString:@"trackNumber"]) {
				replacement = [NSString stringWithFormat:[NSString stringWithFormat:@"%%0%lud", (unsigned long)trackNumberDigits], [replacement integerValue]];
			} else if (cdNumberDigits > 0 && [key isEqualToString:@"cdNumber"]) {
				replacement = [NSString stringWithFormat:[NSString stringWithFormat:@"%%0%lud", (unsigned long)cdNumberDigits], [replacement integerValue]];
			}
		} else {
			replacement = @"";
		}
		[name replaceOccurrencesOfString:[NSString stringWithFormat:@"[%@]", key]
							  withString:[NSString stringWithFormat:@"%@", replacement]
								 options:NSCaseInsensitiveSearch
								   range:NSMakeRange(0, [name length])];
	}
	
	[name replaceOccurrencesOfString:@":" withString:@"_" options:0 range:NSMakeRange(0, [name length])];
	[name replaceOccurrencesOfString:@"/" withString:@":" options:0 range:NSMakeRange(0, [name length])];
	
	return [name stringByAppendingPathExtension:[audioFile fileExtension]];
}

- (void)modelDidChange:(NSNotification *)notification
{
	[self updateUI];
}

- (void)progressDidChange:(NSNotification *)notification
{
	[progressPanel setProgress:[audioFile progressValue]];
	if ([progressPanel shouldCancel]) {
		[audioFile abortAnalyzing];
	}
}

- (void)analyzingDidFinish:(NSNotification *)notification
{
	[progressPanel endModalPanel];
}

@end
