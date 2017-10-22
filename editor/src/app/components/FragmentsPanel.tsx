import * as React from 'react';
import { observer, arrayMove } from 'utils';
import { Button, Form, Field, Panel, NumberInput, SelectInput, TextInput, Title, Alt, Sortable } from 'components';
import { project } from 'app/model';

@observer class FragmentsPanel extends React.Component {

    props:{
        /** Available height */
        height:number
    };

/// Lifecycle

    render() {

        let selectedFragment = project.ui.selectedFragment;
        let fragmentBundleIndex = 0;
        let fragmentBundleList:Array<string> = [];
        if (project.defaultFragmentBundle) {
            fragmentBundleList.push(project.defaultFragmentBundle + '.fragments');
        } else {
            fragmentBundleList.push('default');
        }
        let n = 1;
        for (let bundle of project.fragmentBundles) {
            if (selectedFragment != null && bundle === selectedFragment.bundle) {
                fragmentBundleIndex = n;
            }
            fragmentBundleList.push(bundle + '.fragments');
            n++;
        }

        return (
            <Panel>

                <div>
                    <Title>All fragments</Title>
                    <Alt>
                        
                    <div style={{ height: this.props.height * 0.3 - 24 * 2, overflowY: 'auto' }}>

                        <Sortable
                            lockAxis={'y'}
                            distance={5}
                            helperClass={"dragging"}
                            onSortEnd={({oldIndex, newIndex}) => {
                                if (oldIndex === newIndex) return;
                                let fragments = project.fragments.slice();
                                fragments = arrayMove(fragments, oldIndex, newIndex);
                                project.fragments = fragments;
                            }}
                        >
                        {project.fragments.length > 0 ?
                            project.fragments.map((fragment, i) =>
                                <div
                                    key={i}
                                    className={
                                        'entry in-alt with-separator'
                                        + (project.ui.selectedFragmentId === fragment.id ? ' selected' : '')}
                                    onClick={() => {
                                        project.ui.selectedFragmentId = fragment.id;
                                    }}
                                >
                                    <div className="name">
                                    {
                                        fragment.name
                                    }
                                    </div>
                                    <div className="info">{
                                        fragment.bundle != null ?
                                            fragment.bundle + '.fragments'
                                        :
                                            (project.defaultFragmentBundle ?
                                                project.defaultFragmentBundle + '.fragments'
                                            : 'default')
                                    }</div>
                                </div>
                            )
                        : null}
                        </Sortable>
                    </div>
                    </Alt>
                </div>
                {selectedFragment ?
                <div>
                    <Title>Selected fragment</Title>
                    <Alt>
                        <Form>
                            <Field label="Name">
                                <TextInput value={selectedFragment.name} onChange={(val) => { selectedFragment.name = val; }} />
                            </Field>
                            <Field label="Width">
                                <NumberInput value={selectedFragment.width} onChange={(val) => { selectedFragment.width = val; }} />
                            </Field>
                            <Field label="Height">
                                <NumberInput value={selectedFragment.height} onChange={(val) => { selectedFragment.height = val; }} />
                            </Field>
                            <Field label="Bundle">
                                <SelectInput
                                    empty={0}
                                    selected={fragmentBundleIndex}
                                    options={fragmentBundleList}
                                    onChange={(selected) => {
                                        selectedFragment.bundle = selected === 0 ? null : fragmentBundleList[selected].substr(0, fragmentBundleList[selected].length - '.fragments'.length);
                                    }}
                                />
                            </Field>
                        </Form>
                    </Alt>
                </div>
                : null}
                <div>
                    <Title>Fragment bundles</Title>
                    <Alt>
                        <Form>
                            <Field label="Custom bundles">
                                <TextInput
                                    multiline={true}
                                    separator={','}
                                    placeholder={"Bundle1, Bundle2\u2026"}
                                    value={project.fragmentBundles.join(",\n")}
                                    onChange={(val) => {
                                        let result = [];
                                        for (let item of val.split(",").join("\n").split("\n")) {
                                            let trimmed = item.trim();
                                            if (trimmed.length > 0) {
                                                result.push(trimmed);
                                            }
                                        }
                                        project.fragmentBundles = result;
                                    }}
                                />
                            </Field>
                        </Form>
                    </Alt>
                </div>
                <Form>
                    <Field>
                        <Button
                            value="Add fragment"
                            onClick={() => { project.createFragment(); }}
                        />
                    </Field>
                </Form>
            </Panel>
        );

    } //render
    
}

export default FragmentsPanel;
