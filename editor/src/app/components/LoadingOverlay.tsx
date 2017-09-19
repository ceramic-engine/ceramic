import * as React from 'react';
import { observer } from 'utils';
import { Center } from 'components';
import { project } from 'app/model';
import { Overlay } from 'app/components';

@observer class LoadingOverlay extends React.Component {

    props:{
        /** Message */
        message?:string
    };

/// Lifecycle

    render() {

        return (
            <Overlay>
                <Center>
                    {this.props.message != null ? this.props.message : project.ui.loadingMessage}
                </Center>
            </Overlay>
        );

    } //render

}

export default LoadingOverlay;