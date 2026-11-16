
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const os = require('os');
const express = require('express')
const { detect } = require('detect-port')
const spawn = require('child_process').spawn;

const remoteMain = require('@electron/remote/main');
remoteMain.initialize();

function getInstanceLockFilePath(appFilesPath) {
    // Create a hash of the app files path to use in the lock file name
    const hash = crypto.createHash('md5').update(appFilesPath).digest('hex');
    const ceramicDir = path.join(os.homedir(), '.ceramic');

    // Ensure .ceramic directory exists
    if (!fs.existsSync(ceramicDir)) {
        fs.mkdirSync(ceramicDir, { recursive: true });
    }

    return path.join(ceramicDir, `electron-${hash}.lock`);
}

function setupInstanceManager(appFilesPath) {
    const lockFile = getInstanceLockFilePath(appFilesPath);

    // Touch the lock file to signal our presence
    fs.writeFileSync(lockFile, String(process.pid), 'utf8');

    // Watch for changes to the lock file
    fs.watchFile(lockFile, { interval: 1000 }, (curr, prev) => {
        if (curr.mtime > prev.mtime) {
            console.log('New instance detected, shutting down...');
            app.quit();
        }
    });

    // Clean up on exit
    app.on('will-quit', () => {
        fs.unwatchFile(lockFile);
        try {
            if (fs.readFileSync(lockFile, 'utf8') === String(process.pid)) {
                fs.unlinkSync(lockFile);
            }
        } catch (err) {
            console.error('Error cleaning up lock file:', err);
        }
    });
}

// Electron
const electron = require('electron');
// Module to control application life.
const app = electron.app;
// Module to create native browser window.
const BrowserWindow = electron.BrowserWindow;
// Menu
const Menu = electron.Menu;
const MenuItem = electron.MenuItem;

const appName = 'Ceramic Runner';

let appUrl = null;
let appFiles = null;
let watchFile = null;
let useNativeBridge = false;
let screenshotDelay = 0;
let screenshotPath = null;
let screenshotThenQuit = false;
let keepHidden = false;
let screenshotOnSignal = false;
let forcedDeviceScaleFactor = false;

var argv = process.argv.slice();
var i = 0;
while (i < argv.length) {
    var arg = argv[i];
    if (arg == '--app-files') {
        i++;
        appFiles = argv[i];
    }
    if (arg == '--watch') {
        i++;
        watchFile = argv[i];
    }
    if (arg == '--native-bridge') {
        useNativeBridge = true;
    }
    if (arg == '--screenshot') {
        i++;
        screenshotPath = argv[i];
    }
    if (arg == '--screenshot-delay') {
        i++;
        screenshotDelay = parseFloat(argv[i]);
    }
    if (arg == '--screenshot-then-quit') {
        screenshotThenQuit = true;
    }
    if (arg == '--hidden') {
        // Keep the window hidden (offscreen): useful for automated screenshot
        // capture without a window popping up. Paired with --screenshot[-then-quit].
        keepHidden = true;
    }
    if (arg == '--screenshot-on-signal') {
        // Don't screenshot on a timer; wait for the app to call exports.takeScreenshot()
        // (deterministic: the app fires it once its scene is actually ready/rendered).
        screenshotOnSignal = true;
    }
    if (arg.startsWith('--force-device-scale-factor')) {
        // Chromium switch added by `ceramic web --device-scale-factor <factor>`
        forcedDeviceScaleFactor = true;
    }
    i++;
}

// Automated run (hidden window, screenshot capture or fixed device scale factor):
// its result must not depend on what earlier runs left behind. Chromium stores the
// page zoom per host ("localhost", whatever the port) in the runner profile, and every app served
// by the runner shares it, so a zoom set by one run would change the device pixel
// ratio of the next ones. Such runs use an in-memory session (nothing they do is
// saved, nothing saved is read back) and start at zoom 1. Interactive runs keep
// the default persistent session, so a developer's own zoom stays as it is.
const automatedRun = keepHidden || screenshotPath != null || forcedDeviceScaleFactor;

