//
//  MenuItem.h
//  TapMania
//
//  Created by Alex Kremer on 06.11.08.
//  Copyright 2008 Godexsoft. All rights reserved.
//

#import "TMControl.h"

@class TMFramedTexture, Texture2D, TMSound;

@interface MenuItem : TMControl {
	TMFramedTexture*	m_pTexture;
	Texture2D*			m_pTitle;
	NSString*			m_sTitle;
	
	/* Sound effect */
	TMSound*	sr_MenuButtonEffect;
}

- (id) initWithTitle:(NSString*)title andShape:(CGRect) shape;

@end
