//
//  TMSteps.m
//  TapMania
//
//  Created by Alex Kremer on 04.11.08.
//  Copyright 2008 Godexsoft. All rights reserved.
//

#import "TMSteps.h"
#import "TMTrack.h"
#import "TMNote.h"
#import "TapNote.h"
#import "HoldNote.h"

#import "TimingUtil.h"
#import "MessageManager.h"
#import "TMMessage.h"
#import "ThemeManager.h"
#import "TapMania.h"
#import "JoyPad.h"

#import "GameState.h"

extern TMGameState* g_pGameState;

@implementation TMSteps

- (id) init {
	self = [super init];
	if(!self) 
		return nil;
	
	int i;
	
	// Alloc space for tracks
	for(i=0; i<kNumOfAvailableTracks; i++){
		m_pTracks[i] = [[TMTrack alloc] init];
	
		// Cache metrics
		mt_TapNotes[i] =					RECT_SKIN_METRIC(([NSString stringWithFormat:@"TapNote %d", i]));
		mt_TapNoteRotations[i] =			FLOAT_SKIN_METRIC(([NSString stringWithFormat:@"TapNote Rotation %d", i]));		
		mt_HalfOfArrowHeight[i] =			mt_TapNotes[i].size.height/2;
		
		mt_Receptors[i]	=					RECT_SKIN_METRIC(([NSString stringWithFormat:@"ReceptorRow %d", i]));
	}
	
	mt_HoldCap =							SIZE_SKIN_METRIC(@"HoldNote Cap");
	mt_HoldBody =							SIZE_SKIN_METRIC(@"HoldNote Body");
	
	// Cache textures
	t_TapNote = (TapNote*)SKIN_TEXTURE(@"DownTapNote");
	t_HoldNoteActive = (HoldNote*)SKIN_TEXTURE(@"HoldBody DownActive");
	t_HoldNoteInactive = (HoldNote*)SKIN_TEXTURE(@"HoldBody DownInactive");
	
	t_HoldBottomCapActive = SKIN_TEXTURE(@"HoldBody BottomCapActive");
	t_HoldBottomCapInactive = SKIN_TEXTURE(@"HoldBody BottomCapInactive");
	
	// Drop track positions to first elements
	for(int i=0; i<kNumOfAvailableTracks; i++) {
		m_nTrackPos[i] = 0;
	}	
	
	return self;
}

- (void) dealloc {
	TMLog(@"Release steps!");
	
	for(int i=0; i<kNumOfAvailableTracks; ++i) {
		[m_pTracks[i] release];
	}
	
	[super dealloc];
}

- (int) getDifficultyLevel {
	return m_nDifficultyLevel;
}

- (TMSongDifficulty) getDifficulty {
	return m_nDifficulty;
}

- (void) setNote:(TMNote*) note toTrack:(int) trackIndex onNoteRow:(int) noteRow{
	[m_pTracks[trackIndex] setNote:note onNoteRow:noteRow];
}

- (TMNote*) getNote:(int) index fromTrack:(int) trackIndex {
	return [m_pTracks[trackIndex] getNote:index];
}

- (TMNote*) getNoteFromRow:(int) noteRow forTrack:(int) trackIndex {
	return [m_pTracks[trackIndex] getNoteFromRow:noteRow];
}

- (BOOL) hasNoteAtRow:(int) noteRow forTrack:(int) trackIndex {
	return [m_pTracks[trackIndex] hasNoteAtRow:noteRow];
}

- (int) getNotesCountForTrack:(int) trackIndex {
	return [m_pTracks[trackIndex] getNotesCount];
}