// The window options kept between launches (title bar, frame) are not used by
// automated runs, unless CERAMIC_RUNNER_WINDOW_OPTIONS is set (to check them
// in a hidden run, with a home folder of its own)
const keepWindowOptions = !automatedRun || !!process.env.CERAMIC_RUNNER_WINDOW_OPTIONS;

if (appFiles == null) {
    console.error('Missing app files path (use --app-files /your/files/dir)');
    process.exit(0);
}
if (!fs.existsSync(appFiles)) {
    console.error('Invalid app files path: ' + appFiles);
    process.exit(1);
}

// Set up instance management immediately after validating appFiles
setupInstanceManager(appFiles);

// Set cwd to appFiles
process.chdir(appFiles);

// App icon
if (process.platform == 'darwin') {
    app.dock.setIcon(path.join(__dirname, 'resources/AppIcon-mac.png'));
}

// App flags
app.commandLine.appendSwitch('force_high_performance_gpu');

// App name
app.setName(appName);
exports.app = app;
exports.Menu = Menu;
exports.MenuItem = MenuItem;
exports.electronDev = process.env.ELECTRON_DEV;
exports.dirname = __dirname;
exports.isCeramicRunner = true;
exports.appFiles = appFiles;

// Keep a global reference of the window object, if you don't, the window will
// be closed automatically when the JavaScript object is garbage collected.
let mainWindow;
exports.mainWindow = null;

// The options of the window that only apply when it is created (the title bar
// and the frame): the app gives them with its settings once its page is loaded,
// so they are kept for the next launch, and a window created with other ones
// is created again before it is shown (see ceramicSettings)
const windowOptionsPath = function() {
    return path.join(app.getPath('userData'), 'ceramic-window.json');
};

function readWindowOptions() {
    try {
        return JSON.parse(fs.readFileSync(windowOptionsPath(), 'utf8'));
    }
    catch (e) {
        return {};
    }
}

function writeWindowOptions(options) {
    try {
        fs.writeFileSync(windowOptionsPath(), JSON.stringify(options), 'utf8');
    }
    catch (e) {
        console.error('Failed to save the window options: ' + e);
    }
}

function sameWindowOptions(a, b) {
    return !!a.overlay == !!b.overlay && !!a.borderless == !!b.borderless
        && (a.buttonsX|0) == (b.buttonsX|0) && (a.buttonsY|0) == (b.buttonsY|0);
}

// The options the current window was created with
let createdWindowOptions = null;

// Whether the window was created again for its options (once per launch)
let windowRecreated = false;

// Whether the window was shown (ceramicReady)
let windowShown = false;

