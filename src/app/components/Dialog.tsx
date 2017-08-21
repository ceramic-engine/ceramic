import * as React from 'react';
import { observer } from 'utils';

@observer class Dialog extends React.Component {

    props:{
        /** Title */
        title:string,
        /** Children */
        children:React.ReactNode
    };

    render() {

        return (
            <div className="dialog">
                <div className="title">{this.props.title}</div>
                <div className="content">
                    {this.props.children}
                </div>
            </div>
        );

    } //render

}

export default Dialog;