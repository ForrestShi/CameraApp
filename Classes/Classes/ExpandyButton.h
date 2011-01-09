/*
     File: ExpandyButton.h
 Abstract: Class that implements the HUD configuration buttons: Flash, Torch, Focus, etc.
  Version: 1.0
  
 */

#import <UIKit/UIKit.h>

@interface ExpandyButton : UIButton {
    @private
    BOOL _expanded;
    UILabel *_titleLabel;
    CGRect _frameExpanded;
    CGRect _frameShrunk;
    CGFloat _buttonWidth;
    NSInteger _selectedItem;
    NSArray *_labels;
}

- (id)initWithPoint:(CGPoint)point title:(NSString *)title buttonNames:(NSArray *)buttonNames selectedItem:(NSInteger)selectedItem buttonWidth:(CGFloat)butonWidth;
- (id)initWithPoint:(CGPoint)point title:(NSString *)title buttonNames:(NSArray *)buttonNames selectedItem:(NSInteger)selectedItem;
- (id)initWithPoint:(CGPoint)point title:(NSString *)title buttonNames:(NSArray *)buttonNames;

@property (nonatomic,readonly,retain) UILabel *titleLabel;
@property (nonatomic,readonly,retain) NSArray *labels;
@property (nonatomic,assign) NSInteger selectedItem;

@end
