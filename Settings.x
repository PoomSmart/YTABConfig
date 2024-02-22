#import <YouTubeHeader/GOOHUDManagerInternal.h>
#import <YouTubeHeader/YTAlertView.h>
#import <YouTubeHeader/YTCommonUtils.h>
#import <YouTubeHeader/YTSettingsSectionItem.h>
#import <YouTubeHeader/YTSettingsSectionItemManager.h>
#import <YouTubeHeader/YTSettingsPickerViewController.h>
#import <YouTubeHeader/YTSettingsViewController.h>
#import <YouTubeHeader/YTSearchableSettingsViewController.h>
#import <YouTubeHeader/YTUIUtils.h>
#import <YouTubeHeader/YTVersionUtils.h>
#import <rootless.h>

#define Prefix @"YTABC"
#define EnabledKey @"EnabledYTABC"
#define GroupedKey @"GroupedYTABC"
#define INCLUDED_CLASSES @"Included classes: YTGlobalConfig, YTColdConfig, YTHotConfig"
#define EXCLUDED_METHODS @"Excluded settings: android*, amsterdam*, musicClient* and unplugged*"

#define _LOC(b, x) [b localizedStringForKey:x value:nil table:nil]
#define LOC(x) _LOC(tweakBundle, x)

static const NSInteger YTABCSection = 404;

@interface YTSettingsSectionItemManager (YTABConfig)
- (void)updateYTABCSectionWithEntry:(id)entry;
@end

extern NSMutableDictionary <NSString *, NSMutableDictionary <NSString *, NSNumber *> *> *cache;
NSUserDefaults *defaults;
NSArray <NSString *> *allKeys;

BOOL tweakEnabled() {
    return [defaults boolForKey:EnabledKey];
}

BOOL groupedSettings() {
    return [defaults boolForKey:GroupedKey];
}

NSBundle *YTABCBundle() {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:@"YTABC" ofType:@"bundle"];
        if (tweakBundlePath)
            bundle = [NSBundle bundleWithPath:tweakBundlePath];
        else
            bundle = [NSBundle bundleWithPath:ROOT_PATH_NS(@"/Library/Application Support/YTABC.bundle")];
    });
    return bundle;
}

NSString *getKey(NSString *method, NSString *classKey) {
    return [NSString stringWithFormat:@"%@.%@.%@", Prefix, classKey, method];
}

static NSString *getCacheKey(NSString *method, NSString *classKey) {
    return [NSString stringWithFormat:@"%@.%@", classKey, method];
}

BOOL getValue(NSString *methodKey) {
    if (![allKeys containsObject:methodKey])
        return [[cache valueForKeyPath:[methodKey substringFromIndex:Prefix.length + 1]] boolValue];
    return [defaults boolForKey:methodKey];
}

static void setValue(NSString *method, NSString *classKey, BOOL value) {
    [cache setValue:@(value) forKeyPath:getCacheKey(method, classKey)];
    [defaults setBool:value forKey:getKey(method, classKey)];
}

static void setValueFromImport(NSString *settingKey, BOOL value) {
    [cache setValue:@(value) forKeyPath:settingKey];
    [defaults setBool:value forKey:[NSString stringWithFormat:@"%@.%@", Prefix, settingKey]];
}

void updateAllKeys() {
    allKeys = [defaults dictionaryRepresentation].allKeys;
}

%group Search

%hook YTSettingsViewController

- (void)loadWithModel:(id)model fromView:(UIView *)view {
    %orig;
    if ([[self valueForKey:@"_detailsCategoryID"] integerValue] == YTABCSection)
        [self setValue:@(YES) forKey:@"_shouldShowSearchBar"];
}

