import * as React from 'react';

/** Field */
class Field extends React.Component {

    props:{
        /** Label */
        label?:string,
        /** Children */
        children:React.ReactNode
    };

    render() {

        return (
            <div className={'field' + (this.props.label ? ' with-label' : '')}>

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
