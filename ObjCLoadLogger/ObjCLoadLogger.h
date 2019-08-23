//
//  ObjCLoadLogger.h
//  ObjCLoadLogger
//
//  Created by Darcy Liu on 2019/8/23.
//  Copyright © 2019 Darcy Liu. All rights reserved.
//

#import <Foundation/Foundation.h>

//! Project version number for ObjCLoadLogger.
FOUNDATION_EXPORT double ObjCLoadLoggerVersionNumber;

//! Project version string for ObjCLoadLogger.
FOUNDATION_EXPORT const unsigned char ObjCLoadLoggerVersionString[];

@interface ObjCLoadLogger : NSObject
+ (NSArray *)allObjCLoadInfo;
@end