// Time out stuff should be a pointer to array of kNumOfAvailableTracks elements but obj-c doesn't like the C syntax. FIXME
- (BOOL) checkAllNotesHitFromRow:(int) noteRow withNoteTime:(double)inNoteTime {
	// Check whether other tracks has any notes which are not hit yet and are on the same noterow
	BOOL allNotesHit = YES;
	int tr = 0;
	TMNote* notesInRow[kNumOfAvailableTracks];
	
	for(; tr<kNumOfAvailableTracks; ++tr) {
		notesInRow[tr] = nil;
		TMNote* n = [self getNoteFromRow:noteRow forTrack:tr];
		
		// If found - check
		if(n != nil) {
			if(!n.m_bIsHit) {
				allNotesHit = NO;
			} else {
				notesInRow[tr] = n;
			}
		}
	}
	
	// Mark all hit if all notes actually were hit
	if(allNotesHit) {
		
		// Get the worse scoring of all hit notes
		double worseDelta = 0.0f;
		TMTimingFlag timingFlag;
		
		for(tr=0; tr<kNumOfAvailableTracks; ++tr){
			if(notesInRow[tr] != nil) {
				double timing = inNoteTime - notesInRow[tr].m_dHitTime;
				double thisDelta = fabs(timing);
				
				if(thisDelta > worseDelta) {
					worseDelta = thisDelta;
					timingFlag = timing<0?kTimingFlagEarly:kTimingFlagLate;
				}
			}
		}
		
		TMJudgement noteScore = [TimingUtil getJudgementByDelta:worseDelta];				

		// And now actually mark them hit
		for(tr=0; tr<kNumOfAvailableTracks; ++tr){
			if(notesInRow[tr] != nil) {
				[(notesInRow[tr]) score:noteScore withTimingFlag:timingFlag];
			}
		}		
	}
	
	return allNotesHit;
}

- (void) markAllNotesLostFromRow:(int) noteRow {
	int tr = 0;
	for(; tr<kNumOfAvailableTracks; ++tr) {
		
		TMNote* n = [self getNoteFromRow:noteRow forTrack:tr];
		
		// If found - check
		if(n != nil) {
			[n markLost];
			[n score:kJudgementMiss withTimingFlag:kTimingFlagLate];
			
			// Extra judgement for hold notes..
			if(n.m_nType == kNoteType_HoldHead) {
				[n markHoldLost];
			}				
		}
	}
}


- (int) getFirstNoteRow {
	int i;
	int minNoteRow = INT_MAX;

	for(i=0; i<kNumOfAvailableTracks; i++){
		int j;

		int total = [m_pTracks[i] getNotesCount];
		for(j=0; [m_pTracks[i] getNote:j].m_nType == kNoteType_Empty && j < total; j++);
				
		// Get the smallest
		minNoteRow = (int) fminf( (float)minNoteRow, (float)[(TMNote*)[m_pTracks[i] getNote:j] m_nStartNoteRow] );
	}

	return minNoteRow;
}

- (int) getLastNoteRow {
	int i;
	int maxNoteRow = 0;
	
	for(i=0; i<kNumOfAvailableTracks; i++){
		// Get the biggest
		TMNote* lastNote = [m_pTracks[i] getNote:[m_pTracks[i] getNotesCount]-1];
		maxNoteRow = (int) fmaxf( (float)maxNoteRow, (float) lastNote.m_nType==kNoteType_HoldHead? [lastNote m_nStopNoteRow] : [lastNote m_nStartNoteRow] );
	}
	
	return maxNoteRow;
}

- (void) dump {
	printf("Dumping steps: %d/%d\n\n", m_nDifficulty, m_nDifficultyLevel);
	for(int i=0; i<kNumOfAvailableTracks; i++){
		
		printf("row %d |", i);
		BOOL holdActive = NO;
		
		for(int j=0; j<[m_pTracks[i] getNotesCount]; j++){
			TMNote* pNote = [m_pTracks[i] getNote:j];
			char c = ' ';
			
			switch(pNote.m_nType) {
				case kNoteType_HoldHead:
					c = '#';
					holdActive = YES;
					break;
				case kNoteType_Original:
					c = '*';
					holdActive = NO;
					break;
				case kNoteType_Empty:
					c = '0';
					break;
				default:
					if(holdActive)
						c = '=';
			}
						
			printf("%c", c);
		}
		printf("|\n");
	}
}

