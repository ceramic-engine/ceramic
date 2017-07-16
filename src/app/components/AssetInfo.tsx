import * as React from 'react';
import { observer } from 'utils';
import { project } from 'app/model';
import { context } from 'app/context';

@observer class AssetInfo extends React.Component {

/// Lifecycle

    render() {

        // Don't do anything until a server port is defined
        if (context.serverPort == null) return null;

        let asset = project.ui.expandedAsset;
        if (!asset) return null;

        if (asset.paths[0].toLowerCase().endsWith('.png')) {

            let imgPath = 'http://localhost:' + context.serverPort + '/editor/assets/' + asset.paths[0];

            return (
                <div className="asset-info">
                    <img src={imgPath} />
                </div>
            );
        } else {
            return null;
        }

    } //render
    
}

export default AssetInfo;
