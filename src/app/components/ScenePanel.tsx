import * as React from 'react';
import { observer } from 'utils';
import { Form, InputNumber } from 'antd';
import { Scene } from 'app/model';

@observer class ScenePanel extends React.Component {

    constructor(public props:{data:Scene}) {

        super();

    } //constructor

/// Lifecycle

    render() {

        const data = this.props.data;

        const formItemLayout:any = {
            labelCol: {
                xs: { span: 24 },
                sm: { span: 6 }
            },
            wrapperCol: {
                xs: { span: 24 },
                sm: { span: 16 }
            },
            style: {
                marginBottom: '6px'
            }
        };

        return (
            <Form
                onSubmit={(e:any) => { e.preventDefault(); }}
            >

                <Form.Item label="width" {...formItemLayout}>
                    <InputNumber
                        value={data.width}
                        onChange={(e:any) => { data.width = e; }}
                    />
                </Form.Item>

                <Form.Item label="height" {...formItemLayout}>
                    <InputNumber
                        value={data.height}
                        onChange={(e:any) => { data.height = e; }}
                    />
                </Form.Item>

            </Form>
        );

    } //render
    
}

export default ScenePanel;
