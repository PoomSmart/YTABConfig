#import "../YouTubeHeader/YTAlertView.h"
#import "../YouTubeHeader/YTAppDelegate.h"
#import "../YouTubeHeader/YTCommonUtils.h"
#import "../YouTubeHeader/YTVersionUtils.h"
#import "../YouTubeHeader/YTColdConfig.h"
#import "../YouTubeHeader/YTHotConfig.h"
#import "../YouTubeHeader/YTSettingsSectionItem.h"
#import "../YouTubeHeader/YTSettingsSectionItemManager.h"
#import "../YouTubeHeader/YTSettingsViewController.h"

#define Prefix @"YTABC-"
#define INCLUDED_CLASSES @"Included classes: YTColdConfig, YTHotConfig"

@interface YTSettingsSectionItemManager (YTABConfig)
- (void)updateYTABCSectionWithEntry:(id)entry;
@end

static const NSInteger YTABCSection = 404;

NSMutableDictionary <NSString *, NSNumber *> *cache;
NSUserDefaults *defaults;
static NSMutableArray <NSString *> *hotConfigMethods;
static NSMutableArray <NSString *> *coldConfigMethods;

static NSString *getKey(NSString *method) {
    return [NSString stringWithFormat:@"%@%@", Prefix, method];
}

static BOOL getValue(NSString *methodKey) {
    if ([defaults objectForKey:methodKey] == nil)
        return [[cache objectForKey:methodKey] boolValue];
    return [defaults boolForKey:methodKey];
}

static void setValue(NSString *methodKey, BOOL value) {
    [cache setObject:@(value) forKey:methodKey];
    [defaults setBool:value forKey:methodKey];
}

static BOOL returnFunction(id const self, SEL _cmd) {
    NSString *method = NSStringFromSelector(_cmd);
    NSString *methodKey = getKey(method);
    return getValue(methodKey);
}

static BOOL getValueFromInvocation(id target, SEL selector) {
    NSInvocationOperation *i = [[NSInvocationOperation alloc] initWithTarget:target selector:selector object:nil];
    [i start];
    BOOL result = NO;
    [i.result getValue:&result];
    return result;
}

%hook YTAppSettingsPresentationData

+ (NSArray *)settingsCategoryOrder {
    NSArray *order = %orig;
    NSMutableArray *mutableOrder = [order mutableCopy];
    [mutableOrder insertObject:@(YTABCSection) atIndex:0];
    return mutableOrder;
}

%end

%hook YTSettingsSectionItemManager

%new(v@:@)
- (void)updateYTABCSectionWithEntry:(id)entry {
    NSMutableArray *sectionItems = [NSMutableArray array];
    for (NSString *method in coldConfigMethods) {
        NSString *key = getKey(method);
        YTSettingsSectionItem *methodSwitch = [%c(YTSettingsSectionItem) switchItemWithTitle:method
            titleDescription:nil
            accessibilityIdentifier:nil
            switchOn:getValue(key)
            switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
                setValue(key, enabled);
                return YES;
            }
            settingItemId:0];
        [sectionItems addObject:methodSwitch];
    }
    for (NSString *method in hotConfigMethods) {
        NSString *key = getKey(method);
        YTSettingsSectionItem *methodSwitch = [%c(YTSettingsSectionItem) switchItemWithTitle:method
            titleDescription:nil
            accessibilityIdentifier:nil
            switchOn:getValue(key)
            switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
                setValue(key, enabled);
                return YES;
            }
            settingItemId:0];
        [sectionItems addObject:methodSwitch];
    }
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES];
    [sectionItems sortUsingDescriptors:@[sort]];
    YTSettingsSectionItem *copyAll = [%c(YTSettingsSectionItem)
        itemWithTitle:@"Copy current settings"
        titleDescription:@"Tap to copy the current settings to the clipboard."
        accessibilityIdentifier:nil
        detailTextBlock:nil
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
            NSMutableArray *content = [NSMutableArray array];
            [cache enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSNumber *value, BOOL* stop) {
                NSString *displayKey = [key substringFromIndex:Prefix.length];
                [content addObject:[NSString stringWithFormat:@"%@: %d", displayKey, [value boolValue]]];
            }];
            [content sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
            [content insertObject:[NSString stringWithFormat:@"Device model: %@", [%c(YTCommonUtils) hardwareModel]] atIndex:0];
            [content insertObject:[NSString stringWithFormat:@"App version: %@", [%c(YTVersionUtils) appVersion]] atIndex:0];
            [content insertObject:INCLUDED_CLASSES atIndex:0];
            [content insertObject:[NSString stringWithFormat:@"YTABConfig version: %@", @(OS_STRINGIFY(TWEAK_VERSION))] atIndex:0];
            pasteboard.string = [content componentsJoinedByString:@"\n"];
            return YES;
        }];
    [sectionItems insertObject:copyAll atIndex:0];
    YTSettingsSectionItem *modified = [%c(YTSettingsSectionItem)
        itemWithTitle:@"View modified settings"
        titleDescription:@"Tap to view all the changes you made manually."
        accessibilityIdentifier:nil
        detailTextBlock:nil
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            NSMutableArray *features = [NSMutableArray array];
            for (NSString *key in [defaults dictionaryRepresentation].allKeys) {
                if ([key hasPrefix:Prefix]) {
                    NSString *displayKey = [key substringFromIndex:Prefix.length];
                    [features addObject:[NSString stringWithFormat:@"%@: %d", displayKey, [defaults boolForKey:key]]];
                }
            }
            [features sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
            [features insertObject:[NSString stringWithFormat:@"Total: %ld", features.count] atIndex:0];
            NSString *content = [features componentsJoinedByString:@"\n"];
            YTAlertView *alertView = [%c(YTAlertView) confirmationDialogWithAction:^{
                UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                pasteboard.string = content;
            } actionTitle:@"Copy to clipboard"];
            alertView.title = @"Changes";
            alertView.subtitle = content;
            [alertView show];
            return YES;
        }];
    [sectionItems insertObject:modified atIndex:0];
    YTSettingsSectionItem *reset = [%c(YTSettingsSectionItem)
        itemWithTitle:@"Reset and Kill"
        titleDescription:@"Tap to undo all of your changes and kill the app."
        accessibilityIdentifier:nil
        detailTextBlock:nil
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            for (NSString *key in [defaults dictionaryRepresentation].allKeys) {
                if ([key hasPrefix:Prefix])
                    [defaults removeObjectForKey:key];
            }
            exit(0);
        }];
    [sectionItems insertObject:reset atIndex:0];
    YTSettingsViewController *delegate = [self valueForKey:@"_dataDelegate"];
    [delegate
        setSectionItems:sectionItems
        forCategory:YTABCSection
        title:@"A/B"
        titleDescription:[NSString stringWithFormat:@"Here is the list of %ld YouTube app features. Be absolutely sure of what you try to change here!", sectionItems.count]
        headerHidden:NO];
}

