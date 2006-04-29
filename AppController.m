//
//  AppController.m
//  Jumpcut
//
//  Created by Steve Cook on 4/3/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//
//  This code is open-source software subject to the MIT License; see the homepage
//  at <http://jumpcut.sourceforge.net/> for details.

#import "AppController.h"
#import "PTHotKey.h"
#import "PTHotKeyCenter.h"

@implementation AppController

- (void)awakeFromNib
{
	// Set up the bezel window
    NSSize windowSize = NSMakeSize(325.0, 325.0);
    NSSize screenSize = [[NSScreen mainScreen] frame].size;
	NSRect windowFrame = NSMakeRect( (screenSize.width - windowSize.width) / 2,
                                     (screenSize.height - windowSize.height) / 3,
									 windowSize.width, windowSize.height );
	bezel = [[BezelWindow alloc] initWithContentRect:windowFrame
										   styleMask:NSBorderlessWindowMask
											 backing:NSBackingStoreBuffered
											   defer:NO];
	[bezel setDelegate:self];
	// Initialize the JumpcutStore
    clippingStore = [[JumpcutStore alloc] initRemembering:25
											   displaying:40
										withDisplayLength:40];
	// Create our pasteboard interface
    jcPasteboard = [NSPasteboard generalPasteboard];
    [jcPasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    pbCount = [[NSNumber numberWithInt:[jcPasteboard changeCount]] retain];
    NSLog(@"Starting changeCount: %d", [pbCount intValue]);

	// Build the statusbar menu
    statusItem = [[[NSStatusBar systemStatusBar]
            statusItemWithLength:NSSquareStatusItemLength] retain];
    [statusItem setHighlightMode:YES];
    [statusItem setTitle:[NSString stringWithFormat:@"%C",0x2702]]; 
    [statusItem setMenu:jcMenu];
    [statusItem setEnabled:YES];
	
    // If our preferences indicate that we are saving, load the dictionary from the saved plist
    // and use it to get everything set up.
    [self loadEngineFromPList];
	
	// Build our listener timer
    pollPBTimer = [[NSTimer scheduledTimerWithTimeInterval:(1.0)
													target:self
												  selector:@selector(pollPB:)
												  userInfo:nil
												   repeats:YES] retain];
	
    // Finish up
    pbBlockCount = [[NSNumber numberWithInt:0] retain];
    [pollPBTimer fire];

	// Forcing this to a value just to get it working
	// until the preferences are up.
	// sbc
	jcDisplayNum = 15;

	NSLog(@"Jumpcut running: init complete.");
		
    [super init];
}

-(IBAction) showPreferencePanel:(id)sender
{
    if ( ![prefsPanel isVisible] ) {
		[NSApp activateIgnoringOtherApps: YES];
        [prefsPanel makeKeyAndOrderFront:self];
    } else {
		[NSApp activateIgnoringOtherApps: YES];
        [prefsPanel makeKeyAndOrderFront:self];
    }
}


- (void)metaKeysReleased
{
	if ( ! isBezelPinned )
	{
		[self hideBezel];
	}
}

-(void)pollPB:(NSTimer *)timer
{
    NSString *type = [jcPasteboard availableTypeFromArray:[NSArray arrayWithObject:NSStringPboardType]];
    if ( [pbCount intValue] != [jcPasteboard changeCount] ) {
        // Reload pbCount with the current changeCount
        // Probably poor coding technique, but pollPB should be the only thing messing with pbCount, so it should be okay
        [pbCount release];
        pbCount = [[NSNumber numberWithInt:[jcPasteboard changeCount]] retain];
        if ( type != nil ) {
			NSString *contents = [jcPasteboard stringForType:type];
			if ( contents == nil ) {
                NSLog(@"Contents: Empty");
            } else {
				if (( [clippingStore jcListCount] == 0 || ! [contents isEqualToString:[clippingStore clippingContentsAtPosition:0]])
					&&  ! [pbCount isEqualTo:pbBlockCount] ) {
                    [clippingStore addClipping:contents
										ofType:type	];
					/* Okay, here's where we need to decide what to do when something is pasted:
					From the beginning, JC tracked the last item pasted, but this proved to be a giant pain in actual use.
					However, that stickiness may be useful in certain circumstances. 0.6 or a later 0.5 version will
					provide an option of some kind for users to choose what they track.
					Options seem like they can be
					Last Selected (default)
					[popup setTrackingInt:0] on copy, [popup setTrackingInt:foo] on paste
					Last Pasted
					[popup moveTrackingInt:1 withBounce:YES] on copy, [popup setTrackingInt:foo] on paste
					Track downwards/Track upwards
					NC on copy; [popup moveTrackingInt:1/-1 withBounce:YES] on paste
					Last Copied
					[popup setTrackingInt:0] on copy, NC on paste
					*/
					stackPosition = 0;
                    [self updateMenu];
                    if ( [savePreference isEqualToString:@"onChange"] ) {
                        [self saveEngine];
                    }
                }
            }
        } else {
            NSLog(@"Contents: Non-string");
        }
    }
	
}

- (void)processBezelKeyDown:(NSEvent *)theEvent
{
	// AppControl should only be getting these directly from bezel via delegation
	if ( [theEvent type] == NSKeyDown )
	{
		int scratch;
		NSString *pressedKey = [theEvent charactersIgnoringModifiers];
		NSLog(@"Pressed: %@", pressedKey);
	}
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	//Create our hot key
	mainHotKey = [[PTHotKey alloc] initWithIdentifier:@"mainHotKey"
											   keyCombo:[PTKeyCombo keyComboWithKeyCode:[mainRecorder keyCombo].code
																			  modifiers:[mainRecorder cocoaToCarbonFlags: [mainRecorder keyCombo].flags]]];
	mainHotkeyModifiers = [mainRecorder cocoaToCarbonFlags:[mainRecorder keyCombo].flags];
	NSLog(@"Hotkey modifiers: %d", mainHotkeyModifiers);
	[mainHotKey setName: @"Activate Bezel HotKey"]; //This is typically used by PTKeyComboPanel
	[mainHotKey setTarget: self];
	[mainHotKey setAction: @selector( hitMainHotKey: ) ];
	
	//Register it
	[[PTHotKeyCenter sharedCenter] registerHotKey: mainHotKey];
}

- (void) showBezel
{
	[bezel makeKeyAndOrderFront:nil];
	isBezelDisplayed = YES;
}

- (void) hideBezel
{
	[bezel orderOut:nil];
	isBezelDisplayed = NO;
}

- (IBAction)dummyShow:(id)sender
{
	[self showBezel];
	isBezelPinned = YES;
	return;
}

- (IBAction)dummyHide:(id)sender
{
	[self hideBezel];
	isBezelPinned = NO;
	return;
}

- (void) applicationWillResignActive:(NSApplication *)app; {
	// This should be hidden anyway, but just in case it's not.
    [self hideBezel];
}


- (void)hitMainHotKey:(PTHotKey *)hotKey
{
	if ( ! isBezelDisplayed ) {
		[NSApp activateIgnoringOtherApps:YES];
		[self showBezel];
	} else {
		NSLog(@"Hotkey pressed, bezel already active.");
	}
}

- (IBAction)toggleMainHotKey:(id)sender
{
	if (mainHotKey != nil)
	{
		NSLog(@"Unregistering.");
		[[PTHotKeyCenter sharedCenter] unregisterHotKey:mainHotKey];
		[mainHotKey release];
		mainHotKey = nil;
	}
	
	mainHotKey = [[PTHotKey alloc] initWithIdentifier:@"mainHotKey"
											   keyCombo:[PTKeyCombo keyComboWithKeyCode:[mainRecorder keyCombo].code
																			  modifiers:[mainRecorder cocoaToCarbonFlags: [mainRecorder keyCombo].flags]]];
	
	[mainHotKey setTarget: self];
	[mainHotKey setAction: @selector(hitMainHotKey:)];
	
	[[PTHotKeyCenter sharedCenter] registerHotKey:mainHotKey];
}

- (void)updateMenu {
    int passedSeparator = 0;
    NSMenuItem *oldItem;
    NSMenuItem *item;
    NSString *pbMenuTitle;
    NSArray *returnedDisplayStrings = [clippingStore previousDisplayStrings:jcDisplayNum];
    NSEnumerator *menuEnumerator = [[jcMenu itemArray] reverseObjectEnumerator];
    NSEnumerator *clipEnumerator = [returnedDisplayStrings reverseObjectEnumerator];
	
    //remove clippings from menu
    while( oldItem = [menuEnumerator nextObject] ) {
		if( [oldItem isSeparatorItem]) {
            passedSeparator++;
        } else if ( passedSeparator == 2 ) {
            [jcMenu removeItem:oldItem];
        }
    }
	
    while( pbMenuTitle = [clipEnumerator nextObject] ) {
        item = [[NSMenuItem alloc] initWithTitle:pbMenuTitle
										  action:@selector(addClipToPasteboardFromMenu:)
								   keyEquivalent:@""];
        [item setTarget:self];
        [item setEnabled:YES];
        [jcMenu insertItem:item atIndex:0];
        // Way back in 0.2, failure to release the new item here was causing a quite atrocious memory leak.
        [item release];
	} 
}

-(IBAction)addClipToPasteboardFromMenu:(id)sender
{
    int index=[[sender menu] indexOfItem:sender];
    [self addClipToPasteboardFromCount:index];
}

-(BOOL) isValidClippingNumber:(NSNumber *)number {
    return ( ([number intValue] + 1) <= [clippingStore jcListCount] );
}

-(NSString *) clippingStringWithCount:(int)count {
    if ( [self isValidClippingNumber:[NSNumber numberWithInt:count]] ) {
        return [clippingStore clippingContentsAtPosition:count];
    } else { // It fails -- we shouldn't be passed this, but...
        NSLog(@"Asked for non-existant clipping count: %d");
        return @"";
    }
}

-(void) setPBBlockCount:(NSNumber *)newPBBlockCount
{
    [newPBBlockCount retain];
    [pbBlockCount release];
    pbBlockCount = newPBBlockCount;
}

-(BOOL)addClipToPasteboardFromCount:(int)indexInt
{
    NSString *pbFullText;
    NSArray *pbTypes;
    if ( (indexInt + 1) > [clippingStore jcListCount] ) {
        // We're asking for a clipping that isn't there yet
		// This only tends to happen immediately on startup when not saving, as the entire list is empty.
        NSLog(@"Out of bounds request to jcList ignored.");
        return false;
    }
    pbFullText = [self clippingStringWithCount:indexInt];
    pbTypes = [NSArray arrayWithObjects:@"NSStringPboardType",NULL];
    
    [jcPasteboard declareTypes:pbTypes owner:NULL];
	
    [jcPasteboard setString:pbFullText forType:@"NSStringPboardType"];
    [self setPBBlockCount:[NSNumber numberWithInt:[jcPasteboard changeCount]]];
    return true;
}

-(void) loadEngineFromPList
{
    NSString *path = [[NSString stringWithString:@"~/Library/Application Support/Jumpcut/JCEngine.save"] 					stringByExpandingTildeInPath];
    NSDictionary *loadDict = [[NSDictionary alloc] initWithContentsOfFile:path];
    NSEnumerator *enumerator;
    NSDictionary *aSavedClipping;
    NSArray *savedJCList;
	NSRange loadRange;
	int rangeCap;
	
    if ( loadDict != nil ) {
        savedJCList = [loadDict objectForKey:@"jcList"];
        if ( [savedJCList isKindOfClass:[NSArray class]] ) {
			// There's probably a nicer way to prevent the range from going out of bounds, but this works.
			rangeCap = [savedJCList count] < [[NSUserDefaults standardUserDefaults] integerForKey:@"rememberNum"] ? [savedJCList count] : [[NSUserDefaults standardUserDefaults] integerForKey:@"rememberNum"];
			loadRange = NSMakeRange(0, rangeCap);
			enumerator = [[savedJCList subarrayWithRange:loadRange] reverseObjectEnumerator];
			while ( aSavedClipping = [enumerator nextObject] ) {
				[clippingStore addClipping:[aSavedClipping objectForKey:@"Contents"]
									ofType:[aSavedClipping objectForKey:@"Type"]];
            }
        }
        NSLog(@"Contents loaded from file.");
        [self updateMenu];
        [loadDict release];
    }
}

-(void) saveEngine
{
    NSMutableDictionary *saveDict;
    NSMutableArray *jcListArray = [NSMutableArray array];
    int i;
    BOOL isDir;
    NSString *path;
    path = [[NSString stringWithString:@"~/Library/Application Support/Jumpcut"] stringByExpandingTildeInPath];
    if ( ![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] || ! isDir ) {
        NSLog(@"Creating Application Support directory");
        [[NSFileManager defaultManager] createDirectoryAtPath:path
												   attributes:[NSDictionary dictionaryWithObjectsAndKeys:
													   @"NSFileModificationDate", [NSNull null],
													   @"NSFileOwnerAccountName", [NSNull null],
													   @"NSFileGroupOwnerAccountName", [NSNull null],
													   @"NSFilePosixPermissions", [NSNull null],
													   @"NSFileExtensionsHidden", [NSNull null],
													   nil]
			];
    }
	
    saveDict = [NSMutableDictionary dictionaryWithCapacity:3];
    [saveDict setObject:@"0.5a" forKey:@"version"];
    [saveDict setObject:[NSNumber numberWithInt:[[NSUserDefaults standardUserDefaults] integerForKey:@"rememberNum"]]
                 forKey:@"rememberNum"];
    [saveDict setObject:[NSNumber numberWithInt:[[NSUserDefaults standardUserDefaults] integerForKey:@"displayLen"]]
                 forKey:@"displayLen"];
    [saveDict setObject:[NSNumber numberWithInt:[[NSUserDefaults standardUserDefaults] integerForKey:@"displayNum"]]
                 forKey:@"displayNum"];
    for ( i = 0 ; i < [clippingStore jcListCount]; i++) {
		[jcListArray addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			[clippingStore clippingContentsAtPosition:i], @"Contents",
			[clippingStore clippingTypeAtPosition:i], @"Type",
			[NSNumber numberWithInt:i], @"Position",
			nil
			]
			];
    }
    [saveDict setObject:jcListArray forKey:@"jcList"];
	
    if ( [saveDict writeToFile:[path stringByAppendingString:@"/JCEngine.save"] atomically:true] ) {
		NSLog(@"Engine contents saved.");
    } else {
		NSLog(@"Engine contents NOT saved.");
    }
}


