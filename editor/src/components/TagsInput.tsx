import * as React from 'react';
import { autobind, observer, observe, arrayMove } from 'utils';
import Sortable from './Sortable';

/** Tags input */
@observer class TagsInput extends React.Component {

    props:{
        /** Value */
        value:Array<string>,
        /** Width */
        size?:"large",
        /** onChange */
        onChange?:(value:Array<string>) => void,
        /** Disabled */
        disabled?:boolean
    };

    inputElement:HTMLDivElement = null;

    focusing:boolean = false;

    @observe nextValue:string = '';

    render() {

        let className = 'input-tags-container' + (process.platform === 'win32' ? ' windows' : ' mac');

        let tags = this.props.value;
        if (tags == null) tags = [];

        return (
            <div
                className={className + (this.props.size === 'large' ? ' large' : '')}
                onMouseDown={this.handleContainerFocus}
            >
                <Sortable
                    distance={5}
                    helperClass={"dragging"}
                    shouldCancelStart={this.handleTagShouldCancelStart}
                    onSortStart={this.handleTagSortStart}
                    onSortEnd={this.handleTagSortEnd}
                    lockAxis={'y'}
                >
                    {tags.map((value, index) => {
                        return <div
                            key={index}
                            className="tag-item"
                        >
                            {value}
                        </div>;
                    })}
                </Sortable>
                <div
                    contentEditable={true}
                    className="tag-input"
                    placeholder={''}
                    value={this.nextValue}
                    onKeyDown={this.handleInputKeyDown}
                    onInput={this.handleInputChange}
                    onPaste={this.handleInputChange}
                    onFocus={this.handleInputFocus}
                    onBlur={this.handleInputBlur}
                    ref={(el) => { this.inputElement = el; }}
                />
            </div>
        );

    } //render

    @autobind handleInputChange(e:any) {

        if (this.inputElement.style.opacity === '0') {
            this.inputElement.textContent = this.nextValue;
            return;
        }

        // Only allow text
        this.nextValue = '' + this.inputElement.textContent;
        this.inputElement.textContent = this.nextValue;

    } //handleInputChange

    @autobind handleContainerFocus(e:any) {

        if (this.props.disabled) return;

        let items = (this.inputElement as any).parentNode.querySelectorAll('.tag-item');
        for (let item of items) {
            item.classList.remove('selected');
        }

        if (e.target.classList.contains('tag-item')) {
            e.target.classList.add('selected');
            this.inputElement.style.opacity = '0';
        }
        else {
            this.inputElement.style.opacity = '1';
        }

        this.focusing = true;
        this.inputElement.focus();
        setImmediate(() => {
            this.inputElement.focus();
            this.focusing = false;
        });

    } //handleContainerFocus

    @autobind handleInputFocus(e:any) {

        if (this.props.disabled) return;

        (this.inputElement as any).parentNode.classList.add('focus');

        global['focusedInput'] = this;

    } //handleInputFocus

    @autobind handleInputBlur(e:any) {

        if (!this.focusing) {

            (this.inputElement as any).parentNode.classList.remove('focus');

            let items = (this.inputElement as any).parentNode.querySelectorAll('.tag-item');
            for (let item of items) {
                item.classList.remove('selected');
            }

            this.inputElement.style.opacity = '1';

            this.inputElement.textContent = '';
            this.nextValue = '';
        }

        if (global['focusedInput'] === this) {
            global['focusedInput'] = undefined;
        }

    } //handleInputBlur

