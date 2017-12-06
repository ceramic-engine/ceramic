
const path = require('path')
const url = require('url')
const fs = require('fs')

const express = require('express')
const detect = require('detect-port')

// Electron
const electron = require('electron')
// Module to control application life.
const app = electron.app
// Module to create native browser window.
const BrowserWindow = electron.BrowserWindow
// Menu
const Menu = electron.Menu
const MenuItem = electron.MenuItem

const appName = 'Ceramic';

// App name
app.setName(appName)
exports.app = app
exports.Menu = Menu
exports.MenuItem = MenuItem
exports.electronDev = process.env.ELECTRON_DEV;

// Handle dev args
var argv = [].concat(process.argv)
if (argv[1] == '.' && argv[2] == 'ceramic') {
  argv.splice(1, 1)
}

// Ceramic CLI
if (argv[1] == 'ceramic') {
  try {

    // Expose global require
    global.rReqOrig = require
    global.rReq = function(module) {
      if (rReqOrig.resolve(module)) {
        return rReqOrig(module)
      } else {
        return require.main.require(module)
      }
    }

    var hasProxy = argv.indexOf('--electron-proxy') != -1;

    // Hide dock icon when running ceramic command
    if (app.dock != null) {
      app.dock.hide();
    }

    const ceramicPath = require.resolve('ceramic-tools')
    const ceramicDir = path.dirname(ceramicPath)
    const args = argv.slice(2)
    const ceramic = require('ceramic-tools')

    if (hasProxy) process.stdout.write('[|ceramic:begin|]' + "\n");
    ceramic(process.cwd(), args, ceramicDir)

    return;
  }
  catch (e) {
    // Log error on console
    console.error(e);
    process.exit(-1);
  }
}

// Keep a global reference of the window object, if you don't, the window will
// be closed automatically when the JavaScript object is garbage collected.
let mainWindow
exports.mainWindow = null;

function createWindow () {

  if (exports.serverPort == null) {
    setTimeout(createWindow, 100);
    return;
  }

  if (mainWindow != null) return;

  // Create the browser window.
  mainWindow = new BrowserWindow({
    width: 1024,
    height: 600,
    titleBarStyle: 'hidden',
    minWidth: 800,
    minHeight: 600,
    resizable: true,
    movable: true,
    title: appName,
    frame: process.platform != 'darwin',
    icon: process.env.ELECTRON_DEV ?
      path.join(__dirname, 'public/icons/256x256.png') : 
      path.join(__dirname, 'build/icons/256x256.png')
  })
  exports.mainWindow = mainWindow;

  // and load the index.html of the app.
  if (process.env.ELECTRON_DEV) {
    mainWindow.loadURL('http://localhost:3000')
  } else {
    /*mainWindow.loadURL(url.format({
      pathname: path.normalize(path.join(__dirname, '/../build/index.html')),
      protocol: 'file:',
      slashes: true
    }))*/
    mainWindow.loadURL('http://localhost:' + exports.serverPort + '/app/index.html')
  }

  // Ensure we keep the initial window title we set
  mainWindow.on('page-title-updated', function (e) {
    e.preventDefault()
  })

  // Open the DevTools.
  //mainWindow.webContents.openDevTools()

  // Emitted when the window is closed.
  mainWindow.on('closed', function () {
    // Dereference the window object, usually you would store windows
    // in an array if your app supports multi windows, this is the time
    // when you should delete the corresponding element.
    mainWindow = null
    exports.mainWindow = null;
  })
}

// This method will be called when Electron has finished
// initialization and is ready to create browser windows.
// Some APIs can only be used after this event occurs.
app.on('ready', createWindow)

// Quit when all windows are closed.
app.on('window-all-closed', function () {
  // On OS X it is common for applications and their menu bar
  // to stay active until the user quits explicitly with Cmd + Q
  if (!(process.platform === 'darwin' && process.env.ELECTRON_DEV)) {
    app.quit()
  }
})

