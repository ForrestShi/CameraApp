/*
 File: AVCamViewController.m
 Abstract: View controller code that manages all the buttons in the main view (HUD, Swap, Record, Still, Grav) as well as the device controls and and session properties (Focus, Exposure, Power, Peak, etc.) that are displayed over the live capture window.
 Version: 1.0
 
 
 */

#import "AVCamViewController.h"
#import "AVCamCaptureManager.h"
#import "ExpandyButton.h"
#import "AVCamPreviewView.h"
#import <AVFoundation/AVFoundation.h>
#import "FlipsideViewController.h"

#define DEBUG_DEMO 0

// KVO contexts
static void *AVCamFocusModeObserverContext = &AVCamFocusModeObserverContext;
static void *AVCamTorchModeObserverContext = &AVCamTorchModeObserverContext;
static void *AVCamFlashModeObserverContext = &AVCamFlashModeObserverContext;
static void *AVCamAdjustingObserverContext = &AVCamAdjustingObserverContext;
static void *AVCamSessionPresetObserverContext = &AVCamSessionPresetObserverContext;
static void *AVCamFocusPointOfInterestObserverContext = &AVCamFocusPointOfInterestObserverContext;
static void *AVCamExposePointOfInterestObserverContext = &AVCamExposePointOfInterestObserverContext;

// HUD Appearance
const CGFloat hudCornerRadius = 8.f;
const CGFloat hudLayerWhite = 1.f;
const CGFloat hudLayerAlpha = .5f;
const CGFloat hudBorderWhite = .0f;
const CGFloat hudBorderAlpha = 1.f;
const CGFloat hudBorderWidth = 1.f;

@interface AVCamViewController ()
@property (nonatomic,retain) NSNumberFormatter *numberFormatter;
@property (nonatomic,assign,getter=isHudHidden) BOOL hudHidden;
@property (nonatomic,retain) CALayer *focusBox;
@property (nonatomic,retain) CALayer *exposeBox;
@end

@interface AVCamViewController (InternalMethods)
- (CALayer *)createLayerBoxWithColor:(UIColor *)color;
- (void)updateExpandyButtonVisibility;
- (void)updateAudioLevels;
- (void)updateRecordingValues;
+ (CGRect)cleanApertureFromPorts:(NSArray *)ports;
+ (CGSize)sizeForGravity:(NSString *)gravity frameSize:(CGSize)frameSize apertureSize:(CGSize)apertureSize;
+ (void)addAdjustingAnimationToLayer:(CALayer *)layer removeAnimation:(BOOL)remove;
- (CGPoint)translatePoint:(CGPoint)point fromGravity:(NSString *)gravity1 toGravity:(NSString *)gravity2;
- (void)drawFocusBoxAtPointOfInterest:(CGPoint)point;
- (void)drawExposeBoxAtPointOfInterest:(CGPoint)point;
- (CGPoint)convertToPointOfInterestFromViewCoordinates:(CGPoint)viewCoordinates;
@end


@interface AVCamViewController (AVCamCaptureManagerDelegate) <AVCamCaptureManagerDelegate>
@end

@interface AVCamViewController (AVCamPreviewViewDelegate) <AVCamPreviewViewDelegate>
@end

@interface AVCamViewController (ADBannerViewDelegate) <ADBannerViewDelegate>

@end


@interface AVCamViewController (FlipsideViewControllerDelegate) <FlipsideViewControllerDelegate>

@end
@implementation AVCamViewController

@synthesize numberFormatter = _numberFormatter;
@synthesize captureManager = _captureManager;
@synthesize cameraToggleButton = _cameraToggleButton;
@synthesize recordButton = _recordButton;
@synthesize stillButton = _stillButton;
@synthesize gravityButton = _gravityButton;
@synthesize videoPreviewView = _videoPreviewView;
@synthesize captureVideoPreviewLayer = _captureVideoPreviewLayer;
@synthesize adjustingInfoView = _adjustingInfoView;
@synthesize hudHidden = _hudHidden;
@synthesize cameraType = _cameraType;
@synthesize flash = _flash;
@synthesize torch = _torch;
@synthesize focus = _focus;
@synthesize exposure = _exposure;
@synthesize whiteBalance = _whiteBalance;
@synthesize preset = _preset;
@synthesize videoConnection = _videoConnection;
@synthesize audioConnection = _audioConnection;
@synthesize orientation = _orientation;
@synthesize mirroring = _mirroring;
@synthesize timerSecondsPerShot= _timerSecondsPerShot;
@synthesize adjustingFocus = _adjustingFocus;
@synthesize adjustingExposure = _adjustingExposure;
@synthesize adjustingWhiteBalance = _adjustingWhiteBalance;
@synthesize statView = _statView;
@synthesize averagePowerLevel = _averagePowerLevel;
@synthesize peakHoldLevel = _peakHoldLevel;
@synthesize focusPoint = _focusPoint;
@synthesize exposurePoint = _exposurePoint;
@synthesize deviceCount = _deviceCount;
@synthesize recordingDuration = _recordingDuration;
@synthesize fileSize = _fileSize;
@synthesize focusBox = _focusBox;
@synthesize exposeBox = _exposeBox;
@synthesize previewImageView = _previewImageView;

@synthesize infoButton = _infoButton;
@synthesize banner;

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [super initWithCoder:(NSCoder *)decoder];
    if (self != nil) {
        NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
        [numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
        [numberFormatter setMinimumFractionDigits:2];
        [numberFormatter setMaximumFractionDigits:2];
        [self setNumberFormatter:numberFormatter];
        [numberFormatter release];            
        
        [self addObserver:self forKeyPath:@"captureManager.videoInput.device.focusMode" options:NSKeyValueObservingOptionNew context:AVCamFocusModeObserverContext];
        [self addObserver:self forKeyPath:@"captureManager.videoInput.device.torchMode" options:NSKeyValueObservingOptionNew context:AVCamTorchModeObserverContext];
        [self addObserver:self forKeyPath:@"captureManager.videoInput.device.flashMode" options:NSKeyValueObservingOptionNew context:AVCamFlashModeObserverContext];
        [self addObserver:self forKeyPath:@"captureManager.videoInput.device.adjustingFocus" options:NSKeyValueObservingOptionNew context:AVCamAdjustingObserverContext];
        [self addObserver:self forKeyPath:@"captureManager.videoInput.device.adjustingExposure" options:NSKeyValueObservingOptionNew context:AVCamAdjustingObserverContext];
        [self addObserver:self forKeyPath:@"captureManager.videoInput.device.adjustingWhiteBalance" options:NSKeyValueObservingOptionNew context:AVCamAdjustingObserverContext];
        [self addObserver:self forKeyPath:@"captureManager.session.sessionPreset" options:NSKeyValueObservingOptionNew context:AVCamSessionPresetObserverContext];
        [self addObserver:self forKeyPath:@"captureManager.videoInput.device.focusPointOfInterest" options:NSKeyValueObservingOptionNew context:AVCamFocusPointOfInterestObserverContext];
        [self addObserver:self forKeyPath:@"captureManager.videoInput.device.exposurePointOfInterest" options:NSKeyValueObservingOptionNew context:AVCamExposePointOfInterestObserverContext];
	}
    return self;
}

- (void) dealloc
{
	self.previewImageView = nil;
    [self setNumberFormatter:nil];
    [self setCaptureManager:nil];
    [super dealloc];
}