function createWindow() {

    if (appUrl == null) {
        setTimeout(createWindow, 100);
        return;
    }

    if (mainWindow != null) return;

    // Create the browser window.
    var windowOptions = {
        width: 1024,
        height: 768,
        show: false,
        minWidth: 64,
        minHeight: 64,
        resizable: true,
        fullscreenable: true,
        movable: true,
        title: appName,
        backgroundColor: '#000000',
        icon: path.join(__dirname, 'resources/AppIcon.png'),
        webPreferences: {
            webSecurity: false,
            nodeIntegration: true,
            contextIsolation: false
        }
    };

    if (automatedRun) {
        // No `persist:` prefix: an in-memory session, dropped when the runner quits
        windowOptions.webPreferences.partition = 'ceramic-automated-run';
        windowOptions.webPreferences.zoomFactor = 1.0;
    }

    // Title bar and frame (kept from the app's last settings)
    if (!keepWindowOptions) {
        // An automated run does not depend on what earlier runs left behind
        createdWindowOptions = {};
    }
    else if (createdWindowOptions == null) {
        createdWindowOptions = readWindowOptions();
    }
    applyCreationOptions(windowOptions, createdWindowOptions);

    if (keepHidden) {
        // Window stays offscreen (`--hidden`): keep painting so capturePage()
        // still produces a valid frame, and don't throttle rendering when hidden.
        windowOptions.paintWhenInitiallyHidden = true;
        windowOptions.webPreferences.backgroundThrottling = false;
    }

    mainWindow = new BrowserWindow(windowOptions);
    remoteMain.enable(mainWindow.webContents);
    exports.mainWindow = mainWindow;

    /*mainWindow.webContents.on('did-finish-load', function() {
        mainWindow.show();
    });*/

    if (automatedRun) {
        // Start every page load at zoom 1, whatever the session holds for this host
        // (a zoom the app sets itself after loading still applies)
        mainWindow.webContents.on('did-finish-load', function() {
            if (mainWindow != null && mainWindow.webContents.getZoomFactor() != 1) {
                mainWindow.webContents.setZoomFactor(1);
            }
        });
    }

    // and load the index.html of the app.
    mainWindow.loadURL(appUrl);

    // Open the DevTools.
    //mainWindow.webContents.openDevTools()

    // Open links in the OS default browser
    mainWindow.webContents.setWindowOpenHandler(( { url }) => {
	electron.shell.openExternal(url);
	return { action : 'deny' };
    });

    // Emitted when the window is closed.
    const createdWindow = mainWindow;
    mainWindow.on('closed', function() {
        // Dereference the window object (unless another window replaced it:
        // see ceramicSettings)
        if (mainWindow === createdWindow) {
            mainWindow = null;
            exports.mainWindow = null;
        }
    });
}

// The options of `options` (see readWindowOptions) in the options of a new BrowserWindow
function applyCreationOptions(windowOptions, options) {
    if (options.overlay && process.platform == 'darwin') {
        // The content goes under the title bar, which has no title and keeps
        // the traffic lights (the overlay title bar of native builds)
        windowOptions.titleBarStyle = 'hidden';
        if (options.buttonsX >= 0 && options.buttonsY >= 0) {
            windowOptions.trafficLightPosition = { x: options.buttonsX, y: options.buttonsY };
        }
    }
    else if (options.borderless) {
        // No system frame (the app draws its own window buttons)
        windowOptions.frame = false;
    }
}

// This method will be called when Electron has finished
// initialization and is ready to create browser windows.
// Some APIs can only be used after this event occurs.
app.on('ready', createWindow);

// Quit when all windows are closed.
app.on('window-all-closed', function() {
    app.quit();
});

app.on('activate', function() {
    // On OS X it's common to re-create a window in the app when the
    // dock icon is clicked and there are no other windows open.
    if (mainWindow === null) {
        createWindow();
    }
});

// Handle ceramic app settings and events
//

// Whether the app window is resizable, from ceramic settings.
// (the window itself can't tell: it is reported as not resizable while fullscreen)
var windowResizable = true;

