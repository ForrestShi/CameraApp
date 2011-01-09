#import "WelcomeViewController.h"
#import "MyAVController.h"

@implementation WelcomeViewController

- (IBAction)startFlashcodeDetection {
	MyAVController* mainViewCtr = [[MyAVController alloc] init];
	[self presentModalViewController:mainViewCtr animated:YES];
	[mainViewCtr release];
}


- (void)dealloc {
    [super dealloc];
}

@end
