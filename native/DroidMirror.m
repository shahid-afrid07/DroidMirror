#import <Cocoa/Cocoa.h>

@interface DMDevice : NSObject
@property(nonatomic, copy) NSString *serial;
@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy) NSString *state;
@property(nonatomic, copy) NSString *pairAddress;
@end
@implementation DMDevice
@end

@interface AppDelegate : NSObject <NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate>
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) NSTableView *deviceTable;
@property(nonatomic, strong) NSTextField *statusLabel;
@property(nonatomic, strong) NSView *statusDot;
@property(nonatomic, strong) NSTextField *pairAddressField;
@property(nonatomic, strong) NSSecureTextField *pairCodeField;
@property(nonatomic, strong) NSTextField *connectAddressField;
@property(nonatomic, strong) NSMutableArray<DMDevice *> *devices;
@property(nonatomic, strong) dispatch_queue_t workerQueue;
@property(nonatomic, copy) NSString *adbPath;
@property(nonatomic, copy) NSString *scrcpyPath;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSDate *> *connectionAttempts;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.devices = [NSMutableArray array];
    self.connectionAttempts = [NSMutableDictionary dictionary];
    self.workerQueue = dispatch_queue_create("dev.droidmirror.device-discovery", DISPATCH_QUEUE_SERIAL);
    self.adbPath = [self findExecutableNamed:@"adb"];
    self.scrcpyPath = [self findExecutableNamed:@"scrcpy"];
    [self buildWindow];
    [self refreshDevices:nil];
    [self scheduleRefresh];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender { return YES; }

