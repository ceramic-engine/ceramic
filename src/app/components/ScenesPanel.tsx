import * as React from 'react';
import { observer, arrayMove } from 'utils';
import { Button, Form, Field, Panel, NumberInput, TextInput, Title, Alt, Sortable } from 'components';
import { project } from 'app/model';

@observer class ScenesPanel extends React.Component {

    props:{
        /** Available height */
        height:number
    };

/// Lifecycle

    render() {

        let selectedScene = project.ui.selectedScene;

        return (
            <Panel>

                <div>
                    <Title>All scenes</Title>
                    <Alt>
                        
                    <div style={{ height: this.props.height * 0.3 - 24 * 2, overflowY: 'auto' }}>

                        <Sortable
                            lockAxis={'y'}
                            distance={5}
                            helperClass={"dragging"}
                            onSortEnd={({oldIndex, newIndex}) => {
                                if (oldIndex === newIndex) return;
                                let scenes = project.scenes.slice();
                                scenes = arrayMove(scenes, oldIndex, newIndex);
                                project.scenes = scenes;
                            }}
                        >
                        {project.scenes.length > 0 ?
                            project.scenes.map((scene, i) =>
                                <div
                                    key={i}
                                    className={
                                        'entry in-alt with-separator'
                                        + (project.ui.selectedSceneId === scene.id ? ' selected' : '')}
                                    onClick={() => {
                                        project.ui.selectedSceneId = scene.id;
                                    }}
                                >
                                    <div className="name">
                                    {
                                        scene.name
                                    }
                                    </div>
                                    <div className="info">{
                                        'scene info'
                                    }</div>
                                </div>
                            )
                        : null}
                        </Sortable>
                    </div>
                    </Alt>
                </div>
                {selectedScene ?
                <div>
                    <Title>Selected scene</Title>
                    <Alt>
                        <Form>
                            <Field label="name">
                                <TextInput value={selectedScene.name} onChange={(val) => { selectedScene.name = val; }} />
                            </Field>
                            <Field label="width">
                                <NumberInput value={selectedScene.width} onChange={(val) => { selectedScene.width = val; }} />
                            </Field>
                            <Field label="height">
                                <NumberInput value={selectedScene.height} onChange={(val) => { selectedScene.height = val; }} />
                            </Field>
                        </Form>
                    </Alt>
                </div>
                : null}
                <Form>
                    <Field>
                        <Button
                            value="Add scene"
                            onClick={() => { project.createScene(); }}
                        />
                    </Field>
                </Form>
            </Panel>
        );

    } //render
    
}

export default ScenesPanel;
