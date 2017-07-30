import * as React from 'react';
import { observer } from 'utils';
import { Button, Form, Field, Panel, NumberInput, SelectInput, Title, Alt } from 'components';
import { project, VisualItem, QuadItem } from 'app/model';

@observer class VisualsPanel extends React.Component {

/// Lifecycle

    render() {

        let selectedVisual:VisualItem = null;
        let selectedQuad:QuadItem = null;
        if (project.ui.selectedItem != null) {
            if (project.ui.selectedItem instanceof VisualItem) {
                selectedVisual = project.ui.selectedItem;
            }
            if (project.ui.selectedItem instanceof QuadItem) {
                selectedQuad = project.ui.selectedItem;
            }
        }

        let texturesList = ['none'];
        let quadTextureIndex = 0;
        let i = 1;
        for (let asset of project.imageAssets) {
            texturesList.push(asset.name);
            if (selectedQuad != null && asset.name === selectedQuad.texture) {
                quadTextureIndex = i;
            }
            i++;
        }

        return (
            <Panel>
                {
                    selectedVisual != null
                    ?
                        <div>
                            <Title>Selected visual</Title>
                            <Alt>
                                <Form>
                                    <Field label="width">
                                        <NumberInput disabled={quadTextureIndex !== 0} value={selectedVisual.width} onChange={(val) => { selectedVisual.width = val; }} />
                                    </Field>
                                    <Field label="height">
                                        <NumberInput disabled={quadTextureIndex !== 0} value={selectedVisual.height} onChange={(val) => { selectedVisual.height = val; }} />
                                    </Field>
                                    <Field label="scaleX">
                                        <NumberInput value={selectedVisual.scaleX} onChange={(val) => { selectedVisual.scaleX = val; }} />
                                    </Field>
                                    <Field label="scaleY">
                                        <NumberInput value={selectedVisual.scaleY} onChange={(val) => { selectedVisual.scaleY = val; }} />
                                    </Field>
                                    <Field label="x">
                                        <NumberInput value={selectedVisual.x} onChange={(val) => { selectedVisual.x = val; }} />
                                    </Field>
                                    <Field label="y">
                                        <NumberInput value={selectedVisual.y} onChange={(val) => { selectedVisual.y = val; }} />
                                    </Field>
                                    <Field label="anchorX">
                                        <NumberInput value={selectedVisual.anchorX} onChange={(val) => { selectedVisual.anchorX = val; }} />
                                    </Field>
                                    <Field label="anchorY">
                                        <NumberInput value={selectedVisual.anchorY} onChange={(val) => { selectedVisual.anchorY = val; }} />
                                    </Field>
                                    <Field label="rotation">
                                        <NumberInput value={selectedVisual.rotation} onChange={(val) => { selectedVisual.rotation = val; }} />
                                    </Field>
                                    <Field label="skewX">
                                        <NumberInput value={selectedVisual.skewX} onChange={(val) => { selectedVisual.skewX = val; }} />
                                    </Field>
                                    <Field label="skewY">
                                        <NumberInput value={selectedVisual.skewY} onChange={(val) => { selectedVisual.skewY = val; }} />
                                    </Field>
                                    {
                                        selectedQuad != null ?
                                            <Field label="texture">
                                                <SelectInput
                                                    empty={0}
                                                    selected={quadTextureIndex}
                                                    options={texturesList}
                                                    onChange={(selected) => {
                                                        selectedQuad.texture = selected === 0 ? null : texturesList[selected];
                                                    }}
                                                />
                                            </Field>
                                        :
                                            null
                                    }
                                </Form>
                            </Alt>
                        </div>
                    :
                        null
                }
                <Form>
                    <Field>
                        <Button
                            value="Add visual"
                            onClick={() => { project.ui.addingVisual = true; }}
                        />
                    </Field>
                </Form>
            </Panel>
        );

    } //render
    
}

export default VisualsPanel;
