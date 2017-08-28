import * as React from 'react';
import { observer, autobind, ceramic, files } from 'utils';
import { Button, Inline, Form, Field, TextInput, SelectInput } from 'components';
import Overlay from './Overlay';
import Dialog from './Dialog';
import { project } from 'app/model';
import * as fs from 'fs';
import { relative } from 'path';
import { homedir } from 'os';

@observer class EditSettings extends React.Component {

/// Lifecycle

    render() {

        let editorsList = ['default'];
        if (project.editorPath) {
            let displayPath = project.editorPath;
            if (displayPath.startsWith(homedir())) {
                displayPath = '~' + displayPath.substr(homedir().length);
            }
            editorsList.push(displayPath);
        }
        editorsList.push('choose');

        return (
            <Overlay>
                <Dialog title="Settings">
                    <Form>
                        <Field label="editor canvas">
                            <SelectInput
                                empty={0}
                                selected={project.editorPath ? 1 : 0}
                                options={editorsList}
                                onChange={(selected) => {
                                    if (selected === 0) {
                                        project.editorPath = null;
                                    }
                                    else if (!project.editorPath || selected === 2) {
                                        let path = files.chooseDirectory('Editor Canvas Directory');
                                        if (path && fs.existsSync(path)) {
                                            project.editorPath = path;
                                        }
                                    }
                                }}
                            />
                        </Field>
                    </Form>
                    <div style={{ height: 12 }} />
                    <Button value="Close" onClick={() => { project.ui.editSettings = false; }} />
                </Dialog>
            </Overlay>
        );

    } //render
    
}

export default EditSettings;
