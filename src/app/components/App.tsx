import * as React from 'react';
import { observer } from 'mobx-react';
import { Button } from 'antd';
import { Center } from 'components';
import { project } from 'app/model';
import { context } from 'app/context';
import { CreateProject, EditProject } from 'app/components';

project.setProjectPath("/Users/jeremyfa/Documents/SCENES/Test01"); // TODO remove

@observer class App extends React.Component {

/// Lifecycle

    render() {

        const navHeight = 22;
        const leftSideWidth = 44;

        return (
            <div
                style={{
                    position: 'relative',
                    left: 0,
                    top: 0
                }}
            >
                <div
                    style={{
                        width: context.width,
                        height: '100%',
                        position: 'absolute',
                        left: 0,
                        top: 0
                    }}
                >
                    <div
                        style={{
                            position: 'absolute',
                            left: 0,
                            top: 0,
                            width: '100%',
                            zIndex: 999,
                            lineHeight: navHeight + 'px',
                            height: navHeight,
                            WebkitAppRegion: 'drag',
                            textAlign: 'center'
                        }}
                        className="topnav"
                    >
                        { project.path != null ? (
                            project.name != null ? (
                                <span>{project.name}</span>
                            ) : (
                                <span>New project</span>
                            )
                        ) : null }
                    </div>
                    <div
                        className="leftside"
                        style={{
                            width: leftSideWidth,
                            height: context.height - navHeight,
                            position: 'absolute',
                            left: 0,
                            top: navHeight
                        }}
                    />
                    <div
                        style={{
                            width: context.width - leftSideWidth,
                            height: context.height - navHeight,
                            position: 'absolute',
                            left: leftSideWidth,
                            top: navHeight
                        }}
                    >
                        { project.path == null ? (
                            <Center>
                                <div style={{ width: 300 }}>
                                    <Button
                                        icon="folder"
                                        size="large"
                                        type="primary"
                                        onClick={project.chooseDirectory}
                                        style={{ height: '55px', width: '250px' }}
                                    >
                                        Select project directory
                                    </Button>
                                </div>
                            </Center>
                        ) : (
                            project.name == null ? <CreateProject /> : <EditProject width={context.width - leftSideWidth} height={context.height - navHeight} />
                        ) }
                    </div>
                </div>
            </div>
        );

    } //render
    
}

export default App;
