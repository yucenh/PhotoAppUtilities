//
//  HomeViewController.h
//  GrabKitExplorer
//
//  Created by Akshat on 11/02/14.
//  Copyright (c) 2014 Akshat. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GRKPickerViewControllerDelegate.h"

@interface HomeViewController : UIViewController <GRKPickerViewControllerDelegate>

-(IBAction)buttonClicked:(id)sender;

@end