exports.ceramicSettings = function(settings) {

    settings.trace('settings.targetWidth=' + settings.targetWidth);
    settings.trace('settings.targetHeight=' + settings.targetHeight);
    settings.trace('settings.title=' + settings.title);
    settings.trace('settings.resizable=' + settings.resizable);
    settings.trace('settings.fullscreen=' + settings.fullscreen);

    windowResizable = !!settings.resizable;

    // The title bar and the frame are options of the window's creation: the
    // window is created again (still hidden) when it was made with other ones,
    // and they are kept for the next launch
    var wanted = {
        overlay: settings.titleBarStyle == 1,
        buttonsX: settings.trafficLightX,
        buttonsY: settings.trafficLightY,
        borderless: !!settings.borderless
    };
    if (keepWindowOptions) {
        writeWindowOptions(wanted);
    }
    if (keepWindowOptions && !windowShown && !windowRecreated && !sameWindowOptions(wanted, createdWindowOptions)) {
        windowRecreated = true;
        if (process.env.CERAMIC_RUNNER_DEBUG) {
            console.log('runner window created again: ' + JSON.stringify(createdWindowOptions) + ' -> ' + JSON.stringify(wanted));
        }
        createdWindowOptions = wanted;
        var previous = mainWindow;
        mainWindow = null;
        exports.mainWindow = null;
        // The page of the new window gives its settings again. The former
        // window goes once this call (made by its page) has returned
        createWindow();
        setTimeout(function() {
            if (!previous.isDestroyed()) previous.destroy();
        }, 0);
        return;
    }

    mainWindow.setTitle(settings.title);
    mainWindow.setResizable(windowResizable);
    mainWindow.setFullScreenable(windowResizable);

    if (settings.fullscreen) {
        // We delay this call so that before setting window fullscreen,
        // Windowed version is set to target width & height
        setTimeout(function() {
            mainWindow.setFullScreen(true);
        }, 100);
    }

    if (process.platform == 'win32' || process.platform == 'linux') {
        mainWindow.removeMenu();
    }

    var targetWidth = settings.targetWidth;
    var targetHeight = settings.targetHeight;
    // if (process.platform == 'win32') {
    //     // Somehow, setContentSize() is not working as expected on windows,
    //     // so we are doing some hacky hardcoded magic instead :(
    //     targetWidth += 8;
    //     targetHeight += 93;
    //     mainWindow.setSize(targetWidth, targetHeight, false);
    // }
    // else {
        mainWindow.setContentSize(targetWidth, targetHeight, false);
    // }

    if (settings.minWidth > 0 || settings.minHeight > 0) {
        mainWindow.setMinimumSize(Math.max(64, settings.minWidth|0), Math.max(64, settings.minHeight|0));
    }

    if (settings.windowX != null && settings.windowY != null && settings.windowX >= 0 && settings.windowY >= 0) {
        // The position the app restores (kept inside the work area of its display)
        var area = electron.screen.getDisplayMatching({ x: settings.windowX, y: settings.windowY, width: targetWidth, height: targetHeight }).workArea;
        var x = Math.min(Math.max(settings.windowX, area.x), Math.max(area.x, area.x + area.width - targetWidth));
        var y = Math.min(Math.max(settings.windowY, area.y), Math.max(area.y, area.y + area.height - targetHeight));
        mainWindow.setPosition(Math.round(x), Math.round(y), false);
    }
    else {
        mainWindow.center();
    }
};

// Capture the window (webContents.capturePage) to the configured screenshot path,
// then quit if requested. Exported so the ceramic app can trigger it on demand
// (deterministic timing), via the @electron/remote bridge: electronRunner.takeScreenshot().
// CERAMIC_RUNNER_DEBUG set: prints what the app gave the window (its menu bar,
// its drag regions) when the screenshot is taken, for automated checks
function printWindowDebug(done) {
    if (!process.env.CERAMIC_RUNNER_DEBUG || mainWindow == null) {
        done();
        return;
    }
    function describe(menu, depth) {
        var lines = [];
        for (var i = 0; i < menu.items.length; i++) {
            var item = menu.items[i];
            var text = new Array(depth + 1).join('  ') + (item.type == 'separator' ? '-' : item.label);
            if (item.accelerator) text += ' [' + item.accelerator + ']';
            if (item.role) text += ' role=' + item.role;
            if (item.enabled === false) text += ' disabled';
            lines.push(text);
            if (item.submenu != null) lines = lines.concat(describe(item.submenu, depth + 1));
        }
        return lines;
    }
    var menu = Menu.getApplicationMenu();
    console.log('runner menu:\n' + (menu != null ? describe(menu, 1).join('\n') : '  (none)'));
    console.log('runner window: ' + JSON.stringify(createdWindowOptions) + ' minimum=' + JSON.stringify(mainWindow.getMinimumSize()));
    mainWindow.webContents.executeJavaScript(
        "(function() { var el = document.getElementById('ceramic-drag-regions'); if (el == null) return '(none)';" +
        " var out = []; for (var i = 0; i < el.children.length; i++) { var c = el.children[i];" +
        " out.push(c.style.getPropertyValue('-webkit-app-region') + ' ' + c.style.left + ',' + c.style.top + ' ' + c.style.width + 'x' + c.style.height); }" +
        " var canvas = document.getElementById('app'); for (var j = 0; j < el.children.length; j++) { var h = el.children[j];" +
        " if (h.style.getPropertyValue('-webkit-app-region') != 'no-drag') continue;" +
        " var x = parseFloat(h.style.left) + parseFloat(h.style.width) / 2, y = parseFloat(h.style.top) + parseFloat(h.style.height) / 2;" +
        " out.push('click at ' + x + ',' + y + ' reaches ' + (document.elementFromPoint(x, y) == canvas ? 'the canvas' : 'another element')); }" +
        " return out.join('\\n'); })()"
    ).then(function(regions) {
        console.log('runner drag regions:\n' + regions);
        done();
    }).catch(function(e) {
        console.log('runner drag regions: ' + e);
        done();
    });
}

