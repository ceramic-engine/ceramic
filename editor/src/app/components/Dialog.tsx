import * as React from 'react';
import { observer } from 'utils';

@observer class Dialog extends React.Component {

    props:{
        /** Title */
        title:string,
        /** Width */
        width?:number,
        /** Children */
        children:React.ReactNode
    };

    render() {

        let styles:any = {};
        if (this.props.width) {
            styles.width = this.props.width;
        }

        return (
            <div className="dialog" style={styles}>
                <div className="title">{this.props.title}</div>
                <div className="content">
                    {this.props.children}
                </div>
            </div>
        );

    } //render

}

export default Dialog;