import * as React from 'react';

class Inline extends React.Component {

    props:{
        /** Children */
        children:React.ReactNode
    };

    render() {

        return (
            <div className="inline">
                {this.props.children}
            </div>
        );

    } //render

}

export default Inline;