import * as React from 'react';
import { observer } from 'utils';
import { Center, Tabs, Form, Panel, Title, NumberInput, Field, Button, Alt } from 'components';
import { Ceramic, AssetInfo, VisualsPanel, FragmentsPanel, AssetsPanel, StatusBar } from 'app/components';
import { project } from 'app/model';
import { context } from 'app/context';

@observer class EditFragment extends React.Component {

    props:{
        /** Available width */
        width:number,
        /** Available height */
        height:number
    };

/// Lifecycle

    componentWillMount() {
        
    } //componentWillMount

    render() {

        let tabHeight = 28;
        let fragment = project.ui.selectedFragment;

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
                        overflowY: 'hidden'
                    }}
                >
                    <div className="rightside">
                        {project.assetsPath != null ?
                            fragment ?
                                <Tabs
                                    tabs={["Visuals", "Fragments", "Assets"]}
                                    active={
                                        function() {
                                            switch(project.ui.fragmentTab) {
                                                case 'visuals': return 0;
                                                case 'fragments': return 1;
                                                case 'assets': return 2;
                                                default: 1;
                                            }
                                            return 0;
                                        }()
                                    }
                                    onChange={
                                        (i) => {
                                            project.ui.fragmentTab = ['visuals', 'fragments', 'assets'][i] as any;
                                        }
                                    }
                                >
                                    <VisualsPanel height={this.props.height - tabHeight} />
                                    <FragmentsPanel height={this.props.height - tabHeight} />
                                    <AssetsPanel height={this.props.height} />
                                </Tabs>
                            :
                                <Tabs
                                    tabs={["Fragments", "Assets"]}
                                    active={
                                        function() {
                                            switch(project.ui.fragmentTab) {
                                                case 'fragments': return 0;
                                                case 'assets': return 1;
                                                default: 0;
                                            }
                                            return 0;
                                        }()
                                    }
                                    onChange={
                                        (i) => {
                                            project.ui.fragmentTab = ['fragments', 'assets'][i] as any;
                                        }
                                    }
                                >
                                    <FragmentsPanel height={this.props.height - tabHeight} />
                                    <AssetsPanel height={this.props.height} />
                                </Tabs>
                        :
                            <Tabs tabs={["Assets"]} active={0} onChange={(i) => {}}>
                                <AssetsPanel height={this.props.height} />
                            </Tabs>
                        }
                    </div>
                </div>
                <div
                    style={{
                        width: this.props.width - 300,
                        height: this.props.height - StatusBar.statusHeight,
                        position: 'absolute',
                        left: 0,
                        top: 0
                    }}
                >
                    <Center>
                        <Ceramic />
                    </Center>
                </div>
                <StatusBar
                    width={this.props.width - 300}
                    top={this.props.height - StatusBar.statusHeight}
                />
            </div>
        );

    } //render
    
}

export default EditFragment;
