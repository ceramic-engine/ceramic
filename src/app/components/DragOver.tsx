import * as React from 'react';
import { observer, autobind, ceramic } from 'utils';
import Overlay from './Overlay';
import MdFolderOpen from 'react-icons/lib/md/folder-open';

@observer class DragOver extends React.Component {

/// Lifecycle

    render() {

        return (
            <Overlay>
                <div style={{ opacity: 0.95 }}>
                    <MdFolderOpen size={40} />
                    <span style={{ position: 'relative', left: 7, top: 3 }}>Drop</span>
                </div>
            </Overlay>
        );

    } //render
    
}

export default DragOver;
