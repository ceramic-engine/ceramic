import * as electron from 'electron';
import { autorun } from 'utils';
import { project } from 'app/model';
import { EventEmitter } from 'events';
const electronApp = electron.remote.require('./app.js');

class Shortcuts extends EventEmitter {

    menuReady:boolean = false;

    createMenu() {

        if (this.menuReady) return;
        this.menuReady = true;

        // Menu
        const template = [
            {
                label: 'File',
                submenu: [
                    {
                        label: 'New project',
                        accelerator: 'CmdOrCtrl+N',
                        click: () => {
                            if (project.initialized) {
                                if (confirm('Create a new project?')) {
                                    project.createNew();
                                }
                            }
                        }
                    },
                    {type: 'separator'},
                    {
                        label: 'Open\u2026',
                        accelerator: 'CmdOrCtrl+O',
                        click: () => {
                            console.debug('FILE OPEN');
                        }
                    },
                    {type: 'separator'},
                    {
                        label: 'Save project',
                        accelerator: 'CmdOrCtrl+S',
                        click: () => {
                            console.debug('FILE SAVE');
                        }
                    },
                    {
                        label: 'Save as\u2026',
                        accelerator: 'Shift+CmdOrCtrl+S',
                        click: () => {
                            console.debug('FILE SAVE AS');
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
                    {role: 'selectall'},
                    {type: 'separator'},
                    {
                        label: 'Delete',
                        accelerator: 'Backspace',
                        click() {
                            if (document.activeElement.id !== 'body') return;
                            if (project.ui.editor === 'scene') {
                                if (project.ui.sceneTab === 'visuals') {
                                    project.removeCurrentSceneItem();
                                }
                                else if (project.ui.sceneTab === 'scenes') {
                                    if (confirm('Delete current scene?')) {
                                        project.removeCurrentScene();
                                    }
                                }
                            }
                        }
                    }
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

        autorun(() => {

            //if (!project.name)

            /*for (let item of fileItems) {
                if (item.label === 'New') {
                    item.enabled = false;
                }
            }*/

        });

        electronApp.Menu.setApplicationMenu(menu);

    } //createMenu

}

const shortcuts = new Shortcuts();
export default shortcuts;
