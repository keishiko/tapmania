//
//  ThemeManager.m
//  ThemeManager
//
//  Created by Alex Kremer on 03.02.09.
//  Copyright 2008-2009 Godexsoft. All rights reserved.
//

#import "ThemeManager.h"
#import "ThemeMetrics.h"
#import "ResourcesLoader.h"
#import "VersionInfo.h"

// This is a singleton class, see below
static ThemeManager *sharedThemeManagerDelegate = nil;

@interface ThemeManager (Private)
- (NSObject*) lookUpNode:(NSString*) key;
@end


@implementation ThemeManager

@synthesize m_aThemesList, m_sCurrentThemeName, m_aNoteskinsList, m_sCurrentNoteskinName;
@synthesize m_pCurrentThemeResources, m_pCurrentThemeWebResources, m_pCurrentNoteSkinResources;

- (id) init {
	self = [super init];
	if(!self)
		return nil;
	
	/* We must list all the themes and store them into the mThemesList array */
	m_aThemesList = [[NSMutableArray alloc] initWithCapacity:1];
	m_aNoteskinsList = [[NSMutableArray alloc] initWithCapacity:1];
	int i;	
	
	NSString* themesDir = [[NSBundle mainBundle] pathForResource:@"themes" ofType:nil];	
	TMLog(@"Point themes dir to '%@'!", themesDir);

	NSString* noteskinsDir = [[NSBundle mainBundle] pathForResource:@"noteskins" ofType:nil];	
	TMLog(@"Point noteskins dir to '%@'!", noteskinsDir);
	
	NSArray* themesDirContents = [[NSFileManager defaultManager] directoryContentsAtPath:themesDir];
	NSArray* noteskinsDirContents = [[NSFileManager defaultManager] directoryContentsAtPath:noteskinsDir];
	
	// Raise error if empty themes dir
	if([themesDirContents count] == 0 || [noteskinsDirContents count] == 0) {
		TMLog(@"Oops! Themes dir or noteskins dir is empty. This should never happen."); // We should have the default themes always
		return nil;
	}
	
	// Iterate through the themes
	for(i = 0; i<[themesDirContents count]; i++) {		
		NSString* themeDirName = [themesDirContents objectAtIndex:i];
		NSString* path = [themesDir stringByAppendingFormat:@"/%@/Metrics.plist", themeDirName];
	
		// Check the Metrics.plist file
		if([[NSFileManager defaultManager] fileExistsAtPath:path]) {			
			// Ok. Looks like a valid tapmania theme.. need to check the SystemVersion number
			NSDictionary* themeMetrics = [NSDictionary dictionaryWithContentsOfFile:path];
			NSNumber* version = [themeMetrics objectForKey:@"ThemeSystemVersion"];
			
			if(version != nil && [version doubleValue]==TAPMANIA_THEME_VERSION) {
				[m_aThemesList addObject:themeDirName];
				TMLog(@"Added theme '%@' to themes list.", themeDirName);
			}
		}
	}

	// Iterate through the noteskins
	for(i = 0; i<[noteskinsDirContents count]; i++) {		
		NSString* noteskinDirName = [noteskinsDirContents objectAtIndex:i];
		NSString* path = [noteskinsDir stringByAppendingFormat:@"/%@/Metrics.plist", noteskinDirName];
		
		// Check the Metrics.plist file
		if([[NSFileManager defaultManager] fileExistsAtPath:path]) {
			// Ok. Looks like a valid tapmania noteskin.. need to check the SystemVersion number
			NSDictionary* skinMetrics = [NSDictionary dictionaryWithContentsOfFile:path];
			NSNumber* version = [skinMetrics objectForKey:@"NoteskinSystemVersion"];
			
			if(version != nil && [version doubleValue]==TAPMANIA_NOTESKIN_VERSION) {
				[m_aNoteskinsList addObject:noteskinDirName];
				TMLog(@"Added noteskin '%@' to noteskins list.", noteskinDirName);
			}
		}
	}
	
	return self;
}

