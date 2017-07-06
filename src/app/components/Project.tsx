import * as React from 'react';
import { observer } from 'mobx-react';
import { Button, Menu, Icon } from 'antd';
import { Center } from 'components';
import { project } from 'app/model';
import { context } from 'app/context';
import { CreateProject, EditProject } from 'app/components';

project.setProjectPath("/Users/jeremyfa/Documents/SCENES/Test01"); // TODO remove

@observer class Project extends React.Component {

/// Lifecycle

    render() {

        return (
            <div style={{ width: '100%', height: '100%' }}>
                <Menu
                    mode="horizontal"
                    style={{
                        position: 'absolute',
                        lineHeight: '22px',
                        height: '23px',
                        width: '100%',
                        zIndex: 999,
                        paddingLeft: context.fullscreen ? '0px' : '80px',
                        WebkitAppRegion: 'drag'
                    }}
                    selectedKeys={project.path != null ? ["1"] : []}
                >
                    { project.path != null ? (
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
                <div style={{ height: '22px' }} />
                <div style={{ height: (context.height - 22) + 'px' }}>
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
                        project.name == null ? <CreateProject /> : <EditProject />
                    ) }
                </div>
            </div>
        );

    } //render
    
}

export default Project;
