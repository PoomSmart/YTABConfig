#import "../YouTubeHeader/YTAlertView.h"
#import "../YouTubeHeader/YTAppDelegate.h"
#import "../YouTubeHeader/YTCommonUtils.h"
#import "../YouTubeHeader/YTVersionUtils.h"
#import "../YouTubeHeader/YTGlobalConfig.h"
#import "../YouTubeHeader/YTColdConfig.h"
#import "../YouTubeHeader/YTHotConfig.h"
#import "../YouTubeHeader/YTSettingsSectionItem.h"
#import "../YouTubeHeader/YTSettingsSectionItemManager.h"
#import "../YouTubeHeader/YTSettingsViewController.h"

#define Prefix @"YTABC"
#define INCLUDED_CLASSES @"Included classes: YTGlobalConfig, YTColdConfig, YTHotConfig"
#define EXCLUDED_METHODS @"Excluded settings: android*, amsterdam*, musicClient* and unplugged*"

@interface YTSettingsSectionItemManager (YTABConfig)
- (void)updateYTABCSectionWithEntry:(id)entry;
@end

static const NSInteger YTABCSection = 404;

NSMutableDictionary <NSString *, NSMutableDictionary <NSString *, NSNumber *> *> *cache;
NSUserDefaults *defaults;

static NSString *getKey(NSString *method, NSString *classKey) {
    return [NSString stringWithFormat:@"%@.%@.%@", Prefix, classKey, method];
}

static NSString *getCacheKey(NSString *method, NSString *classKey) {
    return [NSString stringWithFormat:@"%@.%@", classKey, method];
}

static BOOL getValue(NSString *methodKey) {
    if ([defaults objectForKey:methodKey] == nil)
        return [[cache valueForKeyPath:[methodKey substringFromIndex:Prefix.length + 1]] boolValue];
    return [defaults boolForKey:methodKey];
}

static void setValue(NSString *method, NSString *classKey, BOOL value) {
    [cache setValue:@(value) forKeyPath:getCacheKey(method, classKey)];
    [defaults setBool:value forKey:getKey(method, classKey)];
}

static BOOL returnFunction(id const self, SEL _cmd) {
    NSString *method = NSStringFromSelector(_cmd);
    NSString *methodKey = getKey(method, NSStringFromClass([self class]));
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
    for (NSString *classKey in cache) {
        for (NSString *method in cache[classKey]) {
            YTSettingsSectionItem *methodSwitch = [%c(YTSettingsSectionItem) switchItemWithTitle:method
            titleDescription:nil
            accessibilityIdentifier:nil
            switchOn:getValue(getKey(method, classKey))
            switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
                setValue(method, classKey, enabled);
                return YES;
            }
            // selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            //     YTAlertView *alertView = [%c(YTAlertView) infoDialog];
            //     alertView.title = method;
            //     alertView.subtitle = [NSString stringWithFormat:@"-[%@ %@]", classKey, method];
            //     [alertView show];
            //     return YES;
            // }
            settingItemId:0];
            [sectionItems addObject:methodSwitch];
        }
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
            for (NSString *classKey in cache) {
                [cache[classKey] enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSNumber *value, BOOL* stop) {
                    [content addObject:[NSString stringWithFormat:@"%@: %d", key, [value boolValue]]];
                }];
            }
            [content sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
            [content insertObject:[NSString stringWithFormat:@"Device model: %@", [%c(YTCommonUtils) hardwareModel]] atIndex:0];
            [content insertObject:[NSString stringWithFormat:@"App version: %@", [%c(YTVersionUtils) appVersion]] atIndex:0];
            [content insertObject:EXCLUDED_METHODS atIndex:0];
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
                    NSString *displayKey = [key substringFromIndex:Prefix.length + 1];
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
        if (strstr(name, "ndroid") || strstr(name, "musicClient") || strstr(name, "amsterdam") || strstr(name, "unplugged")) continue;
        const char *encoding = method_getTypeEncoding(method);
        if (strcmp(encoding, "B16@0:8")) continue;
        NSString *selector = [NSString stringWithUTF8String:name];
        if (![allMethods containsObject:selector])
            [allMethods addObject:selector];
    }
    free(methods);
    return allMethods;
}

static void hookClass(NSObject *instance, Class instanceClass) {
    NSMutableArray <NSString *> *methods = getBooleanMethods(instanceClass);
    NSString *classKey = NSStringFromClass(instanceClass);
    NSMutableDictionary *classCache = cache[classKey] = [NSMutableDictionary new];
    for (NSString *method in methods) {
        SEL selector = NSSelectorFromString(method);
        BOOL result = getValueFromInvocation(instance, selector);
        classCache[method] = @(result);
        MSHookMessageEx(instanceClass, selector, (IMP)returnFunction, NULL);
    }
}

%hook YTAppDelegate

- (BOOL)application:(id)arg1 didFinishLaunchingWithOptions:(id)arg2 {
    defaults = [NSUserDefaults standardUserDefaults];
    YTGlobalConfig *globalConfig = [self valueForKey:@"_globalConfig"];
    YTColdConfig *coldConfig = [self valueForKey:@"_coldConfig"];
    YTHotConfig *hotConfig = [self valueForKey:@"_hotConfig"];
    hookClass(globalConfig, [globalConfig class]);
    hookClass(coldConfig, [coldConfig class]);
    hookClass(hotConfig, [hotConfig class]);
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
