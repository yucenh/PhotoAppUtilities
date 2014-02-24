/*
 * This file is part of the GrabKit package.
 * Copyright (c) 2013 Pierre-Olivier Simonard <pierre.olivier.simonard@gmail.com>
 *  
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software and 
 * associated documentation files (the "Software"), to deal in the Software without restriction, including 
 * without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
 * copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the 
 * following conditions:
 *  
 * The above copyright notice and this permission notice shall be included in all copies or substantial 
 * portions of the Software.
 *  
 * The Software is provided "as is", without warranty of any kind, express or implied, including but not 
 * limited to the warranties of merchantability, fitness for a particular purpose and noninfringement. In no
 * event shall the authors or copyright holders be liable for any claim, damages or other liability, whether
 * in an action of contract, tort or otherwise, arising from, out of or in connection with the Software or the 
 * use or other dealings in the Software.
 *
 * Except as contained in this notice, the name(s) of (the) Author shall not be used in advertising or otherwise
 * to promote the sale, use or other dealings in this Software without prior written authorization from (the )Author.
 */

//#import <CoreLocation/CoreLocation.h>

#import "GRKDeviceGrabber.h"
#import "GRKServiceGrabberProtocol.h"
#import "GRKAlbum.h"
#import "GRKConstants.h"
#import "GRKAlbum+modify.h"

#import "NSIndexSet+pagination.h"


static NSString *kGRKServiceNameDevice = @"device";

@interface GRKDeviceGrabber()

-(void) incrementQueriesCount;
-(void) decrementQueriesCount;

-(NSString *) photoIdFromAsset:(ALAsset *)asset;
-(GRKPhoto*) photoFromALAsset:(ALAsset *)result atIndex:(NSUInteger)index;
-(GRKImage*) imageFromALAssetRepresentation:(ALAssetRepresentation*)representation isOriginal:(BOOL)isOriginal;
@end


@implementation GRKDeviceGrabber


-(id) init {

    if ((self = [super initWithServiceName:kGRKServiceNameDevice]) != nil){
        
        library = [[ALAssetsLibrary alloc] init];
        assetsGroupsById = [[NSMutableDictionary alloc] init];

        cancelAllFlag = NO;
        queriesCount = 0;
        cancelAllCompleteBlock = nil;
        
        _requiresConnection = NO;
    }     
    
    return self;
}

-(void) incrementQueriesCount {
    queriesCount++;

}

-(void) decrementQueriesCount {
    queriesCount--;
    
    if ( queriesCount == 0 ){
        cancelAllFlag = NO;

        dispatch_async_on_main_queue(cancelAllCompleteBlock, nil);
       
    }
}


#pragma mark GRKServiceGrabberProtocol methods

/* @see refer to GRKServiceGrabberProtocol documentation
 */