- (void)setSectionControllers {
    %orig;
    if ([[self valueForKey:@"_shouldShowSearchBar"] boolValue]) {
        YTSettingsSectionController *settingsSectionController = [self settingsSectionControllers][[self valueForKey:@"_detailsCategoryID"]];
        if (settingsSectionController) {
            YTSearchableSettingsViewController *searchableVC = [self valueForKey:@"_searchableSettingsViewController"];
            [searchableVC storeCollectionViewSections:@[settingsSectionController]];
        }
    }
}

%end

%end

%hook YTSettingsSectionController

- (void)setSelectedItem:(NSUInteger)selectedItem {
    if (selectedItem != NSNotFound) %orig;
}

%end

%hook YTAppSettingsPresentationData

+ (NSArray *)settingsCategoryOrder {
    NSArray *order = %orig;
    NSMutableArray *mutableOrder = [order mutableCopy];
    [mutableOrder insertObject:@(YTABCSection) atIndex:0];
    return mutableOrder;
}

%end

static NSString *getCategory(char c, NSString *method) {
    if (c == 'e') {
        if ([method hasPrefix:@"elements"]) return @"elements";
        if ([method hasPrefix:@"enable"]) return @"enable";
    }
    if (c == 'i') {
        if ([method hasPrefix:@"ios"]) return @"ios";
        if ([method hasPrefix:@"is"]) return @"is";
    }
    if (c == 's') {
        if ([method hasPrefix:@"shorts"]) return @"shorts";
        if ([method hasPrefix:@"should"]) return @"should";
    }
    unichar uc = (unichar)c;
    return [NSString stringWithCharacters:&uc length:1];;
}

%hook YTSettingsSectionItemManager

