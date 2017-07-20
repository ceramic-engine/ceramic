import * as React from 'react';
import { observer, autobind } from 'utils';
import { Button, Inline } from 'components';
import Overlay from './Overlay';
import Dialog from './Dialog';
import { project, VisualItem } from 'app/model';

@observer class AddVisual extends React.Component {

/// Lifecycle

    render() {

        return (
            <Overlay>
                <Dialog title="Add visual">
                    <Inline><Button kind="square" value="Quad" onClick={this.addQuad} /></Inline>
                    <Inline><Button kind="square" value="Text" /></Inline>
                    <div style={{ height: 12 }} />
                    <Button value="Cancel" onClick={() => { project.ui.addingVisual = false; }} />
                </Dialog>
            </Overlay>
        );

    } //render

/// Add

    @autobind addQuad() {

        let quad = new VisualItem(); // TODO make better ID
        quad.name = quad.id;
        quad.entity = 'ceramic.Quad';
        quad.x = Math.round(project.scene.width / 2);
        quad.y = Math.round(project.scene.height / 2);

        while (project.scene.items.length > 0) {
            project.scene.items.shift();
        }
        project.scene.items.push(quad);

        project.ui.addingVisual = false;

    } //addQuad
    
}

export default AddVisual;
