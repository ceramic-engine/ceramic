
const path = require('path');
const fs = require('fs');

const express = require('express')
const { detect } = require('detect-port')

const spawn = require('child_process').spawn;

const remoteMain = require('@electron/remote/main');
remoteMain.initialize();

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
    i++;
}

if (appFiles == null) {
    console.error('Missing app files path (use --app-files /your/files/dir)');
    process.exit(0);
}
if (!fs.existsSync(appFiles)) {
    console.error('Invalid app files path: ' + appFiles);
    process.exit(1);
}

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

function createWindow() {

    if (appUrl == null) {
        setTimeout(createWindow, 100);
        return;
    }

    if (mainWindow != null) return;

    // Create the browser window.
    mainWindow = new BrowserWindow({
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
    });
    remoteMain.enable(mainWindow.webContents);
    exports.mainWindow = mainWindow;

    /*mainWindow.webContents.on('did-finish-load', function() {
        mainWindow.show();
    });*/

    // and load the index.html of the app.
    mainWindow.loadURL(appUrl);

    // Open the DevTools.
    //mainWindow.webContents.openDevTools()

    // Emitted when the window is closed.
    mainWindow.on('closed', function() {
        // Dereference the window object, usually you would store windows
        // in an array if your app supports multi windows, this is the time
        // when you should delete the corresponding element.
        mainWindow = null
        exports.mainWindow = null;
    });
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
exports.ceramicSettings = function(settings) {

    settings.trace('settings.targetWidth=' + settings.targetWidth);
    settings.trace('settings.targetHeight=' + settings.targetHeight);
    settings.trace('settings.title=' + settings.title);
    settings.trace('settings.resizable=' + settings.resizable);
    settings.trace('settings.fullscreen=' + settings.fullscreen);

    mainWindow.setTitle(settings.title);
    mainWindow.setResizable(settings.resizable);
    mainWindow.setFullScreenable(settings.resizable);

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

    //var prevPos = mainWindow.getPosition();
    //var prevSize = mainWindow.getContentSize();
    mainWindow.center();
};

exports.ceramicReady = function() {
    mainWindow.show();

    // Take screenshot?
    if (screenshotPath != null) {
        setTimeout(function() {
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
        }, 100 + screenshotDelay * 1000);
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
        mainWindow.setFullScreen(false);
        mainWindow.setFullScreenable(mainWindow.resizable);
    }
};

exports.listenFullscreen = function(enterFullscreen, leaveFullscreen) {
    mainWindow.on('enter-full-screen', enterFullscreen);
    mainWindow.on('leave-full-screen', leaveFullscreen);
};

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