-(void) albumsOfCurrentUserAtPageIndex:(NSUInteger)pageIndex
              withNumberOfAlbumsPerPage:(NSUInteger)numberOfAlbumsPerPage
                       andCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock 
                          andErrorBlock:(GRKErrorBlock)errorBlock;
{

    if ( numberOfAlbumsPerPage > kGRKMaximumNumberOfAlbumsPerPage ) {
        
        NSException* exception = [NSException
                                  exceptionWithName:@"numberOfAlbumsPerPageTooHigh"
                                  reason:[NSString stringWithFormat:@"The number of albums per page you asked (%d) is too high", numberOfAlbumsPerPage]
                                  userInfo:nil];
        @throw exception;
    }
    
    /* We want to present the "Camera Roll" as first result.
     This is why, if we're asked for the pageIndex 0, 
     	_ First, we retrieve the "Camera Roll" ALAssetsGroup (type ALAssetsGroupSavedPhotos)
        _ Then, we retrieve all the other groups, minus one (all types of ALAssetsGroup, except ALAssetsGroupSavedPhotos)
     */

    
    if ( pageIndex == 0 ){
        
        // The dictionary of albums that will be sent to the caller
        __block NSMutableArray * albums = [[NSMutableArray alloc] init];
        
        [self albumsOfCurrentUserFromIndex:0
                                   toIndex:0
                              andGroupsTypes:ALAssetsGroupSavedPhotos
                            andCompleteBlock:^(NSArray *results) {
                                
                                if ( [results count] != 1 ){
                                    
                                    if ( errorBlock != nil ){
						
                                        NSString * errorDomain = [NSString stringWithFormat:@"com.grabKit.%@", _serviceName];
                                        NSError * error = [NSError errorWithDomain:errorDomain code:404 userInfo:nil];
                                        errorBlock(error);
                                    }
                                    return;
                                }
                                
                                [albums addObject:results[0]];
                                
                                [self albumsOfCurrentUserFromIndex:0
                                                           toIndex:(numberOfAlbumsPerPage>=2)?(numberOfAlbumsPerPage-2):0
                                                      andGroupsTypes:(ALAssetsGroupAll & ~ALAssetsGroupSavedPhotos)
                                                    andCompleteBlock:^(NSArray *results) {
                                                        
                                                        [albums addObjectsFromArray:results];
                                                        dispatch_async_on_main_queue(completeBlock, albums);
                                                        return;
                                                        
                                                    } andErrorBlock:^(NSError *error) {
                                                     
                                                        if ( errorBlock != nil ){
                                                            errorBlock(error);
                                                        }
                                                        return;
                                                    }];
                                
                            } andErrorBlock:^(NSError *error) {
                                
                                if ( errorBlock != nil ){
	                                errorBlock(error);
                                }
                                return;
                            }];
        
        
        return;
    } else {
        
        [self albumsOfCurrentUserFromIndex:(pageIndex*numberOfAlbumsPerPage)-1
                                   toIndex:((pageIndex+1)*numberOfAlbumsPerPage)-2
                              andGroupsTypes:(ALAssetsGroupAll & ~ALAssetsGroupSavedPhotos)
                            andCompleteBlock:^(NSArray *results) {
                                
                                dispatch_async_on_main_queue(completeBlock, results);
                                return;
                                
                            } andErrorBlock:^(NSError *error) {
                                
                            }];

    }
    

    
}


