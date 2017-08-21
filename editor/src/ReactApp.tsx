import * as React from 'react';
import './ReactApp.css';
import { observer } from 'mobx-react';
import { App } from './app/components';

@observer class ReactApp extends React.Component {

    render() {

        return <App />;

    } //render
    
}

export default ReactApp;
