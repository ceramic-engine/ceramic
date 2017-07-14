import * as React from 'react';
import { observer, observe } from 'utils';

/** Tabs */
@observer class Tabs extends React.Component {

    props:{
        /** Tab texts */
        tabs:Array<string>,
        /** Children */
        children:React.ReactNode
    };

    @observe active:number = 0;

    render() {

        return (
            <div className="tabs">
                {this.props.tabs.map((tab, i) =>
                    i === this.active ? 
                        <div className="tab active" key={i} onClick={() => { this.active = i; }}>{tab}</div>
                    :
                        <div className="tab" key={i} onClick={() => { this.active = i; }}>{tab}</div>
                )}
                {this.props.children != null ? (this.props.children as any[]).map((child, i) =>
                    i === this.active ?
                        child
                    :
                        null
                ) : null}
            </div>
        );

    } //render

}

export default Tabs;
