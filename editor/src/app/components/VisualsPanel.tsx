import * as React from 'react';
import { observer, arrayMove } from 'utils';
import { Button, Form, Field, Panel, NumberInput, TextInput, ColorInput, SelectInput, Title, Alt, Sortable } from 'components';
import { project, VisualItem, QuadItem } from 'app/model';
import FaLock from 'react-icons/lib/fa/lock';

@observer class VisualsPanel extends React.Component {

    static textAlignList:Array<string> = ['left', 'right', 'center'];

    props:{
        /** Available height */
        height:number
    };

/// Lifecycle

    render() {

        // Typed `selected`
        let selectedVisual = project.ui.selectedVisual;
        let selectedQuad = project.ui.selectedQuad;
        let selectedText = project.ui.selectedText;

        // Textures list
        let texturesList = ['none'];
        let quadTextureIndex = 0;
        let n = 1;
        if (selectedQuad != null && project.imageAssets != null) {
            for (let asset of project.imageAssets) {
                texturesList.push(asset.name);
                if (selectedQuad != null && asset.name === selectedQuad.texture) {
                    quadTextureIndex = n;
                }
                n++;
            }
        }

        // Text align
        var textAlignList = VisualsPanel.textAlignList;
        let textAlignIndex = 0;
        if (selectedText != null) {
            textAlignIndex = Math.max(0, textAlignList.indexOf(selectedText.align));
        }

        // Fonts list

        // Textures list
        let fontsList = ['default'];
        let textFontIndex = 0;
        n = 1;
        if (selectedText != null && project.fontAssets != null) {
            for (let asset of project.fontAssets) {
                fontsList.push(asset.name);
                if (selectedText != null && asset.name === selectedText.font) {
                    textFontIndex = n;
                }
                n++;
            }
        }

        // Explicit sizes?
        let allowExplicitSizes = (selectedQuad != null && quadTextureIndex === 0);

        return (
            <Panel>
                {project.ui.selectedFragment.visualItems.length > 0 ?
                <div>
                <div>
                    <Title>All visuals</Title>
                    <Alt>
                        
                    <div style={{ height: this.props.height * 0.3 - 24 * 2, overflowY: 'auto' }}>

                        <Sortable
                            lockAxis={'y'}
                            distance={5}
                            helperClass={"dragging"}
                            onSortEnd={({oldIndex, newIndex}) => {
                                if (oldIndex === newIndex) return;
                                let visuals = project.ui.selectedFragment.visualItemsSorted.slice();
                                visuals = arrayMove(visuals, oldIndex, newIndex);
                                let depth = 1;
                                for (let i = visuals.length -1; i >= 0; i--) {
                                    visuals[i].depth = depth++;
                                }
                            }}
                        >
                        {project.ui.selectedFragment.visualItemsSorted.length > 0 ?
                            project.ui.selectedFragment.visualItemsSorted.map((visual, i) =>
                                <div
                                    key={i}
                                    className={
                                        'entry in-alt with-separator'
                                        + (project.ui.selectedItemId === visual.id ? ' selected' : '')
                                        + (visual.locked ? ' locked' : '')}
                                    onClick={() => {
                                        if (visual.locked) return;
                                        project.ui.selectedItemId = visual.id;
                                    }}
                                >
                                    <div className="name">
                                    <div className="lock" style={{float: 'right'}}>
                                        <FaLock
                                            onClick={(e) => {
                                                e.stopPropagation();
                                                visual.locked = !visual.locked;
                                                if (visual.locked && visual.id === project.ui.selectedItemId) {
                                                    project.ui.selectedItemId = null;
                                                }
                                            }}
                                            size={14}
                                            style={{ marginTop: 6 }}
                                        />
                                    </div>
                                    {
                                        visual.name
                                    }
                                    </div>
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
                                <div style={{ height: this.props.height * 0.7 - 24 * 2 - 4, overflowY: 'auto' }}>
                                <Form>
                                    {
                                        selectedQuad != null ?
                                        <div className="visual-extra-options">
                                            <Field label="Texture">
                                                <SelectInput
                                                    empty={0}
                                                    selected={quadTextureIndex}
                                                    options={texturesList}
                                                    onChange={(selected) => {
                                                        selectedQuad.texture = selected === 0 ? null : texturesList[selected];
                                                    }}
                                                />
                                            </Field>
                                            <Field label="Color">
                                                <ColorInput value={selectedQuad.hexColor} onChange={(val) => { selectedQuad.setHexColor(val); }} />
                                            </Field>
                                        </div>
                                        :
                                            null
                                    }
                                    {
                                        selectedText != null ?
                                        <div className="visual-extra-options">
                                            <Field label="Content">
                                                <TextInput multiline={true} value={selectedText.content} onChange={(val:string) => { selectedText.content = val; }} />
                                            </Field>
                                            <Field label="Align">
                                                <SelectInput
                                                    selected={textAlignIndex}
                                                    options={textAlignList}
                                                    onChange={(selected) => {
                                                        selectedText.align = textAlignList[selected] as any;
                                                    }}
                                                />
                                            </Field>
                                            <Field label="Point Size">
                                                <NumberInput value={selectedText.pointSize} onChange={(val) => { selectedText.pointSize = val; }} />
                                            </Field>
                                            <Field label="Line Height">
                                                <NumberInput value={selectedText.lineHeight} onChange={(val) => { selectedText.lineHeight = val; }} />
                                            </Field>
                                            <Field label="Letter Spacing">
                                                <NumberInput value={selectedText.letterSpacing} onChange={(val) => { selectedText.letterSpacing = val; }} />
                                            </Field>
                                            <Field label="Font">
                                                <SelectInput
                                                    empty={0}
                                                    selected={textFontIndex}
                                                    options={fontsList}
                                                    onChange={(selected) => {
                                                        selectedText.font = selected === 0 ? null : fontsList[selected];
                                                    }}
                                                />
                                            </Field>
                                            <Field label="Color">
                                                <ColorInput value={selectedText.hexColor} onChange={(val) => { selectedText.setHexColor(val); }} />
                                            </Field>
                                        </div>
                                        :
                                            null
                                    }
                                    <Field label="Name">
                                        <TextInput value={selectedVisual.name} onChange={(val) => { selectedVisual.name = val; }} />
                                    </Field>
                                    {
                                        allowExplicitSizes ?
                                        <div>
                                            <Field label="Width">
                                                <NumberInput disabled={false} value={selectedVisual['explicitWidth']} onChange={(val) => { selectedVisual['explicitWidth'] = val; }} />
                                            </Field>
                                            <Field label="Height">
                                                <NumberInput disabled={false} value={selectedVisual['explicitHeight']} onChange={(val) => { selectedVisual['explicitHeight'] = val; }} />
                                            </Field>
                                        </div>
                                        :
                                        <div>
                                            <Field label="Width">
                                                <NumberInput disabled={true} value={selectedVisual.width} />
                                            </Field>
                                            <Field label="Height">
                                                <NumberInput disabled={true} value={selectedVisual.height} />
                                            </Field>
                                        </div>
                                    }
                                    <Field label="Scale X">
                                        <NumberInput value={selectedVisual.scaleX} onChange={(val) => { selectedVisual.scaleX = val; }} />
                                    </Field>
                                    <Field label="Scale Y">
                                        <NumberInput value={selectedVisual.scaleY} onChange={(val) => { selectedVisual.scaleY = val; }} />
                                    </Field>
                                    <Field label="X">
                                        <NumberInput value={selectedVisual.x} onChange={(val) => { selectedVisual.x = val; }} />
                                    </Field>
                                    <Field label="Y">
                                        <NumberInput value={selectedVisual.y} onChange={(val) => { selectedVisual.y = val; }} />
                                    </Field>
                                    <Field label="Anchor X">
                                        <NumberInput value={selectedVisual.anchorX} onChange={(val) => { selectedVisual.anchorX = val; }} />
                                    </Field>
                                    <Field label="Anchor Y">
                                        <NumberInput value={selectedVisual.anchorY} onChange={(val) => { selectedVisual.anchorY = val; }} />
                                    </Field>
                                    <Field label="Rotation">
                                        <NumberInput value={selectedVisual.rotation} onChange={(val) => { selectedVisual.rotation = val; }} />
                                    </Field>
                                    <Field label="Skew X">
                                        <NumberInput value={selectedVisual.skewX} onChange={(val) => { selectedVisual.skewX = val; }} />
                                    </Field>
                                    <Field label="Skew Y">
                                        <NumberInput value={selectedVisual.skewY} onChange={(val) => { selectedVisual.skewY = val; }} />
                                    </Field>
                                    <Field label="Depth">
                                        <NumberInput value={selectedVisual.depth} onChange={(val) => { selectedVisual.depth = val; }} />
                                    </Field>
                                    <Field label="Alpha">
                                        <NumberInput value={selectedVisual.alpha} onChange={(val) => { selectedVisual.alpha = val; }} />
                                    </Field>
                                </Form>
                                </div>
                            </Alt>
                        </div>
                    :
                        <div>
                            <Title>Nothing selected</Title>
                        </div>
                }
                </div>
                : null}
                <Form>
                    <Field>
                        <Button
                            value="Add visual"
                            onClick={() => { project.ui.addVisual = true; }}
                        />
                    </Field>
                </Form>
            </Panel>
        );

    } //render
    
}

export default VisualsPanel;
