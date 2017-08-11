import * as React from 'react';
import { observer } from 'utils';
import { project } from 'app/model';
import { context } from 'app/context';

@observer class MenuInfo extends React.Component {

/// Lifecycle

    render() {

        // Don't do anything until a server port is defined
        if (context.serverPort == null) return null;

        let info = project.ui.menuInfo;
        if (!info) return null;

        return (
            <div className="menu-info" style={{ top: info.y }}>
                {info.text}
            </div>
        );

    } //render
    
}

export default MenuInfo;
