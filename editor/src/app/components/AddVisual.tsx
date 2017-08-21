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

        let scene = project.ui.selectedScene;

        let quad = new QuadItem();
        quad.entity = 'ceramic.Quad';
        quad.x = Math.round(scene.width / 2);
        quad.y = Math.round(scene.height / 2);
        quad.name = 'Quad ' + (scene.quadItems.length + 1);
        
        var maxDepth = 0;
        for (let item of scene.items) {
            if (item instanceof VisualItem)
            if (item.depth > maxDepth) {
                maxDepth = item.depth;
            }
        }

        quad.depth = maxDepth + 1;

        scene.items.push(quad);

        // Select visual
        project.ui.selectedItemId = quad.id;

        project.ui.addingVisual = false;

    } //addQuad

    @autobind addText() {

        let scene = project.ui.selectedScene;

        let text = new TextItem();
        text.entity = 'ceramic.Text';
        text.x = Math.round(scene.width / 2);
        text.y = Math.round(scene.height / 2);
        text.content = 'text';
        text.name = 'Text ' + (scene.textItems.length + 1);
        
        var maxDepth = 0;
        for (let item of scene.items) {
            if (item instanceof VisualItem)
            if (item.depth > maxDepth) {
                maxDepth = item.depth;
            }
        }

        text.depth = maxDepth + 1;

        scene.items.push(text);

        // Select visual
        project.ui.selectedItemId = text.id;

        project.ui.addingVisual = false;

    } //addText
    
}

export default AddVisual;
