//
//  LoginViewController.h
//  FacebookTutorial
//
//  Created by Akshat on 05/02/14.
//  Copyright (c) 2014 Akshat. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <FacebookSDK/FacebookSDK.h>
#import "MyCell.h"

@interface LoginViewController : UIViewController <FBLoginViewDelegate,UICollectionViewDataSource,UICollectionViewDelegate>{
    NSArray *arr;
    BOOL flag;
}

@property (strong, nonatomic) IBOutlet FBLoginView *loginView;
@property (strong, nonatomic) IBOutlet FBProfilePictureView *profilePictureView;
@property (strong, nonatomic) IBOutlet UICollectionView *myCollectionView;
@property (strong, nonatomic) IBOutlet UILabel *nameLabel;
@property (strong, nonatomic) IBOutlet UILabel *statusLabel;

@end
