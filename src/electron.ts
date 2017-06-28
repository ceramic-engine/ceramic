
// Helper to import electron without
// ejectring the app, but still with typings.

var w:any = window;
const electron:Electron.AllElectron = w.require('electron');
export default electron;
