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

    inputElement:HTMLInputElement|HTMLTextAreaElement = null;

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
                    onBlur={this.handleBlur}
                    ref={(el) => { this.inputElement = el; }}
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
                    onBlur={this.handleBlur}
                    ref={(el) => { this.inputElement = el; }}
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
            
            global['focusedInput'] = this;
        }

    } //handleFocus

    @autobind handleBlur(e:any) {

        if (global['focusedInput'] === this) {
            global['focusedInput'] = undefined;
        }

    } //handleBlur

/// Clipboard

    getSelected(cut:boolean = false) {

        let input = this.inputElement;
        let val = input.value.substring(input.selectionStart, input.selectionEnd);

        if (cut && val.length > 0) {
            
            input.value = input.value.substring(0, input.selectionStart) + input.value.substring(input.selectionEnd);
            this.handleChange({
                target: input
            });
        }

        return val;

    } //getSelected

    setSelected(content:string) {

        let input = this.inputElement;

        input.value = input.value.substring(0, input.selectionStart) + content + input.value.substring(input.selectionEnd);
        this.handleChange({
            target: input
        });

        input.selectionStart = input.selectionEnd;

    } //setSelected

}

export default TextInput;
