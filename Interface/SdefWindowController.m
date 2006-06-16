/*
 *  SdefWindowController.m
 *  Sdef Editor
 *
 *  Created by Rainbow Team.
 *  Copyright � 2006 Shadow Lab. All rights reserved.
 */

#import "SdefWindowController.h"
#import "SdefViewController.h"

#import <ShadowKit/SKFunctions.h>
#import <ShadowKit/SKAppKitExtensions.h>
#import <ShadowKit/SKOutlineViewController.h>

#import "SdefVerb.h"
#import "SdefClass.h"
#import "SdefSuite.h"
#import "SdefObjects.h"
#import "SdefTypedef.h"
#import "SdefDocument.h"
#import "SdefDictionary.h"

#define IsObjectOwner(item)		 		[item findRoot] == [sd_tree root]

static
NSString * const SdefObjectDragType = @"SdefObjectDragType";

@interface SdefDictionaryTree : SKOutlineViewController {
}

@end

NSString * const SdefTreePboardType = @"SdefTreeType";
NSString * const SdefInfoPboardType = @"SdefInfoType";

NSString * const SdefDictionarySelectionDidChangeNotification = @"SdefDictionarySelectionDidChange";

static inline BOOL SdefEditorExistsForItem(SdefObject *item) {
  switch ([item objectType]) {
    case kSdefDictionaryType:
    case kSdefSuiteType:
      /* Class */
    case kSdefClassType:
      /* Verbs */
    case kSdefVerbType:
      /* Enumeration */
    case kSdefRecordType:
    case kSdefEnumerationType:  
      return YES;
    default:
      return NO;
  }
}

@implementation SdefWindowController

- (id)initWithOwner:(id)owner {
  if (self = [super initWithWindowNibName:@"SdefDocument" owner:(owner) ? : self]) {
    sd_viewControllers = [[NSMutableDictionary alloc] initWithCapacity:16];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didChangeNodeName:)
                                                 name:SKUITreeNodeDidChangeNameNotification
                                               object:nil];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [sd_viewControllers release];
  [sd_tree unbind:@"autoSelect"];
  [sd_tree release];
  [super dealloc];
}

#pragma mark -
- (SdefObject *)selection {
  return [outline itemAtRow:[outline selectedRow]];
}

- (void)displayObject:(SdefObject *)anObject {
  [sd_tree displayNode:anObject];
}

- (void)setSelection:(SdefObject *)anObject display:(BOOL)display {
  if (IsObjectOwner(anObject)) {
    [sd_tree setSelectedNode:anObject display:display];
    if (SdefEditorExistsForItem(anObject))
      [[self window] makeFirstResponder:outline];
  }
}

- (void)setSelection:(SdefObject *)anObject {
  [self setSelection:anObject display:YES];
}

- (SdefViewController *)currentController {
  SdefObject *selection = [outline itemAtRow:[outline selectedRow]];
  SdefObject *item = selection;
  while (item && !SdefEditorExistsForItem(item)) {
    item = [item parent];
  }
  if (item && ([item objectType] != kSdefUndefinedType)) {
    return [sd_viewControllers objectForKey:SKFileTypeForHFSTypeCode([item objectType])];
  }
  return nil;
}

- (void)didChangeNodeName:(NSNotification *)aNotification {
  id item = [aNotification object];
  if (item == [(SdefDocument *)[self document] dictionary]) {
    [self synchronizeWindowTitleWithDocumentName];
  }
}

#pragma mark -

// set autoselect: [[NSUserDefaults standardUserDefaults] boolForKey:@"SdefAutoSelectItem"]
- (void)windowDidLoad {
  [outline registerForDraggedTypes:[NSArray arrayWithObject:SdefObjectDragType]];
  [super windowDidLoad];
}

- (void)windowWillClose:(NSNotification *)notification {
  [[sd_viewControllers allValues] makeObjectsPerformSelector:@selector(setObject:) withObject:nil];
  [[sd_viewControllers allValues] makeObjectsPerformSelector:@selector(documentWillClose:) withObject:[self document]];
}

- (NSRect)window:(NSWindow *)window willPositionSheet:(NSWindow *)sheet usingRect:(NSRect)rect {
  id ctrl = [sheet windowController];
  if (ctrl && [ctrl respondsToSelector:@selector(field)]) {
    NSView *type = [ctrl performSelector:@selector(field)];
    if ([type superview]) {
      NSRect typeRect = [[type superview] convertRect:[type frame] toView:nil];
      rect.origin.x = NSMinX(typeRect);
      rect.origin.y = NSMaxY(typeRect) - 2;
      rect.size.width = NSWidth(typeRect);
      rect.size.height = 0;
    }
  }
  return rect;
}

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName {
  return [NSString stringWithFormat:@"%@ : %@", displayName, [[(SdefDocument *)[self document] dictionary] name]];
}

