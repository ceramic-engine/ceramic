import * as React from 'react';
import { observer, arrayMove } from 'utils';
import { Button, Form, Field, Panel, NumberInput, TextInput, ColorInput, SelectInput, Title, Alt, Sortable } from 'components';
import { FragmentItemField } from 'app/components';
import { project, VisualItem, Fragment } from 'app/model';
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

        // Fragment overrides?
        let fragmentOverrides:Array<{key:string, value:string}> = [];
        let isFragment = selectedVisual && selectedVisual.entity === 'ceramic.Fragment';
        let fragment:Fragment = null;
        let fragmentData = null;
        if (isFragment) {
            fragmentData = selectedVisual.props.get('fragmentData');
            if (fragmentData != null && project.fragments != null) {

                for (let aFragment of project.fragments) {
                    if (fragmentData.id === aFragment.id) {
                        fragment = aFragment;
                        break;
                    }
                }
            }
            if (fragment != null && fragment.overrides != null) {
                fragment.overrides.forEach((value, key) => {
                    fragmentOverrides.push({
                        key: key,
                        value: value
                    });
                });
            }
        }

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
                                    visuals[i].props.set('depth', depth++);
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
                                        visual.entity
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
                            <Title>Selected {this.simpleName(selectedVisual.entity, true)}</Title>
                            <Alt>
                                <div style={{ height: this.props.height * 0.7 - 24 * 2 - 4, overflowY: 'auto' }}>
                                <Form>
                                    <Field label="name">
                                        <TextInput value={selectedVisual.name} onChange={(val) => { selectedVisual.name = val; }} />
                                    </Field>
                                    {this.mapEntries(selectedVisual.props).map((entry) => 
                                        <FragmentItemField key={entry.key} item={selectedVisual} field={entry.key} />
                                    )}
                                    {fragmentOverrides.map((entry) => 
                                        <FragmentItemField key={entry.key} item={selectedVisual} field={entry.key} overridesFragment={fragment} />
                                    )}
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

/// Helpers

    simpleName(inName:string, lowercaseFirst:boolean = false):string {

        let dotIndex = inName.lastIndexOf('.');
        if (dotIndex !== -1) inName = inName.slice(dotIndex + 1);

        if (lowercaseFirst) {
            inName = inName.slice(0, 1).toLowerCase() + inName.slice(1);
        }

        return inName;

    } //simpleName

    mapEntries(map:Map<string,any>):Array<{key:string, value:any}> {

        let entries:Array<{key:string, value:any}> = [];

        map.forEach((value, key) => {
            entries.push({ key, value });
        });

        return entries;

    } //mapEntries
    
}

export default VisualsPanel;
