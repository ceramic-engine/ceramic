import * as React from 'react';
import { observer, observe, autobind } from 'utils';
import { Center, Tabs, Panel, NumberInput, Field } from 'components';
import { Ceramic } from 'app/components';
import { project } from 'app/model';

@observer class EditScene extends React.Component {

    @observe activePanels:Map<string, boolean> = new Map();

    props:{
        /** Available width */
        width:number,
        /** Available height */
        height:number
    };

    panelTabs = ["Scene", "Visuals", "Assets"];

/// Lifecycle

    componentWillMount() {

        this.activePanels.set('1', true);
        this.activePanels.set('2', true);
        
    } //componentWillMount

    render() {

        let statusHeight = 16;

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
                        <Tabs tabs={this.panelTabs}>
                            <Panel>
                                <Field label="width">
                                    <NumberInput value={project.scene.width} onChange={(val) => { project.scene.width = val; }} />
                                </Field>
                                <Field label="height">
                                    <NumberInput value={project.scene.height} onChange={(val) => { project.scene.height = val; }} />
                                </Field>
                            </Panel>
                            <Panel>
                                <p>blah2</p>
                            </Panel>
                            <Panel>
                                <p>blah3</p>
                            </Panel>
                        </Tabs>
                    </div>
                </div>
                <div
                    style={{
                        width: this.props.width - 300,
                        height: this.props.height - statusHeight,
                        position: 'absolute',
                        left: 0,
                        top: 0
                    }}
                >
                    <Center>
                        <Ceramic />
                    </Center>
                </div>
                <div
                    className="statusbar"
                    style={{
                        width: this.props.width - 300,
                        height: statusHeight,
                        position: 'absolute',
                        left: 0,
                        top: this.props.height - statusHeight
                    }}
                />
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

export default EditScene;
