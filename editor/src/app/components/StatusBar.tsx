import * as React from 'react';
import { observer } from 'utils';
import { project } from 'app/model';
import { Center } from 'components';

@observer class StatusBar extends React.Component {

    static statusHeight = 16;

    props:{
        /** Width */
        width:number,
        /** Top */
        top:number,
        /** Disabled */
        disabled?:boolean,
        /** onChange */
        onChange?:(value:string) => void
    };

    render() {

        return (
            <div
                className="statusbar"
                style={{
                    width: this.props.width,
                    height: StatusBar.statusHeight - 1,
                    position: 'absolute',
                    left: 0,
                    top: this.props.top
                }}
            >
                <div className="statusbar-text">{project.ui.statusBarText}</div>
            </div>
        );

    } //render

}

export default StatusBar;