-(void) albumsOfCurrentUserFromIndex:(NSUInteger)startIndex
                               toIndex:(NSUInteger)endIndex
                       andGroupsTypes:(ALAssetsGroupType)groupTypes
                      andCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock
                         andErrorBlock:(GRKErrorBlock)errorBlock {
    
//    NSLog(@" albums from index %d to index %d", startIndex,  endIndex);
    
    // The dictionary of albums that will be sent to the caller
    __block NSMutableArray * albums = [[NSMutableArray alloc] init];
    
    [self incrementQueriesCount];
    cancelAllFlag = NO;
    
    __block int indexOfIteratedAssetsGroup = -1; // enumerations count
    [library enumerateGroupsWithTypes:groupTypes
                           usingBlock:^(ALAssetsGroup * group, BOOL *stop){
                               
                               if ( (*stop) ){
                                   return;
                               }
                               
                               // check if the cancelAll flag has been set
                               if ( cancelAllFlag == YES ){
                                   *stop = YES;
                                   [self decrementQueriesCount];
                                   return;
                               }
                               
                               indexOfIteratedAssetsGroup++;
                               
                               
                               // the ALAssetsLibrary doesn't allow pagination
                               // So let's skip the groups that are not in the wanted range
                               
                               // if the current group is before the first desired group, just skip it
                               if ( indexOfIteratedAssetsGroup < startIndex ) {
                                   return;
                               }
                               
                               /* if the current group is after the last desired group,
                                _ stop the iteration
                                _ perform the complete block
                                _ return
                                */
                               if ( indexOfIteratedAssetsGroup > endIndex ){
                                   *stop = YES;

                                   [self decrementQueriesCount];
                                   dispatch_async_on_main_queue(completeBlock, albums);
                                   
                                   return;
                               }
                               
                               
                               /* When all the groups have been enumerated, a nil group is passed to this block.
                                then call the completeBlock and return
                                */
                               if ( group == nil ){
                                    *stop = YES;
                                    [self decrementQueriesCount];
                                	dispatch_async_on_main_queue(completeBlock, albums);
                                   
                                   return;
                               }
                               
//                               NSLog( @"%d group : %@", indexOfIteratedAssetsGroup, group);
                               
                               // Let's fetch the group's informations to build a GRKAlbum
                               
                               // restrict the group to photos only (i.e. excluding videos) to have the proper 'numberOfAssets' value
                               [group setAssetsFilter:[ALAssetsFilter allPhotos]];
                               
                               NSString * albumId = [group valueForProperty:ALAssetsGroupPropertyPersistentID];
                               if ( albumId == nil ){
                                   return;
                               }
                               
                               NSString * albumName = [group valueForProperty:ALAssetsGroupPropertyName];
                               NSUInteger count = [group numberOfAssets];
                               
                               // Build the GRKAlbum
                               GRKAlbum * album = [GRKAlbum albumWithId:albumId andName:albumName andCount:count  andDates:nil];
                               
                               // add the GRKAlbum to the result dictionary
                               [albums addObject:album];
                               
                               // keep a reference to the group for the albumId
                               [assetsGroupsById setObject:group forKey:albumId];
                               
                               
                           }
                         failureBlock:^(NSError * error){
                             
                             [self decrementQueriesCount];
                             
                             dispatch_async_on_main_queue(errorBlock, [self errorForAlbumsOperationWithOriginalError:error]);
                             
                         }];
    
}


/* @see refer to GRKServiceGrabberProtocol documentation
 */
