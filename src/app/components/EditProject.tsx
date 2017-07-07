import * as React from 'react';
import { observer } from 'utils';
import { Center } from 'components';
import { Ceramic } from 'app/components';
import { context } from 'app/context';

@observer class EditProject extends React.Component {

/// Lifecycle

    render() {

        return (
            <div
                style={{
                    position: 'relative',
                    width: '100%',
                    height: '100%'
                }}
            >
                <div
                    style={{
                        width: '300px',
                        height: '100%',
                        position: 'absolute',
                        left: 0,
                        top: 0
                    }}
                >
                    <div />
                </div>
                <div
                    style={{
                        width: (context.width - 300) + 'px',
                        height: '100%',
                        position: 'absolute',
                        left: 300,
                        top: 0
                    }}
                >
                    <Center>
                        <Ceramic />
                    </Center>
                </div>
            </div>
        );

    } //render
    
}

export default EditProject;
