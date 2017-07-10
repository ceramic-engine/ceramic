import * as React from 'react';
import { observer } from 'mobx-react';
import { Button, Menu, Icon } from 'antd';
import { Center } from 'components';
import { project } from 'app/model';
import { context } from 'app/context';
import { CreateProject, EditProject } from 'app/components';

project.setProjectPath("/Users/jeremyfa/Documents/SCENES/Test01"); // TODO remove

@observer class App extends React.Component {

/// Lifecycle

    render() {

        const navHeight = 22;
        const leftSideWidth = 32;

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
                    <Menu
                        mode="horizontal"
                        style={{
                            position: 'absolute',
                            width: '100%',
                            zIndex: 999,
                            lineHeight: navHeight + 'px',
                            height: (navHeight + 1) + 'px',
                            WebkitAppRegion: 'drag'
                        }}
                        selectedKeys={project.path != null ? ["1"] : []}
                        className="topnav"
                    >
                        { project.path == null ? (
                            project.name != null ? (
                                <Menu.Item
                                    key="1"
                                    style={{ WebkitAppRegion: 'no-drag' }}
                                >
                                    <Icon type="folder-open" style={{ position: 'relative', top: '1px' }} />{project.name}
                                </Menu.Item>
                            ) : (
                                <Menu.Item
                                    key="1"
                                    style={{ WebkitAppRegion: 'no-drag' }}
                                >
                                    <Icon type="folder-open" style={{ position: 'relative', top: '1px' }} />New project
                                </Menu.Item>
                            )
                        ) : null }
                    </Menu>
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
                            project.name == null ? <CreateProject /> : <EditProject width={context.width - leftSideWidth} />
                        ) }
                    </div>
                </div>
            </div>
        );

    } //render
    
}

export default App;