/* TMLogicUpdater stuff */
-(void) update:(float)fDelta {
	if(!g_pGameState->m_bPlayingGame)
		return; 
	
	float currentBeat, currentBps;
	BOOL hasFreeze;
	
	[TimingUtil getBeatAndBPSFromElapsedTime:g_pGameState->m_dElapsedTime beatOut:&currentBeat bpsOut:&currentBps freezeOut:&hasFreeze inSong:g_pGameState->m_pSong]; 
	
	// Calculate animation of the tap notes. The speed of the animation is actually one frame per beat
	[t_TapNote setM_fFrameTime:[TimingUtil getTimeInBeatForBPS:currentBps]];
	[t_TapNote update:fDelta];
	
	// If freeze - stop animating the notes but still check for hits etc.
	if(hasFreeze) {
		[t_TapNote pauseAnimation];
	} else {
		[t_TapNote continueAnimation];
	}
	
	double searchHitFromTime = g_pGameState->m_dElapsedTime - 0.1f;
	double searchHitTillTime = g_pGameState->m_dElapsedTime + 0.1f;
	int i;
	
	// For every track
	for(i=0; i<kNumOfAvailableTracks; i++) {
		// Search in this track for items starting at index:
		int startIndex = m_nTrackPos[i];
		int j;
		
		// This will hold the Y coordinate of the previous note in this track
		float lastNoteYPosition = mt_Receptors[i].origin.y;
		
		TMNote* prevNote = nil;
		
		double lastHitTime = [[TapMania sharedInstance].joyPad getTouchTimeForButton:(JPButton)i] - g_pGameState->m_dPlayBackStartTime;		
		BOOL testHit = NO;
		
		// Check for hit?
		if(lastHitTime >= searchHitFromTime && lastHitTime <= searchHitTillTime) {
			testHit = YES;
		}
		
		// For all interesting notes in the track
		for(j=startIndex; j<[self getNotesCountForTrack:i] ; ++j) {
			TMNote* note = [self getNote:j fromTrack:i];
			
			// We are not handling empty notes though
			if(note.m_nType == kNoteType_Empty)
				continue;
			
			// Get beats out of noteRows
			float beat = [TMNote noteRowToBeat: note.m_nStartNoteRow];
			float tillBeat = note.m_nStopNoteRow == -1 ? -1.0f : [TMNote noteRowToBeat: note.m_nStopNoteRow];
			
			float noteBps = [TimingUtil getBpsAtBeat:beat inSong:g_pGameState->m_pSong];
			
			float noteYPosition = lastNoteYPosition;
			float holdBottomCapYPosition = 0.0f;
			
			int lastNoteRow = prevNote ? prevNote.m_nStartNoteRow : [TMNote beatToNoteRow:currentBeat];
			int nextBpmChangeNoteRow = [TimingUtil getNextBpmChangeFromBeat:[TMNote noteRowToBeat:lastNoteRow] inSong:g_pGameState->m_pSong];
			
			double noteTime = [TimingUtil getElapsedTimeFromBeat:beat inSong:g_pGameState->m_pSong];
			
			if(g_pGameState->m_bAutoPlay) {
				if(fabsf(noteTime - g_pGameState->m_dElapsedTime) <= 0.03f) {
					testHit = YES;
					lastHitTime = g_pGameState->m_dElapsedTime;
				}
			}
			
			// Now for every bpmchange we must apply all bpmchange related offsets
			while (nextBpmChangeNoteRow != -1 && nextBpmChangeNoteRow < note.m_nStartNoteRow) {
				float tBps = [TimingUtil getBpsAtBeat:[TMNote noteRowToBeat:nextBpmChangeNoteRow-1] inSong:g_pGameState->m_pSong];
				
				noteYPosition -= (nextBpmChangeNoteRow-lastNoteRow)*[TimingUtil getPixelsPerNoteRowForBPS:tBps andSpeedMod:g_pGameState->m_dSpeedModValue];
				lastNoteRow = nextBpmChangeNoteRow;
				nextBpmChangeNoteRow = [TimingUtil getNextBpmChangeFromBeat:[TMNote noteRowToBeat:nextBpmChangeNoteRow] inSong:g_pGameState->m_pSong];
			}
			
			// Calculate for last segment
			noteYPosition -= (note.m_nStartNoteRow-lastNoteRow)*[TimingUtil getPixelsPerNoteRowForBPS:noteBps andSpeedMod:g_pGameState->m_dSpeedModValue];
			note.m_fStartYPosition = noteYPosition;
			
			/* We must also calculate the Y position of the bottom cap of the hold if we handle a hold note */
			if(note.m_nType == kNoteType_HoldHead) {
				// If we hit (was ever holding) the note now we must fix it on the receptor base
				if(note.m_bIsHit) {
					note.m_fStartYPosition = mt_Receptors[i].origin.y;
				}
				
				// Start from the calculated note head position
				holdBottomCapYPosition = noteYPosition;
				lastNoteRow = note.m_nStartNoteRow;
				
				nextBpmChangeNoteRow = [TimingUtil getNextBpmChangeFromBeat:[TMNote noteRowToBeat:lastNoteRow] inSong:g_pGameState->m_pSong];
				
				// Now for every bpmchange we must apply all bpmchange related offsets
				while (nextBpmChangeNoteRow != -1 && nextBpmChangeNoteRow < note.m_nStopNoteRow) {
					float tBps = [TimingUtil getBpsAtBeat:[TMNote noteRowToBeat:nextBpmChangeNoteRow-1] inSong:g_pGameState->m_pSong];
					
					holdBottomCapYPosition -= (nextBpmChangeNoteRow-lastNoteRow)*[TimingUtil getPixelsPerNoteRowForBPS:tBps andSpeedMod:g_pGameState->m_dSpeedModValue];
					lastNoteRow = nextBpmChangeNoteRow;
					nextBpmChangeNoteRow = [TimingUtil getNextBpmChangeFromBeat:[TMNote noteRowToBeat:nextBpmChangeNoteRow] inSong:g_pGameState->m_pSong];
				}
				
				// Calculate for last segment of the hold body
				float capBps = [TimingUtil getBpsAtBeat:tillBeat inSong:g_pGameState->m_pSong];
				holdBottomCapYPosition -= (note.m_nStopNoteRow-lastNoteRow)*[TimingUtil getPixelsPerNoteRowForBPS:capBps andSpeedMod:g_pGameState->m_dSpeedModValue];			
				
				note.m_fStopYPosition = holdBottomCapYPosition;
			}
			
			// Check whether we already missed a note (hold head too)
			if(!note.m_bIsLost && !note.m_bIsHit && (g_pGameState->m_dElapsedTime-noteTime)>=0.1f) {
				[self markAllNotesLostFromRow:note.m_nStartNoteRow];						
			}
			
			// Check whether this note is already out of scope
			if(note.m_nType != kNoteType_HoldHead && noteYPosition >= 480.0f) {
				++m_nTrackPos[i];				
				continue; // Skip this note
			}
			
			// Now the same for hold notes
			if(note.m_nType == kNoteType_HoldHead) {
				if(note.m_bIsHit && holdBottomCapYPosition >= mt_Receptors[i].origin.y) {
					if(note.m_bIsHeld) {
						[note markHoldHeld];
					}
					
					++m_nTrackPos[i];
					continue; // Skip this hold already
				} else if (!note.m_bIsHit && holdBottomCapYPosition >= 480.0f) {
					// Let the hold go till the end of the screen. The lifebar and the NG graphic is done already when the hold was lost
					++m_nTrackPos[i];
					continue; // Skip
				}				
			}
			
			// If the Y position is at the floor - jump to next track
			if(note.m_fStartYPosition <= -mt_TapNotes[i].size.height){
				break; // Start another track coz this note is out of screen
			}				
			
			// Check old hit first
			if(testHit && note.m_bIsHit){
				// This note was hit already (maybe using the same tap as we still hold)
				if(note.m_dHitTime == lastHitTime) {
					// Bingo! prevent further notes in this track from being hit
					testHit = NO;
				} 
			}
			
			// If we are at a hold arrow we must check it anyway
			if(note.m_nType == kNoteType_HoldHead) {
				double lastReleaseTime = [[TapMania sharedInstance].joyPad getReleaseTimeForButton:(JPButton)i] - g_pGameState->m_dPlayBackStartTime;
				
				if(g_pGameState->m_bAutoPlay) {
					lastReleaseTime = lastHitTime-0.01f;
				}
				
				if(note.m_bIsHit && !note.m_bIsHoldLost && !note.m_bIsHolding) {
					// This means we released the hold but we still can catch it again
					if(fabsf(g_pGameState->m_dElapsedTime - note.m_dLastHoldReleaseTime) >= 0.4f) {
						[note markHoldLost];						
					}
					
					// But maybe we have touched it again before it was marked as lost totally?
					if(!note.m_bIsHoldLost && note.m_dLastHoldReleaseTime < lastHitTime) {
						[note startHolding:lastHitTime];
					}
				} else if(note.m_bIsHit && !note.m_bIsHoldLost && note.m_bIsHolding) {				
					if(lastReleaseTime >= lastHitTime) {						
						[note stopHolding:lastReleaseTime];
					}
				} 
			}
			
			// Check hit
			if(testHit && !note.m_bIsLost && !note.m_bIsHit){
				if(noteTime >= searchHitFromTime && noteTime <= searchHitTillTime) {
					
					// Mark note as hit
					[note hit:lastHitTime];
					testHit = NO; // Don't want to test hit on other notes on the track in this run
					
					if(note.m_nType == kNoteType_HoldHead) {
						[note startHolding:lastHitTime];
					}
					
					// Check whether other tracks has any notes which are not hit yet and are on the same noterow
					// The routine below will automatically broadcast all required messages to make things work (hit notes)
					[self checkAllNotesHitFromRow:note.m_nStartNoteRow withNoteTime:noteTime];					
				}
			}
			
			prevNote = note;
			lastNoteYPosition = noteYPosition;
		}
	}
}

