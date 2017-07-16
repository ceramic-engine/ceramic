import * as React from 'react';
import { observer } from 'utils';
import { Button, Inline } from 'components';
import Overlay from './Overlay';
import Dialog from './Dialog';
import { project } from 'app/model';

@observer class AddVisual extends React.Component {

/// Lifecycle

    render() {

        return (
            <Overlay>
                <Dialog title="Add visual">
                    <Inline><Button kind="square" value="Quad" /></Inline>
                    <Inline><Button kind="square" value="Text" /></Inline>
                    <div style={{ height: 12 }} />
                    <Button value="Cancel" onClick={() => { project.ui.addingVisual = false; }} />
                </Dialog>
            </Overlay>
        );

    } //render
    
}

export default AddVisual;
