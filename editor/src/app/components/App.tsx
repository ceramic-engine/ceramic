import * as React from 'react';
import { observer } from 'mobx-react';
import { project, user } from 'app/model';
import { context } from 'app/context';
import { EditScene, AddVisual, EditSettings, DragOver, MenuInfo, PromptChoice, PromptText, LoadingOverlay } from 'app/components';
import MdImage from 'react-icons/lib/md/image';
import MdGridOn from 'react-icons/lib/md/grid-on';

@observer class App extends React.Component {

/// Lifecycle

    render() {

        const navHeight = 23;
        const leftSideWidth = 44;

        return (
            <div
                style={{
                    position: 'relative',
                    left: 0,
                    top: 0,
                    width: context.width,
                    height: context.height
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
                        {context.draggingOver ?
                            <DragOver />
                        :
                            null
                        }
                        {project.ui.addVisual ?
                            <AddVisual />
                        :
                            null
                        }
                        {project.ui.editSettings ?
                            <EditSettings />
                        :
                            null
                        }
                        {project.ui.promptChoice ?
                            <PromptChoice />
                        :
                            null
                        }
                        {project.ui.promptText ?
                            <PromptText />
                        :
                            null
                        }
                        {project.ui.loadingMessage ?
                            <LoadingOverlay />
                        :
                            null
                        }
                    </div>
                    <div
                        style={{
                            position: 'absolute',
                            left: 0,
                            top: 0,
                            width: '100%',
                            lineHeight: navHeight + 'px',
                            height: navHeight - 1,
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
                    </div>
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
                                text: 'Scene Editor'
                            }; }}
                            onMouseOut={() => { project.ui.menuInfo = null; }}
                        >
                            <MdImage size={22} style={{ position: 'relative', left: 0.5, top: 2 }} />
                        </div>
                        <div
                            className="leftside-button"
                            onMouseOver={(e) => { project.ui.menuInfo = {
                                y: (e.currentTarget as HTMLElement).getClientRects()[0].top,
                                text: 'Texture Atlas Editor'
                            }; }}
                            onMouseOut={() => { project.ui.menuInfo = null; }}
                        >
                            <MdGridOn size={20} style={{ position: 'relative', left: 0.5, top: 2.5 }} />
                        </div>
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
                        <EditScene width={context.width - leftSideWidth} height={context.height - navHeight} />
                    </div>
                </div>
            </div>
        );

    } //render
    
}

export default App;
