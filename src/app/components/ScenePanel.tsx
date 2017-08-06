import * as React from 'react';
import { observer } from 'utils';
import { Button, Form, Field, Panel, NumberInput, Title, Alt } from 'components';
import { project } from 'app/model';

@observer class ScenePanel extends React.Component {

/// Lifecycle

    render() {

        return (
            <Panel>
                <Title>Scene properties</Title>
                <Alt>
                    <Form>
                        <Field label="width">
                            <NumberInput value={project.scene.width} onChange={(val) => { project.scene.width = val; }} />
                        </Field>
                        <Field label="height">
                            <NumberInput value={project.scene.height} onChange={(val) => { project.scene.height = val; }} />
                        </Field>
                    </Form>
                </Alt>
            </Panel>
        );

    } //render
    
}

export default ScenePanel;
