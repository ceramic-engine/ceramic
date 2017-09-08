import * as React from 'react';
import { observer, observe, autobind, ceramic } from 'utils';
import { Button, Inline, Form, Field, TextInput } from 'components';
import Overlay from './Overlay';
import Dialog from './Dialog';
import { project } from 'app/model';
import shortcuts from 'app/shortcuts';

@observer class PromptText extends React.Component {

    @observe values:Array<string> = [''];

    @observe valueIndex:number = 0;

/// Lifecycle

    componentDidMount() {

        shortcuts.handleUndo = this.handleUndo;

        shortcuts.handleRedo = this.handleRedo;

        shortcuts.handleCancel = this.handleCancel;

        shortcuts.handleValidate = this.handleValidate;

    } //componentDidMount

    componentWillUnmount() {

        if (shortcuts.handleUndo === this.handleUndo) {
            shortcuts.handleUndo = null;
        }

        if (shortcuts.handleRedo === this.handleRedo) {
            shortcuts.handleRedo = null;
        }

        if (shortcuts.handleCancel === this.handleCancel) {
            shortcuts.handleCancel = null;
        }

        if (shortcuts.handleValidate === this.handleValidate) {
            shortcuts.handleValidate = null;
        }

    } //componentWillUnmount

    render() {

        return project.ui.promptText ? (
            <Overlay>
                <Dialog title={project.ui.promptText.title}>
                    <div className="message">{project.ui.promptText.message.split("\n").map((val, index) =>
                        val ? <div key={index} className="line">{val}</div> : null
                    )}</div>
                    <div style={{ height: 12 }} />
                    <div className="prompt-text">
                        <Form>
                            <TextInput
                                size="large"
                                autoFocus={true}
                                multiline={true}
                                placeholder={project.ui.promptText.placeholder}
                                value={this.values[this.valueIndex]}
                                onChange={(val) => {
                                    this.values = this.values.slice(0, this.valueIndex + 1);
                                    this.values.push(val);
                                    this.valueIndex++;
                                }}
                            />
                        </Form>
                        <div style={{ height: 12 }} />
                        {project.ui.promptText.cancel ?
                            <Inline>
                                <Button
                                    value={project.ui.promptText.cancel}
                                    onClick={() => {
                                        project.ui.promptTextCanceled = true;
                                        project.ui.promptText = null;
                                        project.ui.promptTextResult = null;
                                    }}
                                />
                            </Inline>
                        : null}
                        <Inline>
                            <Button
                                value={project.ui.promptText.validate}
                                disabled={this.values[this.valueIndex].trim().length === 0}
                                onClick={() => {
                                    project.ui.promptText = null;
                                    project.ui.promptTextCanceled = false;
                                    project.ui.promptTextResult = this.values[this.valueIndex];
                                }}
                            />
                        </Inline>
                    </div>
                </Dialog>
            </Overlay>
        ) : null;

    } //render

/// Keyboard shortcuts

    @autobind handleUndo() {

        if (this.valueIndex > 0) {
            this.valueIndex--;
        }

    } //handleUndo

    @autobind handleRedo() {

        if (this.valueIndex < this.values.length - 1) {
            this.valueIndex++;
        }

    } //handleRedo

    @autobind handleCancel() {

        if (project.ui.promptText.cancel) {
            project.ui.promptTextCanceled = true;
            project.ui.promptText = null;
            project.ui.promptTextResult = null;
        }

    } //handleCancel

    @autobind handleValidate() {

        if (this.values[this.valueIndex].trim().length > 0) {
            project.ui.promptText = null;
            project.ui.promptTextCanceled = false;
            project.ui.promptTextResult = this.values[this.valueIndex];
        }

    } //handleValidate
    
}

export default PromptText;