function takeScreenshot() {
    if (screenshotPath == null || mainWindow == null) return;
    printWindowDebug(captureWindow);
}

function captureWindow() {
    if (screenshotPath == null || mainWindow == null) return;
    console.log("Take screenshot at path: " + screenshotPath);
    mainWindow.webContents.capturePage().then(function(image) {
        fs.writeFile(screenshotPath, image.toPNG(), function(err) {
            if (err)
                console.error(err);
            if (screenshotThenQuit) {
                app.quit();
            }
        });
    });
}
exports.takeScreenshot = takeScreenshot;

exports.ceramicReady = function() {
    windowShown = true;
    if (!keepHidden) {
        mainWindow.show();
    }

    // Screenshot on a fixed timer, UNLESS --screenshot-on-signal: then the app
    // calls exports.takeScreenshot() itself once its scene is ready.
    if (screenshotPath != null && !screenshotOnSignal) {
        setTimeout(takeScreenshot, 100 + screenshotDelay * 1000);
    }
};

exports.consoleLog = function(str) {
    console.log(str);
};

exports.setFullscreen = function(fullscreen) {
    if (fullscreen) {
        mainWindow.setFullScreenable(true);
        mainWindow.setFullScreen(true);
    }
    else {
        if (mainWindow.isFullScreen()) {
            // Restore the fullscreenable state once the window has left fullscreen:
            // changing it before would prevent the window from leaving fullscreen
            mainWindow.once('leave-full-screen', function() {
                mainWindow.setFullScreenable(windowResizable);
            });
            mainWindow.setFullScreen(false);
        }
        else {
            mainWindow.setFullScreenable(windowResizable);
        }
    }
};

// Resize the window so that its content gets the given size.
// Returns true if the window is changing size (or will when leaving fullscreen).
var pendingWindowSize = null;
exports.setWindowSize = function(width, height) {
    if (mainWindow == null || !(width > 0) || !(height > 0)) return false;

    if (mainWindow.isFullScreen()) {
        // Can't resize when fullscreen: apply the size when leaving it
        if (pendingWindowSize == null) {
            mainWindow.once('leave-full-screen', function() {
                var size = pendingWindowSize;
                pendingWindowSize = null;
                if (size != null) {
                    exports.setWindowSize(size[0], size[1]);
                }
            });
        }
        pendingWindowSize = [width, height];
        return true;
    }

    if (mainWindow.isMaximized()) {
        mainWindow.unmaximize();
    }

    var size = mainWindow.getContentSize();
    if (size[0] == width && size[1] == height) return false;

    mainWindow.setContentSize(width, height, false);
    return true;
};

