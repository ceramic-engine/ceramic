import * as React from 'react';
import { observer } from 'utils';
import { context } from 'app/context';
import { Center } from 'components';

@observer class Overlay extends React.Component {

    props:{
        /** Children */
        children:React.ReactNode
    };

    render() {

        return (
            <div
                className="overlay"
                style={{
                    width: context.width,
                    height: context.height,
                    top: 0,
                    left: 0,
                    zIndex: 100
                }}
            >
                <Center>
                    {this.props.children}
                </Center>
            </div>
        );

    } //render

}

export default Overlay;