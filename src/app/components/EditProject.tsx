import * as React from 'react';
import { observer, observe, autobind } from 'utils';
import { Center } from 'components';
import { Ceramic, ScenePanel, VisualsPanel } from 'app/components';
import { project } from 'app/model';
import { Collapse } from 'antd';

@observer class EditProject extends React.Component {

    @observe activePanels:Map<string, boolean> = new Map();

/// Lifecycle

    constructor(public props:{width:number}) {

        super();

    } //constructor

    componentWillMount() {

        this.activePanels.set('1', true);
        this.activePanels.set('2', true);
        
    } //componentWillMount

    render() {

        let activePanels:Array<string> = [];
        this.activePanels.forEach((_, key) => {
            activePanels.push(key);
        });

        const panelStyle = {
        };

        console.log("RENDER -> " + JSON.stringify(activePanels));

        return (
            <div
                style={{
                    position: 'relative',
                    width: '100%',
                    height: '100%'
                }}
            >
                <div
                    style={{
                        width: '300px',
                        height: '100%',
                        position: 'absolute',
                        left: (this.props.width - 300) + 'px',
                        top: 0,
                        overflowY: 'auto'
                    }}
                >
                    <div className="rightside">
                        <Collapse bordered={false} onChange={this.handlePanels} activeKey={activePanels}>

                            <Collapse.Panel header="Scene" key="1" style={panelStyle}>
                                <ScenePanel data={project.scene} />
                            </Collapse.Panel>

                            <Collapse.Panel header="Visuals" key="2" style={panelStyle}>
                                <VisualsPanel data={project.scene} />
                            </Collapse.Panel>

                        </Collapse>
                    </div>
                </div>
                <div
                    style={{
                        width: (this.props.width - 300) + 'px',
                        height: '100%',
                        position: 'absolute',
                        left: 0,
                        top: 0
                    }}
                >
                    <Center>
                        <Ceramic />
                    </Center>
                </div>
            </div>
        );

    } //render

    @autobind handlePanels(event:any) {

        var newPanels = event as Array<string>;
        this.activePanels.clear();

        // Add new keys
        for (let key of newPanels) {
            this.activePanels.set(key, true);
        }

    } //handlePanels
    
}

export default EditProject;