- (void)viewDidLoad {
    NSError *error;
    
	// If the banner wasn't included in the nib, create one.
    if(banner == nil)
    {
        [self createADBannerView];
    }
    [self layoutForCurrentOrientation:NO];
	
	
    CALayer *adjustingInfolayer = [[self adjustingInfoView] layer];
    [adjustingInfolayer setCornerRadius:hudCornerRadius];
    [adjustingInfolayer setBorderColor:[[UIColor colorWithWhite:hudBorderWhite alpha:hudBorderAlpha] CGColor]];
    [adjustingInfolayer setBorderWidth:hudBorderWidth];
    [adjustingInfolayer setBackgroundColor:[[UIColor colorWithWhite:hudLayerWhite alpha:hudLayerAlpha] CGColor]];
    [adjustingInfolayer setPosition:CGPointMake([adjustingInfolayer position].x, [adjustingInfolayer position].y + 12.f)];
    
    AVCamCaptureManager *captureManager = [[AVCamCaptureManager alloc] init];
	captureManager.previewImageDelegate = self;
	
    if ([captureManager setupSessionWithPreset:AVCaptureSessionPresetHigh error:&error]) {
        [self setCaptureManager:captureManager];
        
        AVCaptureVideoPreviewLayer *captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:[captureManager session]];
		
		UIView* view = [self videoPreviewView];
        CALayer *viewLayer = [view layer];
        [viewLayer setMasksToBounds:YES];
		
        CGRect bounds = [view bounds];
        
        [captureVideoPreviewLayer setFrame:bounds];
        
        if ([captureVideoPreviewLayer isOrientationSupported]) {
            [captureVideoPreviewLayer setOrientation:AVCaptureVideoOrientationPortrait];
        }
        
        [captureVideoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
        
        [[captureManager session] startRunning];
        
        [self setCaptureVideoPreviewLayer:captureVideoPreviewLayer];
        
        if ([[captureManager session] isRunning]) {
            CALayer *focusBox = [self createLayerBoxWithColor:[UIColor colorWithRed:0.f green:0.f blue:1.f alpha:.8f]];
            [viewLayer addSublayer:focusBox];
            [self setFocusBox:focusBox];
            
            CALayer *exposeBox = [self createLayerBoxWithColor:[UIColor colorWithRed:1.f green:0.f blue:0.f alpha:.8f]]; 
            [viewLayer addSublayer:exposeBox];
            [self setExposeBox:exposeBox];
            
            CGPoint screenCenter = CGPointMake(bounds.size.width / 2.f, bounds.size.height / 2.f);
            
            [self drawFocusBoxAtPointOfInterest:screenCenter];
            [self drawExposeBoxAtPointOfInterest:screenCenter];        
			
            [self performSelector:@selector(updateAudioLevels) withObject:nil afterDelay:0.1f];
            
            [self setHudHidden:YES];
            
            [captureManager setOrientation:AVCaptureVideoOrientationPortrait];
            [captureManager setDelegate:self];
			
            NSUInteger cameraCount = [captureManager cameraCount];
            if (cameraCount < 1) {
                [[self cameraToggleButton] setEnabled:NO];
                [[self stillButton] setEnabled:NO];
                [[self gravityButton] setEnabled:NO];
            } else if (cameraCount < 2) {
                [[self cameraToggleButton] setEnabled:NO]; 
            }
            
            if (cameraCount < 1 && [captureManager micCount] < 1) {
                [[self recordButton] setEnabled:NO];
            }
            
            [viewLayer insertSublayer:captureVideoPreviewLayer below:[[viewLayer sublayers] objectAtIndex:0]];
            
            NSString *countString = [[NSString alloc] initWithFormat:@"%d", [[AVCaptureDevice devices] count]];
            [[self deviceCount] setText:countString];
            [countString release];
            
            [captureVideoPreviewLayer release];
        } else {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Failure"
                                                                message:@"Failed to start session."
                                                               delegate:nil
                                                      cancelButtonTitle:@"Okay"
                                                      otherButtonTitles:nil];
            [alertView show];
            [alertView release];
            [[self stillButton] setEnabled:NO];
            [[self recordButton] setEnabled:NO];
            [[self cameraToggleButton] setEnabled:NO];
        }
    } else {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Input Device Init Failed"
                                                            message:[error localizedDescription]
                                                           delegate:nil
                                                  cancelButtonTitle:@"Okay"
                                                  otherButtonTitles:nil];
        [alertView show];
        [alertView release];        
    }
    
    [captureManager release];
    
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)viewDidUnload
{
    [self removeObserver:self forKeyPath:@"captureManager.videoInput.device.flashMode"];
    [self removeObserver:self forKeyPath:@"captureManager.videoInput.device.torchMode"];
    [self removeObserver:self forKeyPath:@"captureManager.videoInput.device.focusMode"];
    [self removeObserver:self forKeyPath:@"captureManager.videoInput.device.adjustingFocus"];
    [self removeObserver:self forKeyPath:@"captureManager.videoInput.device.adjustingExposure"];
    [self removeObserver:self forKeyPath:@"captureManager.videoInput.device.adjustingWhiteBalance"];
    [self removeObserver:self forKeyPath:@"captureManager.session.sessionPreset"];
    [self removeObserver:self forKeyPath:@"captureManager.videoInput.device.focusPointOfInterest"];
    [self removeObserver:self forKeyPath:@"captureManager.videoInput.device.exposurePointOfInterest"];
    
	self.previewImageView = nil;
    [self setVideoPreviewView:nil];
    [self setCaptureVideoPreviewLayer:nil];
    [self setAdjustingInfoView:nil];
    [self setCameraToggleButton:nil];
    [self setRecordButton:nil];
    [self setStillButton:nil];
    [self setGravityButton:nil];
    [self setFlash:nil];
    [self setTorch:nil];
    [self setFocus:nil];
    [self setExposure:nil];
    [self setWhiteBalance:nil];
    [self setPreset:nil];
    [self setOrientation:nil];
    [self setMirroring:nil];
    [self setVideoConnection:nil];
    [self setAudioConnection:nil];
    [self setAdjustingFocus:nil];
    [self setAdjustingExposure:nil];
    [self setAdjustingWhiteBalance:nil];
    [self setAveragePowerLevel:nil];
    [self setPeakHoldLevel:nil];
    [self setFocusPoint:nil];
    [self setExposurePoint:nil];
    [self setDeviceCount:nil];
    [self setRecordingDuration:nil];
    [self setFileSize:nil];
    [self setFocusBox:nil];
    [self setExposeBox:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([[change objectForKey:NSKeyValueChangeNewKey] isEqual:[NSNull null]]) {
        return;
    }
    if (AVCamFocusModeObserverContext == context) {
        if ([[change objectForKey:NSKeyValueChangeNewKey] integerValue] != [[self focus] selectedItem]) {
            [[self focus] setSelectedItem:[[change objectForKey:NSKeyValueChangeNewKey] integerValue]];
        }
    } else if (AVCamFlashModeObserverContext == context) {
        if ([[change objectForKey:NSKeyValueChangeNewKey] integerValue] != [[self flash] selectedItem]) {
            [[self flash] setSelectedItem:[[change objectForKey:NSKeyValueChangeNewKey] integerValue]];
        }
    } else if (AVCamTorchModeObserverContext == context) {
        if ([[change objectForKey:NSKeyValueChangeNewKey] integerValue] != [[self torch] selectedItem]) {
            [[self torch] setSelectedItem:[[change objectForKey:NSKeyValueChangeNewKey] integerValue]];
        }
    } else if (AVCamAdjustingObserverContext == context) {
        UIView *view = nil;
        if ([keyPath isEqualToString:@"captureManager.videoInput.device.adjustingFocus"]) {
            view = [self adjustingFocus];
            [AVCamViewController addAdjustingAnimationToLayer:[self focusBox] removeAnimation:NO];
        } else if ([keyPath isEqualToString:@"captureManager.videoInput.device.adjustingExposure"]) {
            view = [self adjustingExposure];
            [AVCamViewController addAdjustingAnimationToLayer:[self exposeBox] removeAnimation:NO];
        } else if ([keyPath isEqualToString:@"captureManager.videoInput.device.adjustingWhiteBalance"]) {
            view = [self adjustingWhiteBalance];
        }
        
        if (view != nil) {
            CALayer *layer = [view layer];
            [layer setBorderWidth:1.f];
            [layer setBorderColor:[[UIColor colorWithWhite:0.f alpha:.7f] CGColor]];
            [layer setCornerRadius:8.f];
            
            if ([[change objectForKey:NSKeyValueChangeNewKey] boolValue] == YES) {
                [layer setBackgroundColor:[[UIColor colorWithRed:1.f green:0.f blue:0.f alpha:.7f] CGColor]];
            } else {
                [layer setBackgroundColor:[[UIColor colorWithWhite:1.f alpha:.2f] CGColor]];
            }
        }        
    } else if (AVCamSessionPresetObserverContext == context) {        
        NSString *sessionPreset = [change objectForKey:NSKeyValueChangeNewKey];
        NSInteger selectedItem = -1;
        
        if ([[[self captureManager] sessionPreset] isEqualToString:sessionPreset]) {
            if ([sessionPreset isEqualToString:AVCaptureSessionPresetLow]) {
                selectedItem = 0;
            } else if ([sessionPreset isEqualToString:AVCaptureSessionPresetMedium]) {
                selectedItem = 1;
            } else if ([sessionPreset isEqualToString:AVCaptureSessionPresetHigh]) {
                selectedItem = 2;    
            } else if ([sessionPreset isEqualToString:AVCaptureSessionPresetPhoto]) {
                selectedItem = 3;
            } else if ([sessionPreset isEqualToString:AVCaptureSessionPreset640x480]) {
                selectedItem = 4;
            } else if ([sessionPreset isEqualToString:AVCaptureSessionPreset1280x720]) {
                selectedItem = 5;
            }
            
            [[self preset] setSelectedItem:selectedItem];            
        }
    } else if (AVCamFocusPointOfInterestObserverContext == context) {
        CGPoint point = [[change objectForKey:NSKeyValueChangeNewKey] CGPointValue];
        [[self focusPoint] setText:[NSString stringWithFormat:@"{%.2f,%.2f}", point.y, point.x]];
    } else if (AVCamExposePointOfInterestObserverContext == context) {
        CGPoint point = [[change objectForKey:NSKeyValueChangeNewKey] CGPointValue];
        [[self exposurePoint] setText:[NSString stringWithFormat:@"{%.2f,%.2f}", point.y, point.x]];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}
#pragma mark 
#pragma mark PreviewImageViewDelegate

-(void) configureNewPreviewImage:(CGImageRef)newImage{
	//NSLog(@"configureNewPreviewImage");
	if ([[NSThread currentThread] isMainThread]) {
		static CALayer* previewLayer = nil;
		if (!previewLayer) {
			previewLayer = [self.previewImageView layer];
		}
		previewLayer.contents = (id)newImage;
		
	}else {
		[self performSelectorOnMainThread:@selector(configureNewPreviewImage:) withObject:newImage waitUntilDone:NO];
	}
	
}
#pragma mark Toolbar Actions
- (IBAction)hudViewToggle:(id)sender
{
    if ([self isHudHidden]) {
        [self setHudHidden:NO];
        
        [self updateExpandyButtonVisibility];
        if (DEBUG_DEMO) {
			[[self statView] setHidden:NO];
			if ([[self captureManager] cameraCount] > 0) {
				[[self adjustingInfoView] setHidden:NO];
			}
		}   
                
        
    } else {
        [self setHudHidden:YES];
        
        [self updateExpandyButtonVisibility];
		
        if (DEBUG_DEMO) {
			[[self statView] setHidden:YES];
			[[self adjustingInfoView] setHidden:YES];
		}
                
        
    }    
}

- (IBAction)cameraToggle:(id)sender
{
    [[self captureManager] cameraToggle];
    [[self focusBox] removeAllAnimations];
    [[self exposeBox] removeAllAnimations];
    [self resetFocusAndExpose];
    [self updateExpandyButtonVisibility];
}

//- (IBAction)record:(id)sender
//{
//    if (![[self captureManager] isRecording]) {
//        [[self recordButton] setEnabled:NO];
//        [[self captureManager] startRecording];
//    } else {
//        [[self recordButton] setEnabled:NO];
//        [[self captureManager] stopRecording];
//    }
//}

- (IBAction)viewPhoto:(id)sender
{
	UIImagePickerController* ipc = [[UIImagePickerController alloc] init];
	ipc.delegate = self;

	[self presentModalViewController:ipc animated:YES];
	[ipc release];
}

- (IBAction)still:(id)sender
{
	if (![[self captureManager] isCaptureStillImageWithTimer] ) {
		NSLog(@"start capture");
		[[self captureManager] captureStillImageWithTimer];
		//[_stillButton setImage:[UIImage imageNamed:@"film.png"]];
	}else {
		NSLog(@"stop catpure");
		[[self captureManager] stopCaptureStillImageWithTimer];
		//[_stillButton setImage:[UIImage imageNamed:@"start.png"]];

		
	}
}


- (IBAction)cycleGravity:(id)sender
{
    AVCaptureVideoPreviewLayer *videoPreviewLayer = [self captureVideoPreviewLayer];
    if ( [[videoPreviewLayer videoGravity] isEqualToString:AVLayerVideoGravityResize] ) {
        [[self focusBox] setPosition:[self translatePoint:[[self focusBox] position] fromGravity:AVLayerVideoGravityResize toGravity:AVLayerVideoGravityResizeAspect]];
        [[self exposeBox] setPosition:[self translatePoint:[[self exposeBox] position] fromGravity:AVLayerVideoGravityResize toGravity:AVLayerVideoGravityResizeAspect]];
        [videoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];        
    } else if ( [[videoPreviewLayer videoGravity] isEqualToString:AVLayerVideoGravityResizeAspect] ) {
        [[self focusBox] setPosition:[self translatePoint:[[self focusBox] position] fromGravity:AVLayerVideoGravityResizeAspect toGravity:AVLayerVideoGravityResizeAspectFill]];
        [[self exposeBox] setPosition:[self translatePoint:[[self exposeBox] position] fromGravity:AVLayerVideoGravityResizeAspect toGravity:AVLayerVideoGravityResizeAspectFill]];
        [videoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    } else if ( [[videoPreviewLayer videoGravity] isEqualToString:AVLayerVideoGravityResizeAspectFill] ) {        
        [[self focusBox] setPosition:[self translatePoint:[[self focusBox] position] fromGravity:AVLayerVideoGravityResizeAspectFill toGravity:AVLayerVideoGravityResize]];
        [[self exposeBox] setPosition:[self translatePoint:[[self exposeBox] position] fromGravity:AVLayerVideoGravityResizeAspectFill toGravity:AVLayerVideoGravityResize]];
        [videoPreviewLayer setVideoGravity:AVLayerVideoGravityResize];
    }
    
    [self drawFocusBoxAtPointOfInterest:[[self focusBox] position]];
    [self drawExposeBoxAtPointOfInterest:[[self exposeBox] position]];
}


#pragma mark HUD Actions
- (void)flashChange:(id)sender
{
    switch ([(ExpandyButton *)sender selectedItem]) {
        case 0:
            [[self captureManager] setFlashMode:AVCaptureFlashModeOff];
            break;
        case 1:
            [[self captureManager] setFlashMode:AVCaptureFlashModeOn];
            break;
        case 2:
            [[self captureManager] setFlashMode:AVCaptureFlashModeAuto];
            break;
    }
}

- (void)torchChange:(id)sender
{
    switch ([(ExpandyButton *)sender selectedItem]) {
        case 0:
            [[self captureManager] setTorchMode:AVCaptureTorchModeOff];
            break;
        case 1:
            [[self captureManager] setTorchMode:AVCaptureTorchModeOn];
            break;
        case 2:
            [[self captureManager] setTorchMode:AVCaptureTorchModeAuto];
            break;
    }
}

- (void)focusChange:(id)sender
{
    switch ([(ExpandyButton *)sender selectedItem]) {
        case 0:
            [[self captureManager] setFocusMode:AVCaptureFocusModeLocked];
            break;
        case 1:
            [[self captureManager] setFocusMode:AVCaptureFocusModeAutoFocus];
            break;
        case 2:
            [[self captureManager] setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
            break;
    }
}

- (void)exposureChange:(id)sender
{
    switch ([(ExpandyButton *)sender selectedItem]) {
        case 0:
            [[self captureManager] setExposureMode:AVCaptureExposureModeLocked];
            break;
        case 1:
            [[self captureManager] setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
            break;
    }
}

- (void)whiteBalanceChange:(id)sender
{
    switch ([(ExpandyButton *)sender selectedItem]) {
        case 0:
            [[self captureManager] setWhiteBalanceMode:AVCaptureWhiteBalanceModeLocked];
            break;
        case 1:
            [[self captureManager] setWhiteBalanceMode:AVCaptureWhiteBalanceModeAutoWhiteBalance];
            break;
    }
}

- (void)presetChange:(id)sender
{
    NSString *oldSessionPreset = [[self captureManager] sessionPreset];
    switch ([(ExpandyButton *)sender selectedItem]) {
        case 0:
            [[self captureManager] setSessionPreset:AVCaptureSessionPresetLow];
            break;
        case 1:
            [[self captureManager] setSessionPreset:AVCaptureSessionPresetMedium];
            break;
        case 2:
            [[self captureManager] setSessionPreset:AVCaptureSessionPresetHigh];
            break;
        case 3:
            [[self captureManager] setSessionPreset:AVCaptureSessionPresetPhoto];
            break;
        case 4:
            [[self captureManager] setSessionPreset:AVCaptureSessionPreset640x480];
            break;
        case 5:
            [[self captureManager] setSessionPreset:AVCaptureSessionPreset1280x720];
            break;
    }
    
    if ([oldSessionPreset isEqualToString:[[self captureManager] sessionPreset]]) {
        if ([oldSessionPreset isEqualToString:AVCaptureSessionPresetLow]) {
            [(ExpandyButton *)sender setSelectedItem:0];
        } else if ([oldSessionPreset isEqualToString:AVCaptureSessionPresetMedium]) {
            [(ExpandyButton *)sender setSelectedItem:1];
        } else if ([oldSessionPreset isEqualToString:AVCaptureSessionPresetHigh]) {
            [(ExpandyButton *)sender setSelectedItem:2];
        } else if ([oldSessionPreset isEqualToString:AVCaptureSessionPresetPhoto]) {
            [(ExpandyButton *)sender setSelectedItem:3];
        } else if ([oldSessionPreset isEqualToString:AVCaptureSessionPreset640x480]) {
            [(ExpandyButton *)sender setSelectedItem:4];
        } else if ([oldSessionPreset isEqualToString:AVCaptureSessionPreset1280x720]) {
            [(ExpandyButton *)sender setSelectedItem:5];
        }
    }
}

- (void)videoConnectionToggle:(id)sender
{
    switch ([(ExpandyButton *)sender selectedItem]) {
        case 0:
            [[self captureManager] setConnectionWithMediaType:AVMediaTypeVideo enabled:NO];
            break;
        case 1:
            [[self captureManager] setConnectionWithMediaType:AVMediaTypeVideo enabled:YES];
            break;
    }
}

- (void)audioConnectionToggle:(id)sender
{
    switch ([(ExpandyButton *)sender selectedItem]) {
        case 0:
            [[self captureManager] setConnectionWithMediaType:AVMediaTypeAudio enabled:NO];
            break;
        case 1:
            [[self captureManager] setConnectionWithMediaType:AVMediaTypeAudio enabled:YES];
            break;
    }
}

- (void)adjustOrientation:(id)sender
{
    AVCaptureVideoPreviewLayer *previewLayer = [self captureVideoPreviewLayer];
    AVCaptureSession *session = [[self captureManager] session];
    [session beginConfiguration];    
    switch ([(ExpandyButton *)sender selectedItem]) {
        case 0:
            [[self captureManager] setOrientation:AVCaptureVideoOrientationPortrait];
            if ([previewLayer isOrientationSupported]) {
                [previewLayer setOrientation:AVCaptureVideoOrientationPortrait];
            }
            break;
        case 1:
            [[self captureManager] setOrientation:AVCaptureVideoOrientationPortraitUpsideDown];
            if ([previewLayer isOrientationSupported]) {
                [previewLayer setOrientation:AVCaptureVideoOrientationPortraitUpsideDown];
            }
            break;
        case 2:
            [[self captureManager] setOrientation:AVCaptureVideoOrientationLandscapeLeft];
            if ([previewLayer isOrientationSupported]) {
                [previewLayer setOrientation:AVCaptureVideoOrientationLandscapeLeft];
            }
            break;
        case 3:
            [[self captureManager] setOrientation:AVCaptureVideoOrientationLandscapeRight];
            if ([previewLayer isOrientationSupported]) {
                [previewLayer setOrientation:AVCaptureVideoOrientationLandscapeRight];
            }
            break;
    }
    [session commitConfiguration];
}

- (void)adjustMirroring:(id)sender
{
    AVCaptureVideoPreviewLayer *previewLayer = [self captureVideoPreviewLayer];
    AVCaptureSession *session = [[self captureManager] session];
    [session beginConfiguration];
    switch ([(ExpandyButton *)sender selectedItem]) {
        case 0:
            [[self captureManager] setMirroringMode:AVCamMirroringOff];
            if ([previewLayer isMirroringSupported]) {
                [previewLayer setAutomaticallyAdjustsMirroring:NO];
                [previewLayer setMirrored:NO];
            }
            break;
        case 1:
            [[self captureManager] setMirroringMode:AVCamMirroringOn];
            if ([previewLayer isMirroringSupported]) {
                [previewLayer setAutomaticallyAdjustsMirroring:NO];
                [previewLayer setMirrored:YES];
            }
            break;
        case 2:
            [[self captureManager] setMirroringMode:AVCamMirroringAuto];
            if ([previewLayer isMirroringSupported]) {
                [previewLayer setAutomaticallyAdjustsMirroring:YES];
            }
            break;
    }
    [session commitConfiguration];
}

-(void)timerSecondsPerShotSelect:(id)sender
{
	switch ([(ExpandyButton *)sender selectedItem]) {
        case 0:
            [[self captureManager] setTimerSecPerShot:3];
            break;
        case 1:
            [[self captureManager] setTimerSecPerShot:4];
			break;
		case 2:
            [[self captureManager] setTimerSecPerShot:5];
			break;
		case 3:
            [[self captureManager] setTimerSecPerShot:7];
			break;
		case 4:
            [[self captureManager] setTimerSecPerShot:10];
			break;
	}
	
}

@end

@implementation AVCamViewController (InternalMethods)

- (CALayer *)createLayerBoxWithColor:(UIColor *)color
{
    NSDictionary *unanimatedActions = [[NSDictionary alloc] initWithObjectsAndKeys:[NSNull null], @"bounds",[NSNull null], @"frame",[NSNull null], @"position", nil];
    CALayer *box = [[CALayer alloc] init];
    [box setActions:unanimatedActions];
    [box setBorderWidth:3.f];
    [box setBorderColor:[color CGColor]];
    [box setOpacity:0.f];
    [unanimatedActions release];
    
    return [box autorelease];
}

- (void)updateExpandyButtonVisibility
{
    if ([self isHudHidden]) {
		[[self cameraType] setHidden:YES];
        [[self flash] setHidden:YES];
        [[self torch] setHidden:YES];
        [[self focus] setHidden:YES];
        [[self exposure] setHidden:YES];
        [[self whiteBalance] setHidden:YES];
        [[self preset] setHidden:YES];
        [[self videoConnection] setHidden:YES];
        [[self audioConnection] setHidden:YES];
        [[self orientation] setHidden:YES];
        [[self mirroring] setHidden:YES]; 
		[[self timerSecondsPerShot] setHidden:YES];
		[[self infoButton] setHidden:YES];
			
    } else {
		// 
			
        NSInteger count = 2;   // put it below iAd banner 
		
		UIView *previewView = [self videoPreviewView];
        static UIScrollView *view = nil;
		if (!view) {
			view = [[[UIScrollView alloc] initWithFrame:previewView.frame] autorelease];
			view.scrollEnabled = YES;
			view.showsVerticalScrollIndicator = UIScrollViewIndicatorStyleWhite;
			view.contentSize = CGSizeMake(view.frame.size.width, view.frame.size.height*2);
			[previewView addSubview:view];
		}
		
        AVCamCaptureManager *captureManager = [self captureManager];
        ExpandyButton *expandyButton;
		
		expandyButton = [self cameraType];
        if ([captureManager hasMultiCamera]) {
            if (expandyButton == nil) {
                ExpandyButton *cameraTypeButton =  [[ExpandyButton alloc] initWithPoint:CGPointMake(8.f, 8.f + (40.f * count) )
                                                                       title:@"Cam"
                                                                 buttonNames:[NSArray arrayWithObjects:@"Back",@"Front",nil]
                                                                selectedItem:[captureManager cameraPosition]];
                [cameraTypeButton addTarget:self action:@selector(cameraToggle:) forControlEvents:UIControlEventValueChanged];
                [view addSubview:cameraTypeButton];
                [self setCameraType:cameraTypeButton];
                [cameraTypeButton release];
            } else {
                CGRect frame = [expandyButton frame];
                [expandyButton setFrame:CGRectMake(8.f, 8.f + (40.f * count), frame.size.width, frame.size.height)];
                [expandyButton setHidden:NO];
            }
            count++;
        } else {
            [expandyButton setHidden:YES];
        }
        
        expandyButton = [self flash];
        if ([captureManager hasFlash]) {
            if (expandyButton == nil) {
                ExpandyButton *flash =  [[ExpandyButton alloc] initWithPoint:CGPointMake(8.f,8.f + (40.f * count))
                                                                       title:@"Flash"
                                                                 buttonNames:[NSArray arrayWithObjects:@"Off",@"On",@"Auto",nil]
                                                                selectedItem:[captureManager flashMode]];
                [flash addTarget:self action:@selector(flashChange:) forControlEvents:UIControlEventValueChanged];
                [view addSubview:flash];
                [self setFlash:flash];
                [flash release];
            } else {
                CGRect frame = [expandyButton frame];
                [expandyButton setFrame:CGRectMake(8.f, 8.f + (40.f * count), frame.size.width, frame.size.height)];
                [expandyButton setHidden:NO];
            }
            count++;
        } else {
            [expandyButton setHidden:YES];
        }
		
        expandyButton = [self torch];        
        if ([captureManager hasTorch]) {
            if (expandyButton == nil) {
                ExpandyButton *torch =  [[ExpandyButton alloc] initWithPoint:CGPointMake(8.f, 8.f + (40.f * count))
                                                                       title:@"Torch"
                                                                 buttonNames:[NSArray arrayWithObjects:@"Off",@"On",@"Auto",nil]
                                                                selectedItem:[captureManager torchMode]];
                [torch addTarget:self action:@selector(torchChange:) forControlEvents:UIControlEventValueChanged];
                [view addSubview:torch];
                [self setTorch:torch];
                [torch release];                
            } else {
                CGRect frame = [expandyButton frame];
                [expandyButton setFrame:CGRectMake(8.f, 8.f + (40.f * count), frame.size.width, frame.size.height)];
                [expandyButton setHidden:NO];
            }
            count++;
        } else {
            [expandyButton setHidden:YES];
        }
        
//        expandyButton = [self focus];
//        if ([captureManager hasFocus]) {
//            if (expandyButton == nil) {
//                ExpandyButton *focus =  [[ExpandyButton alloc] initWithPoint:CGPointMake(8.f, 8.f + (40.f * count))
//                                                                       title:@"Focus"
//                                                                 buttonNames:[NSArray arrayWithObjects:@"Lock",@"Auto",@"Cont",nil]
//                                                                selectedItem:[captureManager focusMode]];
//                [focus addTarget:self action:@selector(focusChange:) forControlEvents:UIControlEventValueChanged];
//                [view addSubview:focus];
//                [self setFocus:focus];
//                [focus release];
//            } else {
//                CGRect frame = [expandyButton frame];
//                [expandyButton setFrame:CGRectMake(8.f, 8.f + (40.f * count), frame.size.width, frame.size.height)];
//                [expandyButton setHidden:NO];                
//            }
//            count++;
//        } else {
//            [expandyButton setHidden:YES];
//        }
        
       // expandyButton = [self exposure];
//        if ([captureManager hasExposure]) {
//            if (expandyButton == nil) {
//                ExpandyButton *exposure =  [[ExpandyButton alloc] initWithPoint:CGPointMake(8.f, 8.f + (40.f * count))
//                                                                          title:@"AExp"
//                                                                    buttonNames:[NSArray arrayWithObjects:@"Lock",@"Cont",nil]
//                                                                   selectedItem:([captureManager exposureMode] == 2 ? 1 : [captureManager exposureMode])];
//                [exposure addTarget:self action:@selector(exposureChange:) forControlEvents:UIControlEventValueChanged];
//                [view addSubview:exposure];
//                [self setExposure:exposure];
//                [exposure release];
//            } else {
//                CGRect frame = [expandyButton frame];
//                [expandyButton setFrame:CGRectMake(8.f, 8.f + (40.f * count), frame.size.width, frame.size.height)];
//                [expandyButton setHidden:NO];                
//            }
//            count++;
//        } else {
//            [expandyButton setHidden:YES];
//        }
//        
//        expandyButton = [self whiteBalance];
//        if ([captureManager hasWhiteBalance]) {
//            if (expandyButton == nil) {
//                ExpandyButton *whiteBalance =  [[ExpandyButton alloc] initWithPoint:CGPointMake(8.f, 8.f + (40.f * count))
//                                                                              title:@"AWB"
//                                                                        buttonNames:[NSArray arrayWithObjects:@"Lock",@"Cont",nil]
//                                                                       selectedItem:([captureManager whiteBalanceMode] == 2 ? 1 : [captureManager whiteBalanceMode])];
//                [whiteBalance addTarget:self action:@selector(whiteBalanceChange:) forControlEvents:UIControlEventValueChanged];
//                [view addSubview:whiteBalance];
//                [self setWhiteBalance:whiteBalance];
//                [whiteBalance release];
//            } else {
//                CGRect frame = [expandyButton frame];
//                [expandyButton setFrame:CGRectMake(8.f, 8.f + (40.f * count), frame.size.width, frame.size.height)];
//                [expandyButton setHidden:NO];                
//            }
//            count++;
//        } else {
//            [expandyButton setHidden:YES];
//        }
        
        {
            expandyButton = [self preset];
            if (expandyButton == nil) {
                ExpandyButton *preset =  [[ExpandyButton alloc] initWithPoint:CGPointMake(8.f, 8.f + (40.f * count))
                                                                        title:@"Preset"
                                                                  buttonNames:[NSArray arrayWithObjects:@"Low",@"Med",@"High",@"Photo",@"480p",@"720p",nil]
                                                                 selectedItem:2
                                                                  buttonWidth:40.f];
                [preset addTarget:self action:@selector(presetChange:) forControlEvents:UIControlEventValueChanged];
                [view addSubview:preset];
                [self setPreset:preset];
                [preset release];
            } else {
                CGRect frame = [expandyButton frame];
                [expandyButton setFrame:CGRectMake(8.f, 8.f + (40.f * count), frame.size.width, frame.size.height)];
                [expandyButton setHidden:NO];                
            }
            count++;
        }       
		
	//	self.infoButton.frame.origin.x = 8.f;
	//	self.infoButton.frame.origin.x = 8.f + (40.f * count); //CGRectMake(8.f, 8.f + (40.f * count), frame.size.width, frame.size.height);
        
      //  expandyButton = [self videoConnection];
//        if ([[captureManager videoInput] device] != nil) {
//            if (expandyButton == nil) {
//                ExpandyButton *videoConnection =  [[ExpandyButton alloc] initWithPoint:CGPointMake(8.f, 8.f + (40.f * count))
//                                                                                 title:@"Video"
//                                                                           buttonNames:[NSArray arrayWithObjects:@"Off",@"On",nil]
//                                                                          selectedItem:1];
//                [videoConnection addTarget:self action:@selector(videoConnectionToggle:) forControlEvents:UIControlEventValueChanged];
//                [view addSubview:videoConnection];
//                [self setVideoConnection:videoConnection];
//                [videoConnection release];
//            } else {
//                CGRect frame = [expandyButton frame];
//                [expandyButton setFrame:CGRectMake(8.f, 8.f + (40.f * count), frame.size.width, frame.size.height)];
//                [expandyButton setHidden:NO];                
//            }
//            count++;
//        } else {
//            [expandyButton setHidden:YES];
//        }
//        
//        expandyButton = [self audioConnection];
//        if ([[captureManager audioInput] device] != nil) {
//            if (expandyButton == nil) {
//                ExpandyButton *audioConnection =  [[ExpandyButton alloc] initWithPoint:CGPointMake(8.f, 8.f + (40.f * count))
//                                                                                 title:@"Audio"
//                                                                           buttonNames:[NSArray arrayWithObjects:@"Off",@"On",nil]
//                                                                          selectedItem:1];
//                [audioConnection addTarget:self action:@selector(audioConnectionToggle:) forControlEvents:UIControlEventValueChanged];
//                [view addSubview:audioConnection];
//                [self setAudioConnection:audioConnection];
//                [audioConnection release];
//            } else {
//                CGRect frame = [expandyButton frame];
//                [expandyButton setFrame:CGRectMake(8.f, 8.f + (40.f * count), frame.size.width, frame.size.height)];
//                [expandyButton setHidden:NO];                
//            }
//            count++;
//        } else {
//            [expandyButton setHidden:YES];
//        }
//        
//        {
//            expandyButton = [self orientation];
//            if (expandyButton == nil) {
//                ExpandyButton *orientation =  [[ExpandyButton alloc] initWithPoint:CGPointMake(8.f, 8.f + (40.f * count))
//                                                                             title:@"Orient"
//                                                                       buttonNames:[NSArray arrayWithObjects:@"Port",@"Upsi",@"Left",@"Right",nil]];
//                [orientation addTarget:self action:@selector(adjustOrientation:) forControlEvents:UIControlEventValueChanged];
//                [view addSubview:orientation];
//                [self setOrientation:orientation];
//                [orientation release];
//            } else {
//                CGRect frame = [expandyButton frame];
//                [expandyButton setFrame:CGRectMake(8.f, 8.f + (40.f * count), frame.size.width, frame.size.height)];
//                [expandyButton setHidden:NO];                
//            }
//            count++;
//        }
//        
//		{
//			expandyButton = [self mirroring];
//			if ([captureManager supportsMirroring] || [[self captureVideoPreviewLayer] isMirroringSupported]) {
//				if (expandyButton == nil) {
//					ExpandyButton *mirroring =  [[ExpandyButton alloc] initWithPoint:CGPointMake(8.f, 8.f + (40.f * count))
//																			   title:@"Mirror"
//																		 buttonNames:[NSArray arrayWithObjects:@"Off",@"On",@"Auto",nil]
//																		selectedItem:2];
//					[mirroring addTarget:self action:@selector(adjustMirroring:) forControlEvents:UIControlEventValueChanged];
//					[view addSubview:mirroring];
//					[self setMirroring:mirroring];
//					[mirroring release];
//				} else {
//					CGRect frame = [expandyButton frame];
//					[expandyButton setFrame:CGRectMake(8.f, 8.f + (40.f * count), frame.size.width, frame.size.height)];
//					[expandyButton setHidden:NO];                
//				}
//			} else {
//				[expandyButton setHidden:YES];
//			}
//			count++;
//		}
//				
		{
			expandyButton = [self timerSecondsPerShot];
			if ([captureManager supportsTimer]) {
				if (expandyButton == nil) {
					ExpandyButton *timerSecondsPerShot =  [[ExpandyButton alloc] initWithPoint:CGPointMake(8.f, 8.f + (40.f * count))
																						 title:@"Interval"
																				   buttonNames:[NSArray arrayWithObjects:@"3s",@"4s",@"5s",@"7s",@"10s",nil]
																				  selectedItem:1];
					[timerSecondsPerShot addTarget:self action:@selector(timerSecondsPerShotSelect:) forControlEvents:UIControlEventValueChanged];
					[view addSubview:timerSecondsPerShot];
					self.timerSecondsPerShot = timerSecondsPerShot;
					[timerSecondsPerShot release];
				} else {
					CGRect frame = [expandyButton frame];
					[expandyButton setFrame:CGRectMake(8.f, 8.f + (40.f * count), frame.size.width, frame.size.height)];
					[expandyButton setHidden:NO];                
				}
				count++;
			} else {
				[expandyButton setHidden:YES];
			}
		}

    }
}

- (void)updateAudioLevels
{
	if (DEBUG_DEMO == 0) {
		return ;
	}
    AVCaptureAudioChannel *audioChannel = [[self captureManager] audioChannel];
    float powerLevel = [audioChannel averagePowerLevel];
    float peakHoldLevel = [audioChannel peakHoldLevel];
    NSNumberFormatter *numberFormatter = [self numberFormatter];
    NSString *powerLevelString = [numberFormatter stringFromNumber:[NSNumber numberWithFloat:powerLevel]];
    NSString *peakHoldLevelString = [numberFormatter stringFromNumber:[NSNumber numberWithFloat:peakHoldLevel]];
    
    [[self averagePowerLevel] setText:[NSString stringWithFormat:@"%@ dB", powerLevelString]];
    [[self peakHoldLevel] setText:[NSString stringWithFormat:@"%@ dB", peakHoldLevelString]];
    
    [self performSelector:@selector(updateAudioLevels) withObject:nil afterDelay:.1f];
}

- (void)updateRecordingValues
{
	if (DEBUG_DEMO == 0) {
		return ;
	}
	
    AVCaptureMovieFileOutput *movieFileOutput = [[self captureManager] movieFileOutput];
    if ([movieFileOutput isRecording]) {
        Float64 seconds = CMTimeGetSeconds([movieFileOutput recordedDuration]);
        Float64 hours = trunc(seconds / 3600.f);
        seconds -= hours * 3600.f;
        Float64 minutes = trunc(seconds / 60.f);
        seconds -= minutes * 60.f;
        [[self recordingDuration] setText:[NSString stringWithFormat:@"%02.0f:%02.0f:%05.2f",hours,minutes,seconds]];
        
        [[self fileSize] setText:[NSString stringWithFormat:@"%lld",[movieFileOutput recordedFileSize]]];
        
        [self performSelector:@selector(updateRecordingValues) withObject:nil afterDelay:.1f];
    }
}

+ (CGRect)cleanApertureFromPorts:(NSArray *)ports
{
    CGRect cleanAperture;
    for (AVCaptureInputPort *port in ports) {
        if ([port mediaType] == AVMediaTypeVideo) {
            cleanAperture = CMVideoFormatDescriptionGetCleanAperture([port formatDescription], YES);
            break;
        }
    }
    return cleanAperture;
}

+ (CGSize)sizeForGravity:(NSString *)gravity frameSize:(CGSize)frameSize apertureSize:(CGSize)apertureSize
{
    CGFloat apertureRatio = apertureSize.height / apertureSize.width;
    CGFloat viewRatio = frameSize.width / frameSize.height;
    
    CGSize size;
    if ([gravity isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
        if (viewRatio > apertureRatio) {
            size.width = frameSize.width;
            size.height = apertureSize.width * (frameSize.width / apertureSize.height);
        } else {
            size.width = apertureSize.height * (frameSize.height / apertureSize.width);
            size.height = frameSize.height;
        }
    } else if ([gravity isEqualToString:AVLayerVideoGravityResizeAspect]) {
        if (viewRatio > apertureRatio) {
            size.width = apertureSize.height * (frameSize.height / apertureSize.width);
            size.height = frameSize.height;
        } else {
            size.width = frameSize.width;
            size.height = apertureSize.width * (frameSize.width / apertureSize.height);
        }
    } else if ([gravity isEqualToString:AVLayerVideoGravityResize]) {
        size.width = frameSize.width;
        size.height = frameSize.height;
    }
    
    return size;
}

+ (void)addAdjustingAnimationToLayer:(CALayer *)layer removeAnimation:(BOOL)remove
{
    if (remove) {
        [layer removeAnimationForKey:@"animateOpacity"];
    }
    if ([layer animationForKey:@"animateOpacity"] == nil) {
        [layer setHidden:NO];
        CABasicAnimation *opacityAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
        [opacityAnimation setDuration:.3f];
        [opacityAnimation setRepeatCount:1.f];
        [opacityAnimation setAutoreverses:YES];
        [opacityAnimation setFromValue:[NSNumber numberWithFloat:1.f]];
        [opacityAnimation setToValue:[NSNumber numberWithFloat:.0f]];
        [layer addAnimation:opacityAnimation forKey:@"animateOpacity"];
    }
}

- (CGPoint)translatePoint:(CGPoint)point fromGravity:(NSString *)oldGravity toGravity:(NSString *)newGravity
{
    CGPoint newPoint;
    
    CGSize frameSize = [[self videoPreviewView] frame].size;
    
    CGSize apertureSize = [AVCamViewController cleanApertureFromPorts:[[[self captureManager] videoInput] ports]].size;
    
    CGSize oldSize = [AVCamViewController sizeForGravity:oldGravity frameSize:frameSize apertureSize:apertureSize];
    
    CGSize newSize = [AVCamViewController sizeForGravity:newGravity frameSize:frameSize apertureSize:apertureSize];
    
    if (oldSize.height < newSize.height) {
        newPoint.y = ((point.y * newSize.height) / oldSize.height) - ((newSize.height - oldSize.height) / 2.f);
    } else if (oldSize.height > newSize.height) {
        newPoint.y = ((point.y * newSize.height) / oldSize.height) + ((oldSize.height - newSize.height) / 2.f) * (newSize.height / oldSize.height);
    } else if (oldSize.height == newSize.height) {
        newPoint.y = point.y;
    }
    
    if (oldSize.width < newSize.width) {
        newPoint.x = (((point.x - ((newSize.width - oldSize.width) / 2.f)) * newSize.width) / oldSize.width);
    } else if (oldSize.width > newSize.width) {
        newPoint.x = ((point.x * newSize.width) / oldSize.width) + ((oldSize.width - newSize.width) / 2.f);
    } else if (oldSize.width == newSize.width) {
        newPoint.x = point.x;
    }
    
    return newPoint;
}

- (void)drawFocusBoxAtPointOfInterest:(CGPoint)point
{
	//simplify for release product
	if (DEBUG_DEMO == 0) {
		return;  // 
	}
	
    AVCamCaptureManager *captureManager = [self captureManager];
    if ([captureManager hasFocus]) {
        CGSize frameSize = [[self videoPreviewView] frame].size;
        
        CGSize apertureSize = [AVCamViewController cleanApertureFromPorts:[[[self captureManager] videoInput] ports]].size;
        
        CGSize oldBoxSize = [AVCamViewController sizeForGravity:[[self captureVideoPreviewLayer] videoGravity] frameSize:frameSize apertureSize:apertureSize];
        
        CGPoint focusPointOfInterest = [[[captureManager videoInput] device] focusPointOfInterest];
        CGSize newBoxSize;
        if (focusPointOfInterest.x == .5f && focusPointOfInterest.y == .5f) {
            newBoxSize.width = (116.f / frameSize.width) * oldBoxSize.width;
            newBoxSize.height = (158.f / frameSize.height) * oldBoxSize.height;
        } else {
            newBoxSize.width = (80.f / frameSize.width) * oldBoxSize.width;
            newBoxSize.height = (110.f / frameSize.height) * oldBoxSize.height;
        }
        
        CALayer *focusBox = [self focusBox];
        [focusBox setFrame:CGRectMake(0.f, 0.f, newBoxSize.width, newBoxSize.height)];
        [focusBox setPosition:point];
        [AVCamViewController addAdjustingAnimationToLayer:focusBox removeAnimation:YES];
    }
}

- (void)drawExposeBoxAtPointOfInterest:(CGPoint)point
{
	//simplify for release product
	if (DEBUG_DEMO == 0) {
		return;  // 
	}
    AVCamCaptureManager *captureManager = [self captureManager];
    if ([captureManager hasExposure]) {
        CGSize frameSize = [[self videoPreviewView] frame].size;
        
        CGSize apertureSize = [AVCamViewController cleanApertureFromPorts:[[[self captureManager] videoInput] ports]].size;
        
        CGSize oldBoxSize = [AVCamViewController sizeForGravity:[[self captureVideoPreviewLayer] videoGravity] frameSize:frameSize apertureSize:apertureSize];
        
        CGPoint exposurePointOfInterest = [[[captureManager videoInput] device] exposurePointOfInterest];
        CGSize newBoxSize;
        if (exposurePointOfInterest.x == .5f && exposurePointOfInterest.y == .5f) {
            newBoxSize.width = (290.f / frameSize.width) * oldBoxSize.width;
            newBoxSize.height = (395.f / frameSize.height) * oldBoxSize.height;
        } else {
            newBoxSize.width = (114.f / frameSize.width) * oldBoxSize.width;
            newBoxSize.height = (154.f / frameSize.height) * oldBoxSize.height;
        }
        
        CALayer *exposeBox = [self exposeBox];
        [exposeBox setFrame:CGRectMake(0.f, 0.f, newBoxSize.width, newBoxSize.height)];
        [exposeBox setPosition:point];
        [AVCamViewController addAdjustingAnimationToLayer:exposeBox removeAnimation:YES];
    }
}

- (CGPoint)convertToPointOfInterestFromViewCoordinates:(CGPoint)viewCoordinates 
{
    CGPoint pointOfInterest = CGPointMake(.5f, .5f);
    CGSize frameSize = [[self videoPreviewView] frame].size;
    
    AVCaptureVideoPreviewLayer *videoPreviewLayer = [self captureVideoPreviewLayer];
    
    if ([[self captureVideoPreviewLayer] isMirrored]) {
        viewCoordinates.x = frameSize.width - viewCoordinates.x;
    }    
    
    if ( [[videoPreviewLayer videoGravity] isEqualToString:AVLayerVideoGravityResize] ) {
        pointOfInterest = CGPointMake(viewCoordinates.y / frameSize.height, 1.f - (viewCoordinates.x / frameSize.width));
    } else {
        CGRect cleanAperture;
        for (AVCaptureInputPort *port in [[[self captureManager] videoInput] ports]) {
            if ([port mediaType] == AVMediaTypeVideo) {
                cleanAperture = CMVideoFormatDescriptionGetCleanAperture([port formatDescription], YES);
                CGSize apertureSize = cleanAperture.size;
                CGPoint point = viewCoordinates;
                
                CGFloat apertureRatio = apertureSize.height / apertureSize.width;
                CGFloat viewRatio = frameSize.width / frameSize.height;
                CGFloat xc = .5f;
                CGFloat yc = .5f;
                
                if ( [[videoPreviewLayer videoGravity] isEqualToString:AVLayerVideoGravityResizeAspect] ) {
                    if (viewRatio > apertureRatio) {
                        CGFloat y2 = frameSize.height;
                        CGFloat x2 = frameSize.height * apertureRatio;
                        CGFloat x1 = frameSize.width;
                        CGFloat blackBar = (x1 - x2) / 2;
                        if (point.x >= blackBar && point.x <= blackBar + x2) {
                            xc = point.y / y2;
                            yc = 1.f - ((point.x - blackBar) / x2);
                        }
                    } else {
                        CGFloat y2 = frameSize.width / apertureRatio;
                        CGFloat y1 = frameSize.height;
                        CGFloat x2 = frameSize.width;
                        CGFloat blackBar = (y1 - y2) / 2;
                        if (point.y >= blackBar && point.y <= blackBar + y2) {
                            xc = ((point.y - blackBar) / y2);
                            yc = 1.f - (point.x / x2);
                        }
                    }
                } else if ([[videoPreviewLayer videoGravity] isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
                    if (viewRatio > apertureRatio) {
                        CGFloat y2 = apertureSize.width * (frameSize.width / apertureSize.height);
                        xc = (point.y + ((y2 - frameSize.height) / 2.f)) / y2;
                        yc = (frameSize.width - point.x) / frameSize.width;
                    } else {
                        CGFloat x2 = apertureSize.height * (frameSize.height / apertureSize.width);
                        yc = 1.f - ((point.x + ((x2 - frameSize.width) / 2)) / x2);
                        xc = point.y / frameSize.height;
                    }
                }
                
                pointOfInterest = CGPointMake(xc, yc);
                break;
            }
        }
    }
    
    return pointOfInterest;
}



@end

@implementation AVCamViewController (AVCamCaptureManagerDelegate)

- (void) captureStillImageFailedWithError:(NSError *)error
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Still Image Capture Failure"
                                                        message:[error localizedDescription]
                                                       delegate:nil
                                              cancelButtonTitle:@"Okay"
                                              otherButtonTitles:nil];
    [alertView show];
    [alertView release];
}

- (void) cannotWriteToAssetLibrary
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Incompatible with Asset Library"
                                                        message:@"The captured file cannot be written to the asset library. It is likely an audio-only file."
                                                       delegate:nil
                                              cancelButtonTitle:@"Okay"
                                              otherButtonTitles:nil];
    [alertView show];
    [alertView release];        
}

- (void) acquiringDeviceLockFailedWithError:(NSError *)error
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Device Configuration Lock Failure"
                                                        message:[error localizedDescription]
                                                       delegate:nil
                                              cancelButtonTitle:@"Okay"
                                              otherButtonTitles:nil];
    [alertView show];
    [alertView release];    
}

- (void) assetLibraryError:(NSError *)error forURL:(NSURL *)assetURL
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Asset Library Error"
                                                        message:[error localizedDescription]
                                                       delegate:nil
                                              cancelButtonTitle:@"Okay"
                                              otherButtonTitles:nil];
    [alertView show];
    [alertView release];    
}

