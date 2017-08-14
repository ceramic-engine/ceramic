import * as React from 'react';
import { autobind } from 'utils';

/** Text input */
class TextInput extends React.Component {

    props:{
        /** Value */
        value:string,
        /** Disabled */
        disabled?:boolean,
        /* Multiline */
        multiline?:boolean,
        /** onChange */
        onChange?:(value:string) => void
    };

    render() {

        let multiline = this.props.multiline != null ? this.props.multiline : false;
        let className = 'input input-text';
        if (this.props.disabled) className += ' disabled';

        if (multiline) {
            let value = this.props.value ? this.props.value : '';
            let numLines = value.split("\n").length;
            let height = numLines * 12 + 2;

            return (
                <textarea
                    disabled={this.props.disabled}
                    className={className}
                    value={this.props.value}
                    onChange={this.handleChange}
                    onFocus={this.handleFocus}
                    style={{
                        resize: "none",
                        height: height
                    }}
                />
            );
        }
        else {
            return (
                <input
                    disabled={this.props.disabled}
                    className={className}
                    type="text"
                    value={this.props.value}
                    onChange={this.handleChange}
                    onFocus={this.handleFocus}
                />
            );
        }

    } //render

    @autobind handleChange(e:any) {

        if (this.props.onChange) {
            this.props.onChange(e.target.value);
        }

    } //handleChange

    @autobind handleFocus(e:any) {

        if (!this.props.disabled) {
            e.target.select();
        }

    } //handleFocus

}

export default TextInput;