-(void) fillAlbum:(GRKAlbum *)album
withPhotosAtPageIndex:(NSUInteger)pageIndex
withNumberOfPhotosPerPage:(NSUInteger)numberOfPhotosPerPage
 andCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock 
    andErrorBlock:(GRKErrorBlock)errorBlock;
{
    if ( numberOfPhotosPerPage > kGRKMaximumNumberOfPhotosPerPage ) {
        
        NSException* exception = [NSException
                                  exceptionWithName:@"numberOfPhotosPerPageTooHigh"
                                  reason:[NSString stringWithFormat:@"The number of photos per page you asked (%d) is too high", numberOfPhotosPerPage]
                                  userInfo:nil];
        @throw exception;
    }

    
    ALAssetsGroup * groupForThisAlbum = [assetsGroupsById objectForKey:album.albumId];
    if ( groupForThisAlbum == nil ) {
        
        dispatch_async_on_main_queue(errorBlock, [self errorForFillAlbumOperationWithOriginalError:nil]);
        
        return;
    }
    
/*
     We use the method [ALAssetsGroup enumerateAssetsAtIndexes:options:usingBlock:] to fetch the photos (ALAsset) for an album (ALAssetsGroup)
     This method takes a NSIndexSet as parameter, that we will build from a NSRange.
     
     If we pass to this method a NSIndexSet for ranks over the number of photos of the group, an exception will be thrown ( 'NSRangeException', reason: 'indexSet count or lastIndex must not exceed -numberOfAssets' )

so, if : 
     "rank of the last photo to fetch" > "rank of the last photo in album"
i.e if :     
	"(page index) * (number of photo per page) + (number of photo per page)" > "number of photos in album"-1

Then : we have to fetch from "(page index) * (number of photo per page)" to "rank of the last photo in album"

 This is what the finalN var is made for, avoiding that way the NSRangeException.
 */
    
    NSUInteger finalNumberOfPhotosPerPage = numberOfPhotosPerPage;
    NSIndexSet * indexSetAtThisPageIndex;
    
    if ( pageIndex*numberOfPhotosPerPage + numberOfPhotosPerPage > album.count ){
        
        finalNumberOfPhotosPerPage = MAX(0,album.count - pageIndex*numberOfPhotosPerPage);
        
        NSMutableIndexSet * mutableIndexSetAtThisPageIndex = [[NSMutableIndexSet alloc] initWithIndexSet:[NSIndexSet indexSetForPageIndex:pageIndex
                                                                                                                 withNumberOfItemsPerPage:numberOfPhotosPerPage]];
        
        NSInteger numberOfExtraIndexSet = (pageIndex+1)*numberOfPhotosPerPage - album.count;
        
        NSIndexSet * indexSetToRemove = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange( (pageIndex+1)*numberOfPhotosPerPage - numberOfExtraIndexSet,
                                                                                           numberOfExtraIndexSet ) ];

        [mutableIndexSetAtThisPageIndex removeIndexes:indexSetToRemove];
        
        indexSetAtThisPageIndex = [[NSIndexSet alloc] initWithIndexSet:mutableIndexSetAtThisPageIndex];
        
    } else {
		indexSetAtThisPageIndex = [NSIndexSet indexSetForPageIndex:pageIndex withNumberOfItemsPerPage:finalNumberOfPhotosPerPage];
    }

    
    [self incrementQueriesCount];
    cancelAllFlag = NO;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
       
        
        // the array of GRKPhoto for this page of the album
        __block NSMutableArray * newPhotos = [NSMutableArray array];
        __block id me = self;
        
        [groupForThisAlbum enumerateAssetsAtIndexes:indexSetAtThisPageIndex
                                            options:0
                                         usingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
                                             
                                             // check if the cancelAll flag has been set
                                             if ( cancelAllFlag == YES ){
                                                 *stop = YES;
                                                 [me decrementQueriesCount];
                                                 return;
                                             }
                                             
                                             // when enumeration is finished, a nil result is passed to this block
                                             if ( result == nil ){
                                                 
                                                 // add the new photos to the album
                                                 [album addPhotos:newPhotos forPageIndex:pageIndex withNumberOfPhotosPerPage:numberOfPhotosPerPage];
                                                 
                                                 [me decrementQueriesCount];
                                                 
                                                 // perform the completeBlock
                                                 dispatch_async_on_main_queue(completeBlock, newPhotos);
                                                 
                                                 return;
                                                 
                                             }
                                             
                                             GRKPhoto * photo = [me photoFromALAsset:result atIndex:index];
                                             [newPhotos addObject:photo];
                                             
                                         }];
        
    });
    
     
}



-(void) fillCoverPhotoOfAlbums:(NSArray *)albums 
              withCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock 
                 andErrorBlock:(GRKErrorBlock)errorBlock; {
    
    
    cancelAllFlag = NO;

    NSMutableArray * updatedAlbums = [NSMutableArray array];
    
    
    __block int numberOfAlbumsParsed = 0;
    for ( GRKAlbum * album in albums ){
    
       [self fillCoverPhotoOfAlbum:album 
                  andCompleteBlock:^(id result) {
           
                      [updatedAlbums addObject:result];
                      numberOfAlbumsParsed++;
                      
                      if ( numberOfAlbumsParsed == [albums count] ){
                          
                          dispatch_async_on_main_queue(completeBlock, updatedAlbums);
                      }
                      
                      
       } andErrorBlock:^(NSError *error) {
           numberOfAlbumsParsed++;
           
           
           if ( numberOfAlbumsParsed == [albums count] ){
               
               dispatch_async_on_main_queue(completeBlock, updatedAlbums);
           }

           
       } ];
    }
    
    
    
}

