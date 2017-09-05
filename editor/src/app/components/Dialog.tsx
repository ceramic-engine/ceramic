import * as React from 'react';
import { observer } from 'utils';

@observer class Dialog extends React.Component {

    props:{
        /** Title */
        title?:string,
        /** Size */
        size?:"large",
        /** Children */
        children:React.ReactNode
    };

    render() {

        return (
            <div className={'dialog' + (this.props.size ? ' ' + this.props.size : '')}>
                {this.props.title ?
                    <div className="dialog-title">{this.props.title}</div>
                : null}
                <div className="dialog-content">
                    {this.props.children}
                </div>
            </div>
        );

    } //render

}

export default Dialog;