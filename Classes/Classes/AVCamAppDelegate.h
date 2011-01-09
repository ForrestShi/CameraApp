/*
     File: AVCamAppDelegate.h
 Abstract: Application delegate -- releases the AVCamViewController and associated window when the dealloc: method is called.
  Version: 1.0

 
 */

#import <UIKit/UIKit.h>

@class AVCamViewController;

@interface AVCamAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
    AVCamViewController *viewController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet AVCamViewController *viewController;

@end

