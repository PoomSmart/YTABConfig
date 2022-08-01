#import "../YouTubeHeader/YTAppDelegate.h"
#import "../YouTubeHeader/YTSettingsSectionItem.h"
#import "../YouTubeHeader/YTSettingsSectionItemManager.h"
#import "../YouTubeHeader/YTSettingsViewController.h"

#define Prefix @"YTABC-"

BOOL didHook = NO;

@interface YTSettingsSectionItemManager (YTABConfig)
- (void)updateYTABCSectionWithEntry:(id)entry;
@end

Class YTColdConfigClass, YTHotConfigClass;
static const NSInteger YTABCSection = 404;

static NSCache <NSString *, NSNumber *> *cache;
static NSUserDefaults *defaults;
static NSMutableArray <NSString *> *hotConfigMethods;
static NSMutableArray <NSString *> *coldConfigMethods;

static NSString *getKey(NSString *method) {
    return [NSString stringWithFormat:@"%@%@", Prefix, method];
}

static BOOL getValue(NSString *method, NSString *methodKey) {
    if ([defaults objectForKey:methodKey] == nil)
        return [[cache objectForKey:getKey(method)] boolValue];
    return [defaults boolForKey:methodKey];
}

static BOOL (*origFunction)(id const, SEL);
static BOOL returnFunction(id const self, SEL _cmd) {
    NSString *method = NSStringFromSelector(_cmd);
    NSString *methodKey = getKey(method);
    return getValue(method, methodKey);
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
    YTSettingsViewController *delegate = [self valueForKey:@"_dataDelegate"];
    YTAppDelegate *appDelegate = (YTAppDelegate *)[[UIApplication sharedApplication] delegate];
    YTColdConfig *coldConfig = [appDelegate valueForKey:@"_coldConfig"];
    YTHotConfig *hotConfig = [appDelegate valueForKey:@"_hotConfig"];
    NSMutableArray *sectionItems = [NSMutableArray array];
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
    for (NSString *method in coldConfigMethods) {
        NSString *key = getKey(method);
        SEL selector = NSSelectorFromString(method);
        if ([cache objectForKey:key] == nil) {
            BOOL result = getValueFromInvocation(coldConfig, selector);
            [cache setObject:@(result) forKey:key];
        }
        YTSettingsSectionItem *methodSwitch = [%c(YTSettingsSectionItem) switchItemWithTitle:[NSString stringWithFormat:@"%@ (Cold)", method]
            titleDescription:nil
            accessibilityIdentifier:nil
            switchOn:getValue(method, key)
            switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
                [cache setObject:@(enabled) forKey:key];
                [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:key];
                return YES;
            }
            settingItemId:0];
        if (!didHook)
            MSHookMessageEx(YTColdConfigClass, selector, (IMP)returnFunction, (IMP *)&origFunction);
        [sectionItems addObject:methodSwitch];
    }
    for (NSString *method in hotConfigMethods) {
        NSString *key = getKey(method);
        SEL selector = NSSelectorFromString(method);
        if ([cache objectForKey:key] == nil) {
            BOOL result = getValueFromInvocation(hotConfig, selector);
            [cache setObject:@(result) forKey:key];
        }
        YTSettingsSectionItem *methodSwitch = [%c(YTSettingsSectionItem) switchItemWithTitle:[NSString stringWithFormat:@"%@ (Hot)", method]
            titleDescription:nil
            accessibilityIdentifier:nil
            switchOn:getValue(method, key)
            switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
                [cache setObject:@(enabled) forKey:key];
                [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:key];
                return YES;
            }
            settingItemId:0];
        if (!didHook)
            MSHookMessageEx(YTHotConfigClass, selector, (IMP)returnFunction, (IMP *)&origFunction);
        [sectionItems addObject:methodSwitch];
    }
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES];
    [sectionItems sortUsingDescriptors:@[sort]];
    [sectionItems insertObject:reset atIndex:0];
    [delegate
        setSectionItems:sectionItems
        forCategory:YTABCSection
        title:@"A/B"
        titleDescription:[NSString stringWithFormat:@"Here is the list of app configurations A/B by Google (%ld). Be absolutely sure of what you try to change here!", sectionItems.count]
        headerHidden:NO];
    didHook = YES;
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
    NSMutableArray <NSString *> *allMethods = [NSMutableArray array];
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

%ctor {
    NSBundle *bundle = [NSBundle bundleWithPath:[NSString stringWithFormat:@"%@/Frameworks/Module_Framework.framework", [[NSBundle mainBundle] bundlePath]]];
    if (!bundle.loaded) [bundle load];
    cache = [NSCache new];
    YTHotConfigClass = %c(YTHotConfig);
    YTColdConfigClass = %c(YTColdConfig);
    defaults = [NSUserDefaults standardUserDefaults];
    hotConfigMethods = getBooleanMethods(YTHotConfigClass);
    coldConfigMethods = getBooleanMethods(YTColdConfigClass);
    %init;
}

%dtor {
    [cache removeAllObjects];
}