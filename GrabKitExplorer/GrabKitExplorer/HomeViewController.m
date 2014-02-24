//
//  HomeViewController.m
//  GrabKitExplorer
//
//  Created by Akshat on 11/02/14.
//  Copyright (c) 2014 Akshat. All rights reserved.
//

#import "HomeViewController.h"
#import "GrabKit.h"
#import "GRKPickerViewController.h"

@interface HomeViewController ()

@property (weak, nonatomic) IBOutlet UIButton *myButton;

@end

@implementation HomeViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(IBAction)buttonClicked:(id)sender{
    GRKPickerViewController * grabkitPickerViewController = [GRKPickerViewController sharedInstance];

    
    // Set the picker's delegate.
    // Don't forget to add GRKPickerViewControllerDelegate in the list of protocols implemented by your controller.
    grabkitPickerViewController.pickerDelegate = self;
    
    // We allow the selection
    grabkitPickerViewController.allowsSelection = YES;
    grabkitPickerViewController.allowsMultipleSelection = YES;
    
    [self presentViewController:grabkitPickerViewController animated:YES completion:^{
        // GrabKitPicker is now displayed
    }];
}

-(void)picker:(GRKPickerViewController*)picker didDismissWithSelectedPhotos:(NSArray*)selectedPhotos {
    // selectedPhotos is an NSArray of GRKPhoto objects. Check the "Model" section below for more details.
}

@end