/* TMRenderable stuff */
-(void) render:(float)fDelta {
	
	if(!g_pGameState->m_bPlayingGame)
		return;
	
	// For every track
	for(int i=0; i<kNumOfAvailableTracks; ++i) {
		
		// Search in this track for items starting at index:
		int startIndex = m_nTrackPos[i];
		int j;
		
		// For all interesting notes in the track
		for(j=startIndex; j<[self getNotesCountForTrack:i] ; j++) {
			TMNote* note = [self getNote:j fromTrack:i];
			
			// We are not handling empty notes though
			if(note.m_nType == kNoteType_Empty)
				continue;
			
			// We will draw the note only if it wasn't hit yet
			if(note.m_nType == kNoteType_HoldHead || !note.m_bIsHit) {
				if(note.m_fStartYPosition <= -mt_TapNotes[i].size.height) {
					break; // Start another track coz this note is out of screen
				}
				
				// If note is a holdnote
				if(note.m_nType == kNoteType_HoldHead) {			
					// Calculate body length
					float bodyTopY = note.m_fStartYPosition + mt_HalfOfArrowHeight[i]; // Plus half of the tap note so that it will be overlapping
					float bodyBottomY = note.m_fStopYPosition + mt_HalfOfArrowHeight[i]; // Make space for bottom cap
					
					// Determine the track X position now
					float holdX = mt_TapNotes[i].origin.x;
					
					// Calculate the height of the hold's body
					float totalBodyHeight = bodyTopY - bodyBottomY;
					float offset = bodyBottomY;
					
					// Draw every piece separately
					do{
						float sizeOfPiece = totalBodyHeight > mt_HoldBody.height ? mt_HoldBody.height : totalBodyHeight;
						
						// Don't draw if we are out of screen
						if(offset+sizeOfPiece > 0.0f) {					
							if(note.m_bIsHolding) {
								[t_HoldNoteActive drawBodyPieceWithSize:sizeOfPiece atPoint:CGPointMake(holdX, offset)];
							} else {
								[t_HoldNoteInactive drawBodyPieceWithSize:sizeOfPiece atPoint:CGPointMake(holdX, offset)];
							}
						}
						
						totalBodyHeight -= mt_HoldBody.height;
						offset += mt_HoldBody.height;
					} while(totalBodyHeight > 0.0f);					
					
					// determine the position of the cap and draw it if needed
					if(bodyBottomY > 0.0f) {
						// Ok. must draw the cap
						glEnable(GL_BLEND);
						
						if(note.m_bIsHolding) {
							[t_HoldBottomCapActive drawInRect:CGRectMake(holdX, bodyBottomY-(mt_HoldCap.height-1), mt_HoldCap.width, mt_HoldCap.height)];
						} else {
							[t_HoldBottomCapInactive drawInRect:CGRectMake(holdX, bodyBottomY-(mt_HoldCap.height-1), mt_HoldCap.width, mt_HoldCap.height)];
						}
						
						glDisable(GL_BLEND);
					}
				}
				
				CGRect arrowRect = CGRectMake(mt_TapNotes[i].origin.x, note.m_fStartYPosition, mt_TapNotes[i].size.width, mt_TapNotes[i].size.height);
				if(note.m_nType == kNoteType_HoldHead) {
					if(note.m_bIsHolding) {
						[t_TapNote drawHoldTapNoteHolding:note.m_nBeatType direction:(TMNoteDirection)i inRect:arrowRect];
					} else { 
						[t_TapNote drawHoldTapNoteReleased:note.m_nBeatType direction:(TMNoteDirection)i inRect:arrowRect];	
					}
				} else {
					[t_TapNote drawTapNote:note.m_nBeatType direction:(TMNoteDirection)i inRect:arrowRect];
				}			
			}
		}
	}	
}

/* TMMessageSupport stuff */
-(void) handleMessage:(TMMessage*)message {
}

@end