- (NSString *)findExecutableNamed:(NSString *)name {
    NSArray<NSString *> *candidates = [name isEqualToString:@"adb"] ? @[
        @"/opt/homebrew/bin/adb", @"/usr/local/bin/adb",
        [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Android/sdk/platform-tools/adb"],
        [NSHomeDirectory() stringByAppendingPathComponent:@"Android/Sdk/platform-tools/adb"]
    ] : @[@"/opt/homebrew/bin/scrcpy", @"/usr/local/bin/scrcpy", @"/opt/local/bin/scrcpy"];
    for (NSString *path in candidates) if ([[NSFileManager defaultManager] isExecutableFileAtPath:path]) return path;
    NSString *pathEnvironment = NSProcessInfo.processInfo.environment[@"PATH"] ?: @"";
    for (NSString *directory in [pathEnvironment componentsSeparatedByString:@":"]) {
        NSString *path = [directory stringByAppendingPathComponent:name];
        if ([[NSFileManager defaultManager] isExecutableFileAtPath:path]) return path;
    }
    return nil;
}

- (void)buildWindow {
    NSRect visibleFrame = NSScreen.mainScreen.visibleFrame;
    CGFloat windowWidth = MIN(1460, visibleFrame.size.width * 0.94);
    CGFloat windowHeight = MIN(980, visibleFrame.size.height * 0.92);
    NSRect frame = NSMakeRect(0, 0, windowWidth, windowHeight);
    self.window = [[NSWindow alloc] initWithContentRect:frame
        styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable)
        backing:NSBackingStoreBuffered defer:NO];
    self.window.title = @"DroidMirror";
    self.window.minSize = NSMakeSize(MIN(1050, windowWidth), MIN(720, windowHeight));
    [self.window center];

    NSView *content = self.window.contentView;
    NSStackView *root = [NSStackView stackViewWithViews:@[]];
    root.orientation = NSUserInterfaceLayoutOrientationVertical;
    root.alignment = NSLayoutAttributeLeading;
    root.distribution = NSStackViewDistributionFill;
    root.spacing = 14;
    root.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:root];
    [NSLayoutConstraint activateConstraints:@[
        [root.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:26],
        [root.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-26],
        [root.topAnchor constraintEqualToAnchor:content.topAnchor constant:24],
        [root.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-22]
    ]];

    NSTextField *title = [NSTextField labelWithString:@"Your Android devices"];
    title.font = [NSFont systemFontOfSize:28 weight:NSFontWeightBold];
    NSTextField *subtitle = [NSTextField labelWithString:@"Mirror your phone on this Mac over Wi-Fi or a phone hotspot."];
    subtitle.textColor = NSColor.secondaryLabelColor;
    NSStackView *header = [NSStackView stackViewWithViews:@[title, subtitle]];
    header.orientation = NSUserInterfaceLayoutOrientationVertical;
    header.alignment = NSLayoutAttributeLeading;
    header.spacing = 4;
    [root addArrangedSubview:header];

    self.statusDot = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
    self.statusDot.wantsLayer = YES;
    self.statusDot.layer.cornerRadius = 5;
    self.statusDot.layer.backgroundColor = NSColor.systemOrangeColor.CGColor;
    [self.statusDot.widthAnchor constraintEqualToConstant:10].active = YES;
    [self.statusDot.heightAnchor constraintEqualToConstant:10].active = YES;
    self.statusLabel = [NSTextField labelWithString:@"Looking for Android devices…"];
    self.statusLabel.textColor = NSColor.secondaryLabelColor;
    NSButton *refreshButton = [self buttonWithTitle:@"Refresh" action:@selector(refreshDevices:)];
    NSStackView *statusRow = [NSStackView stackViewWithViews:@[self.statusDot, self.statusLabel, refreshButton]];
    statusRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    statusRow.alignment = NSLayoutAttributeCenterY;
    statusRow.distribution = NSStackViewDistributionFill;
    [self.statusLabel setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    [refreshButton setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    [root addArrangedSubview:statusRow];

    NSBox *deviceBox = [[NSBox alloc] init];
    deviceBox.title = @"Devices";
    deviceBox.boxType = NSBoxPrimary;
    deviceBox.translatesAutoresizingMaskIntoConstraints = NO;
    NSScrollView *scroll = [[NSScrollView alloc] init];
    scroll.hasVerticalScroller = YES;
    scroll.drawsBackground = NO;
    self.deviceTable = [[NSTableView alloc] init];
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"device"];
    column.title = @"Android phone";
    column.width = 800;
    column.resizingMask = NSTableColumnAutoresizingMask;
    [self.deviceTable addTableColumn:column];
    self.deviceTable.columnAutoresizingStyle = NSTableViewLastColumnOnlyAutoresizingStyle;
    self.deviceTable.headerView = nil;
    self.deviceTable.rowHeight = 42;
    self.deviceTable.delegate = self;
    self.deviceTable.dataSource = self;
    self.deviceTable.allowsEmptySelection = YES;
    scroll.documentView = self.deviceTable;
    deviceBox.contentView = scroll;
    [scroll.leadingAnchor constraintEqualToAnchor:deviceBox.contentView.leadingAnchor constant:8].active = YES;
    [scroll.trailingAnchor constraintEqualToAnchor:deviceBox.contentView.trailingAnchor constant:-8].active = YES;
    [scroll.topAnchor constraintEqualToAnchor:deviceBox.contentView.topAnchor constant:8].active = YES;
    [scroll.bottomAnchor constraintEqualToAnchor:deviceBox.contentView.bottomAnchor constant:-8].active = YES;
    [deviceBox.heightAnchor constraintGreaterThanOrEqualToConstant:440].active = YES;

    NSBox *wirelessBox = [[NSBox alloc] init];
    wirelessBox.title = @"Wireless setup";
    wirelessBox.boxType = NSBoxPrimary;
    wirelessBox.translatesAutoresizingMaskIntoConstraints = NO;
    NSView *wirelessContent = wirelessBox.contentView;
    NSTextField *instructions = [NSTextField wrappingLabelWithString:@"Phones with Wireless debugging on appear in Devices when this Mac can discover them on the same Wi-Fi or hotspot. For first pairing, open Pair device with pairing code on Android, select the phone here, enter its code, then choose Start Mirroring. Keep Wireless debugging enabled."];
    instructions.textColor = NSColor.secondaryLabelColor;
    NSTextField *pairTitle = [NSTextField labelWithString:@"Pair this Mac (first time)"];
    pairTitle.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    self.pairAddressField = [self textFieldWithPlaceholder:@"Pairing IP:port (filled after opening phone's pairing screen)"];
    self.pairCodeField = [[NSSecureTextField alloc] init];
    self.pairCodeField.placeholderString = @"Pairing code";
    self.pairCodeField.bezelStyle = NSTextFieldRoundedBezel;
    self.pairCodeField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.pairCodeField.heightAnchor constraintEqualToConstant:30].active = YES;

    NSTextField *manualTitle = [NSTextField labelWithString:@"Manual connection (if this network blocks discovery)"];
    manualTitle.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    self.connectAddressField = [self textFieldWithPlaceholder:@"Device IP:port (Wireless debugging screen)"];
    NSButton *connectButton = [self buttonWithTitle:@"Connect" action:@selector(connectManually:)];
    NSStackView *manualRow = [NSStackView stackViewWithViews:@[self.connectAddressField, connectButton]];
    manualRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    manualRow.alignment = NSLayoutAttributeCenterY;
    manualRow.spacing = 8;
    [self.connectAddressField setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    [connectButton setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];

    NSStackView *wirelessStack = [NSStackView stackViewWithViews:@[instructions, pairTitle, self.pairAddressField, self.pairCodeField, manualTitle, manualRow]];
    wirelessStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    wirelessStack.alignment = NSLayoutAttributeLeading;
    wirelessStack.distribution = NSStackViewDistributionFill;
    wirelessStack.spacing = 9;
    wirelessStack.translatesAutoresizingMaskIntoConstraints = NO;
    [wirelessContent addSubview:wirelessStack];
    [NSLayoutConstraint activateConstraints:@[
        [wirelessStack.leadingAnchor constraintEqualToAnchor:wirelessContent.leadingAnchor constant:12],
        [wirelessStack.trailingAnchor constraintEqualToAnchor:wirelessContent.trailingAnchor constant:-12],
        [wirelessStack.topAnchor constraintEqualToAnchor:wirelessContent.topAnchor constant:10],
        [wirelessStack.bottomAnchor constraintEqualToAnchor:wirelessContent.bottomAnchor constant:-10],
        [instructions.widthAnchor constraintEqualToAnchor:wirelessStack.widthAnchor],
        [self.pairAddressField.widthAnchor constraintEqualToAnchor:wirelessStack.widthAnchor],
        [self.pairCodeField.widthAnchor constraintEqualToAnchor:wirelessStack.widthAnchor],
        [manualRow.widthAnchor constraintEqualToAnchor:wirelessStack.widthAnchor]
    ]];
    NSStackView *mainRow = [NSStackView stackViewWithViews:@[deviceBox, wirelessBox]];
    mainRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    mainRow.alignment = NSLayoutAttributeTop;
    mainRow.distribution = NSStackViewDistributionFill;
    mainRow.spacing = 18;
    mainRow.translatesAutoresizingMaskIntoConstraints = NO;
    [root addArrangedSubview:mainRow];
    [mainRow.widthAnchor constraintEqualToAnchor:root.widthAnchor].active = YES;
    [deviceBox.widthAnchor constraintEqualToAnchor:mainRow.widthAnchor multiplier:0.57].active = YES;
    [wirelessBox.widthAnchor constraintEqualToAnchor:mainRow.widthAnchor multiplier:0.41].active = YES;
    [deviceBox.heightAnchor constraintEqualToAnchor:wirelessBox.heightAnchor].active = YES;
    [mainRow setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationVertical];

    NSButton *mirrorButton = [self buttonWithTitle:@"Start Mirroring" action:@selector(startMirroring:)];
    mirrorButton.bezelStyle = NSBezelStylePush;
    mirrorButton.keyEquivalent = @"\r";
    [mirrorButton setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    [mirrorButton.widthAnchor constraintEqualToConstant:180].active = YES;
    NSStackView *footer = [NSStackView stackViewWithViews:@[mirrorButton]];
    footer.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    footer.alignment = NSLayoutAttributeCenterY;
    footer.distribution = NSStackViewDistributionFill;
    [root addArrangedSubview:footer];
    [footer.widthAnchor constraintEqualToAnchor:root.widthAnchor].active = YES;

    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (NSTextField *)textFieldWithPlaceholder:(NSString *)placeholder {
    NSTextField *field = [[NSTextField alloc] init];
    field.placeholderString = placeholder;
    field.bezelStyle = NSTextFieldRoundedBezel;
    field.translatesAutoresizingMaskIntoConstraints = NO;
    [field.heightAnchor constraintEqualToConstant:30].active = YES;
    return field;
}

- (NSButton *)buttonWithTitle:(NSString *)title action:(SEL)action {
    NSButton *button = [NSButton buttonWithTitle:title target:self action:action];
    button.bezelStyle = NSBezelStyleRounded;
    return button;
}

- (void)setStatus:(NSString *)message color:(NSColor *)color {
    self.statusLabel.stringValue = message;
    self.statusLabel.textColor = NSColor.secondaryLabelColor;
    self.statusDot.layer.backgroundColor = color.CGColor;
}

- (NSString *)runExecutable:(NSString *)path arguments:(NSArray<NSString *> *)arguments error:(NSString **)errorText {
    if (path.length == 0) { if (errorText) *errorText = @"Required command was not found."; return @""; }
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:path];
    task.arguments = arguments;
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    task.standardError = pipe;
    NSMutableDictionary *environment = [NSProcessInfo.processInfo.environment mutableCopy];
    NSString *directory = [path stringByDeletingLastPathComponent];
    NSString *existing = environment[@"PATH"] ?: @"/usr/bin:/bin:/usr/sbin:/sbin";
    environment[@"PATH"] = [NSString stringWithFormat:@"%@:/opt/homebrew/bin:/usr/local/bin:%@", directory, existing];
    task.environment = environment;
    NSError *launchError = nil;
    if (![task launchAndReturnError:&launchError]) {
        if (errorText) *errorText = launchError.localizedDescription;
        return @"";
    }
    NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
    [task waitUntilExit];
    NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
    if (task.terminationStatus != 0 && errorText) *errorText = output.length ? output : @"Command failed.";
    return [output stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

- (void)refreshDevices:(id)sender {
    if (self.adbPath.length == 0 || self.scrcpyPath.length == 0) {
        NSMutableArray<NSString *> *missing = [NSMutableArray array];
        if (self.adbPath.length == 0) [missing addObject:@"Android Platform Tools (adb)"];
        if (self.scrcpyPath.length == 0) [missing addObject:@"scrcpy"];
        [self setStatus:[NSString stringWithFormat:@"Not found: %@. Install it, then reopen DroidMirror.", [missing componentsJoinedByString:@" and "]] color:NSColor.systemRedColor];
        return;
    }
    [self setStatus:@"Looking for Android devices on Wi-Fi…" color:NSColor.systemOrangeColor];
    dispatch_async(self.workerQueue, ^{
        [self discoverAndConnect];
        NSArray<DMDevice *> *connected = [self readDevices];
        NSMutableArray<DMDevice *> *found = [connected mutableCopy];
        [found addObjectsFromArray:[self readNearbyWirelessDevicesExcluding:connected]];
        dispatch_async(dispatch_get_main_queue(), ^{
            NSInteger selectedRow = self.deviceTable.selectedRow;
            [self.devices setArray:found];
            [self.deviceTable reloadData];
            if (selectedRow >= 0 && selectedRow < (NSInteger)found.count) {
                DMDevice *selectedDevice = found[(NSUInteger)selectedRow];
                if ([selectedDevice.state isEqualToString:@"available"] && selectedDevice.pairAddress.length > 0) {
                    self.pairAddressField.stringValue = selectedDevice.pairAddress;
                }
            }
            if (found.count == 0) [self setStatus:@"No phone found. Turn on Wireless debugging and use the same Wi-Fi or hotspot." color:NSColor.systemOrangeColor];
            else {
                NSUInteger readyCount = 0;
                for (DMDevice *device in connected) if ([device.state isEqualToString:@"device"]) readyCount++;
                if (readyCount > 0) [self setStatus:[NSString stringWithFormat:@"ADB connected · %lu phone%@ ready", (unsigned long)readyCount, readyCount == 1 ? @"" : @"s"] color:NSColor.systemGreenColor];
                else if (connected.count > 0) [self setStatus:@"ADB sees the phone. Allow debugging access on Android." color:NSColor.systemOrangeColor];
                else [self setStatus:@"Phone available · select it and enter its pairing code once." color:NSColor.systemOrangeColor];
            }
        });
    });
}

- (void)scheduleRefresh {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self refreshDevices:nil];
        [self scheduleRefresh];
    });
}