#pragma mark -
- (void)awakeFromNib {
  if (!sd_tree && outline) {
    sd_tree = [[SdefDictionaryTree alloc] initWithOutlineView:outline];
    [sd_tree setDisplayRoot:YES];
    [sd_tree setRoot:[(SdefDocument *)[self document] dictionary]];
    [sd_tree bind:@"autoSelect"    
         toObject:[NSUserDefaultsController sharedUserDefaultsController]
      withKeyPath:@"values.SdefAutoSelectItem"
          options:nil];
  }
  [outline setTarget:[NSApp delegate]];
  [outline setDoubleAction:@selector(openInspector:)];
}

- (void)setDictionary:(SdefDictionary *)dictionary {
  [sd_tree setRoot:dictionary];
}

- (IBAction)sortByName:(id)sender {
  if ([outline selectedRow] != -1) {
    SdefObject *item = [outline itemAtRow:[outline selectedRow]];
    /* If contains user objects */
    if ([[item firstChild] isRemovable]) {
      [item sortByName];
    }
  }
}

#pragma mark -
- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
  NSOutlineView *view = [notification object];
  SdefObject *selection = [view itemAtRow:[view selectedRow]];
  SdefObject *item = selection;
  while (item && !SdefEditorExistsForItem(item)) {
    item = [item parent];
  }
  if (item && ([item objectType] != kSdefUndefinedType)) {
    id str = SKFileTypeForHFSTypeCode([item objectType]);
    unsigned idx = [inspector indexOfTabViewItemWithIdentifier:str];
    NSAssert1(idx != NSNotFound, @"Unable to find tab item for identifier \"%@\"", str);
    SdefViewController *ctrl = [sd_viewControllers objectForKey:str];
    if ([ctrl object] != item) {
      [ctrl setObject:item];
    }
    [ctrl selectObject:selection];
    if ([inspector tabViewItemAtIndex:idx] != [inspector selectedTabViewItem]) {
      [inspector selectTabViewItemAtIndex:idx];
    }
  }
  [[NSNotificationCenter defaultCenter] postNotificationName:SdefDictionarySelectionDidChangeNotification object:[self document]];
}


/*
 - (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item {
   if ([[tableColumn identifier] isEqualToString:@"_item"]) {
     if ([outlineView rowForItem:item] == [outlineView selectedRow]) {
       [cell setTextColor:([[self window] firstResponder] == self) ? [NSColor whiteColor] : [NSColor blackColor]];
     } else {
       [cell setTextColor:([item isEditable]) ? [NSColor textColor] : [NSColor disabledControlTextColor]];
     }
   }
 }
 */
