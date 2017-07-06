import * as React from 'react';
import { observer } from 'utils';

@observer class Ceramic extends React.Component {

/// Lifecycle

    render() {

        return (
            <iframe
                src="/ceramic/index.html"
                frameBorder={0}
                scrolling="no"
                sandbox="allow-scripts allow-popups allow-same-origin"
                style={{ width: '100%', height: '100%', border: 'none' }}
            />
        );

    } //render
    
}

export default Ceramic;
