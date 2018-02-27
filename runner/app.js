
const path = require('path');
const url = require('url');
const fs = require('fs');

const express = require('express')
const detect = require('detect-port')

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

var argv = process.argv.slice();
var i = 0;
while (i < argv.length) {
    var arg = argv[i];
    if (arg == '--app-files') {
        i++;
        appFiles = argv[i];
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

// App icon
if (process.platform == 'darwin') {
    app.dock.setIcon(path.join(__dirname, 'resources/AppIcon.png'));
}

// App name
app.setName(appName);
exports.app = app;
exports.Menu = Menu;
exports.MenuItem = MenuItem;
exports.electronDev = process.env.ELECTRON_DEV;
exports.dirname = __dirname;
exports.isCeramicRunner = true;

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
        minWidth: 320,
        minHeight: 320,
        resizable: false,
        movable: true,
        title: appName,
        backgroundColor: '#000000',
        icon: path.join(__dirname, 'resources/AppIcon.png')
    });
    exports.mainWindow = mainWindow;

    /*mainWindow.webContents.on('did-finish-load', function() {
        mainWindow.show();
    });*/

    // and load the index.html of the app.
    mainWindow.loadURL(appUrl);

    // Ensure we keep the initial window title we set
    mainWindow.on('page-title-updated', function (e) {
        e.preventDefault();
    });

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
    mainWindow.setTitle(settings.title);
    mainWindow.setResizable(settings.resizable);

    var prevPos = mainWindow.getPosition();
    var prevSize = mainWindow.getSize();
    mainWindow.setSize(settings.targetWidth, settings.targetHeight, false);
    mainWindow.setPosition(
        Math.round(prevPos[0] + (prevSize[0] - settings.targetWidth) / 2),
        Math.round(prevPos[1] + (prevSize[1] - settings.targetHeight) / 2),
        false
    );
};

exports.ceramicReady = function() {
    mainWindow.show();
};

exports.consoleLog = function(str) {
    console.log(str);
};

// Create http server
//
let port = 49103
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

    // Dispatch info
    server.listen(port);
    exports.serverPort = port;
    appUrl = 'http://localhost:' + port;

});
