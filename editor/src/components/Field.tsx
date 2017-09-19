import * as React from 'react';

/** Field */
class Field extends React.Component {

    props:{
        /** Label */
        label?:string,
        /** Kind */
        kind?:"custom",
        /** Disabled */
        disabled?:boolean,
        /** Children */
        children:React.ReactNode
    };

    render() {

        return (
            <div className={'field' + (this.props.label ? ' with-label' : '') + (this.props.disabled ? ' disabled' : '') + (this.props.kind ? ' ' + this.props.kind : '')}>

                {this.props.label ?
                    <label>{this.props.label}</label>
                :
                    null
                }

                <div className="field-input">{this.props.children}</div>

            </div>
        );

    } //render

}

export default Field;
