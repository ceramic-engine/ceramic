import * as React from 'react';
import './App.css';
import 'semantic-ui-css/semantic.min.css';
import { observer } from 'mobx-react';
import { Project } from './app/components';

@observer class ReactApp extends React.Component {

    render() {

        return <Project />;

    } //render
    
}

export default ReactApp;