- (void) selectTheme:(NSString*) themeName {
	
	if([m_aThemesList containsObject:themeName]) {
		m_sCurrentThemeName = themeName;
		
		NSString* themesDir = [[NSBundle mainBundle] pathForResource:@"themes" ofType:nil];	
		
		NSString* themeGraphicsPath = [themesDir stringByAppendingFormat:@"/%@/Graphics/", m_sCurrentThemeName];
		NSString* themeWebPath = [themesDir stringByAppendingFormat:@"/%@/WebServer/", m_sCurrentThemeName];
		NSString* themeFontsPath	= [themesDir stringByAppendingFormat:@"/%@/Fonts/", m_sCurrentThemeName];
		
		NSString* filePath = [themesDir stringByAppendingFormat:@"/%@/Metrics.plist", m_sCurrentThemeName];
		
		if([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {		
			m_pCurrentThemeMetrics	 = [[ThemeMetrics alloc] initWithContentsOfFile:filePath];
			m_pCurrentThemeResources = [[ResourcesLoader alloc] initWithPath:themeGraphicsPath type:kResourceLoaderGraphics andDelegate:self];
			m_pCurrentThemeWebResources = [[ResourcesLoader alloc] initWithPath:themeWebPath type:kResourceLoaderWeb andDelegate:self];
			
			// Use font manager to load up fonts
			// TODO: Use our fonts in a later release
			// [[FontManager sharedInstance] loadFonts:themeFontsPath];
						
			TMLog(@"Metrics and resources are loaded for theme '%@'.", m_sCurrentThemeName);
			
		} else {
			TMLog(@"Couldn't load Metrics.plist file from the selected theme! This should not happen.");
			exit(127);
		}
	} else {
		TMLog(@"Theme '%@' is no longer available. Switch to default.", themeName);
		[self selectTheme:kDefaultThemeName];
	}
}

- (void) selectNoteskin:(NSString*) skinName {
	if([m_aNoteskinsList containsObject:skinName]) {
		m_sCurrentNoteskinName = skinName;		

		NSString* noteskinsDir = [[NSBundle mainBundle] pathForResource:@"noteskins" ofType:nil];	
		NSString* skinPath =	 [noteskinsDir stringByAppendingPathComponent:skinName];
		
		m_pCurrentNoteSkinResources = [[ResourcesLoader alloc] initWithPath:skinPath type:kResourceLoaderNoteSkin andDelegate:self];
	} else {
		TMLog(@"NoteSkin '%@' is no longer available. Switch to default.", skinName);
		[self selectNoteskin:kDefaultNoteSkinName];
	}
}

- (int) intMetric:(NSString*) metricKey {
	NSObject* node = [self lookUpNode:metricKey];
	if(!node) 
		return 0; // Defualt value
	
	return [(NSNumber*)node	intValue];
}

- (float) floatMetric:(NSString*) metricKey {
	NSObject* node = [self lookUpNode:metricKey];
	if(!node) 
		return 0.0f; // Defualt value
	
	return [(NSNumber*)node	floatValue];
}

- (NSString*) stringMetric:(NSString*) metricKey {
	NSObject* node = [self lookUpNode:metricKey];
	if(!node) 
		return @"EMPTY"; // Defualt value
	
	return [[NSString stringWithString:(NSString*)node] autorelease];
}

- (Texture2D*) texture:(NSString*) textureKey {
	TMResource* resource = [m_pCurrentThemeResources getResource:textureKey];
	
	if(resource) {
		return (Texture2D*)[resource resource];
	}

	TMLog(@"NOT FOUND! Shit!!!");
	// TODO return some very default texture if not found
	return nil;
}

- (Texture2D*) skinTexture:(NSString*) textureKey {
	TMResource* resource = [m_pCurrentNoteSkinResources getResource:textureKey];
	if(resource) {
		return (Texture2D*)[resource resource];
	}
	
	// TODO return some very default texture if not found
	return nil;	
}

// This is the private method which searches through the metrics tree to get the metric
- (NSObject*) lookUpNode:(NSString*) key {
	
	// Key is of format: "SomeRootElement SomeInnerElement SomeEvenMoreInnerElement TheMetric"
	NSArray* pathChunks = [key componentsSeparatedByString:@" "];
	
	NSObject* tmp = m_pCurrentThemeMetrics;
	int i;
	
	for(i=0; i<[pathChunks count]-1; ++i) {
		if(tmp != nil && [tmp isKindOfClass:[NSDictionary class]]) {
			// Search next component
			tmp = [(NSDictionary*)tmp objectForKey:[pathChunks objectAtIndex:i]];
		}
	}
	
	if(tmp != nil) {
		tmp = [[(NSDictionary*)tmp objectForKey:[pathChunks lastObject]] retain];
	}
		
	return tmp;	// nil or not
}


/* ResourcesLoaderSupport delegate work */
- (BOOL) resourceTypeSupported:(NSString*) itemName {
	if([[itemName lowercaseString] hasSuffix:@".png"] || [[itemName lowercaseString] hasSuffix:@".jpg"] ||
	   [[itemName lowercaseString] hasSuffix:@".gif"] || [[itemName lowercaseString] hasSuffix:@".bmp"] ) 
	{ 
		return YES;
	}
	
	// Another way is redirection. .redir files therefore should also be accepted
	if([[itemName lowercaseString] hasSuffix:@".redir"]) {
		return YES;
	}
	
	// We are also going to support htm/html files for our built-in web server
	if([[itemName lowercaseString] hasSuffix:@".htm"] || [[itemName lowercaseString] hasSuffix:@".html"]) {
		return YES;
	}
	
	return NO;		
}

#pragma mark Singleton stuff

+ (ThemeManager*)sharedInstance {
    @synchronized(self) {
        if (sharedThemeManagerDelegate == nil) {
            [[self alloc] init];
        }
    }
    return sharedThemeManagerDelegate;
}

+ (id)allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if (sharedThemeManagerDelegate	== nil) {
            sharedThemeManagerDelegate = [super allocWithZone:zone];
            return sharedThemeManagerDelegate;
        }
    }
	
    return nil;
}


- (id)retain {
    return self;
}

- (unsigned)retainCount {
    return UINT_MAX;  // denotes an object that cannot be released
}

- (void)release {
	// NOTHING
}

- (id)autorelease {
    return self;
}

@end