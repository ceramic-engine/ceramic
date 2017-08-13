import * as React from 'react';
import { observer } from 'utils';
import { Button, Form, Field, Panel, NumberInput, Title, Alt } from 'components';
import { project } from 'app/model';

@observer class ScenesPanel extends React.Component {

/// Lifecycle

    render() {

        return (
            <Panel>
                {project.ui.selectedScene ?
                <div>
                    <Title>Scene properties</Title>
                    <Alt>
                        <Form>
                            <Field label="width">
                                <NumberInput value={project.ui.selectedScene.width} onChange={(val) => { project.ui.selectedScene.width = val; }} />
                            </Field>
                            <Field label="height">
                                <NumberInput value={project.ui.selectedScene.height} onChange={(val) => { project.ui.selectedScene.height = val; }} />
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
