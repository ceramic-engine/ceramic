//
//  Http.h
//  CeramicIosSupport
//
//  Created by Jeremy FAIVRE on 27/09/2018.
//  Copyright © 2018 Ceramic. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Http : NSObject

+ (void)sendHTTPRequest:(NSDictionary *)params done:(void (^)(NSDictionary *response))done;

+ (void)download:(NSDictionary *)params targetPath:(NSString *)targetPath done:(void (^)(NSString *fullPath))done;

@end
