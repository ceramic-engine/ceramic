import * as React from 'react';
import { observer, observe, autobind } from 'utils';
import { Center } from 'components';
import { Input, Form, Button } from 'antd';
import { project } from 'app/model';

@observer class CreateProject extends React.Component {

/// Lifecycle

    /** Form data */
    data = observe({
        /** Project name */
        name: ''
    });

    render() {

        return (
            <Center>
                <div style={{ width: '500px', textAlign: 'left' }}>
                    <Form onSubmit={this.handleSubmit}>
                        <Form.Item>
                            <h1>Create new project</h1>
                            <p>This will create a new project at path: <em>{project.path}</em></p>
                        </Form.Item>

                        <Form.Item>
                            <Input
                                type="text"
                                placeholder="Enter project name"
                                value={this.data.name}
                                onChange={(e:any) => { this.data.name = e.target.value; }}
                            />
                        </Form.Item>

                        <Form.Item>
                            <Button
                                type="primary"
                                htmlType="submit"
                                size="large"
                                disabled={!this.data.name}
                            >
                                Create project
                            </Button>
                        </Form.Item>
                    </Form>
                </div>
            </Center>
        );

    } //render

    @autobind handleSubmit(e:any) {

        e.preventDefault();

        project.createWithName(this.data.name);

    } //handleSubmit
    
}

export default CreateProject;
