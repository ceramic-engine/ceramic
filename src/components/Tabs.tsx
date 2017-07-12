import * as React from 'react';
import { observer, observe } from 'utils';

class TabsItem extends React.Component {

    props:{
        /** Children */
        children:React.ReactNode
    };

    render() {

        return (
            <div className="panel-content">
                {this.props.children}
            </div>
        );

    } //render

}

/** Tabs and related panel contents */
@observer class Tabs extends React.Component {

    static Item = TabsItem;

    props:{
        /** Tab texts */
        tabs:Array<string>,
        /** Children */
        children:React.ReactNode
    };

    @observe active:number = 0;

    render() {

        return (
            <div className="panel-group">
                {this.props.tabs.map((tab, i) =>
                    i === this.active ? 
                        <div className="panel-tab active" onClick={() => { this.active = i; }}>{tab}</div>
                    :
                        <div className="panel-tab" onClick={() => { this.active = i; }}>{tab}</div>
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