- (void)deleteSelectionInOutlineView:(NSOutlineView *)outlineView {
  SdefObject *item = [outlineView itemAtRow:[outlineView selectedRow]];
  if (item != [(SdefDocument *)[self document] dictionary] && [item isEditable] && [item isRemovable]) {
    SdefObject *parent = [item parent];
    unsigned idx = [parent indexOfChild:item];
    [item remove];
    [self setSelection:((idx > 0) ? [parent childAtIndex:idx-1] : parent) display:NO];
  } else {
    NSBeep();
  }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item {
  return [item isEditable] && [item objectType] != kSdefCollectionType;
}

- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem {
  id key = [tabViewItem identifier];
  if (![sd_viewControllers objectForKey:key]) {
    id ctrl;
    id class = nil;
    id nibName = nil;
    switch (SKHFSTypeCodeFromFileType(key)) {
      case kSdefDictionaryType:
        class = @"SdefDictionaryView";
        nibName = @"SdefDictionary";
        break;
      case kSdefClassType:
        class = @"SdefClassView";
        nibName = @"SdefClass";
        break;
      case kSdefSuiteType:
        class = @"SdefSuiteView";
        nibName = @"SdefSuite";
        break;
      case kSdefRecordType:
        class = @"SdefRecordView";
        nibName = @"SdefRecord";
        break;
      case kSdefEnumerationType:
        class = @"SdefEnumerationView";
        nibName = @"SdefEnumeration";
        break;
      case kSdefVerbType:
        class = @"SdefVerbView";
        nibName = @"SdefVerb";
        break;
    }
    if (class && nibName) {
      ctrl = [[NSClassFromString(class) alloc] initWithNibName:nibName];
      NSAssert1(ctrl != nil, @"Unable to instanciate controller: %@", class);
      if (ctrl) {
        [sd_viewControllers setObject:ctrl forKey:key];
        [ctrl release];
        [tabViewItem setView:[ctrl sdefView]];
      }
    }
  }
}

#pragma mark -
#pragma mark Copy/Paste
- (BOOL)validateMenuItem:(NSMenuItem *)anItem {
  SEL action = [anItem action];
  id selection = [self selection];
  if (action == @selector(copy:) || action == @selector(cut:)) {
    switch ([selection objectType]) {
      case kSdefUndefinedType:
      case kSdefDictionaryType:
        return NO;
      case kSdefCollectionType:
        if ([selection count] == 0)
          return NO;
      default:
        break;
    }
  }
  if (action == @selector(delete:) || action == @selector(cut:)) {
    if (![selection isRemovable] || [(SdefDocument *)[self document] dictionary] == selection)
      return NO;
  }
  if (action == @selector(paste:)) {
    if (![selection isEditable] || ![[[NSPasteboard generalPasteboard] types] containsObject:SdefTreePboardType])
      return NO;
  }
  return YES;
}

- (IBAction)copy:(id)sender {
  SdefObject *selection = [self selection];
  NSPasteboard *pboard = [NSPasteboard generalPasteboard];
  switch ([selection objectType]) {
    case kSdefUndefinedType:
    case kSdefDictionaryType:
      NSBeep();
      break;
    default:
      [pboard declareTypes:[NSArray arrayWithObjects:SdefTreePboardType, SdefInfoPboardType, NSStringPboardType, nil] owner:nil];
      if ([selection objectType] == kSdefRespondsToType || 
          ([selection objectType] == kSdefCollectionType && [(SdefCollection *)selection acceptsObjectType:kSdefRespondsToType])) {
        id str = nil;
        SdefClass *class = [selection firstParentOfType:kSdefClassType];
        if ([selection parent] == [class commands] || selection == [class commands]) {
          str = @"commands";
        } else if ([selection parent] == [class events] || selection == [class events]) {
          str = @"events";
        }
        [pboard setString:str forType:SdefInfoPboardType];
      } else if ([selection objectType] == kSdefVerbType || 
                 ([selection objectType] == kSdefCollectionType && [(SdefCollection *)selection acceptsObjectType:kSdefVerbType])) {
        id str = nil;
        SdefSuite *suite = [selection firstParentOfType:kSdefSuiteType];
        if ([selection parent] == [suite commands] || selection == [suite commands]) {
          str = @"commands";
        } else if ([selection parent] == [suite events] || selection == [suite events]) {
          str = @"events";
        }
        [pboard setString:str forType:SdefInfoPboardType];
      } else {
        [pboard setString:@"" forType:SdefInfoPboardType];
      }
      [pboard setString:[selection name] forType:NSStringPboardType];
      [pboard setData:[NSKeyedArchiver archivedDataWithRootObject:selection] forType:SdefTreePboardType];
  }
}

- (IBAction)delete:(id)sender {
  [self deleteSelectionInOutlineView:outline];
}

- (IBAction)cut:(id)sender {
  [self copy:sender];
  [self delete:sender];
}

- (IBAction)paste:(id)sender {
  NSPasteboard *pboard = [NSPasteboard generalPasteboard];
  if (![[pboard types] containsObject:SdefTreePboardType]) return;
  
  id selection = [self selection];
  id data = [pboard dataForType:SdefTreePboardType];
  SdefObject *tree = [NSKeyedUnarchiver unarchiveObjectWithData:data];
  if (!tree) return;
  
  id destination = nil;
  switch ([tree objectType]) {
    case kSdefUndefinedType:
    case kSdefDictionaryType:
      NSBeep();
      break;
    case kSdefSuiteType:
      destination = [selection firstParentOfType:kSdefDictionaryType];
      break;
      /* 4 main types */
    case kSdefValueType:
    case kSdefRecordType:
    case kSdefEnumerationType:
      destination = [(SdefSuite *)[selection firstParentOfType:kSdefSuiteType] types];
      break;
    case kSdefClassType:
      destination = [(SdefSuite *)[selection firstParentOfType:kSdefSuiteType] classes];
      break;
    case kSdefVerbType:
    {
      id str = [pboard stringForType:SdefInfoPboardType];
      @try {
        destination = [(SdefSuite *)[selection firstParentOfType:kSdefSuiteType] valueForKey:str];
      } @catch (id exception) {
        SKLogException(exception);
        destination = nil;
      }
    }
      break;
      /* 4 Class content type */
    case kSdefElementType:
      destination = [[selection firstParentOfType:kSdefClassType] elements];
      break;
    case kSdefPropertyType:
      destination = [(SdefClass *)[selection firstParentOfType:kSdefClassType] properties];
      if (!destination) {
        destination = [selection firstParentOfType:kSdefRecordType];
      }
      break;
    case kSdefRespondsToType:
    {
      id str = [pboard stringForType:SdefInfoPboardType];
      @try {
        destination = [(SdefClass *)[selection firstParentOfType:kSdefClassType] valueForKey:str];
      } @catch (id exception) {
        SKLogException(exception);
        destination = nil;
      }
    }
      break;
      /* Misc */
    case kSdefEnumeratorType:
      destination = [selection firstParentOfType:kSdefEnumerationType];
      break;
    case kSdefParameterType:
      destination = [selection firstParentOfType:kSdefVerbType];
      break;
    case kSdefCollectionType:
    {
      SdefSuite *suite = [selection firstParentOfType:kSdefSuiteType];
      SdefClass *class = [selection firstParentOfType:kSdefClassType];
      SdefObjectType type = [[(SdefCollection *)tree contentType] objectType];
      if ([[suite types] acceptsObjectType:type]) destination = [suite types];
      else if ([[suite classes] acceptsObjectType:type]) destination = [suite classes];
      else if ([[suite commands] acceptsObjectType:type] ||
               [[suite events] acceptsObjectType:type]) {
        id str = [pboard stringForType:SdefInfoPboardType];
        @try {
          destination = [suite valueForKey:str];
        } @catch (id exception) {
          SKLogException(exception);
          destination = nil;
        }
      }
      else if ([[class elements] acceptsObjectType:type]) destination = [class elements];
      else if ([[class properties] acceptsObjectType:type]) destination = [class properties];
      else if ([[class commands] acceptsObjectType:type] || 
               [[class events] acceptsObjectType:type]) {
        id str = [pboard stringForType:SdefInfoPboardType];
        @try {
          destination = [class valueForKey:str];
        } @catch (id exception) {
          SKLogException(exception);
          destination = nil;
        }
      }
    }
      break;
    default:
      break;
  }
  if (destination) {
    if ([tree objectType] == kSdefCollectionType) {
      id child;
      id children = [tree childEnumerator];
      while (child = [children nextObject]) {
        [child retain];
        [child remove];
        [destination appendChild:child];
        [child release];
      }
    } else {
      [destination appendChild:tree];
    }
  }
  else
    NSBeep();
}

@end

@implementation SdefDictionaryTree 

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
  return item;
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(SdefObject *)item {
  if (![[item name] isEqualToString:object]) {
    [item setName:object];
  }
}

#pragma mark -
#pragma mark Drag & Drop
- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard {
  id selection = [items objectAtIndex:0];
  if (selection != [self root] && [selection objectType] != kSdefCollectionType && [selection isEditable]) {
    NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
    [pboard declareTypes:[NSArray arrayWithObject:SdefObjectDragType] owner:self];
    id value = [NSData dataWithBytes:&selection length:sizeof(id)];
    [pboard setData:value forType:SdefObjectDragType];
    return YES;
  } else {
    return NO;
  }
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info
                  proposedItem:(id)item proposedChildIndex:(int)index {
  NSPasteboard *pboard = [info draggingPasteboard];
  
  if (item == nil && index < 0)
    return NSDragOperationNone;
  
  if (![[pboard types] containsObject:SdefObjectDragType]) {
    return NSDragOperationNone;
  }
  id value = [pboard dataForType:SdefObjectDragType];
  SdefObject *object = nil;
  [value getBytes:&object length:sizeof(id)];
  
  SdefObjectType srcType = [[object parent] objectType];  
  
  if ([object objectType] == kSdefPropertyType) {
    /* refuse if not record and not a collection that accept it */
    if ([item objectType] != kSdefRecordType && 
        ([item objectType] != kSdefCollectionType || ![item acceptsObjectType:kSdefPropertyType]))
      return NSDragOperationNone;
  } else {    
    if (srcType != [item objectType]) {
      return NSDragOperationNone;
    }
    if (srcType == kSdefCollectionType && ![item acceptsObjectType:[object objectType]]) {
      return NSDragOperationNone;
    }
  }
  
  if ([object findRoot] != [self root] || NSDragOperationCopy == [info draggingSourceOperationMask])
    return NSDragOperationCopy;
  
  return NSDragOperationGeneric;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id <NSDraggingInfo>)info item:(SdefObject *)item childIndex:(int)index {
  NSPasteboard *pboard = [info draggingPasteboard];
  if (![[pboard types] containsObject:SdefObjectDragType]) {
    return NO;
  }
  id value = [pboard dataForType:SdefObjectDragType];
  SdefObject *object = nil;
  [value getBytes:&object length:sizeof(id)];
  
  if (object)
    return [self dropObject:object item:item childIndex:index operation:[info draggingSourceOperationMask]];
  
  return NO;
}

@end
