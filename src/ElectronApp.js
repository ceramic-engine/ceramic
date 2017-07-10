const electron = require('electron')
// Module to control application life.
const app = electron.app
// Module to create native browser window.
const BrowserWindow = electron.BrowserWindow

const path = require('path')
const url = require('url')

const express = require('express')
const detect = require('detect-port')

// Keep a global reference of the window object, if you don't, the window will
// be closed automatically when the JavaScript object is garbage collected.
let mainWindow

function createWindow () {
  // Create the browser window.
  mainWindow = new BrowserWindow({
    width: 1024,
    height: 600,
    titleBarStyle: 'hidden',
    minWidth: 800,
    minHeight: 600,
    resizable: true,
    movable: true
  })

  // and load the index.html of the app.
  if (process.env.ELECTRON_DEV) {
    mainWindow.loadURL('http://localhost:3000')
  } else {
    mainWindow.loadURL(url.format({
      pathname: path.normalize(path.join(__dirname, '/../build/index.html')),
      protocol: 'file:',
      slashes: true
    }))
  }

  // Open the DevTools.
  // mainWindow.webContents.openDevTools()

  // Emitted when the window is closed.
  mainWindow.on('closed', function () {
    // Dereference the window object, usually you would store windows
    // in an array if your app supports multi windows, this is the time
    // when you should delete the corresponding element.
    mainWindow = null
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
  if (process.platform !== 'darwin') {
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

if (process.env.ELECTRON_DEV) {
  server.use('/ceramic', express.static(path.normalize(path.join(__dirname, '/../public/ceramic'))))
} else {
  server.use('/ceramic', express.static(path.normalize(path.join(__dirname, '/../build/ceramic'))))
}

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