    @autobind handleInputKeyDown(e:any) {

        if (e.keyCode === 8 && this.inputElement.textContent === '') { // Backspace
            e.preventDefault();

            let selectedTag = this.selectedTag();

            if (selectedTag != null) {

                let i = 0;
                let prevValue = this.props.value;
                let newValue = [];
                let items = (this.inputElement as any).parentNode.querySelectorAll('.tag-item');
                for (let item of items) {
                    if (items[i + 1] === selectedTag) {
                        item.classList.add('selected');
                        newValue.push(prevValue[i]);
                    }
                    else if (item === selectedTag) {
                        item.classList.remove('selected');
                    }
                    else {
                        newValue.push(prevValue[i]);
                    }
                    i++;
                }

                if (this.props.onChange) {
                    this.props.onChange(newValue);
                }

                if (newValue.length === 0) {
                    this.inputElement.style.opacity = '1';
                }
            }
            else {

                let value = this.props.value;
                if (value == null) value = [];
                let newValue = value.slice();
                if (newValue.length > 0) newValue.pop();

                if (this.props.onChange) {
                    this.props.onChange(newValue);
                }
            }
        }
        else if (e.keyCode === 13 && this.inputElement.textContent.trim() !== '' && this.inputElement.style.opacity !== '0') { // Enter
            e.preventDefault();

            let tag = this.inputElement.textContent.split("\r").join('').split("\n").join(' ').trim();
            let value = this.props.value;
            if (value == null) value = [];
            let newValue = value.concat(tag);

            this.inputElement.textContent = '';
            this.nextValue = '';

            if (this.props.onChange) {
                this.props.onChange(newValue);
            }
        }
        else if (e.keyCode === 37 || e.keyCode === 39 || e.keyCode === 40 || e.keyCode === 38) {

            let selectedTag = this.selectedTag();

            let items = (this.inputElement as any).parentNode.querySelectorAll('.tag-item');
            if (selectedTag != null) {
                
                let i = 0;
                if ((e.keyCode === 39 || e.keyCode === 40) || items[0] !== selectedTag) {
                    for (let item of items) {
                        if ((e.keyCode === 37 || e.keyCode === 38) && items[i + 1] === selectedTag) {
                            item.classList.add('selected');
                        }
                        else if (item === selectedTag) {
                            item.classList.remove('selected');
                            if ((e.keyCode === 39 || e.keyCode === 40) && items[i + 1] != null) {
                                items[i + 1].classList.add('selected');
                            }
                        }
                        i++;
                    }
                }

                if ((e.keyCode === 39 || e.keyCode === 40) && selectedTag === items[items.length - 1]) {
                    this.inputElement.style.opacity = '1';
                }
            }
            else if ((e.keyCode === 37 || e.keyCode === 38) && items.length > 0 && this.nextValue === '') {

                items[items.length - 1].classList.add('selected');
                this.inputElement.style.opacity = '0';
            }

        }
 
    } //handleKeyDown

    @autobind handleTagSortStart(info:any) {

        // Nothing to do

    } //handleTagSortStart

    @autobind handleTagSortEnd(info:{oldIndex:number, newIndex:number}) {

        let {oldIndex, newIndex} = info;

        if (oldIndex === newIndex) return;
        let newValue = this.props.value.slice();

        let items = (this.inputElement as any).parentNode.querySelectorAll('.tag-item');
        let i = 0;
        for (let item of items) {
            if (i === newIndex) {
                item.classList.add('selected');
            } else {
                item.classList.remove('selected');
            }
            i++;
        }

        newValue = arrayMove(newValue, oldIndex, newIndex);

        if (this.props.onChange) {
            this.props.onChange(newValue);
        }

    } //handleTagSortEnd

    @autobind handleTagShouldCancelStart(e:any) {

        return !(this.inputElement as any).parentNode.classList.contains('focus');

    } //handleTagShouldCancelStart

/// Helpers

    selectedTag() {

        let items = (this.inputElement as any).parentNode.querySelectorAll('.tag-item');
        for (let item of items) {
            if (item.classList.contains('selected')) {
                return item;
            }
        }

        return null;

    } //selectedTag

/// Clipboard

    copySelected(cut:boolean = false) {

        let selectedTag = this.selectedTag();
        if (selectedTag != null) {
            let content = selectedTag.textContent;
            if (cut) {
                let i = 0;
                let prevValue = this.props.value;
                let newValue = [];
                let items = (this.inputElement as any).parentNode.querySelectorAll('.tag-item');
                for (let item of items) {
                    if (item === selectedTag) {
                        item.classList.remove('selected');
                    }
                    else {
                        newValue.push(prevValue[i]);
                    }
                    i++;
                }

                if (this.props.onChange) {
                    this.props.onChange(newValue);
                }
            }
            return content;
        }
        else {
            return '';
        }

    } //copySelected

    pasteToSelected(content:string) {

        let selectedTag = this.selectedTag();
        if (content != null && content.trim() !== '') {
            content = content.split("\r").join('').split("\n").join(' ').trim();
            if (selectedTag != null) {
                selectedTag.textContent = content;
            }
            else {
                let newValue = this.props.value.slice();
                newValue.push(content);

                if (this.props.onChange) {
                    this.props.onChange(newValue);
                }
            }
        }

    } //pasteToSelected

}

export default TagsInput;
