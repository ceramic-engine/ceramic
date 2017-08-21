import * as React from 'react';

class Panel extends React.Component {

    props:{
        /** Children */
        children:React.ReactNode
    };

    render() {

        return (
            <div className="panel">
                {this.props.children}
            </div>
        );

    } //render

}

export default Panel;