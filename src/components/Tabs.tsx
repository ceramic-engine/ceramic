import * as React from 'react';

/** Tabs */
class Tabs extends React.Component {

    props:{
        /** Store key (to persist/reload tabs position) */
        active:number,
        /** Tab texts */
        tabs:Array<string>,
        /** Children */
        children:React.ReactNode,
        /** onChange */
        onChange:(value:number) => void
    };

    render() {

        return (
            <div className="tabs">
                {this.props.tabs.map((tab, i) =>
                    i === this.props.active || (!this.props.active && i === 0) ? 
                        <div className="tab active" key={i} onClick={() => { this.handleChange(i); }}>{tab}</div>
                    :
                        <div className="tab" key={i} onClick={() => { this.handleChange(i); }}>{tab}</div>
                )}
                {this.props.children != null ? (this.props.children as any[]).map((child, i) =>
                    i === this.props.active || (!this.props.active && i === 0) ?
                        child
                    :
                        null
                ) : null}
            </div>
        );

    } //render

    handleChange(index:number) {

        this.props.onChange(index);

    } //handleChange

}

export default Tabs;
