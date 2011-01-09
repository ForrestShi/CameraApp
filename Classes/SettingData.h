//
//  SettingData.h
//  BestCamera
//
//  Created by forrest on 10-9-4.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface SettingData : NSObject {
	NSInteger intervelSeconds;
	NSInteger shotTimes;
	Boolean	  audioFlag;
	Boolean   colorFlag;
}

@property (nonatomic , assign ) NSInteger intervelSeconds;
@property (nonatomic , assign ) NSInteger shotTimes;
@property (nonatomic , assign ) Boolean	  audioFlag;
@property (nonatomic , assign ) Boolean   colorFlag;


/*
 @ init with default values
 */
- (id) init ;


@end