- (BOOL)shortcutRecorder:(ShortcutRecorder *)aRecorder isKeyCode:(signed short)keyCode andFlagsTaken:(unsigned int)flags reason:(NSString **)aReason
{
	if (aRecorder == mainRecorder)
	{
		BOOL isTaken = NO;
/*		
		KeyCombo kc = [delegateDisallowRecorder keyCombo];
		
		if (kc.code == keyCode && kc.flags == flags) isTaken = YES;
		
		*aReason = [delegateDisallowReasonField stringValue];
*/		
		return isTaken;
	}
	
	return NO;
}

- (void)shortcutRecorder:(ShortcutRecorder *)aRecorder keyComboDidChange:(KeyCombo)newKeyCombo
{
	if (aRecorder == mainRecorder)
	{
		[self toggleMainHotKey: aRecorder];
	}
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)app {
    // if we wanted to cancel, we would:
    //   return NSTerminateLater;
    // That might be useful for us at some point.
    if ( [savePreference isEqualToString:@"onExit"] ) {
        [self saveEngine];
    }
    return NSTerminateNow;
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
	//Unregister our hot key (not required)
	[[PTHotKeyCenter sharedCenter] unregisterHotKey: mainHotKey];
	
	//Memory cleanup
	[mainHotKey release];
	mainHotKey = nil;
	[nc removeObserver:self];
	
	[self hideBezel];
	[bezel release];
}

@end
