import * as React from 'react';
import { observer } from 'utils';
import { Center } from 'components';
import { Ceramic } from 'app/components';

@observer class EditProject extends React.Component {

/// Lifecycle

    render() {

        return (
            <Center>
                <Ceramic />
            </Center>
        );

    } //render
    
}

export default EditProject;
