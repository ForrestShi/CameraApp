/*
     File: AVCamPreviewView.h
 Abstract: Code to detect single-tap, double-tap, and triple-tap to the screen and record the location of the actual touch which is then passed along to the view controller code for further processing.
  Version: 1.0
  
 */

#import <UIKit/UIKit.h>

@protocol AVCamPreviewViewDelegate
@optional
- (void)tapToFocus:(CGPoint)point;
- (void)tapToExpose:(CGPoint)point;
- (void)resetFocusAndExpose;
-(void)cycleGravity;
@end

@interface AVCamPreviewView : UIView {
    id <AVCamPreviewViewDelegate> _delegate;
}

@property (nonatomic,retain) IBOutlet id <AVCamPreviewViewDelegate> delegate;

@end
