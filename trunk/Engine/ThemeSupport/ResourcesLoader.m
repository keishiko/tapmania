//
//  ResourcesLoader.m
//  TapMania
//
//  Created by Alex Kremer on 06.02.09.
//  Copyright 2008-2009 Godexsoft. All rights reserved.
//

#import "ResourcesLoader.h"
#import "TMResource.h"

#import <syslog.h>

@interface ResourcesLoader (Private)
- (void) loadResourceFromPath:(NSString*) path intoNode:(NSDictionary*) node;
- (NSObject*) lookUpNode:(NSString*) key;
@end


@implementation ResourcesLoader

@synthesize m_idDelegate;

- (id) initWithPath:(NSString*) rootPath andDelegate:(id) delegate {
	self = [super init];
	if(!self)
		return nil;
	
	m_idDelegate = delegate;
	m_pRoot = [[NSMutableDictionary alloc] init];
	
	m_sRootPath = rootPath;
	NSLog(@"Loading resources from root path at '%@'!!!", m_sRootPath);
	[self loadResourceFromPath:m_sRootPath intoNode:m_pRoot];
	NSLog(@"Loaded resources.");
	
	return self;
}

- (TMResource*) getResource:(NSString*) path {
	NSObject* node = [self lookUpNode:path];
	if(!node) {
		[self preLoad:path];
	}
	
	if([node isKindOfClass:[TMResource class]]) {
		return node;
	} else {
		NSException* ex = [NSException exceptionWithName:@"Can't get resources." 
												  reason:[NSString stringWithFormat:@"The path is not a resource. it seems to be a directory: %@", path] userInfo:nil];
		@throw ex;
	}
}

- (void) preLoad:(NSString*) path {
	NSObject* node = [self lookUpNode:path];
	if(!node) {
		NSException* ex = [NSException exceptionWithName:@"Can't load resources." 
										reason:[NSString stringWithFormat:@"The path is not loaded: %@", path] userInfo:nil];
		@throw ex;
	}
	
	// If it's a leaf
	if([node isKindOfClass:[TMResource class]]) {
		[(TMResource*)node loadResource];
		
	} else {
		// It's a directory. preload everything inside...
	}
}

- (void) preLoadAll {
}

- (void) unLoad:(NSString*) path {
	NSObject* node = [self lookUpNode:path];
	if(!node) {
		NSLog(@"The resources on path '%@' are not loaded...", path);
	}
	
	// TODO: release resources
}

- (void) unLoadAll {
}

/* Private methods */
- (void) loadResourceFromPath:(NSString*) path intoNode:(NSDictionary*) node {
	NSArray* dirContents = [[NSFileManager defaultManager] directoryContentsAtPath:path];
	
	// List all files and dirs there
	int i;
	for(i = 0; i<[dirContents count]; i++) {	
		NSString* itemName = [dirContents objectAtIndex:i];
		NSString* curPath = [path stringByAppendingPathComponent:itemName];
		
		BOOL isDirectory;
		
		if([[NSFileManager defaultManager] fileExistsAtPath:curPath isDirectory:&isDirectory]) {
			// is dir?
			if(isDirectory) {
				NSLog(@"[+] Found directory: %@", itemName);
				syslog(LOG_DEBUG, "[+] found dir: %s", [itemName UTF8String]);
				
				// Create new dictionary
				NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
				NSLog(@"Start loading into '%@'", itemName);
				syslog(LOG_DEBUG, "start loading into %s", [itemName UTF8String]);
				[self loadResourceFromPath:curPath intoNode:dict];
				
				NSLog(@"------");
				syslog(LOG_DEBUG, "------------");
				
				// Add that new dict node to the node specified in the arguments
				[node setValue:dict forKey:itemName];
				NSLog(@"Stop adding there");
				
			} else {
				// file. check type
				if( m_idDelegate != nil && [m_idDelegate resourceTypeSupported:itemName] ) {
					NSLog(@"[Supported] %@", itemName);
					syslog(LOG_DEBUG, "[SUPPORTED] %s", [itemName UTF8String]);
					TMResource* resource = [[TMResource alloc] initWithPath:curPath andItemName:itemName];
					
					// Add that resource
					[node setValue:resource forKey:resource.componentName];										
					NSLog(@"Added it to current node at key = '%@'", resource.componentName);
					syslog(LOG_DEBUG, "Added it to %s", [resource.componentName UTF8String]);
				}
			}
		}
	}
}

// This method is looking up the resource in the hierarchy
- (NSObject*) lookUpNode:(NSString*) key {
	
	// Key is of format: "SomeRootElement SomeInnerElement SomeEvenMoreInnerElement TheResource"
	NSArray* pathChunks = [key componentsSeparatedByString:@" "];
	
	NSObject* tmp = m_pRoot;
	int i;
	
	for(i=0; i<[pathChunks count]-1; ++i) {
		if(tmp != nil && [tmp isKindOfClass:[NSMutableDictionary class]]) {
			// Search next component
			tmp = [(NSMutableDictionary*)tmp objectForKey:[pathChunks objectAtIndex:i]];
		}
	}
	
	if(tmp != nil) {
		tmp = [[(NSMutableDictionary*)tmp objectForKey:[pathChunks lastObject]] retain];
	}
	
	return tmp;	// nil or not
}

@end
