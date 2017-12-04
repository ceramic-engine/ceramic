import * as React from 'react';
import { FragmentItem, project } from 'app/model';
import { observer, serializeModel } from 'utils';
import { Button, Form, Field, Panel, NumberInput, TextInput, ColorInput, SelectInput, TagsInput, Title, Alt, Sortable } from 'components';

@observer class FragmentItemField extends React.Component {

    props:{
        /** Fragment item */
        item:FragmentItem,
        /** Field name */
        field:string
    };

    render() {

        let item = this.props.item;
        let fieldName = this.props.field;
        let info = project.editableTypesByKey.get(item.entity);
        if (info == null) {
            console.warn('No editable type info for entity: ' + item.entity);
            return null;
        }
        let field:{meta:any, name:string, type:string} = null;
        for (let f of info.fields) {
            if (f.name === fieldName) {
                field = f;
                break;
            }
        }

        if (field != null) {
            let options:any = field.meta.editable[0];
            let type = field.type;
            if (options == null) options = {};
            if (options.collection != null) {
                let collectionOptions:Array<string> = [];
                let collectionOptionIds:Array<string> = [];
                let collection = project.collectionsByName.get(options.collection);
                if (collection == null) {
                    console.warn('No collection found with name: ' + options.collection);
                    return null;
                }
                let selectedIndex = -1;
                let index = 0;
                for (let entry of collection.data) {
                    collectionOptions.push(entry.name);
                    collectionOptionIds.push(entry.id);
                    if (selectedIndex === -1 && entry.id === item.props.get(field.name)) selectedIndex = index;
                    index++;
                }
                if (selectedIndex === -1) selectedIndex = 0;
                return (
                    <Field label={this.toFieldName(field.name)}>
                        <SelectInput
                            empty={options.empty}
                            selected={selectedIndex}
                            options={collectionOptions}
                            onChange={(selected) => {
                                item.props.set(field.name, collectionOptionIds[selected]);
                            }}
                        />
                    </Field>
                );
            }
            else if (options.localCollection != null) {
                let collectionOptions:Array<string> = [];
                let collectionOptionIds:Array<string> = [];
                let localCollection = project.localCollections.get(item.id + '#' + options.localCollection);
                if (localCollection == null) {
                    console.warn('No local collection found with name: ' + options.localCollection);
                    return null;
                }
                let selectedIndex = -1;
                let index = 0;
                for (let entry of localCollection.data) {
                    collectionOptions.push(entry.name);
                    collectionOptionIds.push(entry.id);
                    if (selectedIndex === -1 && entry.id === item.props.get(field.name)) selectedIndex = index;
                    index++;
                }
                if (selectedIndex === -1) selectedIndex = 0;
                return (
                    <Field label={this.toFieldName(field.name)}>
                        <SelectInput
                            empty={options.empty}
                            selected={selectedIndex}
                            options={collectionOptions}
                            onChange={(selected) => {
                                item.props.set(field.name, collectionOptionIds[selected]);
                            }}
                        />
                    </Field>
                );
            }
            else if (options.options != null) {
                let selectedIndex = Math.max(0, options.options.indexOf(item.props.get(field.name)));
                return (
                    <Field label={this.toFieldName(field.name)}>
                        <SelectInput
                            empty={options.empty}
                            selected={selectedIndex}
                            options={options.options}
                            onChange={(selected) => {
                                item.props.set(field.name, options.options[selected]);
                            }}
                        />
                    </Field>
                );
            }
            else {
                if (type === 'String') {
                    return (
                        <Field label={this.toFieldName(field.name)}>
                            <TextInput multiline={!!options.multiline} value={item.props.get(field.name)} onChange={(val:string) => { item.props.set(field.name, val); }} />
                        </Field>
                    );
                }
                else if (type === 'Float' || type === 'Int') {
                    if ((field.name === 'width' || field.name === 'height') && item.implicitSize) {
                        return (
                            <Field label={this.toFieldName(field.name)}>
                                <NumberInput disabled={true} value={item.props.get(field.name)} onChange={(val) => { item.props.set(field.name, val); }} />
                            </Field>
                        );
                    }
                    else {
                        return (
                            <Field label={this.toFieldName(field.name)}>
                                <NumberInput value={item.props.get(field.name)} onChange={(val) => { item.props.set(field.name, val); }} />
                            </Field>
                        );
                    }
                }
                else if (type === 'Bool') {
                    let selectedIndex = !!item.props.get(field.name) ? 1 : 0;
                    return (
                        <Field label={this.toFieldName(field.name)}>
                            <SelectInput
                                empty={0}
                                selected={selectedIndex}
                                options={['no', 'yes']}
                                onChange={(selected) => {
                                    item.props.set(field.name, selected === 1 ? true : false);
                                }}
                            />
                        </Field>
                    );
                }
                else if (type === 'ceramic.Color') {
                    return (
                        <Field label={this.toFieldName(field.name)}>
                            <ColorInput value={this.toHexColor(item.props.get(field.name))} onChange={(val) => { item.props.set(field.name, this.fromHexColor(val)); }} />
                        </Field>
                    );
                }
                else if (type === 'ceramic.BitmapFont') {

                    let list = ['default'];
                    let n = 1;
                    let index = 0;
                    let font = item.props.get(field.name);
                    if (project.fontAssets != null) {
                        for (let asset of project.fontAssets) {
                            list.push(asset.name);
                            if (asset.name === font) {
                                index = n;
                            }
                            n++;
                        }
                    }

                    return (
                        <Field label={this.toFieldName(field.name)}>
                            <SelectInput
                                empty={0}
                                selected={index}
                                options={list}
                                onChange={(selected) => {
                                    item.props.set(field.name, selected === 0 ? null : list[selected]);
                                }}
                            />
                        </Field>
                    );
                }
                else if (type === 'ceramic.Texture') {

                    let list = ['none'];
                    let n = 1;
                    let index = 0;
                    let texture = item.props.get(field.name);
                    if (project.imageAssets != null) {
                        for (let asset of project.imageAssets) {
                            list.push(asset.name);
                            if (asset.name === texture) {
                                index = n;
                            }
                            n++;
                        }
                    }

                    return (
                        <Field label={this.toFieldName(field.name)}>
                            <SelectInput
                                empty={0}
                                selected={index}
                                options={list}
                                onChange={(selected) => {
                                    item.props.set(field.name, selected === 0 ? null : list[selected]);
                                }}
                            />
                        </Field>
                    );
                }
                else if (type === 'ceramic.FragmentData') {

                    let list = ['none'];
                    let n = 1;
                    let index = 0;
                    let fragmentData = item.props.get(field.name);
                    if (project.fragments != null) {
                        for (let fragment of project.fragments) {
                            list.push(fragment.name);
                            if (fragmentData != null && fragmentData.id === fragment.id) {
                                index = n;
                            }
                            n++;
                        }
                    }

                    return (
                        <Field label={this.toFieldName(field.name)}>
                            <SelectInput
                                empty={0}
                                selected={index}
                                options={list}
                                onChange={(selected) => {
                                    let fragment = selected === 0 ? null : project.fragments[selected - 1];
                                    if (fragment != null) {
                                        item.props.set(field.name, fragment.serializeForCeramicSubFragment());
                                    }
                                    else {
                                        item.props.set(field.name, fragment);
                                    }
                                }}
                            />
                        </Field>
                    );

                }
                else if (type === 'Array<String>') {

                    let value = item.props.get(field.name);

                    return (
                        <Field label={this.toFieldName(field.name)}>
                            <TagsInput
                                value={value}
                                onChange={(newValue) => {
                                    item.props.set(field.name, newValue);
                                }}
                            />
                        </Field>
                    );
                }
                else {
                    let result:any = null;

                    if (project.customAssetsInfo) {
                        project.customAssetsInfo.forEach((value, key) => {
                            if (!result && value.types != null && value.types.indexOf(type) !== -1) {

                                let list = ['none'];
                                let n = 1;
                                let index = 0;
                                let assetInstance = item.props.get(field.name);
                                if (project.fontAssets != null) {
                                    for (let asset of project.customAssets.get(key)) {
                                        list.push(asset.name);
                                        if (asset.name === assetInstance) {
                                            index = n;
                                        }
                                        n++;
                                    }
                                }

                                result = (
                                    <Field label={this.toFieldName(field.name)}>
                                        <SelectInput
                                            empty={0}
                                            selected={index}
                                            options={list}
                                            onChange={(selected) => {
                                                item.props.set(field.name, selected === 0 ? null : list[selected]);
                                            }}
                                        />
                                    </Field>
                                );
                            }
                        });
                    }
                    
                    if (!result) {
                        console.warn('Failed to create form field for property ' + fieldName + ' of type ' + type);
                    }
                    return result;
                }
            }
        }
        else {
            console.warn('Entity ' + item.entity + ' has no field ' + fieldName);
            return null;
        }

        //return null;

    } //render

/// Helpers

    toFieldName(inName:string) {

        return inName;

    } //toFieldName

    toHexColor(inColor:number) {

        var hex = Number(inColor).toString(16).toUpperCase();
        while (hex.length < 6) {
            hex = '0' + hex;
        }
        return '#' + hex;

    } //toHexColor

    fromHexColor(inHexColor:string) {

        return parseInt('0x' + inHexColor.substr(1), 16);

    } //fromHexColor

}

export default FragmentItemField;