-(void) fillCoverPhotoOfAlbum:(GRKAlbum *)album
             andCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock 
                andErrorBlock:(GRKErrorBlock)errorBlock {
    
    
    ALAssetsGroup * groupForThisAlbum = [assetsGroupsById objectForKey:album.albumId];

    if ( groupForThisAlbum == nil ) {
        

        dispatch_async_on_main_queue(errorBlock, [self errorForFillCoverOperation]);
       
        return;
    }
    
    
    /* We could retrieve the "posterImage" property of the ALAssetsGroup object.
     BUT the model to fit every services specifies we must set a GRKPhoto, and this object doesn't store any image data.
     
     So, let's retrieve an asset. 
     If the group is "Library", retrieve the last asset of the group.
     Else, retrieve the first one. 
     (it seems to be the way it works on the Photo application ...)
     
     If you ever want to modify this grabber and access to the image directly :         
     [UIImage imageWithCGImage:groupForThisAlbum.posterImage]  
     */
    
    NSIndexSet * indexSetOfAssetToRetrieve = [NSIndexSet indexSet];
    
    if ( album.count > 0 ) {
        
        if ( ALAssetsGroupSavedPhotos == [[groupForThisAlbum valueForProperty:ALAssetsGroupPropertyType] intValue] ){
            
            indexSetOfAssetToRetrieve = [NSIndexSet indexSetWithIndex:album.count-1];
            
        } else if ( ALAssetsGroupAlbum == [[groupForThisAlbum valueForProperty:ALAssetsGroupPropertyType] intValue] ){
            
            indexSetOfAssetToRetrieve = [NSIndexSet indexSetWithIndex:0];
            
        }
    }
    
    [self incrementQueriesCount];
    
    [groupForThisAlbum  enumerateAssetsAtIndexes:indexSetOfAssetToRetrieve
                                         options:0 
                                      usingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
                                          
                                          // check if the cancelAll flag has been set 
                                          if ( cancelAllFlag == YES ){
                                              *stop = YES;
                                              [self decrementQueriesCount];
                                              return;
                                          }
                                          
                                          // when enumeration is finished, a nil group is passed to this block
                                          if ( result == nil ){
                                              [self decrementQueriesCount];
                                              
                                              dispatch_async_on_main_queue(completeBlock, album);
                                              return;
                                              
                                          } else if ( album.coverPhoto == nil ){
                                          
                                              album.coverPhoto = [self photoFromALAsset:result atIndex:index];
                                              
                                          }
                                         
                                          
                                      }];
    
}




/* @see refer to GRKServiceGrabberProtocol documentation
 */
-(void) cancelAll {
    
    cancelAllFlag = YES;
}

/* @see refer to GRKServiceGrabberProtocol documentation
 */
-(void) cancelAllWithCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock;
{
 	cancelAllCompleteBlock = completeBlock;
    [self cancelAll];
    
}

#pragma mark - Internal processing methods


/** Build and return a GRKPhoto from an ALAsset object
 
 @param asset the ALAsset to use to build the GRKPhoto object
 @param index the index of the ALAsset in the album. it is used as a default id for the GRKPhoto.
 @return a GRKPhoto object
*/
-(GRKPhoto*) photoFromALAsset:(ALAsset *)asset atIndex:(NSUInteger)index;
{
    
    NSString * photoId = [self photoIdFromAsset:asset];

    // if retrieving the photoId from the asset failed, let's build a default photoId from the index
    if ( [photoId isEqualToString:@""] )
    	photoId = [NSString stringWithFormat:@"%d", index];
    
    NSDate * dateTaken = [asset valueForProperty:ALAssetPropertyDate];
    NSMutableDictionary * dates = [NSMutableDictionary dictionary];
	if ( dateTaken != nil )
	    [dates setObject:dateTaken forKey:kGRKPhotoDatePropertyDateTaken];
    
    
    //CLLocation * location = [asset valueForProperty:ALAssetPropertyLocation];
    //NSLog(@" photo location : %@", location);
    
    
    // array of the different UTI ( a string for an ALAssetRepresentation ) 
    NSArray * UTIs = [asset valueForProperty:ALAssetPropertyRepresentations];
    
    // Let's use the asset's default representation to find its UTI.
    // It'll be used to define the original GRKImage
    NSString * defaultRepresentationUTI = [[asset defaultRepresentation] UTI];
    
    
    NSMutableArray * images = [NSMutableArray array];
    // Let's enumerate the array of UTIs to retrieve each ALAssetRepresentation and build GRKImage objects
    
    for ( NSString * UTI in UTIs ){
        
        ALAssetRepresentation * representation = [asset representationForUTI:UTI];
        
        GRKImage * image = [self imageFromALAssetRepresentation:representation isOriginal:[UTI isEqualToString:defaultRepresentationUTI]];
        
        [images addObject:image];
        
    }
    
    GRKPhoto * photo = [GRKPhoto photoWithId:photoId 
                                   andCaption:nil 
                                   andName:nil
                                 andImages:images
                       andDates:dates];
    return photo;
    
}