exports.listenFullscreen = function(enterFullscreen, leaveFullscreen) {
    mainWindow.on('enter-full-screen', enterFullscreen);
    mainWindow.on('leave-full-screen', leaveFullscreen);
};

// Window buttons drawn by the app (borderless windows)
//

exports.minimizeWindow = function() {
    if (mainWindow != null) mainWindow.minimize();
};

exports.maximizeWindow = function() {
    if (mainWindow != null) mainWindow.maximize();
};

exports.restoreWindow = function() {
    if (mainWindow != null) {
        if (mainWindow.isMaximized()) mainWindow.unmaximize();
        else if (mainWindow.isMinimized()) mainWindow.restore();
    }
};

exports.isWindowMaximized = function() {
    return mainWindow != null && mainWindow.isMaximized();
};

exports.getWindowPosition = function() {
    return mainWindow != null ? mainWindow.getPosition() : [0, 0];
};

// Moves the window (desktop coordinates), kept inside the work area of its
// display. Returns true when the window moved.
exports.setWindowPosition = function(x, y) {
    if (mainWindow == null) return false;
    var size = mainWindow.getSize();
    var area = electron.screen.getDisplayMatching({ x: x, y: y, width: size[0], height: size[1] }).workArea;
    x = Math.round(Math.min(Math.max(x, area.x), Math.max(area.x, area.x + area.width - size[0])));
    y = Math.round(Math.min(Math.max(y, area.y), Math.max(area.y, area.y + area.height - size[1])));
    var current = mainWindow.getPosition();
    if (current[0] == x && current[1] == y) return false;
    mainWindow.setPosition(x, y, false);
    return true;
};

// Called with the position of the window when it moves
exports.listenMove = function(callback) {
    if (mainWindow == null) return;
    mainWindow.on('move', function() {
        var position = mainWindow.getPosition();
        callback(position[0], position[1]);
    });
};

exports.setMinimumSize = function(width, height) {
    if (mainWindow != null && (width > 0 || height > 0)) {
        mainWindow.setMinimumSize(Math.max(64, width|0), Math.max(64, height|0));
    }
};

exports.closeWindow = function() {
    if (mainWindow != null) mainWindow.close();
};

// Called with true or false when the window is maximized or restored
exports.listenMaximize = function(callback) {
    if (mainWindow == null) return;
    mainWindow.on('maximize', function() { callback(true); });
    mainWindow.on('unmaximize', function() { callback(false); });
};

// Moves the traffic lights of an overlay title bar (macOS): left of the close
// button and top of the buttons, from the top left corner of the window
exports.setTrafficLightPosition = function(x, y) {
    if (mainWindow != null && process.platform == 'darwin' && mainWindow.setWindowButtonPosition != null && x >= 0 && y >= 0) {
        mainWindow.setWindowButtonPosition({ x: x, y: y });
    }
};

// Keeps the title bar and frame options for the next launch (they only apply
// when the window is created)
exports.setCreationOptions = function(options) {
    if (keepWindowOptions) writeWindowOptions(options);
};

// Native menu bar (macOS)
//

let menuItemsById = {};

// Builds the application menu from `menus` (Ceramic menu items as plain
// objects: id, kind, title, key, modifiers, role, enabled, checked, items).
// `onAction(id)` runs an item chosen with the mouse. An item chosen with its
// shortcut is not run here: the page got the key first and the app decides
// whether the item runs (as on native builds, where the keystroke is delivered
// to the app before the menu). Items with a role of the system (hide, minimize,
// zoom, full screen...) are done by the system.
exports.setMenuBar = function(menus, onAction, onWillOpen) {
    if (process.platform != 'darwin') return;
    menuItemsById = {};
    var template = [];
    // The first menu is the application menu
    for (var i = 0; i < menus.length; i++) {
        template.push(menuTemplate(menus[i], onAction, onWillOpen, true));
    }
    var menu = Menu.buildFromTemplate(template);
    Menu.setApplicationMenu(menu);
    collectMenuItems(menu);
    // Opening a menu: the app tells which items are enabled now
    for (var m = 0; m < menu.items.length; m++) {
        var submenu = menu.items[m].submenu;
        if (submenu != null && onWillOpen != null) {
            submenu.on('menu-will-show', function() { onWillOpen(); });
        }
    }
};

