import * as React from 'react';
import { observer } from 'mobx-react';
import { Button } from 'semantic-ui-react';
import { Center } from '../../components';
import { project } from '../stores';

@observer class App extends React.Component {

/// Lifecycle

    render() {

        if (project.path != null) {
            if (project.name != null) {
                return <div>name = {name}</div>;
            }
            else {
                return <div>no name</div>;
            }
        }
        else {
            // Need to select project directory
            return (
                <Center>
                    <div style={{width: 300}}>
                        <Button fluid={true} onClick={project.selectPath}>Select working directory</Button>
                    </div>
                </Center>
            );
        }

    } //render
    
}

export default App;
