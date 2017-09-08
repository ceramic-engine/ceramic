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

    } //componentDidMount

    componentWillUnmount() {

        if (shortcuts.handleUndo === this.handleUndo) {
            shortcuts.handleUndo = null;
        }

        if (shortcuts.handleRedo === this.handleRedo) {
            shortcuts.handleRedo = null;
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

/// Local undo/redo

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
    
}

export default PromptText;
