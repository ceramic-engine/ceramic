import * as electron from 'electron';
import { autorun, history, clipboard, db } from 'utils';
import { project } from 'app/model';
import { EventEmitter } from 'events';
import { context } from './context';
const electronApp = electron.remote.require('./app.js');

class Shortcuts extends EventEmitter {

    menuReady:boolean = false;

    initialize() {

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
                            project.open();
                        }
                    },
                    {type: 'separator'},
                    {
                        label: 'Save project',
                        accelerator: 'CmdOrCtrl+S',
                        click: () => {
                            project.save();
                        }
                    },
                    {
                        label: 'Save as\u2026',
                        accelerator: 'Shift+CmdOrCtrl+S',
                        click: () => {
                            project.saveAs();
                        }
                    },
                    {type: 'separator'},
                    {
                        label: 'Sync with Github',
                        accelerator: 'Shift+CmdOrCtrl+G',
                        click: () => {
                            project.syncWithGithub();
                        }
                    }
                ]
            },
            {
                label: 'Edit',
                submenu: [
                    {
                        label: 'Undo',
                        accelerator: 'CmdOrCtrl+Z',
                        click: () => {
                            if (project.ui.addVisual || context.draggingOver || project.ui.prompt) return;
                            
                            history.undo();
                        }
                    },
                    {
                        label: 'Redo',
                        accelerator: 'CmdOrCtrl+Shift+Z',
                        click: () => {
                            if (project.ui.addVisual || context.draggingOver || project.ui.prompt) return;

                            history.redo();
                        }
                    },
                    {type: 'separator'},
                    {
                        label: 'Cut',
                        accelerator: 'CmdOrCtrl+X',
                        click: () => {
                            if (project.ui.addVisual || context.draggingOver || project.ui.prompt) return;

                            // Save to clipboard
                            if (global['focusedInput'] != null) {
                                clipboard.writeText(global['focusedInput'].copySelected(true));
                            }
                            else if (project.ui.selectedScene != null && project.ui.selectedItem != null) {
                                clipboard.writeText(
                                    '[|ceramic/scene-item|]' + project.copySelectedSceneItem(true)
                                );
                            }
                        }
                    },
                    {
                        label: 'Copy',
                        accelerator: 'CmdOrCtrl+C',
                        click: () => {
                            // Save to clipboard
                            if (global['focusedInput'] != null) {
                                clipboard.writeText(global['focusedInput'].copySelected(false));
                            }
                            else if (project.ui.selectedScene != null && project.ui.selectedItem != null) {
                                clipboard.writeText(
                                    '[|ceramic/scene-item|]' + project.copySelectedSceneItem(false)
                                );
                            }
                        }
                    },
                    {
                        label: 'Paste',
                        accelerator: 'CmdOrCtrl+V',
                        click: () => {
                            if (global['focusedInput'] != null) {
                                let text = clipboard.readText();
                                if (text != null && !text.startsWith('[|ceramic/')) {
                                    global['focusedInput'].pasteToSelected(text);
                                }
                            }
                            else if (project.ui.selectedScene != null) {
                                let text = clipboard.readText();
                                if (text != null && text.startsWith('[|ceramic/scene-item|]')) {
                                    project.pasteSceneItem(text.substr('[|ceramic/scene-item|]'.length));
                                }
                            }
                        }
                    },
                    {role: 'selectall'},
                    {type: 'separator'},
                    {
                        label: 'Delete',
                        accelerator: 'Backspace',
                        click() {
                            if (document.activeElement.nodeName.toLowerCase() !== 'body') return;
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
                label: 'Project',
                submenu: [
                    {
                        label: 'Build',
                        accelerator: 'CmdOrCtrl+Shift+B',
                        click: () => {
                            project.build();
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
            for (let tpl of template) {
                if ((tpl as any).role === 'window') {
                    tpl.submenu = [
                        {role: 'close'},
                        {role: 'minimize'},
                        {role: 'zoom'},
                        {type: 'separator'},
                        {role: 'front'}
                    ];
                    break;
                }
            }
        }

        const menu:Electron.Menu = electronApp.Menu.buildFromTemplate(template);
        const fileItems:Array<Electron.MenuItem> = (menu.items[1] as any).submenu.items;

        electronApp.Menu.setApplicationMenu(menu);

        // Bind drag & drop file
        //
        let dragTimeout:any = null;
        document.addEventListener('dragover', (ev) => {
            ev.preventDefault();

            context.draggingOver = true;
            if (dragTimeout != null) clearTimeout(dragTimeout);
            dragTimeout = setTimeout(() => {
                dragTimeout = null;
                context.draggingOver = false;
            }, 250);
        });
        document.body.ondrop = (ev) => {
            ev.preventDefault();

            if (dragTimeout != null) clearTimeout(dragTimeout);
            context.draggingOver = false;

            let path = ev.dataTransfer.files[0].path;
            if (path) {
                project.dropFile(path);
            }
        };

    } //createMenu

}

const shortcuts = new Shortcuts();
export default shortcuts;
