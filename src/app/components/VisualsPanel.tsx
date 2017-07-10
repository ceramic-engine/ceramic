import * as React from 'react';
import { observer } from 'utils';
import { Button, Icon, Form } from 'antd';
import { Scene } from 'app/model';

@observer class VisualsPanel extends React.Component {

    constructor(public props:{data:Scene}) {

        super();

    } //constructor

/// Lifecycle

    render() {

        //const data = this.props.data;

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

                <Form.Item label="_" className="nolabel" {...formItemLayout}>
                    <Button type="dashed" onClick={() => {}}>
                        <Icon type="plus" /> Add visual
                    </Button>
                </Form.Item>

            </Form>
        );

    } //render
    
}

export default VisualsPanel;
