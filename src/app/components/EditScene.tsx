import * as React from 'react';
import { observer } from 'utils';
import { Center, Tabs, Form, Panel, Title, NumberInput, Field, Button, Alt } from 'components';
import { Ceramic, AssetInfo, VisualsPanel, ScenePanel, AssetsPanel } from 'app/components';
import { project } from 'app/model';
import { context } from 'app/context';

@observer class EditScene extends React.Component {

    props:{
        /** Available width */
        width:number,
        /** Available height */
        height:number
    };

    panelTabs = ["Scene", "Visuals", "Assets"];

/// Lifecycle

    componentWillMount() {
        
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
                <div>
                    <AssetInfo />
                </div>
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
                        <Tabs tabs={this.panelTabs} active={project.ui.sceneTab} onChange={(i) => { project.ui.sceneTab = i; }}>
                            <ScenePanel />
                            <VisualsPanel height={this.props.height - 28 /* tab height */} />
                            <AssetsPanel height={this.props.height} />
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
                        height: statusHeight - 1,
                        position: 'absolute',
                        left: 0,
                        top: this.props.height - statusHeight
                    }}
                />
            </div>
        );

    } //render
    
}

export default EditScene;