- (void) someOtherError:(NSError *)error
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error"
                                                        message:[error localizedDescription]
                                                       delegate:nil
                                              cancelButtonTitle:@"Okay"
                                              otherButtonTitles:nil];
    [alertView show];
    [alertView release];    
}

- (void) recordingBegan
{
    [[self recordButton] setTitle:@"Stop"];
    [[self recordButton] setEnabled:YES];
    [self updateRecordingValues];
}

- (void) recordingFinished
{
    [[self recordButton] setTitle:@"Record"];
    [[self recordButton] setEnabled:YES];
}

- (void) timerCaptureBegan
{
	[[self stillButton] setTitle:@"Stop"];
	[[self stillButton] setEnabled:YES];
}
- (void) timerCaptureFinished
{
	[[self stillButton] setTitle:@"Start Timer"];
	[[self stillButton] setEnabled:YES];
}

- (void) deviceCountChanged
{
    NSString *count = [[NSString alloc] initWithFormat:@"%d", [[AVCaptureDevice devices] count]];
    [[self deviceCount] setText:count];
    [count release];
    [self updateExpandyButtonVisibility];
    
    AVCamCaptureManager *captureManager = [self captureManager];
    if ([captureManager cameraCount] >= 1 || [captureManager micCount] >= 1) {
        [[self recordButton] setEnabled:YES];
    } else {
        [[self recordButton] setEnabled:NO];
    }
}

