//
//  MyCell.m
//  FacebookTutorial
//
//  Created by Akshat on 08/02/14.
//  Copyright (c) 2014 Akshat. All rights reserved.
//

#import "MyCell.h"

@implementation MyCell

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

-(void)setPhotoAtIndex:(NSIndexPath *)index Array:(NSArray *)arr{
        NSMutableDictionary *dict = [arr objectAtIndex:index.row];
        NSString *path = [dict objectForKey:@"picture"];
        NSURL *url = [NSURL URLWithString:path];
        NSData __block *data;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            data = [NSData dataWithContentsOfURL:url];
            dispatch_async(dispatch_get_main_queue(), ^{
                NSLog(@"url : %@",url);
                self.photo = [UIImage imageWithData:data];
                self.imgView.contentMode = UIViewContentModeScaleAspectFit;
                self.imgView.image = self.photo;
                [self.imgView setNeedsDisplay];
            });
        });
}

@end
