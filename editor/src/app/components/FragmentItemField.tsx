import * as React from 'react';
import { FragmentItem, Fragment, project } from 'app/model';
import { observer, serializeModel, serializeValue } from 'utils';
import { Button, Form, Field, Panel, NumberInput, TextInput, ColorInput, SelectInput, TagsInput, MapInput, Title, Alt, Sortable } from 'components';

@observer class FragmentItemField extends React.Component {

    props:{
        /** Fragment item */
        item:FragmentItem,
        /** Field name */
        field:string,
        /** Overrides fragment */
        overridesFragment?:Fragment
    };

    render() {

        let overridesFragment = this.props.overridesFragment;
        let item = this.props.item;
        let fieldName = this.props.field;
        let fieldLabel = this.toFieldName(fieldName);

        let realFieldName:string = null;
        let realItemName:string = null;
        let realItem:FragmentItem = null;

        let realEntity:string = item.entity;
        
        let field:{meta:any, name:string, type:string} = null;

        if (overridesFragment && item.entity !== 'ceramic.Fragment') {
            console.warn('Cannot override ' + item.name + ' fragment data because it is not a fragment');
            return null;
        }

        if (overridesFragment) {
            let overrideInfo = overridesFragment.overrides.get(fieldName);
            if (overrideInfo == null) {
                console.warn('No override for item ' + item.name + ' with field ' + fieldName);
                return null;
            }
            let dotIndex = overrideInfo.lastIndexOf('.');
            if (dotIndex === -1) {
                console.warn('Invalid override for item ' + item.name + ' with field ' + fieldName + ': ' + overrideInfo);
                return;
            }
            realItemName = overrideInfo.slice(0, dotIndex);
            realFieldName = overrideInfo.slice(dotIndex + 1);
            for (let anItem of overridesFragment.items) {
                if (anItem.name === realItemName) {
                    realItem = anItem;
                    break;
                }
            }
        }
        else {
            realItemName = item.name;
            realFieldName = fieldName;
            realItem = item;
        }

        if (realItem == null) {
            console.warn('A problem occured when generating field for ' + item.name);
            return null;
        }

        realEntity = realItem.entity;

        let info = project.editableTypesByKey.get(realEntity);
        if (info == null) {
            console.warn('No editable type info for entity: ' + realEntity);
            return null;
        }

        // TODO handle override
        for (let f of info.fields) {
            if (f.name === realFieldName) {
                field = f;
                break;
            }
        }

        // Get value
        let fieldValue:any = null;
        if (overridesFragment) {
            if (item.overridesData != null) {
                fieldValue = item.overridesData.get(fieldName);
            }
        }
        else {
            fieldValue = item.props.get(realFieldName);
        }

        // Set value
        const set = (val:any) => {
            if (overridesFragment) {
                if (item.overridesData == null) item.overridesData = new Map();
                item.overridesData.set(fieldName, val);
            }
            else {
                item.props.set(realFieldName, val);
            }
        };

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
                    if (selectedIndex === -1 && entry.id === fieldValue) selectedIndex = index;
                    index++;
                }
                if (selectedIndex === -1) selectedIndex = 0;
                return (
                    <Field label={fieldLabel}>
                        <SelectInput
                            empty={options.empty}
                            selected={selectedIndex}
                            options={collectionOptions}
                            onChange={(selected) => {
                                set(collectionOptionIds[selected]);
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
                    if (selectedIndex === -1 && entry.id === fieldValue) selectedIndex = index;
                    index++;
                }
                if (selectedIndex === -1) selectedIndex = 0;
                return (
                    <Field label={fieldLabel}>
                        <SelectInput
                            empty={options.empty}
                            selected={selectedIndex}
                            options={collectionOptions}
                            onChange={(selected) => {
                                set(collectionOptionIds[selected]);
                            }}
                        />
                    </Field>
                );
            }
            else if (options.options != null) {
                let selectedIndex = Math.max(0, options.options.indexOf(fieldValue));
                return (
                    <Field label={fieldLabel}>
                        <SelectInput
                            empty={options.empty}
                            selected={selectedIndex}
                            options={options.options}
                            onChange={(selected) => {
                                set(options.options[selected]);
                            }}
                        />
                    </Field>
                );
            }
            else {
                // TODO use switch
                if (type === 'String') {
                    return (
                        <Field label={fieldLabel}>
                            <TextInput multiline={!!options.multiline} value={fieldValue} onChange={(val:string) => { set(val); }} />
                        </Field>
                    );
                }
                else if (type === 'Float' || type === 'Int') {
                    if ((realFieldName === 'width' || realFieldName === 'height') && item.implicitSize) {
                        return (
                            <Field label={fieldLabel}>
                                <NumberInput disabled={true} value={fieldValue} onChange={(val) => { set(val); }} />
                            </Field>
                        );
                    }
                    else {
                        return (
                            <Field label={fieldLabel}>
                                <NumberInput value={fieldValue} onChange={(val) => { set(val); }} />
                            </Field>
                        );
                    }
                }
                else if (type === 'Bool') {
                    let selectedIndex = !!fieldValue ? 1 : 0;
                    return (
                        <Field label={fieldLabel}>
                            <SelectInput
                                empty={0}
                                selected={selectedIndex}
                                options={['no', 'yes']}
                                onChange={(selected) => {
                                    set(selected === 1 ? true : false);
                                }}
                            />
                        </Field>
                    );
                }
                else if (type === 'ceramic.Color') {
                    return (
                        <Field label={fieldLabel}>
                            <ColorInput value={this.toHexColor(fieldValue)} onChange={(val) => { set(this.fromHexColor(val)); }} />
                        </Field>
                    );
                }
                else if (type === 'ceramic.BitmapFont') {

                    let list = ['default'];
                    let n = 1;
                    let index = 0;
                    let font = fieldValue;
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
                        <Field label={fieldLabel}>
                            <SelectInput
                                empty={0}
                                selected={index}
                                options={list}
                                onChange={(selected) => {
                                    set(selected === 0 ? null : list[selected]);
                                }}
                            />
                        </Field>
                    );
                }
                else if (type === 'ceramic.Texture') {

                    let list = ['none'];
                    let n = 1;
                    let index = 0;
                    let texture = fieldValue;
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
                        <Field label={fieldLabel}>
                            <SelectInput
                                empty={0}
                                selected={index}
                                options={list}
                                onChange={(selected) => {
                                    set(selected === 0 ? null : list[selected]);
                                }}
                            />
                        </Field>
                    );
                }
                else if (type === 'ceramic.FragmentData') {

                    let list = ['none'];
                    let n = 1;
                    let index = 0;
                    let fragmentData = fieldValue;
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
                        <Field label={fieldLabel}>
                            <SelectInput
                                empty={0}
                                selected={index}
                                options={list}
                                onChange={(selected) => {
                                    let fragment = selected === 0 ? null : project.fragments[selected - 1];
                                    if (fragment != null) {
                                        let serialized = fragment.serializeForCeramicSubFragment(realItem.overridesData);
                                        set(serialized);
                                    }
                                    else {
                                        set(fragment);
                                    }
                                }}
                            />
                        </Field>
                    );

                }
                else if (type === 'Array<String>') {

                    let value = fieldValue;

                    return (
                        <Field label={fieldLabel}>
                            <TagsInput
                                value={value}
                                onChange={(newValue) => {
                                    set(newValue);
                                }}
                            />
                        </Field>
                    );
                }
                else if (type === 'Map<String,String>' || type === 'ceramic.ImmutableMap<String,String>' || type === 'ceramic.ImmutableMap<String,ceramic.Component>') {

                    let mapValue = fieldValue;
                    let value:Array<{key:string,value:string}> = [];
                    if (mapValue != null) {
                        for (let key in mapValue) {
                            if (mapValue.hasOwnProperty(key)) {
                                value.push({
                                    key: key,
                                    value: mapValue[key]
                                });
                            }
                        }
                    }

                    return (
                        <Field label={fieldLabel}>
                            <MapInput
                                value={value}
                                onChange={(newValue) => {
                                    let result = {};
                                    for (let entry of newValue) {
                                        result[entry.key] = entry.value;
                                    }
                                    set(result);
                                }}
                            />
                        </Field>
                    );
                }
                else if (type === 'Map<String,Bool>' || type === 'ceramic.ImmutableMap<String,Bool>') {

                    let mapValue = fieldValue;
                    let value:Array<string> = [];
                    if (mapValue != null) {
                        for (let key in mapValue) {
                            if (mapValue.hasOwnProperty(key)) {
                                value.push(key);
                            }
                        }
                    }

                    return (
                        <Field label={fieldLabel}>
                            <TagsInput
                                value={value}
                                onChange={(newValue) => {
                                    let result = {};
                                    for (let key of newValue) {
                                        result[key] = true;
                                    }
                                    set(result);
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
                                let assetInstance = fieldValue;
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
                                    <Field label={fieldLabel}>
                                        <SelectInput
                                            empty={0}
                                            selected={index}
                                            options={list}
                                            onChange={(selected) => {
                                                set(selected === 0 ? null : list[selected]);
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

        if (!inColor) inColor = 0;

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