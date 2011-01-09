//
//  SettingViewController.m
//  BestCamera
//
//  Created by forrest on 10-9-4.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "SettingViewController.h"
#import "SettingData.h"
#import "HelpViewController.h"

@implementation SettingViewController
@synthesize intervalSecondsSlider;
@synthesize  continuousShotsSlider;
@synthesize  audioSwitch;
@synthesize colorSwitch;
@synthesize dataRef;
@synthesize delegate;
@synthesize label1;
@synthesize label2;

- (void)dealloc {
#ifdef DEBUG 
	NSLog(@"%s",__FUNCTION__);
#endif
	[intervalSecondsSlider release];
	[continuousShotsSlider release];
	[audioSwitch release];
	[colorSwitch release];
    [super dealloc];
}

- (IBAction) adjustSetting{	
	NSLog(@"%s",__FUNCTION__);
	
	
	if (self.dataRef) {
		self.dataRef.intervelSeconds = self.intervalSecondsSlider.value;
		self.dataRef.shotTimes = self.continuousShotsSlider.value;
		self.dataRef.audioFlag = self.audioSwitch.on;
		self.dataRef.colorFlag = self.colorSwitch.on;
		
		[label1 setText:[NSString stringWithFormat:@"%d seconds", self.dataRef.intervelSeconds]];
		[label2 setText:[NSString stringWithFormat:@"%d times", self.dataRef.shotTimes]];
	}
}

-(IBAction) onDoneButton{
	if (delegate) {
		[delegate ChangesApplied];
	}
}

-(IBAction) onHelpButton{
	HelpViewController* helpViewCtr = [[HelpViewController alloc] init];
	helpViewCtr.delegate = self;
	[self presentModalViewController:helpViewCtr animated:YES];
	[helpViewCtr release];
}

- (void) ReturnBack{
	[self dismissModalViewControllerAnimated:YES];
}


- (id) initWithData:(SettingData*)data{
	if (self = [super init]) {
		if (data) {
#ifdef DEBUG 
			NSLog(@"%s",__FUNCTION__);
#endif
			
			self.dataRef = data;
		}
		
	}
	return self;
}
 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
		[self.intervalSecondsSlider setValue:5.0];
		[self.continuousShotsSlider setValue:1.0];
		
		[label1 setText:[NSString stringWithFormat:@"%d seconds", 5]];
		[label2 setText:[NSString stringWithFormat:@"%d times", 1]];
		self.view.backgroundColor = [UIColor clearColor];
    }
    return self;
}


/*
// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
}
*/

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}




@end
