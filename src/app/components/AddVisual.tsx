import * as React from 'react';
import { observer, autobind, ceramic } from 'utils';
import { Button, Inline } from 'components';
import Overlay from './Overlay';
import Dialog from './Dialog';
import { project, VisualItem, QuadItem, TextItem } from 'app/model';

@observer class AddVisual extends React.Component {

/// Lifecycle

    render() {

        return (
            <Overlay>
                <Dialog title="Add visual">
                    <Inline><Button kind="square" value="Quad" onClick={this.addQuad} /></Inline>
                    <Inline><Button kind="square" value="Text" onClick={this.addText} /></Inline>
                    <div style={{ height: 12 }} />
                    <Button value="Cancel" onClick={() => { project.ui.addingVisual = false; }} />
                </Dialog>
            </Overlay>
        );

    } //render

/// Add

    @autobind addQuad() {

        let quad = new QuadItem();
        quad.name = quad.id;
        quad.entity = 'ceramic.Quad';
        quad.x = Math.round(project.scene.width / 2);
        quad.y = Math.round(project.scene.height / 2);
        
        var maxDepth = 0;
        for (let item of project.scene.items) {
            if (item instanceof VisualItem)
            if (item.depth > maxDepth) {
                maxDepth = item.depth;
            }
        }

        quad.depth = maxDepth + 1;

        project.scene.items.push(quad);

        // Select visual
        project.ui.selectedItemName = quad.id;

        project.ui.addingVisual = false;

    } //addQuad

    @autobind addText() {

        let text = new TextItem();
        text.name = text.id;
        text.entity = 'ceramic.Text';
        text.x = Math.round(project.scene.width / 2);
        text.y = Math.round(project.scene.height / 2);
        text.content = 'text';
        
        var maxDepth = 0;
        for (let item of project.scene.items) {
            if (item instanceof VisualItem)
            if (item.depth > maxDepth) {
                maxDepth = item.depth;
            }
        }

        text.depth = maxDepth + 1;

        project.scene.items.push(text);

        // Select visual
        project.ui.selectedItemName = text.id;

        project.ui.addingVisual = false;

    } //addText
    
}

export default AddVisual;