app.on('activate', function () {
  // On OS X it's common to re-create a window in the app when the
  // dock icon is clicked and there are no other windows open.
  if (mainWindow === null) {
    createWindow()
  }
})

// In this file you can include the rest of your app's specific main process
// code. You can also put them in separate files and require them here.

// Create http server
//
let port = 48903
const server = express()

// Enable CORS
server.use(function(req, res, next) {
  res.header("Access-Control-Allow-Origin", "*");
  res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
  next();
});

let defaultPreviewPath = null;
let defaultProcessedAssetsPath = null;
if (process.env.ELECTRON_DEV) {
  defaultPreviewPath = path.normalize(path.join(__dirname, '/public/ceramic'))
  defaultProcessedAssetsPath = path.normalize(path.join(__dirname, '/public/ceramic/assets'))
  server.use('/app', express.static(path.normalize(path.join(__dirname, '/public'))))
} else {
  defaultPreviewPath = path.normalize(path.join(__dirname, '/build/ceramic'))
  defaultProcessedAssetsPath = path.normalize(path.join(__dirname, '/build/ceramic/assets'))
  server.use('/app', express.static(path.normalize(path.join(__dirname, '/build'))))
}

// TODO find something else to handle default assets

exports.assetsPath = null;
exports.processingAssets = false;
server.get('/ceramic/assets/*', function(req, res) {
  function handleAsset() {
    let relativePath = req.path.substr('/ceramic/assets/'.length);

    // Wait until assets are ready, if being processed
    if (exports.processingAssets) {
      setTimeout(() => {
        handleAsset();
      }, 250);
      return;
    }

    if (exports.assetsPath == null || !fs.existsSync(path.join(exports.assetsPath, relativePath))) {
      if (fs.existsSync(path.join(defaultProcessedAssetsPath, relativePath))) {
        let assetPath = path.join(defaultProcessedAssetsPath, relativePath);
        fs.readFile(assetPath, function(err, data) {
          if (err) {
            res.status(404)
            res.send('Not found')
          } else {
            res.contentType(assetPath);
            res.end(data);
          }
        });
      }
      else {
        res.status(404)
        res.send('Not found')
      }
    }
    else {
      let assetPath = path.join(exports.assetsPath, relativePath);
      fs.readFile(assetPath, function(err, data) {
        if (err) {
          res.status(404)
          res.send('Not found')
        } else {
          res.contentType(assetPath);
          res.end(data);
        }
      });
    }
  }
  handleAsset();
});

exports.sourceAssetsPath = null;
server.get('/ceramic/source-assets/*', function(req, res) {
  let relativePath = req.path.substr('/ceramic/source-assets/'.length);

  if (exports.sourceAssetsPath == null || !fs.existsSync(path.join(exports.sourceAssetsPath, relativePath))) {
    res.status(404)
    res.send('Not found')
  } else {
    let assetPath = path.join(exports.sourceAssetsPath, relativePath);
    fs.readFile(assetPath, function(err, data) {
      if (err) {
        res.status(404)
        res.send('Not found')
      } else {
        res.contentType(assetPath);
        res.end(data);
      }
    });
  }
});

exports.previewPath = null;
server.get('/ceramic/*', function(req, res) {
  let relativePath = req.path.substr('/ceramic/'.length);
  let basePath = exports.previewPath && fs.existsSync(path.join(exports.previewPath, 'index.html')) ? exports.previewPath : defaultPreviewPath;

  if (!fs.existsSync(path.join(basePath, relativePath))) {
    res.status(404)
    res.send('Not found')
  } else {
    let filePath = path.join(basePath, relativePath);
    fs.readFile(filePath, function(err, data) {
      if (err) {
        res.status(404)
        res.send('Not found')
      } else {
        res.contentType(filePath);
        res.end(data);
      }
    });
  }
});

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
})