// Enables or disables items: `states` maps item ids to booleans
exports.setMenuItemsEnabled = function(states) {
    for (var id in states) {
        var item = menuItemsById[id];
        if (item != null) item.enabled = !!states[id];
    }
};

function collectMenuItems(menu) {
    for (var i = 0; i < menu.items.length; i++) {
        var item = menu.items[i];
        if (item.id != null && item.id !== '') menuItemsById[item.id] = item;
        if (item.submenu != null) collectMenuItems(item.submenu);
    }
}

function menuAccelerator(key, modifiers) {
    if (key == null || key === '') return undefined;
    var names = {
        space: 'Space', backspace: 'Backspace', escape: 'Escape', tab: 'Tab', enter: 'Return',
        up: 'Up', down: 'Down', left: 'Left', right: 'Right', pageup: 'PageUp', pagedown: 'PageDown',
        home: 'Home', end: 'End', 'delete': 'Delete', insert: 'Insert', '+': 'Plus'
    };
    var name = names[key];
    if (name == null) name = /^f[0-9]+$/.test(key) ? key.toUpperCase() : key.toUpperCase();
    var parts = [];
    // Ceramic's KeyModifiers: 1 shift, 2 control, 4 alt, 8 meta
    if (modifiers & 8) parts.push('Command');
    if (modifiers & 2) parts.push('Control');
    if (modifiers & 4) parts.push('Alt');
    if (modifiers & 1) parts.push('Shift');
    parts.push(name);
    return parts.join('+');
}

// Ceramic's MenuItemRole values done by the system, as Electron roles
var systemRoles = { 8: 'hide', 9: 'hideOthers', 10: 'unhide', 11: 'minimize', 12: 'zoom', 13: 'togglefullscreen' };

function menuTemplate(item, onAction, onWillOpen, topLevel) {
    // kind: 0 action, 1 separator, 2 submenu, 3 services
    if (item.kind == 1) return { type: 'separator' };
    if (item.kind == 3) return { label: item.title, role: 'services' };
    if (item.kind == 2) {
        var entry = { id: String(item.id), label: item.title, submenu: [] };
        if (item.role == 7 && topLevel) entry.role = 'windowMenu';
        var children = item.items != null ? item.items : [];
        for (var i = 0; i < children.length; i++) {
            entry.submenu.push(menuTemplate(children[i], onAction, onWillOpen, false));
        }
        if (entry.role == 'windowMenu') {
            // Electron's window menu fills its own items: keep the app's
            delete entry.role;
        }
        return entry;
    }
    var result = {
        id: String(item.id),
        label: item.title,
        enabled: item.enabled !== false,
        accelerator: menuAccelerator(item.key, item.modifiers)
    };
    if (item.checked) {
        result.type = 'checkbox';
        result.checked = true;
    }
    var role = systemRoles[item.role];
    if (role != null) {
        result.role = role;
        return result;
    }
    result.click = function(menuItem, browserWindow, event) {
        // A shortcut reached the page first, which decides (see setMenuBar)
        if (event != null && event.triggeredByAccelerator) return;
        if (onAction != null) onAction(item.id);
    };
    return result;
}

// Create http server
//
let port = 49103;
const server = express();

// Enable CORS
server.use(function(req, res, next) {
  res.header("Access-Control-Allow-Origin", "*");
  res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
  next();
});

// Serve static files through express
// TODO make path dynamic
server.use(express.static(appFiles));