%new(v@:@)
- (void)updateYTABCSectionWithEntry:(id)entry {
    NSMutableArray *sectionItems = [NSMutableArray array];
    int totalSettings = 0;
    NSBundle *tweakBundle = YTABCBundle();
    BOOL isPhone = ![%c(YTCommonUtils) isIPad];
    NSString *yesText = _LOC([NSBundle mainBundle], @"settings.yes");
    NSString *cancelText = _LOC([NSBundle mainBundle], @"confirm.cancel");
    NSString *deleteText = _LOC([NSBundle mainBundle], @"search.action.delete");
    Class YTSettingsSectionItemClass = %c(YTSettingsSectionItem);
    Class YTAlertViewClass = %c(YTAlertView);

    if (tweakEnabled()) {
        // AB flags
        NSMutableDictionary <NSString *, NSMutableArray <YTSettingsSectionItem *> *> *properties = [NSMutableDictionary dictionary];
        for (NSString *classKey in cache) {
            for (NSString *method in cache[classKey]) {
                char c = tolower([method characterAtIndex:0]);
                NSString *category = getCategory(c, method);
                if (![properties objectForKey:category]) properties[category] = [NSMutableArray array];
                updateAllKeys();
                BOOL modified = [allKeys containsObject:getKey(method, classKey)];
                NSString *modifiedTitle = modified ? [NSString stringWithFormat:@"%@ *", method] : method;

                YTSettingsSectionItem *methodSwitch = [YTSettingsSectionItemClass switchItemWithTitle:modifiedTitle
                    titleDescription:isPhone && method.length > 26 ? modifiedTitle : nil
                    accessibilityIdentifier:nil
                    switchOn:getValue(getKey(method, classKey))
                    switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
                        setValue(method, classKey, enabled);
                        return YES;
                    }
                    selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                        NSString *content = [NSString stringWithFormat:@"%@.%@", classKey, method];
                        YTAlertView *alertView = [YTAlertViewClass confirmationDialog];
                        alertView.title = method;
                        alertView.subtitle = content;
                        [alertView addTitle:LOC(@"COPY_TO_CLIPBOARD") withAction:^{
                            UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                            pasteboard.string = content;
                            [[%c(GOOHUDManagerInternal) sharedInstance] showMessageMainThread:[%c(YTHUDMessage) messageWithText:LOC(@"COPIED_TO_CLIPBOARD")]];
                        }];
                        updateAllKeys();
                        NSString *key = getKey(method, classKey);
                        if ([allKeys containsObject:key]) {
                            [alertView addTitle:deleteText withAction:^{
                                [defaults removeObjectForKey:key];
                                updateAllKeys();
                            }];
                        }
                        [alertView addCancelButton:NULL];
                        [alertView show];
                        return NO;
                    }
                    settingItemId:0];
                [properties[category] addObject:methodSwitch];
            }
        }
        YTSettingsViewController *settingsViewController = [self valueForKey:@"_settingsViewControllerDelegate"];
        BOOL grouped = groupedSettings();
        for (NSString *category in properties) {
            NSMutableArray <YTSettingsSectionItem *> *rows = properties[category];
            totalSettings += rows.count;
            if (grouped) {
                NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES];
                [rows sortUsingDescriptors:@[sort]];
                NSString *shortTitle = [NSString stringWithFormat:@"\"%@\" (%ld)", category, rows.count];
                NSString *title = [NSString stringWithFormat:@"%@ %@", LOC(@"SETTINGS_START_WITH"), shortTitle];

                YTSettingsSectionItem *sectionItem = [YTSettingsSectionItemClass itemWithTitle:title accessibilityIdentifier:nil detailTextBlock:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                    YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc] initWithNavTitle:shortTitle pickerSectionTitle:nil rows:rows selectedItemIndex:NSNotFound parentResponder:[self parentResponder]];
                    [settingsViewController pushViewController:picker];
                    return YES;
                }];
                [sectionItems addObject:sectionItem];
            } else {
                [sectionItems addObjectsFromArray:rows];
            }
        }
        NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES];
        [sectionItems sortUsingDescriptors:@[sort]];

        // Import settings
        YTSettingsSectionItem *import = [YTSettingsSectionItemClass itemWithTitle:LOC(@"IMPORT_SETTINGS")
            titleDescription:[NSString stringWithFormat:LOC(@"IMPORT_SETTINGS_DESC"), @"YT(Cold|Hot|Global)Config.*: (0|1)"]
            accessibilityIdentifier:nil
            detailTextBlock:nil
            selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                NSArray *lines = [pasteboard.string componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
                NSString *pattern = @"^(YT.*Config\\..*):\\s*(\\d)$";
                NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
                NSMutableDictionary *importedSettings = [NSMutableDictionary dictionary];
                NSMutableArray *reportedSettings = [NSMutableArray array];

                for (NSString *line in lines) {
                    NSTextCheckingResult *match = [regex firstMatchInString:line options:0 range:NSMakeRange(0, [line length])];
                    if (match) {
                        NSString *key = [line substringWithRange:[match rangeAtIndex:1]];
                        id cacheValue = [cache valueForKeyPath:key];
                        if (cacheValue == nil) continue;
                        NSString *valueString = [line substringWithRange:[match rangeAtIndex:2]];
                        int integerValue = [valueString integerValue];
                        if (integerValue == 0 && ![cacheValue boolValue]) continue;
                        if (integerValue == 1 && [cacheValue boolValue]) continue;
                        importedSettings[key] = @(integerValue);
                        [reportedSettings addObject:[NSString stringWithFormat:@"%@: %d", key, integerValue]];
                    }
                }

                if (reportedSettings.count == 0) {
                    YTAlertView *alertView = [YTAlertViewClass infoDialog];
                    alertView.title = LOC(@"SETTINGS_TO_IMPORT");
                    alertView.subtitle = LOC(@"NOTHING_TO_IMPORT");
                    [alertView show];
                    return NO;
                }

                [reportedSettings insertObject:[NSString stringWithFormat:LOC(@"SETTINGS_TO_IMPORT_DESC"), reportedSettings.count] atIndex:0];

                YTAlertView *alertView = [YTAlertViewClass confirmationDialogWithAction:^{
                    for (NSString *key in importedSettings) {
                        setValueFromImport(key, [importedSettings[key] boolValue]);
                    }
                    updateAllKeys();
                } actionTitle:LOC(@"IMPORT")];
                alertView.title = LOC(@"SETTINGS_TO_IMPORT");
                alertView.subtitle = [reportedSettings componentsJoinedByString:@"\n"];
                [alertView show];
                return YES;
            }];
        [sectionItems insertObject:import atIndex:0];

        // Copy current settings
        YTSettingsSectionItem *copyAll = [YTSettingsSectionItemClass itemWithTitle:LOC(@"COPY_CURRENT_SETTINGS")
            titleDescription:LOC(@"COPY_CURRENT_SETTINGS_DESC")
            accessibilityIdentifier:nil
            detailTextBlock:nil
            selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                NSMutableArray *content = [NSMutableArray array];
                for (NSString *classKey in cache) {
                    [cache[classKey] enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSNumber *value, BOOL* stop) {
                        [content addObject:[NSString stringWithFormat:@"%@.%@: %d", classKey, key, [value boolValue]]];
                    }];
                }
                [content sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
                [content insertObject:[NSString stringWithFormat:@"Device model: %@", [%c(YTCommonUtils) hardwareModel]] atIndex:0];
                [content insertObject:[NSString stringWithFormat:@"App version: %@", [%c(YTVersionUtils) appVersion]] atIndex:0];
                [content insertObject:EXCLUDED_METHODS atIndex:0];
                [content insertObject:INCLUDED_CLASSES atIndex:0];
                [content insertObject:[NSString stringWithFormat:@"YTABConfig version: %@", @(OS_STRINGIFY(TWEAK_VERSION))] atIndex:0];
                pasteboard.string = [content componentsJoinedByString:@"\n"];
                [[%c(GOOHUDManagerInternal) sharedInstance] showMessageMainThread:[%c(YTHUDMessage) messageWithText:LOC(@"COPIED_TO_CLIPBOARD")]];
                return YES;
            }];
        [sectionItems insertObject:copyAll atIndex:0];

        // View modified settings
        YTSettingsSectionItem *modified = [YTSettingsSectionItemClass itemWithTitle:LOC(@"VIEW_MODIFIED_SETTINGS")
            titleDescription:LOC(@"VIEW_MODIFIED_SETTINGS_DESC")
            accessibilityIdentifier:nil
            detailTextBlock:nil
            selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                NSMutableArray *features = [NSMutableArray array];
                updateAllKeys();
                for (NSString *key in allKeys) {
                    if ([key hasPrefix:Prefix]) {
                        NSString *displayKey = [key substringFromIndex:Prefix.length + 1];
                        [features addObject:[NSString stringWithFormat:@"%@: %d", displayKey, [defaults boolForKey:key]]];
                    }
                }
                [features sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
                [features insertObject:[NSString stringWithFormat:LOC(@"TOTAL_MODIFIED_SETTINGS"), features.count] atIndex:0];
                NSString *content = [features componentsJoinedByString:@"\n"];
                YTAlertView *alertView = [YTAlertViewClass confirmationDialogWithAction:^{
                    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                    pasteboard.string = content;
                    [[%c(GOOHUDManagerInternal) sharedInstance] showMessageMainThread:[%c(YTHUDMessage) messageWithText:LOC(@"COPIED_TO_CLIPBOARD")]];
                } actionTitle:LOC(@"COPY_TO_CLIPBOARD")];
                alertView.title = LOC(@"MODIFIED_SETTINGS_TITLE");
                alertView.subtitle = content;
                [alertView show];
                return YES;
            }];
        [sectionItems insertObject:modified atIndex:0];

        // Reset and kill
        YTSettingsSectionItem *reset = [YTSettingsSectionItemClass itemWithTitle:LOC(@"RESET_KILL")
            titleDescription:LOC(@"RESET_KILL_DESC")
            accessibilityIdentifier:nil
            detailTextBlock:nil
            selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                YTAlertView *alertView = [YTAlertViewClass confirmationDialogWithAction:^{
                    updateAllKeys();
                    for (NSString *key in allKeys) {
                        if ([key hasPrefix:Prefix])
                            [defaults removeObjectForKey:key];
                    }
                    exit(0);
                } actionTitle:yesText];
                alertView.title = LOC(@"WARNING");
                alertView.subtitle = LOC(@"APPLY_DESC");
                [alertView show];
                return YES;
            }];
        [sectionItems insertObject:reset atIndex:0];

        // Grouped settings
        YTSettingsSectionItem *group = [YTSettingsSectionItemClass switchItemWithTitle:LOC(@"GROUPED")
            titleDescription:nil
            accessibilityIdentifier:nil
            switchOn:groupedSettings()
            switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
                YTAlertView *alertView = [YTAlertViewClass confirmationDialogWithAction:^{
                        [defaults setBool:enabled forKey:GroupedKey];
                        exit(0);
                    }
                    actionTitle:yesText
                    cancelAction:^{
                        [cell setSwitchOn:!enabled animated:YES];
                        [defaults setBool:!enabled forKey:GroupedKey];
                    }
                    cancelTitle:cancelText];
                alertView.title = LOC(@"WARNING");
                alertView.subtitle = LOC(@"APPLY_DESC");
                [alertView show];
                return YES;
            }
            settingItemId:0];
        [sectionItems insertObject:group atIndex:0];
    }

    // Open megathread
    YTSettingsSectionItem *thread = [YTSettingsSectionItemClass itemWithTitle:LOC(@"OPEN_MEGATHREAD")
        titleDescription:LOC(@"OPEN_MEGATHREAD_DESC")
        accessibilityIdentifier:nil
        detailTextBlock:nil
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            return [%c(YTUIUtils) openURL:[NSURL URLWithString:@"https://github.com/PoomSmart/YTABConfig/discussions"]];
        }];
    [sectionItems insertObject:thread atIndex:0];

    // Killswitch
    YTSettingsSectionItem *master = [YTSettingsSectionItemClass switchItemWithTitle:LOC(@"ENABLED")
        titleDescription:LOC(@"ENABLED_DESC")
        accessibilityIdentifier:nil
        switchOn:tweakEnabled()
        switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
            [defaults setBool:enabled forKey:EnabledKey];
            YTAlertView *alertView = [YTAlertViewClass confirmationDialogWithAction:^{ exit(0); }
                actionTitle:yesText
                cancelAction:^{
                    [cell setSwitchOn:!enabled animated:YES];
                    [defaults setBool:!enabled forKey:EnabledKey];
                }
                cancelTitle:cancelText];
            alertView.title = LOC(@"WARNING");
            alertView.subtitle = LOC(@"APPLY_DESC");
            [alertView show];
            return YES;
        }
        settingItemId:0];
    [sectionItems insertObject:master atIndex:0];

    YTSettingsViewController *delegate = [self valueForKey:@"_dataDelegate"];
    NSString *title = @"A/B";
    NSString *titleDescription = tweakEnabled() ? [NSString stringWithFormat:@"YTABConfig %@, %d feature flags.", @(OS_STRINGIFY(TWEAK_VERSION)), totalSettings] : nil;
    if ([delegate respondsToSelector:@selector(setSectionItems:forCategory:title:icon:titleDescription:headerHidden:)])
        [delegate setSectionItems:sectionItems
            forCategory:YTABCSection
            title:title
            icon:nil
            titleDescription:titleDescription
            headerHidden:NO];
    else
        [delegate setSectionItems:sectionItems
            forCategory:YTABCSection
            title:title
            titleDescription:titleDescription
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

void SearchHook() {
    %init(Search);
}

%ctor {
    defaults = [NSUserDefaults standardUserDefaults];
    %init;
}
