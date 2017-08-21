import * as React from 'react';

class Alt extends React.Component {

    props:{
        /** Children */
        children:React.ReactNode
    };

    render() {

        return (
            <div className="alt">
                {this.props.children}
            </div>
        );

    } //render

}

export default Alt;