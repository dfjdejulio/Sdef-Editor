/*
 *  SdefLeavesValidator.m
 *  Sdef Editor
 *
 *  Created by Rainbow Team.
 *  Copyright © 2006 - 2007 Shadow Lab. All rights reserved.
 */

#import "SdefXRef.h"
#import "SdefType.h"
#import "SdefComment.h"
#import "SdefSynonym.h"

#import "SdefValidatorBase.h"

@implementation SdefXRef (SdefValidator)

- (void)validate:(NSMutableArray *)messages forVersion:(SdefVersion)vers {
  if (!sd_target) {
    [messages addObject:[self invalidValue:nil forAttribute:@"target"]];
  }
  [super validate:messages forVersion:vers];
}

@end


@implementation SdefType (SdefValidator)

- (void)validate:(NSMutableArray *)messages forVersion:(SdefVersion)vers {
  if (![self name]) {
    [messages addObject:[self invalidValue:nil forAttribute:@"name"]];
  }
  [super validate:messages forVersion:vers];
}

@end

@implementation SdefComment (SdefValidator)

- (void)validate:(NSMutableArray *)messages forVersion:(SdefVersion)vers {
  if (sd_value && [sd_value rangeOfString:@"--"].location != NSNotFound) {
    [messages addObject:[SdefValidatorItem errorItemWithNode:self
                                                     message:@"Invalid character sequence '--' found in comment"]];
  }
  [super validate:messages forVersion:vers];
}

@end

@implementation SdefSynonym (SdefValidator)
  
- (void)validate:(NSMutableArray *)messages forVersion:(SdefVersion)vers {
  if (![self name] && ![self code]) {
    [messages addObject:[SdefValidatorItem errorItemWithNode:self
                                                     message:@"at least one of 'name' and 'code' is required"]];
  }
  if (![self code] && !SdefValidatorCheckCode([self code])) {
    [messages addObject:[self invalidValue:[self code] forAttribute:@"code"]];
  }
  [super validate:messages forVersion:vers];
}
  
@end