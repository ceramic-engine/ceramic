import * as React from 'react';
import { observer, autobind, ceramic, files } from 'utils';
import { Button, Inline, Form, Field, TextInput, SelectInput, Alt } from 'components';
import Overlay from './Overlay';
import Dialog from './Dialog';
import { project, user } from 'app/model';
import { context } from 'app/context';
import * as fs from 'fs';
import { relative } from 'path';
import { homedir } from 'os';
import { shell } from 'electron';
import FaCheck from 'react-icons/lib/fa/check';
import FaClose from 'react-icons/lib/fa/close';
import FaQuestion from 'react-icons/lib/fa/question';

@observer class EditSettings extends React.Component {

/// Lifecycle

    render() {

        let editorsList = ['Default'];
        editorsList.push('Choose a ceramic editor export\u2026');
        if (project.previewPath) {
            editorsList.push(project.previewPath);
        }

        let assetsPathList = [project.assetsPath ? project.assetsPath : 'None'];
        assetsPathList.push('Choose assets directory\u2026');

        let rawFilesPathList = [project.rawFilesPath ? project.rawFilesPath : 'None'];
        rawFilesPathList.push('Choose raw files directory\u2026');

        return (
            <Overlay>
                <Dialog title="Ceramic" size="large">
                    <div className="title">Current setup</div>
                    <Form>
                        <Field label="Haxe" kind="custom">
                            {context.haxeVersion ?
                                <span style={{ color: '#00FF00' }}>
                                    <FaCheck style={{ position: 'relative', top: -1 }} size={10} /> {context.haxeVersion}
                                </span>
                            :
                            <span style={{ color: '#FF0000', position: 'relative' }}>
                                <FaClose style={{ position: 'relative', top: -1 }} size={10} /> Not found
                                <span className="install-link">
                                    Install: <a href="#" onClick={(e) => { e.preventDefault(); shell.openExternal('https://haxe.org/'); }}>https://haxe.org/</a>
                                </span>
                            </span>
                            }
                        </Field>
                        <Field label="Git" kind="custom">
                            {context.gitVersion ?
                                <span style={{ color: '#00FF00' }}>
                                    <FaCheck style={{ position: 'relative', top: -1 }} size={10} /> {context.gitVersion}
                                </span>
                            :
                                <span style={{ color: '#FF0000', position: 'relative' }}>
                                    <FaClose style={{ position: 'relative', top: -1 }} size={10} /> Not found
                                    <span className="install-link">
                                        Install: <a href="#" onClick={(e) => { e.preventDefault(); shell.openExternal('https://git-scm.com/'); }}>https://git-scm.com/</a>
                                    </span>
                                </span>
                            }
                        </Field>
                    </Form>
                    <div className="title">Editor preview</div>
                    <Form>
                        <Field label="Local preview path">
                            <SelectInput
                                size="large"
                                empty={0}
                                selected={project.previewPath ? 2 : 0}
                                options={editorsList}
                                onChange={(selected) => {
                                    if (selected === 0) {
                                        project.previewPath = null;
                                    }
                                    else if (!project.previewPath || selected === 1) {
                                        project.choosePreviewPath();
                                    }
                                }}
                            />
                        </Field>
                    </Form>
                    <div className="title">Assets &amp; Files</div>
                    <Form>
                        <Field label="Assets directory">
                            <SelectInput
                                size="large"
                                empty={project.absoluteAssetsPath ? null : 0}
                                selected={0}
                                options={assetsPathList}
                                onChange={(selected) => {
                                    if (selected === 1) {
                                        project.chooseAssetsPath();
                                    }
                                }}
                            />
                        </Field>
                        <Field label="Raw files directory">
                            <SelectInput
                                size="large"
                                empty={project.absoluteRawFilesPath ? null : 0}
                                selected={0}
                                options={rawFilesPathList}
                                onChange={(selected) => {
                                    if (selected === 1) {
                                        project.chooseRawFilesPath();
                                    }
                                }}
                            />
                        </Field>
                    </Form>
                    <div className="title">Online settings</div>
                    <div className="description">Synchronize this project with a Github repository and realtime messaging. This allows to work on a ceramic project and save changes, settings, assets and more remotely. It also makes it possible to share the project between multiple users.</div>
                    <Form>
                        <Field label="Github repository URL">
                            <TextInput
                                size="large"
                                placeholder={'https://github.com/username/project-name.git'}
                                value={project.gitRepository}
                                onChange={(val:string) => { project.gitRepository = val.trim(); }}
                            />
                        </Field>
                        <Field label="Github token">
                            <TextInput
                                password={true}
                                size="large"
                                placeholder={'Enter personal access token\u2026'}
                                value={user.githubToken}
                                onChange={(val:string) => { user.githubToken = val.trim(); }}
                            />
                        </Field>
                        <Field label="Online project">
                            <SelectInput
                                size="large"
                                empty={0}
                                selected={project.onlineEnabled ? 1 : 0}
                                options={['Disabled', 'Enabled']}
                                onChange={(selected) => {
                                    project.onlineEnabled = selected === 1 ? true : false;
                                }}
                            />
                        </Field>
                        <Field label="Realtime.co API key" disabled={!project.onlineEnabled}>
                            <TextInput
                                disabled={!project.onlineEnabled}
                                password={true}
                                size="large"
                                placeholder={'Enter realtime.co API key\u2026'}
                                value={user.realtimeApiKey}
                                onChange={(val:string) => { user.realtimeApiKey = val.trim(); }}
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
