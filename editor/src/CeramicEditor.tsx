import * as React from 'react';
import './CeramicEditor.css';
import { observer } from 'mobx-react';
import { App } from './app/components';

@observer class CeramicEditor extends React.Component {

    render() {

        return <App />;

    } //render
    
}

export default CeramicEditor;
