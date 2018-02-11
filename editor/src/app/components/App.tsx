import * as React from 'react';
import { observer } from 'mobx-react';
import { project, user } from 'app/model';
import { context } from 'app/context';
import { EditFragment, AddVisual, EditSettings, DragOver, MenuInfo, PromptChoice, PromptText, LoadingOverlay, OnlineBroken } from 'app/components';
import MdImage from 'react-icons/lib/md/image';
import MdGridOn from 'react-icons/lib/md/grid-on';

@observer class App extends React.Component {

/// Lifecycle

    render() {

        const isWindows = process.platform === 'win32';
        const navHeight = !isWindows ? 23 : 0;
        const leftSideWidth = 44;

        return (
            <div
                style={{
                    position: 'relative',
                    left: 0,
                    top: 0,
                    width: context.width,
                    height: context.height,
                    visibility: context.needsReload ? 'hidden' : 'visible'
                }}
            >
                <div
                    style={{
                        width: context.width,
                        height: context.height,
                        position: 'absolute',
                        left: 0,
                        top: 0
                    }}
                >
                    <div>
                        { !project.ui.editSettings && project.onlineEnabled && context.connectionStatus === 'pending' ?
                            <LoadingOverlay
                                message={'Connecting to Internet\u2026'}
                            />
                        : !project.ui.editSettings && project.onlineEnabled && !user.githubToken ?
                            <OnlineBroken
                                title={'Github token is required'}
                                message={'This project is configured to be online.\n\nPlease set up a valid Github Personal Access Token.'}
                            />
                        : !project.ui.editSettings && project.onlineEnabled && !project.isUpToDate ?
                            <OnlineBroken
                                title={'Updating\u2026'}
                                message={'Project is getting up to date\u2026'}
                            />
                        : !project.ui.editSettings && project.onlineEnabled && context.connectionStatus === 'offline' ?
                            <OnlineBroken
                                title={'Internet is required'}
                                message={'This project is configured to be online.\n\nPlease ensure you are connected to Internet or set this project as offline.'}
                            />
                        : !project.ui.editSettings && project.onlineEnabled && !user.realtimeApiKey ?
                            <OnlineBroken
                                title={'Realtime token is required'}
                                message={'This project is configured to be online.\n\nPlease add a valid Realtime token.'}
                            />
                        : !project.ui.editSettings && project.onlineEnabled && user.realtimeApiKey && project.realtimeBroken ?
                            <OnlineBroken
                                title={'Realtime token seems invalid'}
                                message={'This project is configured to be online.\n\nEnsure your Realtime token is valid.'}
                            />
                        : context.draggingOver ?
                            <DragOver />
                        : !project.ready && project.absoluteAssetsPath != null ?
                            <LoadingOverlay message={'Loading\u2026'} />
                        : project.ui.addVisual ?
                            <AddVisual />
                        : project.ui.editSettings ?
                            <EditSettings />
                        : project.ui.promptChoice ?
                            <PromptChoice />
                        : project.ui.promptText ?
                            <PromptText />
                        : project.ui.loadingMessage ?
                            <LoadingOverlay />
                        :
                            null
                        }
                    </div>
                    {!isWindows ?
                        <div
                            style={{
                                position: 'absolute',
                                left: 0,
                                top: 0,
                                width: '100%',
                                lineHeight: navHeight + 'px',
                                height: Math.max(0, navHeight - 1),
                                WebkitAppRegion: 'drag',
                                textAlign: 'center'
                            }}
                            className="topnav"
                        >
                        {project.name ?
                            project.name
                        :
                            'New Project'
                        }
                        {user.projectDirty ?
                            ' *'
                        :
                            null
                        }
                        {user.githubToken && project.gitRepository && user.manualGithubProjectDirty ?
                            ' *'
                        :
                            null
                        }
                        </div>
                    : null}
                    <div
                        className="leftside"
                        style={{
                            width: leftSideWidth - 1,
                            height: context.height - navHeight,
                            position: 'absolute',
                            left: 0,
                            top: navHeight
                        }}
                    >
                        <img
                            src="icon-nobg.svg"
                            draggable={false}
                            className="ceramic-icon"
                            onClick={() => { project.ui.editSettings = true; }}
                            onMouseOver={(e) => { project.ui.menuInfo = {
                                y: (e.currentTarget as HTMLElement).getClientRects()[0].top,
                                text: 'Settings'
                            }; }}
                            onMouseOut={() => { project.ui.menuInfo = null; }}
                        />
                        <div className="ceramic-separator" />
                        <div
                            className="leftside-button selected"
                            onMouseOver={(e) => { project.ui.menuInfo = {
                                y: (e.currentTarget as HTMLElement).getClientRects()[0].top,
                                text: 'Fragment Editor'
                            }; }}
                            onMouseOut={() => { project.ui.menuInfo = null; }}
                        >
                            <MdImage size={22} style={{ position: 'relative', left: 0.5, top: 2 }} />
                        </div>
                        {/*<div
                            className="leftside-button"
                            onMouseOver={(e) => { project.ui.menuInfo = {
                                y: (e.currentTarget as HTMLElement).getClientRects()[0].top,
                                text: 'Texture Atlas Editor'
                            }; }}
                            onMouseOut={() => { project.ui.menuInfo = null; }}
                        >
                            <MdGridOn size={20} style={{ position: 'relative', left: 0.5, top: 2.5 }} />
                        </div>*/}
                    </div>
                    <div
                        style={{
                            width: context.width - leftSideWidth,
                            height: context.height - navHeight,
                            position: 'absolute',
                            left: leftSideWidth,
                            top: navHeight
                        }}
                    >
                        <div>
                            <MenuInfo />
                        </div>
                        <EditFragment width={context.width - leftSideWidth} height={context.height - navHeight} />
                    </div>
                </div>
            </div>
        );

    } //render
    
}

export default App;
