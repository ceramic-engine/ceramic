import * as electron from 'electron';
import { autorun, history, clipboard, db } from 'utils';
import { project } from 'app/model';
import { EventEmitter } from 'events';
import { context } from './context';
const electronApp = electron.remote.require('./app.js');

class Shortcuts extends EventEmitter {

/// Properties

    menuReady:boolean = false;

/// Custom event handlers

    handleUndo:() => void = null;

    handleRedo:() => void = null;

    handleCancel:() => void = null;

    handleValidate:() => void = null;

/// Lifecycle

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
                            project.save(true);
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
                        accelerator: 'CmdOrCtrl+Alt+S',
                        click: () => {
                            project.syncWithGithub({
                                auto: false,
                                directions: 'auto'
                            });
                        }
                    },
                    {
                        label: 'Reset to Github',
                        accelerator: 'Shift+CmdOrCtrl+Alt+S',
                        click: () => {
                            if (confirm('Reset to Github changes?')) {
                                project.syncWithGithub({
                                    auto: false,
                                    directions: 'remoteToLocal'
                                });
                            }
                        }
                    },
                    {type: 'separator'},
                    {
                        label: 'Sync Editor Preview',
                        click: () => {
                            project.syncEditorPreview();
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
                            if (!project.ui.canEditHistory) {
                                if (this.handleUndo != null) {
                                    this.handleUndo();
                                }
                                return;
                            }
                            
                            if (history.index >= 0) {
                                let baseTime = history.items[history.index].meta.time;
                                while (history.index >= 0 && baseTime - history.items[history.index].meta.time < 500) {
                                    console.log('UNDO TIME');
                                    history.undo();
                                }
                            }
                        }
                    },
                    {
                        label: 'Redo',
                        accelerator: 'CmdOrCtrl+Shift+Z',
                        click: () => {
                            if (!project.ui.canEditHistory) {
                                if (this.handleRedo != null) {
                                    this.handleRedo();
                                }
                                return;
                            }

                            history.redo();
                        }
                    },
                    {type: 'separator'},
                    {
                        label: 'Cut',
                        accelerator: 'CmdOrCtrl+X',
                        click: () => {

                            // Save to clipboard
                            if (global['focusedInput'] != null) {
                                clipboard.writeText(global['focusedInput'].copySelected(true));
                            }
                            else if (project.ui.selectedFragment != null && project.ui.selectedItem != null) {
                                clipboard.writeText(
                                    '[|ceramic/fragment-item|]' + project.copySelectedFragmentItem(true)
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
                            else if (project.ui.selectedFragment != null && project.ui.selectedItem != null) {
                                clipboard.writeText(
                                    '[|ceramic/fragment-item|]' + project.copySelectedFragmentItem(false)
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
                            else if (project.ui.selectedFragment != null) {
                                let text = clipboard.readText();
                                if (text != null && text.startsWith('[|ceramic/fragment-item|]')) {
                                    project.pasteFragmentItem(text.substr('[|ceramic/fragment-item|]'.length));
                                }
                            }
                        }
                    },
                    {role: 'selectall'},
                    {type: 'separator'},
                    {
                        label: 'Delete',
                        accelerator: 'Backspace',
                        click: () => {
                            if (document.activeElement.nodeName.toLowerCase() !== 'body') return;
                            if (project.ui.editor === 'fragment') {
                                if (project.ui.fragmentTab === 'visuals') {
                                    project.removeCurrentFragmentItem();
                                }
                                else if (project.ui.fragmentTab === 'fragments') {
                                    if (confirm('Delete current fragment?')) {
                                        project.removeCurrentFragment();
                                    }
                                }
                            }
                        }
                    },
                    {type: 'separator'},
                    {
                        label: 'Cancel',
                        accelerator: 'Esc',
                        click: () => {
                            if (this.handleCancel != null) {
                                this.handleCancel();
                            }
                        }
                    },
                    {
                        label: 'Validate',
                        accelerator: 'CmdOrCtrl+Enter',
                        click: () => {
                            if (this.handleValidate != null) {
                                this.handleValidate();
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
                        click: () => { require('electron').shell.openExternal('https://github.com/ceramic-engine/ceramic'); }
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
            if (!project.ui.canDragFileIntoWindow) return;

            context.draggingOver = true;
            if (dragTimeout != null) clearTimeout(dragTimeout);
            dragTimeout = setTimeout(() => {
                dragTimeout = null;
                context.draggingOver = false;
            }, 250);
        });
        document.body.ondrop = (ev) => {
            ev.preventDefault();
            if (!project.ui.canDragFileIntoWindow) return;

            if (dragTimeout != null) clearTimeout(dragTimeout);
            context.draggingOver = false;

            let path = null;
            try {
                path = ev.dataTransfer.files[0].path;
            }
            catch (e) {}
            if (path) {
                project.dropFile(path);
            }
        };

    } //createMenu

}

const shortcuts = new Shortcuts();
export default shortcuts;
