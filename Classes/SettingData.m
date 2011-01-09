//
//  SettingData.m
//  BestCamera
//
//  Created by forrest on 10-9-4.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "SettingData.h"

#define DEBUG 1 ;

@implementation SettingData

@synthesize intervelSeconds;
@synthesize shotTimes;
@synthesize audioFlag;
@synthesize colorFlag;

- (id) init{
	if (self = [super init]) {
		self.intervelSeconds = 5;
		self.shotTimes = 1;
		self.audioFlag = TRUE;
		self.colorFlag = FALSE;
	}
	return self;
}

- (void) dumpData{
	NSLog(@"intervals : [ %d  ] \n", self.intervelSeconds);
	NSLog(@"shotTimes : [ %d  ] \n", self.shotTimes);
	NSLog(@"audio : [ %d  ] \n", self.audioFlag);
	NSLog(@"color : [ %d  ] \n", self.colorFlag);
}
@end
