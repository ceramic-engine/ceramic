import * as React from 'react';
import { autobind, observe, observer } from 'utils';

/** Text input */
@observer class TextInput extends React.Component {

    props:{
        /** Value */
        value:string,
        /** Autofocus */
        autoFocus?:boolean,
        /** Disabled */
        disabled?:boolean,
        /* Multiline */
        multiline?:boolean,
        /* Separator */
        separator?:string,
        /* Placeholder */
        placeholder?:string,
        /** Width */
        size?:"large",
        /** onChange */
        onChange?:(value:string) => void
    };

    inputElement:HTMLInputElement|HTMLTextAreaElement = null;

    @observe tailText:string = '';

    render() {

        let multiline = this.props.multiline != null ? this.props.multiline : false;
        let className = 'input input-text';
        let placeholder = this.props.placeholder != null ? this.props.placeholder : '';
        let value = this.props.value ? this.props.value : '';
        if (this.props.disabled) className += ' disabled';

        if (multiline) {
            let numLines = (value + this.tailText).split("\n").length;
            let height = numLines * 12 + 2;
            
            let styles:any = {
                resize: "none",
                height: height
            };
            if (this.props.size === 'large') {
                styles.width = 360;
            }

            return (
                <textarea
                    disabled={this.props.disabled}
                    className={className}
                    value={value + this.tailText}
                    onChange={this.handleChange}
                    onFocus={this.handleFocus}
                    onBlur={this.handleBlur}
                    autoFocus={this.props.autoFocus}
                    placeholder={placeholder}
                    ref={(el) => { this.inputElement = el; }}
                    style={styles}
                />
            );
        }
        else {
            
            let styles:any = {};
            if (this.props.size === 'large') {
                styles.width = 360;
            }

            return (
                <input
                    disabled={this.props.disabled}
                    className={className}
                    type="text"
                    value={value + this.tailText}
                    onChange={this.handleChange}
                    onFocus={this.handleFocus}
                    onBlur={this.handleBlur}
                    placeholder={placeholder}
                    style={styles}
                    ref={(el) => { this.inputElement = el; }}
                />
            );
        }

    } //render

    @autobind handleChange(e:any) {

        let val:string = e.target.value;
        let tval = val.replace(/\s+$/, '');

        let newTail = '';
        if (this.props.separator) {
            let sep = this.props.separator;
            while (sep.length > 0) {
                if (tval.endsWith(sep)) {
                    let prevVal = val;
                    val = val.substr(0, tval.length - sep.length);
                    newTail = sep + prevVal.substr(tval.length);
                    break;
                }
                else {
                    sep = sep.substr(0, sep.length - 1);
                }
            }
            if (newTail === '' && val.endsWith("\n")) {
                val = tval;
                newTail = ",\n";
            }
        }

        if (newTail !== this.tailText) {
            this.tailText = newTail;
            this.forceUpdate();
        }

        if (this.props.value === val) return;

        if (this.props.onChange) {
            this.props.onChange(val);
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

    copySelected(cut:boolean = false) {

        let input = this.inputElement;
        let val = input.value.substring(input.selectionStart, input.selectionEnd);

        if (cut && val.length > 0) {
            
            input.value = input.value.substring(0, input.selectionStart) + input.value.substring(input.selectionEnd);
            this.handleChange({
                target: input
            });
        }

        return val;

    } //copySelected

    pasteToSelected(content:string) {

        let input = this.inputElement;

        input.value = input.value.substring(0, input.selectionStart) + content + input.value.substring(input.selectionEnd);
        this.handleChange({
            target: input
        });

        input.selectionStart = input.selectionEnd;

    } //pasteToSelected

}

export default TextInput;
