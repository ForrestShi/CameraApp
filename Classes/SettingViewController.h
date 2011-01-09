//
//  SettingViewController.h
//  BestCamera
//
//  Created by forrest on 10-9-4.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//
//#define DEBUG 1

#import <UIKit/UIKit.h>

@protocol SettingDelegate
- (void) ChangesApplied;
@end

@protocol ReturnBackControllerDelegate

- (void) ReturnBack;

@end


@class SettingData;

@interface SettingViewController : UIViewController  <ReturnBackControllerDelegate>{
	IBOutlet UISlider*	intervalSecondsSlider;
	IBOutlet UISlider*   continuousShotsSlider;
	IBOutlet UISwitch*	audioSwitch;
	IBOutlet UISwitch*	colorSwitch;
	IBOutlet UILabel*   label1;
	IBOutlet UILabel*	label2;
	
	SettingData* dataRef;
	id<SettingDelegate> delegate;
}

@property (nonatomic, retain )	 IBOutlet UISlider*	intervalSecondsSlider;
@property (nonatomic, retain )	 IBOutlet UISlider*   continuousShotsSlider;
@property (nonatomic, retain )	 IBOutlet UISwitch*	audioSwitch;
@property (nonatomic, retain )	 IBOutlet UISwitch*	colorSwitch;
@property (nonatomic, retain )	 IBOutlet UILabel*   label1;
@property (nonatomic, retain )	 IBOutlet UILabel*	label2;
@property (nonatomic, assign )	 SettingData* dataRef;
@property (nonatomic, assign )	 id<SettingDelegate> delegate;


- (IBAction) adjustSetting;
- (IBAction) onDoneButton;
-(IBAction) onHelpButton;
/*
 @ init with adjustment parameters
 */
- (id) initWithData:(SettingData*)data;
@end

