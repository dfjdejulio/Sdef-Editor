//
//  SdefXMLGenerator.m
//  SDef Editor
//
//  Created by Grayfox on 08/01/05.
//  Copyright 2005 Shadow Lab. All rights reserved.
//

#import "SdefXMLGenerator.h"
#import "SdefObject.h"
#import "SdefXMLNode.h"
#import "SdefComment.h"

inline NSString *SdefEditorComment() {
  return NSLocalizedStringFromTable(@" Sdef Editor ", @"SdefLibrary", @"XML Document comment");
}

@implementation SdefXMLGenerator

- (id)init {
  if (self = [super init]) {
    
  }
  return self;
}

- (id)initWithRoot:(SdefObject *)anObject {
  if (self = [super init]) {
    [self setRoot:anObject];
  }
  return self;
}

- (void)dealloc {
  if (sd_doc) { CFRelease(sd_doc); sd_doc = nil; }
  [sd_root release];
  [super dealloc];
}

- (SdefObject *)root {
  return sd_root;
}

- (void)setRoot:(SdefObject *)anObject {
  if (sd_root != anObject) {
    [sd_root release];
    sd_root = [anObject retain];
  }
}

- (CFXMLTreeRef)appendNode:(CFXMLNodeRef)node {
  NSParameterAssert(node != nil);
  NSAssert(sd_node != NULL, @"Current node must not be nil.");
  CFXMLTreeRef treeNode = CFXMLTreeCreateWithNode(kCFAllocatorDefault, node);
  CFTreeAppendChild((CFTreeRef)sd_node, (CFTreeRef)treeNode);
  CFRelease(treeNode);
  return treeNode;
}

- (CFXMLTreeRef)appendTree:(CFXMLTreeRef)aTree {
  NSParameterAssert(aTree != nil);
  NSAssert(sd_node != NULL, @"Current node must not be nil.");
  CFTreeAppendChild((CFTreeRef)sd_node, (CFTreeRef)aTree);
  return aTree;
}

- (CFXMLTreeRef)appendElementNode:(NSString *)name attributesKeys:(NSArray *)keys attributesValues:(NSArray *)values isEmpty:(BOOL)flag {
  NSParameterAssert(name != nil);
  NSParameterAssert([keys count] == [values count]);
  CFXMLElementInfo infos;
  infos.attributes = (CFDictionaryRef)[[NSDictionary alloc] initWithObjects:values forKeys:keys];
  infos.attributeOrder = (CFArrayRef)keys;
  infos.isEmpty = flag;
  
  CFXMLNodeRef node = CFXMLNodeCreate(kCFAllocatorDefault, kCFXMLNodeTypeElement, (CFStringRef)name, &infos, kCFXMLNodeCurrentVersion);
  CFXMLTreeRef tree = [self appendNode:node];
  if (!flag) {
    sd_node = tree;
    sd_indent++;
  } 
  CFRelease(node);
  [(id)infos.attributes release];
  return tree;
}

- (CFXMLTreeRef)insertTextNode:(NSString *)str {
  CFXMLNodeRef node = CFXMLNodeCreate(kCFAllocatorDefault, kCFXMLNodeTypeText, (CFStringRef)str, NULL, kCFXMLNodeCurrentVersion);
  CFXMLTreeRef tree  = [self appendNode:node];
  CFRelease(node);
  return tree;
}

- (CFXMLTreeRef)insertComment:(NSString *)str {
  CFXMLTreeRef tree = nil;
  NSMutableString *comment = [str mutableCopy]; 
  if (nil != comment) CFStringTrimWhitespace((CFMutableStringRef)comment);
  if ([comment length]) {
    CFXMLNodeRef node = CFXMLNodeCreate(kCFAllocatorDefault, kCFXMLNodeTypeComment, (CFStringRef)[str stringByEscapingEntities:nil], NULL, kCFXMLNodeCurrentVersion);
    tree  = [self appendNode:node];
    CFRelease(node);
  }
  [comment release];
  return tree;
}

