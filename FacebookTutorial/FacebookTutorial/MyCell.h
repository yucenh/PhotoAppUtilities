//
//  MyCell.h
//  FacebookTutorial
//
//  Created by Akshat on 08/02/14.
//  Copyright (c) 2014 Akshat. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MyCell : UICollectionViewCell

@property (nonatomic, retain) IBOutlet UIImageView *imgView;
@property (nonatomic, strong) UIImage *photo;

-(void)setPhotoAtIndex:(NSIndexPath *)index Array:(NSArray *)arr;

@end
