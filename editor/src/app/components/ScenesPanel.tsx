import * as React from 'react';
import { observer, arrayMove } from 'utils';
import { Button, Form, Field, Panel, NumberInput, SelectInput, TextInput, Title, Alt, Sortable } from 'components';
import { project } from 'app/model';

@observer class ScenesPanel extends React.Component {

    props:{
        /** Available height */
        height:number
    };

/// Lifecycle

    render() {

        let selectedScene = project.ui.selectedScene;
        let sceneBundleIndex = 0;
        let sceneBundleList:Array<string> = [];
        if (project.defaultSceneBundle) {
            sceneBundleList.push(project.defaultSceneBundle + '.scenes');
        } else {
            sceneBundleList.push('default');
        }
        let n = 1;
        for (let bundle of project.sceneBundles) {
            if (selectedScene != null && bundle === selectedScene.bundle) {
                sceneBundleIndex = n;
            }
            sceneBundleList.push(bundle + '.scenes');
            n++;
        }

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
                                        scene.bundle != null ?
                                            scene.bundle + '.scenes'
                                        :
                                            (project.defaultSceneBundle ?
                                                project.defaultSceneBundle + '.scenes'
                                            : 'default')
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
                            <Field label="Name">
                                <TextInput value={selectedScene.name} onChange={(val) => { selectedScene.name = val; }} />
                            </Field>
                            <Field label="Width">
                                <NumberInput value={selectedScene.width} onChange={(val) => { selectedScene.width = val; }} />
                            </Field>
                            <Field label="Height">
                                <NumberInput value={selectedScene.height} onChange={(val) => { selectedScene.height = val; }} />
                            </Field>
                            <Field label="Bundle">
                                <SelectInput
                                    empty={0}
                                    selected={sceneBundleIndex}
                                    options={sceneBundleList}
                                    onChange={(selected) => {
                                        selectedScene.bundle = selected === 0 ? null : sceneBundleList[selected].substr(0, sceneBundleList[selected].length - '.scenes'.length);
                                    }}
                                />
                            </Field>
                        </Form>
                    </Alt>
                </div>
                : null}
                <div>
                    <Title>Scene bundles</Title>
                    <Alt>
                        <Form>
                            <Field label="Custom bundles">
                                <TextInput
                                    multiline={true}
                                    separator={','}
                                    placeholder={"Bundle1, Bundle2\u2026"}
                                    value={project.sceneBundles.join(",\n")}
                                    onChange={(val) => {
                                        let result = [];
                                        for (let item of val.split(",").join("\n").split("\n")) {
                                            let trimmed = item.trim();
                                            if (trimmed.length > 0) {
                                                result.push(trimmed);
                                            }
                                        }
                                        project.sceneBundles = result;
                                    }}
                                />
                            </Field>
                        </Form>
                    </Alt>
                </div>
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