@end

@implementation AVCamViewController (AVCamPreviewViewDelegate)

- (void)tapToFocus:(CGPoint)point
{
    AVCamCaptureManager *captureManager = [self captureManager];
    if ([[[captureManager videoInput] device] isFocusPointOfInterestSupported]) {
        CGPoint convertedFocusPoint = [self convertToPointOfInterestFromViewCoordinates:point];
        [captureManager focusAtPoint:convertedFocusPoint];
        [self drawFocusBoxAtPointOfInterest:point];
    }
}

- (void)tapToExpose:(CGPoint)point
{
    AVCamCaptureManager *captureManager = [self captureManager];
    if ([[[captureManager videoInput] device] isExposurePointOfInterestSupported]) {
        CGPoint convertedExposurePoint = [self convertToPointOfInterestFromViewCoordinates:point];
        [[self captureManager] exposureAtPoint:convertedExposurePoint];
        [self drawExposeBoxAtPointOfInterest:point];
    }
}

- (void)resetFocusAndExpose
{
    CGPoint pointOfInterest = CGPointMake(.5f, .5f);
    [[self captureManager] focusAtPoint:pointOfInterest];
    [[self captureManager] exposureAtPoint:pointOfInterest];
    
    CGRect bounds = [[self videoPreviewView] bounds];
    CGPoint screenCenter = CGPointMake(bounds.size.width / 2.f, bounds.size.height / 2.f);
    
    [self drawFocusBoxAtPointOfInterest:screenCenter];
    [self drawExposeBoxAtPointOfInterest:screenCenter];
    
    [[self captureManager] setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
}

@end

@implementation AVCamViewController (ADBannerViewDelegate)


-(void)createADBannerView
{
    // --- WARNING ---
    // If you are planning on creating banner views at runtime in order to support iOS targets that don't support the iAd framework
    // then you will need to modify this method to do runtime checks for the symbols provided by the iAd framework
    // and you will need to weaklink iAd.framework in your project's target settings.
    // See the iPad Programming Guide, Creating a Universal Application for more information.
    // http://developer.apple.com/iphone/library/documentation/general/conceptual/iPadProgrammingGuide/Introduction/Introduction.html
    // --- WARNING ---
	
    // Depending on our orientation when this method is called, we set our initial content size.
    // If you only support portrait or landscape orientations, then you can remove this check and
    // select either ADBannerContentSizeIdentifierPortrait (if portrait only) or ADBannerContentSizeIdentifierLandscape (if landscape only).
	NSString *contentSize;
	if (&ADBannerContentSizeIdentifierPortrait != nil)
	{
		contentSize = UIInterfaceOrientationIsPortrait(self.interfaceOrientation) ? ADBannerContentSizeIdentifierPortrait : ADBannerContentSizeIdentifierLandscape;
	}
	else
	{
		// user the older sizes 
		contentSize = UIInterfaceOrientationIsPortrait(self.interfaceOrientation) ? ADBannerContentSizeIdentifier320x50 : ADBannerContentSizeIdentifier480x32;
    }
	
    // Calculate the intial location for the banner.
    // We want this banner to be at the bottom of the view controller, but placed
    // offscreen to ensure that the user won't see the banner until its ready.
    // We'll be informed when we have an ad to show because -bannerViewDidLoadAd: will be called.
    CGRect frame;
    frame.size = [ADBannerView sizeFromBannerContentSizeIdentifier:contentSize];
    frame.origin = CGPointMake(0.0f, CGRectGetMaxY(self.view.bounds));
    
    // Now to create and configure the banner view
    ADBannerView *bannerView = [[ADBannerView alloc] initWithFrame:frame];
    // Set the delegate to self, so that we are notified of ad responses.
    bannerView.delegate = self;
    // Set the autoresizing mask so that the banner is pinned to the bottom
    bannerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleTopMargin;
    // Since we support all orientations in this view controller, support portrait and landscape content sizes.
    // If you only supported landscape or portrait, you could remove the other from this set.
    
	bannerView.requiredContentSizeIdentifiers = (&ADBannerContentSizeIdentifierPortrait != nil) ?
	[NSSet setWithObjects:ADBannerContentSizeIdentifierPortrait, ADBannerContentSizeIdentifierLandscape, nil] : 
	[NSSet setWithObjects:ADBannerContentSizeIdentifier320x50, ADBannerContentSizeIdentifier480x32, nil];
	
    // At this point the ad banner is now be visible and looking for an ad.
    [self.view addSubview:bannerView];
    self.banner = bannerView;
    [bannerView release];
}

-(void)layoutForCurrentOrientation:(BOOL)animated
{
    CGFloat animationDuration = animated ? 0.2f : 0.0f;
    // by default content consumes the entire view area
    CGRect contentFrame = self.view.bounds;
    // the banner still needs to be adjusted further, but this is a reasonable starting point
    // the y value will need to be adjusted by the banner height to get the final position
	CGPoint bannerOrigin = CGPointMake(CGRectGetMinX(contentFrame), CGRectGetMaxY(contentFrame));
    CGFloat bannerHeight = 0.0f;
    
    // First, setup the banner's content size and adjustment based on the current orientation
    if(UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
		banner.currentContentSizeIdentifier = (&ADBannerContentSizeIdentifierLandscape != nil) ? ADBannerContentSizeIdentifierLandscape : ADBannerContentSizeIdentifier480x32;
    else
        banner.currentContentSizeIdentifier = (&ADBannerContentSizeIdentifierPortrait != nil) ? ADBannerContentSizeIdentifierPortrait : ADBannerContentSizeIdentifier320x50; 
    bannerHeight = banner.bounds.size.height; 
	
    // Depending on if the banner has been loaded, we adjust the content frame and banner location
    // to accomodate the ad being on or off screen.
    // This layout is for an ad at the bottom of the view.
    if(banner.bannerLoaded)
    {
        contentFrame.size.height -= bannerHeight;
		bannerOrigin.y -= bannerHeight;
    }
    else
    {
		bannerOrigin.y += bannerHeight;
    }
    
	//UIView* view = [self videoPreviewView];
    // And finally animate the changes, running layout for the content view if required.
//    [UIView animateWithDuration:animationDuration
//                     animations:^{
//						// NSLog(@"contentframe %@",contentFrame);
//                        // view.frame = contentFrame;
//                        // [view layoutIfNeeded];
//                         banner.frame = CGRectMake(bannerOrigin.x, bannerOrigin.y, banner.frame.size.width, banner.frame.size.height);
//                     }];
}


-(void)bannerViewDidLoadAd:(ADBannerView *)banner
{
    [self layoutForCurrentOrientation:YES];
}

-(void)bannerView:(ADBannerView *)banner didFailToReceiveAdWithError:(NSError *)error
{
    [self layoutForCurrentOrientation:YES];
}

-(BOOL)bannerViewActionShouldBegin:(ADBannerView *)banner willLeaveApplication:(BOOL)willLeave
{
    return YES;
}

-(void)bannerViewActionDidFinish:(ADBannerView *)banner
{
}

@end

#pragma mark 
#pragma mark FlipsideViewController
@implementation AVCamViewController (FlipsideViewControllerDelegate)


- (void)flipsideViewControllerDidFinish:(FlipsideViewController *)controller {
    
	[self dismissModalViewControllerAnimated:YES];
	self.infoButton.enabled = YES;

}


- (IBAction)showInfo:(id)sender {    
	NSLog(@"show info");
	self.infoButton.enabled = NO;
	FlipsideViewController* ivc = [[FlipsideViewController alloc] init];
	ivc.delegate = self;
	ivc.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
	[self presentModalViewController:ivc animated:YES];
	[ivc release];
}


@end