- (void)discoverAndConnect {
    if (self.adbPath.length == 0) return;
    NSString *services = [self runExecutable:self.adbPath arguments:@[@"mdns", @"services"] error:nil];
    for (NSString *line in [services componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
        if ([line rangeOfString:@"_adb-tls-connect._tcp"].location == NSNotFound) continue;
        NSArray<NSString *> *parts = [line componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSMutableArray<NSString *> *fields = [NSMutableArray array];
        for (NSString *part in parts) if (part.length) [fields addObject:part];
        NSString *endpoint = fields.lastObject;
        if (![endpoint containsString:@":"]) continue;
        NSDate *last = self.connectionAttempts[endpoint];
        if (last && [[NSDate date] timeIntervalSinceDate:last] < 20) continue;
        self.connectionAttempts[endpoint] = [NSDate date];
        [self runExecutable:self.adbPath arguments:@[@"connect", endpoint] error:nil];
    }
}

- (NSArray<DMDevice *> *)readDevices {
    NSString *output = [self runExecutable:self.adbPath arguments:@[@"devices", @"-l"] error:nil];
    NSMutableArray<DMDevice *> *result = [NSMutableArray array];
    for (NSString *line in [output componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
        NSArray<NSString *> *parts = [line componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSMutableArray<NSString *> *fields = [NSMutableArray array];
        for (NSString *part in parts) if (part.length) [fields addObject:part];
        if (fields.count < 2 || (![fields[1] isEqualToString:@"device"] && ![fields[1] isEqualToString:@"unauthorized"])) continue;
        DMDevice *device = [[DMDevice alloc] init];
        device.serial = fields[0];
        device.state = fields[1];
        device.name = device.serial;
        for (NSString *field in fields) if ([field hasPrefix:@"model:"]) device.name = [[field substringFromIndex:6] stringByReplacingOccurrencesOfString:@"_" withString:@" "];
        [result addObject:device];
    }
    return result;
}

- (NSArray<DMDevice *> *)readNearbyWirelessDevicesExcluding:(NSArray<DMDevice *> *)connectedDevices {
    NSString *services = [self runExecutable:self.adbPath arguments:@[@"mdns", @"services"] error:nil];
    NSMutableSet<NSString *> *connectedHosts = [NSMutableSet set];
    for (DMDevice *device in connectedDevices) {
        if (![device.state isEqualToString:@"device"]) continue;
        NSString *host = [[device.serial componentsSeparatedByString:@":"] firstObject];
        if (host.length) [connectedHosts addObject:host];
    }

    NSMutableArray<DMDevice *> *available = [NSMutableArray array];
    NSMutableDictionary<NSString *, DMDevice *> *devicesByHost = [NSMutableDictionary dictionary];
    for (NSString *line in [services componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
        BOOL pairingService = [line rangeOfString:@"_adb-tls-pairing._tcp"].location != NSNotFound;
        BOOL connectService = [line rangeOfString:@"_adb-tls-connect._tcp"].location != NSNotFound;
        if (!pairingService && !connectService) continue;
        NSArray<NSString *> *parts = [line componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSMutableArray<NSString *> *fields = [NSMutableArray array];
        for (NSString *part in parts) if (part.length) [fields addObject:part];
        if (fields.count < 3) continue;
        NSString *instance = fields[0];
        NSString *endpoint = fields.lastObject;
        if (![endpoint containsString:@":"]) continue;
        NSString *host = [[endpoint componentsSeparatedByString:@":"] firstObject];
        if ([connectedHosts containsObject:host]) continue;

        DMDevice *device = devicesByHost[host];
        if (!device) {
            device = [[DMDevice alloc] init];
            device.serial = [NSString stringWithFormat:@"nearby:%@", host];
            device.name = @"Android phone";
            device.state = @"available";
            devicesByHost[host] = device;
            [available addObject:device];
        }
        if (pairingService) device.pairAddress = endpoint;
        // The instance name is the only friendly identifier exposed by `adb mdns services`.
        if (instance.length && [device.name isEqualToString:@"Android phone"]) device.name = instance;
    }
    return available;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSInteger row = self.deviceTable.selectedRow;
    if (row < 0 || row >= (NSInteger)self.devices.count) return;
    DMDevice *device = self.devices[(NSUInteger)row];
    if ([device.state isEqualToString:@"available"] && device.pairAddress.length > 0) {
        self.pairAddressField.stringValue = device.pairAddress;
        [self setStatus:@"Pairing service found · enter the phone's code, then Start Mirroring." color:NSColor.systemOrangeColor];
    } else if ([device.state isEqualToString:@"available"]) {
        [self setStatus:@"Phone found · open Pair device with pairing code on Android." color:NSColor.systemOrangeColor];
    }
}

- (void)connectManually:(id)sender {
    NSString *endpoint = [self.connectAddressField.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (endpoint.length == 0) { [self setStatus:@"Enter the device IP address and port." color:NSColor.systemOrangeColor]; return; }
    dispatch_async(self.workerQueue, ^{
        NSString *error = nil;
        NSString *result = [self runExecutable:self.adbPath arguments:@[@"connect", endpoint] error:&error];
        NSArray<DMDevice *> *found = [self readDevices];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.devices setArray:found];
            [self.deviceTable reloadData];
            BOOL connected = NO;
            for (DMDevice *device in found) if ([device.state isEqualToString:@"device"]) { connected = YES; break; }
            if (error.length) [self setStatus:error color:NSColor.systemRedColor];
            else if (connected) [self setStatus:result.length ? result : @"ADB connected." color:NSColor.systemGreenColor];
            else [self setStatus:result.length ? result : @"No ADB device yet. Check the IP:port and Wireless debugging." color:NSColor.systemOrangeColor];
        });
    });
}

- (void)startMirroring:(id)sender {
    if (self.adbPath.length == 0 || self.scrcpyPath.length == 0) { [self refreshDevices:nil]; return; }
    NSString *address = [self.pairAddressField.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *code = [self.pairCodeField.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSInteger selectedRow = self.deviceTable.selectedRow;
    if (code.length == 0 && (selectedRow < 0 || selectedRow >= (NSInteger)self.devices.count)) {
        NSInteger onlyConnectedRow = -1;
        NSUInteger connectedCount = 0;
        for (NSUInteger i = 0; i < self.devices.count; i++) {
            if ([self.devices[i].state isEqualToString:@"device"]) { onlyConnectedRow = (NSInteger)i; connectedCount++; }
        }
        if (connectedCount == 1) {
            selectedRow = onlyConnectedRow;
            [self.deviceTable selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)selectedRow] byExtendingSelection:NO];
        } else if (connectedCount > 1) {
            [self setStatus:@"Select the Android phone you want to mirror." color:NSColor.systemOrangeColor];
            return;
        }
    }
    if (code.length == 0 && selectedRow >= 0 && selectedRow < (NSInteger)self.devices.count && [self.devices[(NSUInteger)selectedRow].state isEqualToString:@"available"]) {
        [self setStatus:@"Enter the pairing code shown on the selected Android phone, then Start Mirroring." color:NSColor.systemOrangeColor];
        return;
    }
    if (code.length == 0 && (selectedRow < 0 || selectedRow >= (NSInteger)self.devices.count)) {
        [self setStatus:@"Enter the pairing address and code, or select an already connected phone." color:NSColor.systemOrangeColor];
        return;
    }
    if (code.length > 0 && address.length == 0) {
        [self setStatus:@"Open Pair device with pairing code on Android and select the phone to fill its address." color:NSColor.systemOrangeColor];
        return;
    }
    [self setStatus:code.length ? @"Pairing, connecting ADB, then starting scrcpy…" : @"Starting scrcpy…" color:NSColor.systemOrangeColor];
    dispatch_async(self.workerQueue, ^{
        NSString *pairError = nil;
        if (code.length > 0) {
            NSString *pairResult = [self runExecutable:self.adbPath arguments:@[@"pair", address, code] error:&pairError];
            if (pairError.length > 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.pairCodeField.stringValue = @"";
                    [self setStatus:[NSString stringWithFormat:@"Pair failed: %@", pairError] color:NSColor.systemRedColor];
                });
                return;
            }
            [self discoverAndConnect];
        }
        NSArray<DMDevice *> *found = @[];
        for (NSUInteger attempt = 0; attempt < (code.length > 0 ? 10 : 1); attempt++) {
            found = [self readDevices];
            DMDevice *ready = nil;
            for (DMDevice *candidate in found) if ([candidate.state isEqualToString:@"device"]) { ready = candidate; break; }
            if (ready) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.pairCodeField.stringValue = @"";
                    [self.devices setArray:found];
                    [self.deviceTable reloadData];
                    NSUInteger row = [found indexOfObject:ready];
                    [self.deviceTable selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
                    [self setStatus:[NSString stringWithFormat:@"ADB connected · %@", ready.name] color:NSColor.systemGreenColor];
                    [self launchScrcpyForDevice:ready];
                });
                return;
            }
            if (attempt + 1 < (code.length > 0 ? 10 : 1)) { [self discoverAndConnect]; sleep(1); }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (code.length > 0) self.pairCodeField.stringValue = @"";
            [self.devices setArray:found];
            [self.deviceTable reloadData];
            [self setStatus:code.length ? @"Paired, but ADB did not connect. Check Wi-Fi, Wireless debugging, and mDNS." : @"ADB is not connected. Select a phone or enter its Device IP:port below." color:NSColor.systemOrangeColor];
        });
    });
}