// Listen to a free port
detect(port, (err, _port) => {

    if (err) {
        console.error(err);
    }

    if (port != _port) {
        // Other port suggested
        port = _port;
    }

    console.log('Create http server: http://127.0.0.1:' + port + '');

    // Dispatch info
    var expressServer = server.listen(port);
    appUrl = 'http://localhost:' + port;

    exports.serverPort = port;
    exports.appUrl = appUrl;

    if (useNativeBridge) {

        // Websocket server to plug ceramic native bridge
        //

        const WebSocket = require('ws');

        // Listen to another free port
        var wsport = 49113;
        detect(wsport, (err, _wsport) => {

            if (err) {
                console.error(err);
            }

            if (wsport != _wsport) {
                // Other port suggested
                wsport = _wsport;
            }

            let _ws = null;
            const WebSocket = require('ws');

            console.log('Create websocket server to connect native bridge (port: ' + wsport + ')');

            const wss = new WebSocket.Server({
                port: wsport,
                perMessageDeflate: false
            });

            wss.on('connection', function(ws) {

                console.log('Received websocket connection');
                _ws = ws;

                ws.on('message', function(raw) {
                    if (mainWindow != null)
                        mainWindow.webContents.send('ceramic-native-bridge', ''+raw);
                });

                ws.on('error', function(err) {
                    _ws = null;
                    console.error('Websocket error: ' + err);
                });

                ws.on('close', function() {
                    _ws = null;
                    console.log('Websocket connection closed');
                });

            });

            wss.on('error', function(err) {
                console.error('Error when creating websocket server: ' + err);
            });

            exports.ceramicNativeBridgeSend = function(message) {
                if (_ws != null) {
                    _ws.send(''+message);
                }
            };

        });

        // Start native bridge
        //
        var bridgePath = null;
        var platform = null;
        if (process.platform == 'darwin') {
            bridgePath = path.normalize(path.join(__dirname, '../bridge/project/mac/ceramic-native-bridge.app/Contents/MacOS/ceramic-native-bridge'));
            platform = 'mac';
        }
        else if (process.platform == 'win32') {
            bridgePath = path.normalize(path.join(__dirname, '../bridge/project/windows/ceramic-native-bridge.exe'));
            platform = 'windows';
        }
        else {
            bridgePath = path.normalize(path.join(__dirname, '../bridge/project/linux/ceramic-native-bridge'));
            platform = 'linux';
        }

        if (bridgePath != null) {

            console.log('bridge path ' + bridgePath);

            function runBridge() {

                var proc = spawn(bridgePath, ['' + wsport], {
                    stdio: 'inherit'
                });

                app.on('window-all-closed', function() {
                    // Kill bridge when all windows are closed
                    proc.kill();
                });
            }

            if (fs.existsSync(bridgePath)) {
                runBridge();
            }
            else {
                // Need to build native bridge first?
                console.log('Native bridge not built yet. Building...');
                var nodeCmd = path.normalize(path.join(__dirname, '../tools/node'));
                if (process.platform == 'win32') {
                    nodeCmd += '.cmd';
                }
                var ceramicPath = path.normalize(path.join(__dirname, '../tools/ceramic'));
                var bridgeProjectPath = path.normalize(path.join(__dirname, '../bridge'));
                var buildProc = spawn(nodeCmd, [ceramicPath, 'clay', 'build', platform, '--setup', '--assets'], {
                    stdio: 'inherit',
                    cwd: bridgeProjectPath
                });

                buildProc.on('close', function(code) {
                    if (code == 0) {
                        if (fs.existsSync(bridgePath)) {
                            console.log('Finished building bridge, run it...')
                            runBridge();
                        }
                    }
                });
            }
        }

    }

});

// Check for file changes
if (watchFile != null) {
    fs.watchFile(path.join(appFiles, watchFile), function(curr, prev) {
        if (mainWindow != null) {
            mainWindow.reload();
        }
    });
}

process.on('SIGINT', () => {
    app.quit();
});

process.on('SIGTERM', () => {
    app.quit();
});
