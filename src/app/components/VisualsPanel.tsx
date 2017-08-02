import * as React from 'react';
import { observer, arrayMove } from 'utils';
import { Button, Form, Field, Panel, NumberInput, SelectInput, Title, Alt, Sortable } from 'components';
import { project, VisualItem, QuadItem } from 'app/model';
import FaLock from 'react-icons/lib/fa/lock';

@observer class VisualsPanel extends React.Component {

    props:{
        /** Available height */
        height:number
    };

/// Lifecycle

    render() {

        let selectedVisual = project.ui.selectedVisual;
        let selectedQuad = project.ui.selectedQuad;

        let texturesList = ['none'];
        let quadTextureIndex = 0;
        let n = 1;
        for (let asset of project.imageAssets) {
            texturesList.push(asset.name);
            if (selectedQuad != null && asset.name === selectedQuad.texture) {
                quadTextureIndex = n;
            }
            n++;
        }

        return (
            <Panel>
                <div>
                    <Title>All visuals</Title>
                    <Alt>
                        
                    <div style={{ height: this.props.height * 0.3 - 24, overflowY: 'auto' }}>

                        <Sortable
                            lockAxis={'y'}
                            distance={5}
                            onSortEnd={({oldIndex, newIndex}) => {
                                let visuals = project.scene.visualItemsSorted.slice();
                                visuals = arrayMove(visuals, oldIndex, newIndex);
                                if (oldIndex < newIndex) {
                                    let depth = visuals[newIndex-1].depth;
                                    if (newIndex < visuals.length - 1) {
                                        depth = (depth + visuals[newIndex+1].depth) * 0.5;
                                    } else {
                                        depth--;
                                    }
                                    visuals[newIndex].depth = depth;
                                }
                                else {
                                    let depth = visuals[newIndex+1].depth;
                                    if (newIndex > 0) {
                                        depth = (depth + visuals[newIndex-1].depth) * 0.5;
                                    } else {
                                        depth++;
                                    }
                                    visuals[newIndex].depth = depth;
                                }
                            }}
                        >
                        {project.scene.visualItemsSorted.length > 0 ?
                            project.scene.visualItemsSorted.map((visual, i) =>
                                <div
                                    key={i}
                                    className={
                                        'entry in-alt with-separator'
                                        + (project.ui.selectedItemName === visual.name ? ' selected' : '')}
                                    onClick={() => { project.ui.selectedItemName = visual.name; }}
                                >
                                    <div className="name">
                                    <div style={{color: '#888', float: 'right'}}><FaLock size={12} /></div>
                                    {
                                        visual.entity.split('ceramic.').join('')
                                        +
                                        (visual instanceof QuadItem && visual.texture != null ?
                                            ' (' + visual.texture + ')'
                                        :
                                            '')
                                    }</div>
                                    <div className="info">{
                                        'x='+visual.x+
                                        ' y='+visual.y
                                    }</div>
                                </div>
                            )
                        : null}
                        </Sortable>
                    </div>
                    </Alt>
                </div>
                {
                    selectedVisual != null
                    ?
                        <div>
                            <Title>Selected {selectedVisual.entity.split('ceramic.').join('').toLowerCase()}</Title>
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
                                    <Field label="depth">
                                        <NumberInput value={selectedVisual.depth} onChange={(val) => { selectedVisual.depth = val; }} />
                                    </Field>
                                    <Field label="alpha">
                                        <NumberInput value={selectedVisual.alpha} onChange={(val) => { selectedVisual.alpha = val; }} />
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
                        <div>
                            <Title>Nothing selected</Title>
                        </div>
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
