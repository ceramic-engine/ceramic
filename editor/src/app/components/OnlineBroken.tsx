import * as React from 'react';
import { observer, autobind, ceramic } from 'utils';
import { Button, Inline } from 'components';
import Overlay from './Overlay';
import Dialog from './Dialog';
import { project, VisualItem } from 'app/model';

@observer class OnlineBroken extends React.Component {

    props:{
        /** Title */
        title:string,
        /** Message */
        message:string
    };

/// Lifecycle

    render() {

        return (
            <Overlay>
                <Dialog title={this.props.title}>
                    <div className="message">{this.props.message.split("\n").map((val, index) =>
                        val ? <div key={index} className="line">{val}</div> : <div key={index} className="line">&nbsp;</div>
                    )}</div>
                    <div style={{ height: 16 }} />
                    <Button value="Open settings" onClick={() => { project.ui.editSettings = true; }} />
                </Dialog>
            </Overlay>
        );

    } //render
    
}

export default OnlineBroken;