- (void)launchScrcpyForDevice:(DMDevice *)device {
    if ([device.state isEqualToString:@"unauthorized"]) { [self setStatus:@"Allow the debugging prompt on Android." color:NSColor.systemOrangeColor]; return; }
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:self.scrcpyPath];
    task.arguments = @[
        @"--serial", device.serial,
        @"--window-title", [NSString stringWithFormat:@"DroidMirror — %@", device.name],
        @"--max-size=1600",
        @"--max-fps=30",
        @"--video-bit-rate=4M",
        @"--audio-buffer=100"
    ];
    NSMutableDictionary *environment = [NSProcessInfo.processInfo.environment mutableCopy];
    NSString *adbDirectory = [self.adbPath stringByDeletingLastPathComponent];
    environment[@"PATH"] = [NSString stringWithFormat:@"%@:/opt/homebrew/bin:/usr/local/bin:%@", adbDirectory, environment[@"PATH"] ?: @"/usr/bin:/bin:/usr/sbin:/sbin"];
    task.environment = environment;
    task.standardOutput = [NSFileHandle fileHandleWithNullDevice];
    task.standardError = [NSFileHandle fileHandleWithNullDevice];
    NSError *error = nil;
    if ([task launchAndReturnError:&error]) [self setStatus:[NSString stringWithFormat:@"ADB connected · mirroring %@ in the scrcpy window.", device.name] color:NSColor.systemGreenColor];
    else [self setStatus:[NSString stringWithFormat:@"Could not start scrcpy: %@", error.localizedDescription] color:NSColor.systemRedColor];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView { return self.devices.count; }

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSTableCellView *cell = [tableView makeViewWithIdentifier:@"deviceCell" owner:self];
    if (!cell) {
        cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, tableColumn.width, 42)];
        cell.identifier = @"deviceCell";
        NSTextField *text = [NSTextField labelWithString:@""];
        text.translatesAutoresizingMaskIntoConstraints = NO;
        [cell addSubview:text];
        cell.textField = text;
        [NSLayoutConstraint activateConstraints:@[
            [text.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:10],
            [text.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-10],
            [text.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor]
        ]];
    }
    DMDevice *device = self.devices[(NSUInteger)row];
    if ([device.state isEqualToString:@"available"]) {
        NSString *availability = device.pairAddress.length ? @"Ready to pair" : @"Wireless debugging on";
        cell.textField.stringValue = [NSString stringWithFormat:@"%@     %@     %@", device.name, device.pairAddress.length ? device.pairAddress : device.serial, availability];
        cell.textField.textColor = NSColor.systemOrangeColor;
    } else {
        cell.textField.stringValue = [NSString stringWithFormat:@"%@     %@     %@", device.name, device.serial, [device.state isEqualToString:@"device"] ? @"Connected" : @"Allow access on phone"];
        cell.textField.textColor = [device.state isEqualToString:@"device"] ? NSColor.labelColor : NSColor.systemOrangeColor;
    }
    return cell;
}

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        application.activationPolicy = NSApplicationActivationPolicyRegular;
        AppDelegate *delegate = [[AppDelegate alloc] init];
        application.delegate = delegate;
        [application run];
    }
    return 0;
}
