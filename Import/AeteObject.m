//
//  AeteObject.m
//  Sdef Editor
//
//  Created by Grayfox on 30/01/05.
//  Copyright 2005 Shadow Lab. All rights reserved.
//

#import "AeteObject.h"
#import "ShadowMacros.h"

@implementation SdefObject (AeteResource)

- (UInt32)parseData:(char *)bytes {
  ShadowTrace();
  [NSException raise:NSInternalInconsistencyException format:@"Method must be implemented by subclasses"];
  return 0;
}

@end