- (void)updateSectionForCategory:(NSUInteger)category withEntry:(id)entry {
    if (category == YTABCSection) {
        [self updateYTABCSectionWithEntry:entry];
        return;
    }
    %orig;
}

%end

static NSMutableArray <NSString *> *getBooleanMethods(Class clz) {
    NSMutableArray *allMethods = [NSMutableArray array];
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(clz, &methodCount);
    for (unsigned int i = 0; i < methodCount; ++i) {
        Method method = methods[i];
        const char *name = sel_getName(method_getName(method));
        if (strstr(name, "ndroid") || strstr(name, "musicClient")) continue;
        const char *encoding = method_getTypeEncoding(method);
        if (strcmp(encoding, "B16@0:8")) continue;
        NSString *selector = [NSString stringWithUTF8String:name];
        if (![allMethods containsObject:selector])
            [allMethods addObject:selector];
    }
    free(methods);
    return allMethods;
}

%hook YTAppDelegate

- (BOOL)application:(id)arg1 didFinishLaunchingWithOptions:(id)arg2 {
    defaults = [NSUserDefaults standardUserDefaults];
    YTColdConfig *coldConfig = [self valueForKey:@"_coldConfig"];
    YTHotConfig *hotConfig = [self valueForKey:@"_hotConfig"];
    Class YTColdConfigClass = [coldConfig class];
    Class YTHotConfigClass = [hotConfig class];
    hotConfigMethods = getBooleanMethods(YTHotConfigClass);
    coldConfigMethods = getBooleanMethods(YTColdConfigClass);
    for (NSString *method in coldConfigMethods) {
        NSString *key = getKey(method);
        SEL selector = NSSelectorFromString(method);
        if ([cache objectForKey:key] == nil) {
            BOOL result = getValueFromInvocation(coldConfig, selector);
            [cache setObject:@(result) forKey:key];
        }
        MSHookMessageEx(YTColdConfigClass, selector, (IMP)returnFunction, NULL);
    }
    for (NSString *method in hotConfigMethods) {
        NSString *key = getKey(method);
        SEL selector = NSSelectorFromString(method);
        if ([cache objectForKey:key] == nil) {
            BOOL result = getValueFromInvocation(hotConfig, selector);
            [cache setObject:@(result) forKey:key];
        }
        MSHookMessageEx(YTHotConfigClass, selector, (IMP)returnFunction, NULL);
    }
    return %orig;
}

%end

%ctor {
    NSBundle *bundle = [NSBundle bundleWithPath:[NSString stringWithFormat:@"%@/Frameworks/Module_Framework.framework", [[NSBundle mainBundle] bundlePath]]];
    if (!bundle.loaded) [bundle load];
    cache = [NSMutableDictionary new];
    %init;
}

%dtor {
    [cache removeAllObjects];
}
