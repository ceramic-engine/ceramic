import * as React from 'react';

class Title extends React.Component {

    props:{
        /** Children */
        children:React.ReactNode
    };

    render() {

        return (
            <div className="title">
                {this.props.children}
            </div>
        );

    } //render

}

export default Title;