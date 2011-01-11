/*
     File: AVCamViewController.h
 Abstract: View controller code that manages all the buttons in the main view (HUD, Swap, Record, Still, Grav) as well as the device controls and and session properties (Focus, Exposure, Power, Peak, etc.) that are displayed over the live capture window.
  Version: 1.0
 */

#import <UIKit/UIKit.h>
#import "AVCamCaptureManager.h"

@class AVCamCaptureManager, AVCamPreviewView, ExpandyButton, AVCaptureVideoPreviewLayer;

@protocol PreviewImageViewDelegate;

@interface AVCamViewController : UIViewController <UIImagePickerControllerDelegate,
PreviewImageViewDelegate,
UINavigationControllerDelegate> {
    @private
    AVCamCaptureManager *_captureManager;
    AVCamPreviewView *_videoPreviewView;
    AVCaptureVideoPreviewLayer *_captureVideoPreviewLayer;
    UIView *_adjustingInfoView;
    UIBarButtonItem *_cameraToggleButton;
    UIBarButtonItem *_recordButton;
    UIBarButtonItem *_stillButton;
    UIBarButtonItem *_gravityButton;
    ExpandyButton *_flash;
    ExpandyButton *_torch;
    ExpandyButton *_focus;
    ExpandyButton *_exposure;
    ExpandyButton *_whiteBalance;
    ExpandyButton *_preset;
    ExpandyButton *_videoConnection;
    ExpandyButton *_audioConnection;
    ExpandyButton *_orientation;
    ExpandyButton *_mirroring;
	//Timer Camera 
	ExpandyButton *_timerShotCount;
	ExpandyButton *_timerSecondsPerShot;
	ExpandyButton *_timerVoiceMode;
    
    UIView *_adjustingFocus;
    UIView *_adjustingExposure;
    UIView *_adjustingWhiteBalance;
    
    UIView *_statView;
    UIImageView* _previewImageView;
	
    IBOutlet UILabel *_averagePowerLevel;
    IBOutlet UILabel *_peakHoldLevel;
    IBOutlet UILabel *_focusPoint;
    IBOutlet UILabel *_exposurePoint;
    IBOutlet UILabel *_deviceCount;
    IBOutlet UILabel *_recordingDuration;
    IBOutlet UILabel *_fileSize;
    
    NSNumberFormatter *_numberFormatter;
    BOOL _hudHidden;
    CALayer *_focusBox;
    CALayer *_exposeBox;    
}

@property (nonatomic,retain) AVCamCaptureManager *captureManager;
@property (nonatomic,retain) IBOutlet AVCamPreviewView *videoPreviewView;
@property (nonatomic,retain) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
@property (nonatomic,retain) IBOutlet UIView *adjustingInfoView;
@property (nonatomic,retain) IBOutlet UIBarButtonItem *cameraToggleButton;
@property (nonatomic,retain) IBOutlet UIBarButtonItem *recordButton;
@property (nonatomic,retain) IBOutlet UIBarButtonItem *stillButton;
@property (nonatomic,retain) IBOutlet UIBarButtonItem *gravityButton;
@property (nonatomic,retain) ExpandyButton *flash;
@property (nonatomic,retain) ExpandyButton *torch;
@property (nonatomic,retain) ExpandyButton *focus;
@property (nonatomic,retain) ExpandyButton *exposure;
@property (nonatomic,retain) ExpandyButton *whiteBalance;
@property (nonatomic,retain) ExpandyButton *preset;
@property (nonatomic,retain) ExpandyButton *videoConnection;
@property (nonatomic,retain) ExpandyButton *audioConnection;
@property (nonatomic,retain) ExpandyButton *orientation;
@property (nonatomic,retain) ExpandyButton *mirroring;
@property (nonatomic,retain) ExpandyButton *timerShotCount;
@property (nonatomic,retain) ExpandyButton *timerSecondsPerShot;
@property (nonatomic,retain) ExpandyButton *timerVoiceMode;

@property (nonatomic,retain) IBOutlet UIView *adjustingFocus;
@property (nonatomic,retain) IBOutlet UIView *adjustingExposure;
@property (nonatomic,retain) IBOutlet UIView *adjustingWhiteBalance;

@property (nonatomic,retain) IBOutlet UIView *statView;
@property (nonatomic,retain) IBOutlet UIImageView* previewImageView;

@property (nonatomic,retain) IBOutlet UILabel *averagePowerLevel;
@property (nonatomic,retain) IBOutlet UILabel *peakHoldLevel;
@property (nonatomic,retain) IBOutlet UILabel *focusPoint;
@property (nonatomic,retain) IBOutlet UILabel *exposurePoint;
@property (nonatomic,retain) IBOutlet UILabel *deviceCount;
@property (nonatomic,retain) IBOutlet UILabel *recordingDuration;
@property (nonatomic,retain) IBOutlet UILabel *fileSize;

#pragma mark Toolbar Actions
- (IBAction)hudViewToggle:(id)sender;
- (IBAction)record:(id)sender;
- (IBAction)still:(id)sender;
- (IBAction)cameraToggle:(id)sender;
- (IBAction)cycleGravity:(id)sender;

#pragma mark HUD Actions
- (void)flashChange:(id)sender;
- (void)torchChange:(id)sender;
- (void)focusChange:(id)sender;
- (void)exposureChange:(id)sender;
- (void)whiteBalanceChange:(id)sender;
- (void)presetChange:(id)sender;
- (void)adjustOrientation:(id)sender;
- (void)adjustMirroring:(id)sender;
-(void)timerShotCountSelect:(id)sender;
-(void)timerSecondsPerShotSelect:(id)sender;
-(void)timerVoiceModeSelect:(id)sender;

@end

