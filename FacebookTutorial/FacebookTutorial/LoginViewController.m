//
//  LoginViewController.m
//  FacebookTutorial
//
//  Created by Akshat on 05/02/14.
//  Copyright (c) 2014 Akshat. All rights reserved.
//

#import "LoginViewController.h"
#import <FacebookSDK/FacebookSDK.h>
#import "MyCell.h"

@interface LoginViewController ()

@end

@implementation LoginViewController

@synthesize loginView,profilePictureView,nameLabel,statusLabel,myCollectionView;

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    return arr.count;
}

-(UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath{
    //NSLog(@"called %ld",(long)indexPath.row);
    MyCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"CELL" forIndexPath:indexPath];
//    if(cell==nil){
        [cell setPhotoAtIndex:indexPath Array:arr];
//    }
    
    return cell;
}

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
    
    loginView = [[FBLoginView alloc]initWithReadPermissions:@[@"basic_info", @"email", @"user_likes"]];
    flag = FALSE;
    
    [myCollectionView registerNib:[UINib nibWithNibName:@"MyCell" bundle:nil] forCellWithReuseIdentifier:@"CELL"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)loginView:(FBLoginView *)loginView handleError:(NSError *)error{
    
    NSString *alertMessage, *alertTitle;
    if ([FBErrorUtility shouldNotifyUserForError:error]) {
        alertTitle = @"Facebook error";
        alertMessage = [FBErrorUtility userMessageForError:error];
    } else if ([FBErrorUtility errorCategoryForError:error] == FBErrorCategoryAuthenticationReopenSession) {
        alertTitle = @"Session Error";
        alertMessage = @"Your current session is no longer valid. Please log in again.";
    } else if ([FBErrorUtility errorCategoryForError:error] == FBErrorCategoryUserCancelled) {
        NSLog(@"user cancelled login");
    } else {
        alertTitle  = @"Something went wrong";
        alertMessage = @"Please try again later.";
        NSLog(@"Unexpected error:%@", error);
    }
    if (alertMessage) {
        [[[UIAlertView alloc] initWithTitle:alertTitle
                                    message:alertMessage
                                   delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil] show];
    }
}

-(void)loginViewFetchedUserInfo:(FBLoginView *)loginView user:(id<FBGraphUser>)user{
    self.profilePictureView.profileID = user.id;
    self.nameLabel.text = user.name;
    
    
    NSArray *permissionsNeeded = @[@"basic_info", @"user_birthday", @"user_photos"];
    
    [FBRequestConnection startWithGraphPath:@"/me/permissions"
                          completionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
                              if (!error){
                                  NSDictionary *currentPermissions= [(NSArray *)[result data] objectAtIndex:0];
                                  NSMutableArray *requestPermissions = [[NSMutableArray alloc] initWithArray:@[]];
                                  for (NSString *permission in permissionsNeeded){
                                      if (![currentPermissions objectForKey:permission]){
                                          [requestPermissions addObject:permission];
                                      }
                                  }
                                  if ([requestPermissions count] > 0){
                                      [FBSession.activeSession
                                       requestNewReadPermissions:requestPermissions
                                       completionHandler:^(FBSession *session, NSError *error) {
                                           if (!error) {
                                               [self makeRequestForUserData];
                                           } else {
                                           }
                                       }];
                                  } else {
                                      [self makeRequestForUserData];
                                  }
                              } else {
                              }
                          }];
}

-(void)makeRequestForUserData{
    [FBRequestConnection startWithGraphPath:@"/me/photos"
                                 parameters:nil
                                 HTTPMethod:@"GET"
                          completionHandler:^(
                                              FBRequestConnection *connection,
                                              id result,
                                              NSError *error
                                              ) {
                              if (!error){
                                  arr = (NSArray *)[result data];
                                  [myCollectionView reloadData];
                              }else{
                                  NSLog(@"error");
                              }
                          }];
}

-(void)loginViewShowingLoggedInUser:(FBLoginView *)loginView{
    self.statusLabel.text = @"You're logged in as";
}

-(void)loginViewShowingLoggedOutUser:(FBLoginView *)loginView{
    self.profilePictureView.profileID = nil;
    self.nameLabel.text = @"";
    self.statusLabel.text= @"You're not logged in!";
}

@end
