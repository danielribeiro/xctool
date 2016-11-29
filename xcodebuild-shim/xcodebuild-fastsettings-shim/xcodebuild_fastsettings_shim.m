//
// Copyright 2004-present Facebook. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import <objc/message.h>
#import <objc/runtime.h>

#import <Foundation/Foundation.h>

#import "Swizzle.h"

// class-dump'ed from:
// /Applications/Xcode.app/Contents/PlugIns/Xcode3Core.ideplugin/Contents/Frameworks/DevToolsCore.framework/DevToolsCore
@interface Xcode3Target : NSObject
- (NSString *)name;
@end

@interface Xcode3TargetBuildable : NSObject
@property (readonly) Xcode3Target *xcode3Target;
@end

@interface Xcode3TargetProduct : Xcode3TargetBuildable
@end


@interface XCiPhoneSimulatorCodeSignContext: NSObject

/// We're going to swizzle this to be a noop
+ (id)prepareForCodeSigningWithMacroExpansionScope:(id)arg1 certificateUtilities:(id)arg2;
+ (id)prepareForCodeSigningWithMacroExpansionScope:(id)arg1;

@end


static NSArray *FilterBuildables(NSArray *buildables)
{
  NSString *showOnlyBuildsettingsForTarget = [[NSProcessInfo processInfo] environment][@"SHOW_ONLY_BUILD_SETTINGS_FOR_TARGET"];
  NSString *showOnlyBuildsettingsForFirstBuildable = [[NSProcessInfo processInfo] environment][@"SHOW_ONLY_BUILD_SETTINGS_FOR_FIRST_BUILDABLE"];

  if (showOnlyBuildsettingsForTarget != nil) {
    for (Xcode3TargetProduct *buildable in buildables) {
      if ([[[buildable xcode3Target] name] isEqualToString:showOnlyBuildsettingsForTarget]) {
        return @[buildable];
      }
    }
    return @[];
  } else if ([showOnlyBuildsettingsForFirstBuildable isEqualToString:@"YES"]) {
    return buildables.count > 0 ? @[buildables[0]] : @[];
  } else {
    return buildables;
  }
}

static id IDEBuildSchemeAction__uniquedBuildablesForBuildables_includingDependencies(id self, SEL sel, id buildables, BOOL includingDependencies)
{
  id result = objc_msgSend(self,
                      @selector(__IDEBuildSchemeAction__uniquedBuildablesForBuildables:includingDependencies:),
                      buildables,
                      includingDependencies);
  return FilterBuildables(result);
}

static id XCiPhoneSimulatorCodeSignContext__prepareForCodeSigningWithMacroExpansionScope_certificateUtilities(id self, SEL sel, id arg1, BOOL arg2)
{
  // [NSException raise:@"what1" format:@"bad method 1"];
  return arg1;
}

static id XCiPhoneSimulatorCodeSignContext__prepareForCodeSigningWithMacroExpansionScope(id self, SEL sel, id arg1)
{
  // [NSException raise:@"what2" format:@"bad method 2"];
  return arg1;
}

__attribute__((constructor)) static void EntryPoint()
{
  NSCAssert(NSClassFromString(@"IDEBuildSchemeAction") != NULL, @"Should have IDEBuildSchemeAction");

  // Xcode 5 and later will call this method several times as its
  // collecting all the buildables.  We can filter the list each time.
  XTSwizzleClassSelectorForFunction(NSClassFromString(@"IDEBuildSchemeAction"),
                               @selector(_uniquedBuildablesForBuildables:includingDependencies:),
                               (IMP)IDEBuildSchemeAction__uniquedBuildablesForBuildables_includingDependencies);

  // If we're in xcode 7.3.1 or 8.0.0, we have to work around a deadlock that occurs. This is done by making prepareForCodeSigningWithMacroExpansionScope:certificateUtilities: be a noop by returning the first argument
  // This shouldn't be needed for listing build settings.


  /// Load ide plugin bundle. It contains the method we're swizzling. It is not necessarily loaded at the time this library is loaded, so we have to manually load it
  NSURL *pluginURL = [[NSBundle mainBundle] URLForResource:@"IDEiOSSupportCore" withExtension:@"ideplugin" subdirectory:@"../../../PlugIns"];
  NSCAssert(pluginURL != nil, @"Must be able to load IDEiOSSupportCore plugin");

  NSBundle *bundle = [NSBundle bundleWithURL:pluginURL];
  NSCAssert(bundle != nil, @"Must be able to load IDEiOSSupportCore");
  [bundle load];
  NSCAssert(NSClassFromString(@"XCiPhoneSimulatorCodeSignContext") != NULL, @"Should have XCiPhoneSimulatorCodeSignContext");

  // Xcode 5 and later will call this method several times as its
  // collecting all the buildables.  We can filter the list each time.
  XTSwizzleClassSelectorForFunction(NSClassFromString(@"XCiPhoneSimulatorCodeSignContext"),
                                    @selector(prepareForCodeSigningWithMacroExpansionScope:certificateUtilities:),
                                    (IMP)XCiPhoneSimulatorCodeSignContext__prepareForCodeSigningWithMacroExpansionScope_certificateUtilities);
  XTSwizzleClassSelectorForFunction(NSClassFromString(@"XCiPhoneSimulatorCodeSignContext"),
                                    @selector(prepareForCodeSigningWithMacroExpansionScope),
                                    (IMP)XCiPhoneSimulatorCodeSignContext__prepareForCodeSigningWithMacroExpansionScope);


  // Unset so we don't cascade into other process that get spawned from xcodebuild.
  unsetenv("DYLD_INSERT_LIBRARIES");
}
