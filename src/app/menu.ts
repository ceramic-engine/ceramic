import * as electron from 'electron';
import { autorun } from 'utils';
const electronApp = electron.remote.require('./app.js');

let menuReady = false;

export function createMenu() {

    if (menuReady) return;
    menuReady = true;

    // Menu
    const template = [
        {
            label: 'File',
            submenu: [
                {
                    label: 'New',
                    accelerator: 'CmdOrCtrl+N',
                    click() {
                        console.debug('FILE NEW CLICK');
                    }
                }
            ]
        },
        {
            label: 'Edit',
            submenu: [
                {role: 'undo'},
                {role: 'redo'},
                {type: 'separator'},
                {role: 'cut'},
                {role: 'copy'},
                {role: 'paste'},
                {role: 'selectall'}
            ]
        },
        {
            label: 'View',
            submenu: [
                {role: 'reload'},
                {role: 'forcereload'},
                {role: 'toggledevtools'},
                {type: 'separator'},
                {role: 'togglefullscreen'}
            ]
        },
        {
            role: 'window',
            submenu: [
                {role: 'minimize'},
                {role: 'close'}
            ]
        },
        {
            role: 'help',
            submenu: [
                {
                    label: 'Learn More',
                    click () { require('electron').shell.openExternal('https://github.com/jeremyfa/ceramic'); }
                }
            ]
        }
    ];

    if (process.platform === 'darwin') {

        template.unshift({
            label: electronApp.app.getName(),
            submenu: [
                {role: 'about'},
                {type: 'separator'},
                {role: 'hide'},
                {role: 'hideothers'},
                {role: 'unhide'},
                {type: 'separator'},
                {role: 'quit'}
            ]
        });

        // Window menu
        template[4].submenu = [
            {role: 'close'},
            {role: 'minimize'},
            {role: 'zoom'},
            {type: 'separator'},
            {role: 'front'}
        ];
    }

    const menu:Electron.Menu = electronApp.Menu.buildFromTemplate(template);
    const fileItems:Array<Electron.MenuItem> = (menu.items[1] as any).submenu.items;

    for (let item of fileItems) {
        if (item.label === 'New') {
            item.enabled = false;
        }
    }

    electronApp.Menu.setApplicationMenu(menu);

} //createMenu
