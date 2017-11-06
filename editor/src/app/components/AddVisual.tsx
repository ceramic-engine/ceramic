import * as React from 'react';
import { observer, autobind, ceramic, fields } from 'utils';
import { Button, Inline } from 'components';
import Overlay from './Overlay';
import Dialog from './Dialog';
import { project, VisualItem } from 'app/model';
import { EditableType } from 'app/model/Project';

@observer class AddVisual extends React.Component {

/// Lifecycle

    render() {

        return (
            <Overlay>
                <Dialog title="Add visual">
                    <div style={{maxWidth: 600}}>
                        {project.editableVisuals.map((value, index) =>
                            <Inline key={index}><Button kind="large" value={this.simpleName(value.entity)} onClick={() => this.addVisual(value)} /></Inline>
                        )}
                    </div>
                    <div style={{ height: 12 }} />
                    <Button value="Cancel" onClick={() => { project.ui.addVisual = false; }} />
                </Dialog>
            </Overlay>
        );

    } //render

    simpleName(inName:string):string {

        let dotIndex = inName.lastIndexOf('.');
        if (dotIndex !== -1) inName = inName.slice(dotIndex + 1);
        return inName;

    } //simpleName

/// Add

    @autobind addVisual(info:EditableType) {

        let fragment = project.ui.selectedFragment;
        let simpleName = info.entity;
        if (simpleName.lastIndexOf('.') !== -1) {
            simpleName = simpleName.slice(simpleName.lastIndexOf('.') + 1);
        }

        let visual = new VisualItem();
        visual.entity = info.entity;
        visual.props.set('x', Math.round(fragment.width / 2));
        visual.props.set('y', Math.round(fragment.height / 2));
        let n = 1;
        while (true) {
            let testedName = simpleName + ' ' + n;
            let exists = false;
            for (let item of fragment.visualItems) {
                if (item.name === testedName) {
                    exists = true;
                    break;
                }
            }
            if (!exists) break;
            n++;
        }
        visual.name = simpleName + ' ' + n;
        
        var maxDepth = 0;
        for (let item of fragment.items) {
            if (item instanceof VisualItem)
            if (item.props.get('depth') > maxDepth) {
                maxDepth = item.props.get('depth');
            }
        }

        visual.props.set('depth', maxDepth + 1);
        visual.props.set('anchorX', 0.5);
        visual.props.set('anchorY', 0.5);

        // Specific cases
        if (info.entity === 'ceramic.Text') {
            visual.props.set('content', visual.name);
        }
        else if (info.entity === 'ceramic.Quad') {
            visual.props.set('width', 100);
            visual.props.set('height', 100);
        }

        fragment.items.push(visual);

        // Select visual
        project.ui.selectedItemId = visual.id;

        project.ui.addVisual = false;

    } //addVisual
    
}

export default AddVisual;
