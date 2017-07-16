import * as React from 'react';
import { observer } from 'utils';
import { Center, Tabs, Form, Panel, Title, NumberInput, Field, Button, Alt } from 'components';
import { Ceramic, AssetInfo } from 'app/components';
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
                            <Panel>
                                <Form>
                                    <Field label="width">
                                        <NumberInput value={project.scene.width} onChange={(val) => { project.scene.width = val; }} />
                                    </Field>
                                    <Field label="height">
                                        <NumberInput value={project.scene.height} onChange={(val) => { project.scene.height = val; }} />
                                    </Field>
                                </Form>
                            </Panel>
                            <Panel>
                                <Form>
                                    <Field>
                                        <Button
                                            value="Add visual"
                                            onClick={() => { project.ui.addingVisual = true; }}
                                        />
                                    </Field>
                                </Form>
                            </Panel>
                            <Panel>
                                <div style={{ maxHeight: this.props.height - 28, overflowY: 'auto' }}>
                                {(
                                    context.ceramicReady ?
                                        project.allAssets != null ?
                                            <div>
                                                <Title>Images</Title>
                                                <Alt>
                                                    {project.imageAssets.map((val, i) =>
                                                        <div key={i} className="entry" onMouseOver={() => { project.ui.expandedAsset = val; }} onMouseOut={() => { project.ui.expandedAsset = null; }}>
                                                            <div className="name">{val.name}</div>
                                                            <div className="info">{val.paths.join(', ')}</div>
                                                        </div>
                                                    )}
                                                </Alt>
                                                <Title>Texts</Title>
                                                <Alt>
                                                    {project.textAssets.map((val, i) =>
                                                        <div key={i} className="entry">
                                                            <div className="name">{val.name}</div>
                                                            <div className="info">{val.paths.join(', ')}</div>
                                                        </div>
                                                    )}
                                                </Alt>
                                                <Title>Sounds</Title>
                                                <Alt>
                                                    {project.soundAssets.map((val, i) =>
                                                        <div key={i} className="entry">
                                                            <div className="name">{val.name}</div>
                                                            <div className="info">{val.paths.join(', ')}</div>
                                                        </div>
                                                    )}
                                                </Alt>
                                                <Title>Fonts</Title>
                                                <Alt>
                                                    {project.fontAssets.map((val, i) =>
                                                        <div key={i} className="entry">
                                                            <div className="name">{val.name}</div>
                                                            <div className="info">{val.paths.join(', ')}</div>
                                                        </div>
                                                    )}
                                                </Alt>
                                            </div>
                                        :
                                        <Form>
                                            <Field>
                                                <Button
                                                    kind="dashed"
                                                    value="Choose directory"
                                                    onClick={() => { project.chooseAssetsPath(); }}
                                                />
                                            </Field>
                                        </Form>
                                    :
                                        null
                                )}
                                </div>
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
    
}

export default EditScene;
