import * as React from 'react';

/** Center children of this component. */
class Center extends React.Component {

    render() {

        return (
            <div
                style={{
                    width: '100%',
                    height: '100%',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    textAlign: 'center'
                }}
            >
                {this.props.children}
            </div>
        );

    } //render

}

export default Center;