/** Build and return a GRKImage from an ALAssetRepresentation.
 
 @param representation an ALAssetRepresentation to build the GRKImage from
 @param isOriginal a BOOL value to specify if the result GRKImage is original
 @return a GRKImage
 
 */
-(GRKImage*) imageFromALAssetRepresentation:(ALAssetRepresentation*)representation isOriginal:(BOOL)isOriginal;
{

    NSDictionary * metadata = [representation metadata];
    
    NSNumber * width = [metadata objectForKey:@"PixelWidth"];
    NSNumber * height = [metadata objectForKey:@"PixelHeight"];
    NSURL * imageURL = [NSURL URLWithString:[[representation url] absoluteString]];
    
    GRKImage * image = [GRKImage imageWithURL:imageURL
                                   andWidth:[width intValue] 
                                  andHeight:[height intValue] 
                                 isOriginal:isOriginal];
    return image;
    
}

/**  Build a and return a NSString from the URL of an asset's default ALAssetRepresentation.
 This NSString is used as an id for a GRKPhoto object
 
 @param asset an ALAsset to build the photoId from
 @return a NSString
 */
-(NSString *) photoIdFromAsset:(ALAsset *)asset;
{
    /* 
     The API doesn't provide any method to get a unique identifier from an ALAsset object
     But the [[ALAsset defaultRepresentation] url] method, according to Apple's documentation,
     returns a "persistent URL uniquely identifying the representation."
     
     This URL looks like : assets-library://asset/asset.JPG?id=BFFEB67F-0212-4CB3-844A-D14C0A3FA69F&ext=JPG
     I assume that the string "BFFEB67F-0212-4CB3-844A-D14C0A3FA69F" is unique. 
     Let's retrieve it and use it as photoId
     */
    NSString * assetsURLString = [[[asset defaultRepresentation] url] absoluteString];

    // let's retrieve the id in two times.
    // First, let's truncate the string to something similar to : BFFEB67F-0212-4CB3-844A-D14C0A3FA69F&ext=JPG
    NSString * firstDelimiter = @"id=";
    NSRange rangeOfFirstDelimiter = [assetsURLString rangeOfString:firstDelimiter];
    if ( rangeOfFirstDelimiter.location == NSNotFound ) {
    	// if, for some reason, the delimiter was not found, let's return an empty string
        return @"";
    }
    NSUInteger indexOfFirstCharacterOfId = rangeOfFirstDelimiter.location + rangeOfFirstDelimiter.length;
    assetsURLString = [assetsURLString substringFromIndex:indexOfFirstCharacterOfId];
    
    // Now, let's get the substring until the "&ext=???" part
    NSString * secondDelimiter = @"&ext";
    NSRange rangeOfSecondDelimiter = [assetsURLString rangeOfString:secondDelimiter];
    NSUInteger indexOfSecondDelimiter = rangeOfSecondDelimiter.location;
    if ( indexOfSecondDelimiter == NSNotFound ){
     	// if, for some reason, the delimiter was not found, let's return an empty string
        return @"";
    }
        
    NSString * photoId = [assetsURLString substringToIndex:indexOfSecondDelimiter];
    
    return photoId;
}


@end
