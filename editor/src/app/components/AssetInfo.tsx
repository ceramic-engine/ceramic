import * as React from 'react';
import { observer } from 'utils';
import { project } from 'app/model';
import { context } from 'app/context';

@observer class AssetInfo extends React.Component {

/// Lifecycle

    render() {

        // Don't do anything until a server port is defined
        if (context.serverPort == null) return null;

        if (!project.ui.assetInfo) return null;
        let asset = project.ui.assetInfo.asset;
        let y = project.ui.assetInfo.y;

        if (asset.paths[0].toLowerCase().endsWith('.png')) {

            let imgPath = 'http://localhost:' + context.serverPort + '/ceramic/source-assets/' + asset.paths[0];

            return (
                <div className="asset-info" style={{ top: y }}>
                    <img src={imgPath} />
                </div>
            );
        } else {
            return null;
        }

    } //render
    
}

export default AssetInfo;
