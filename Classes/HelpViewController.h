//
//  HelpViewController.h
//  BestCamera
//
//  Created by forrest on 10-9-6.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol ReturnBackControllerDelegate;


@interface HelpViewController : UIViewController {
	id<ReturnBackControllerDelegate> delegate;
}

@property (nonatomic,retain) id<ReturnBackControllerDelegate> delegate;

- (IBAction) ReturnBack ;

@end
