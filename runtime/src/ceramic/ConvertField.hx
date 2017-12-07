package ceramic;

import ceramic.Assets;
import ceramic.Shortcuts.*;
import ceramic.Fragment;

import haxe.DynamicAccess;

/** Interface to convert from/to basic type and field values with complex types. */
interface ConvertField<BasicType,FieldType> {

    /** Get field value from basic type. As this may require loading assets,
        A usable `Assets` instance must be provided and the result will only be
        provided asynchronously by calling `done` callback. */
    function basicToField(assets:Assets, basic:BasicType, done:FieldType->Void):Void;

    /** Get a basic type from the field value. */
    function fieldToBasic(value:FieldType):BasicType;

} //ConvertField


/// Built-in converters

class ConvertTexture implements ConvertField<String,Texture> {

    public function new() {}

    public function basicToField(assets:Assets, basic:String, done:Texture->Void):Void {

        if (basic != null) {
            assets.ensureImage(basic, null, function(asset:ImageAsset) {
                done(asset != null ? asset.texture : null);
            });
        }
        else {
            done(null);
        }

    } //basicToField

    public function fieldToBasic(value:Texture):String {

        return (value == null || value.asset == null) ? null : value.asset.name;

    } //fieldToBasic

} //ConvertTexture

class ConvertFont implements ConvertField<String,BitmapFont> {

    public function new() {}

    public function basicToField(assets:Assets, basic:String, done:BitmapFont->Void):Void {

        if (basic != null) {
            if (basic == app.defaultFont.asset.name) {
                done(app.defaultFont);
            }
            else {
                assets.ensureFont(basic, null, function(asset:FontAsset) {
                    done(asset != null ? asset.font : null);
                });
            }
        }
        else {
            done(null);
        }

    } //basicToField

    public function fieldToBasic(value:BitmapFont):String {

        return (value == null || value.asset == null) ? null : value.asset.name;

    } //fieldToBasic

} //ConvertFont

class ConvertFragmentData implements ConvertField<Dynamic,FragmentData> {

    public function new() {}

    public function basicToField(assets:Assets, basic:Dynamic, done:FragmentData->Void):Void {

        done(basic);

    } //basicToField

    public function fieldToBasic(value:FragmentData):Dynamic {

        return value;

    } //fieldToBasic

} //ConvertFragmentData

class ConvertMap<T> implements ConvertField<DynamicAccess<T>,Map<String,T>> {

    public function new() {}

    public function basicToField(assets:Assets, basic:DynamicAccess<T>, done:Map<String,T>->Void):Void {

        if (basic == null) {
            done(null);
            return;
        }

        var value = new Map<String,T>();

        for (key in basic.keys()) {
            value.set(key, basic.get(key));
        }

        done(value);

    } //basicToField

    public function fieldToBasic(value:Map<String,T>):DynamicAccess<T> {

        if (value == null) return null;

        var basic:DynamicAccess<T> = {};

        for (key in value.keys()) {
            basic.set(key, value.get(key));
        }

        return basic;

    } //fieldToBasic

} //ConvertMap

class ConvertComponentMap implements ConvertField<DynamicAccess<String>,Map<String,Component>> {

    public function new() {}

    public function basicToField(assets:Assets, basic:DynamicAccess<String>, done:Map<String,Component>->Void):Void {

        if (basic == null) {
            done(null);
            return;
        }

        var value = new Map<String,Component>();

        for (name in basic.keys()) {
            // TODO extract arguments from value instead of treating it as initializer name directly
            var initializerName = basic.get(name);

            if (app.componentInitializers.exists(initializerName)) {
                var component = app.componentInitializers.get(initializerName)([]);
                if (component != null) {
                    @:privateAccess component.initializerName = initializerName;
                    value.set(name, component);
                }
            }
            #if debug
            else {
                warning('Missing component initializer: ' + initializerName);
            }
            #end
        }

        done(value);

    } //basicToField

    public function fieldToBasic(value:Map<String,Component>):DynamicAccess<String> {

        if (value == null) return null;

        var basic:DynamicAccess<String> = {};

        for (name in value.keys()) {
            var component = value.get(name);
            if (component != null && component.initializerName != null) {
                basic.set(name, component.initializerName);
            }
        }

        return basic;

    } //fieldToBasic

} //ConvertComponentMap