- (void)insertWhiteSpace {
  if (sd_node) {
    NSMutableString *str = [[NSMutableString alloc] initWithCapacity:sd_indent + 1];
    [str appendString:@"\n"];
    int i;
    for (i=0; i<sd_indent; i++) {
      [str appendString:@"\t"];
    }
    [self insertTextNode:str];
    [str release];
  }
}

- (void)upOneLevelWithWhiteSpace:(BOOL)flag {
  if (sd_node) {
    sd_indent = (sd_indent) ? sd_indent - 1 : 0;
    if (flag) [self insertWhiteSpace];
    sd_node = CFTreeGetParent((CFTreeRef)sd_node);
  }
}

- (void)upOneLevel {
  [self upOneLevelWithWhiteSpace:YES];
}

- (void)createDocument {
  if (sd_doc) {
    CFRelease(sd_doc);
    sd_doc = nil;
  }
  CFXMLDocumentInfo info;
  info.sourceURL = nil;
  info.encoding = kCFStringEncodingUTF8;
  CFXMLNodeRef node = CFXMLNodeCreate(kCFAllocatorDefault,
                                      kCFXMLNodeTypeDocument,
                                      nil, &info, kCFXMLNodeCurrentVersion);
  sd_doc = CFXMLTreeCreateWithNode(kCFAllocatorDefault, node);
  sd_node = sd_doc;
  CFRelease(node);
  sd_indent = 0;
  CFXMLProcessingInstructionInfo procInfo = { CFSTR("version=\"1.0\" encoding=\"UTF-8\"") };
  node = CFXMLNodeCreate(kCFAllocatorDefault, kCFXMLNodeTypeProcessingInstruction, CFSTR("xml"), &procInfo, kCFXMLNodeCurrentVersion);
  [self appendNode:node];
  CFRelease(node);
  
  [self insertWhiteSpace];
  CFURLRef url = CFURLCreateWithString(kCFAllocatorDefault, CFSTR("file://localhost/System/Library/DTDs/sdef.dtd"), nil);
  CFXMLDocumentTypeInfo doctype = { {url, nil} };
  node = CFXMLNodeCreate(kCFAllocatorDefault, kCFXMLNodeTypeDocumentType, CFSTR("dictionary"), &doctype, kCFXMLNodeCurrentVersion);
  [self appendNode:node];
  CFRelease(node);
  CFRelease(url);
  
  NSString *signature = SdefEditorComment();
  if ([signature length]) {
    [self insertWhiteSpace];  
    [self insertComment:signature];
  }
}

- (void)appendXMLNode:(SdefXMLNode *)node {
  [self insertWhiteSpace];
  id comments = [[node comments] objectEnumerator];
  SdefComment *comment;
  while (comment = [comments nextObject]) {
    if (nil != [self insertComment:[comment value]])
      [self insertWhiteSpace];
  }
  [self appendElementNode:[node elementName]
           attributesKeys:[node attrKeys]
         attributesValues:[node attrValues]
                  isEmpty:[node isEmpty]];
  id content = [node content];
  if (nil != content) {
    [self insertTextNode:[content stringByEscapingEntities:nil]];
  }
  id children = [node childEnumerator];
  id child;
  while (child = [children nextObject]) {
    [self appendXMLNode:child];
  }
  if (![node isEmpty]) {
    (nil != content) ? [self upOneLevelWithWhiteSpace:NO] : [self upOneLevel];
  }
}

- (NSData *)xmlData {
  if (!sd_root)
    return nil;
  [self createDocument];
  if (!sd_doc)
    return nil;
  [self appendXMLNode:[sd_root xmlNode]];
  CFDataRef xml = CFXMLTreeCreateXMLData(kCFAllocatorDefault, sd_doc);
  return [(id)xml autorelease];
}

@end