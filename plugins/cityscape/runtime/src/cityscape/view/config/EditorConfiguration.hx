// Ported from vscode src/vs/editor/browser/config/editorConfiguration.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.view.config;

import cityscape.base.common.JsValues;
import cityscape.base.common.Objects;
import cityscape.common.config.EditorOptions;

/**
 * The option validation and computation parts of editorConfiguration.ts.
 *
 * TODO(step 2): the `EditorConfiguration` class itself (environment: outer
 * size, font measurement by Glaze's text system, pixel ratio, accessibility;
 * `onDidChange`, `updateOptions`) comes with the view.
 */
class EditorConfigurationUtils {

    /**
     * Number of decimal digits of `n` (1 for 0).
     */
    public static function digitCount(n:Float):Int {
        var r = 0;
        while (n != 0) {
            n = Math.floor(n / 10);
            r++;
        }
        return r != 0 ? r : 1;
    }

    /**
     * A copy of `options` with the compatibility values of older Monaco
     * versions migrated (`MigrateOptions`).
     */
    public static function deepCloneAndMigrateOptions(_options:IEditorOptions):IEditorOptions {
        final options = Objects.deepClone(_options);
        MigrateOptions.migrateOptions(options);
        return options;
    }

}

/**
 * The validated options, indexed by option id.
 */
class ValidatedEditorOptions {

    final _values:Array<Any> = [];

    public function new() {}

    public function _read<V>(option:EditorOption<V>):V {
        return cast this._values[option];
    }

    public function get<V>(id:EditorOption<V>):V {
        return cast this._values[id];
    }

    public function _write<V>(option:EditorOption<V>, value:V):Void {
        this._values[option] = value;
    }

}

/**
 * The computed options, indexed by option id.
 */
class ComputedEditorOptions implements IComputedEditorOptions {

    final _values:Array<Any> = [];

    public function new() {}

    public function _read<V>(id:EditorOption<V>):V {
        if ((id : Int) >= this._values.length) {
            throw 'Cannot read uninitialized value';
        }
        return cast this._values[id];
    }

    public function get<V>(id:EditorOption<V>):V {
        return this._read(id);
    }

    public function _write<V>(id:EditorOption<V>, value:V):Void {
        this._values[id] = value;
    }

}

class EditorOptionsUtil {

    /**
     * Validates every registered option, reading its value in `options` by
     * its name (the options not ported yet are ignored).
     */
    public static function validateOptions(options:IEditorOptions):ValidatedEditorOptions {
        final result = new ValidatedEditorOptions();
        for (editorOption in EditorOptions.editorOptionsRegistry) {
            if (editorOption == null) {
                continue;
            }
            final value:Any = (editorOption.name == '_never_' ? null : Reflect.field(options, editorOption.name));
            result._write(cast editorOption.id, editorOption.validate(value));
        }
        return result;
    }

    public static function computeOptions(options:ValidatedEditorOptions, env:IEnvironmentalOptions):ComputedEditorOptions {
        final result = new ComputedEditorOptions();
        for (editorOption in EditorOptions.editorOptionsRegistry) {
            if (editorOption == null) {
                continue;
            }
            result._write(cast editorOption.id, editorOption.compute(env, result, options._read(cast editorOption.id)));
        }
        return result;
    }

    static function _deepEquals(a:Any, b:Any):Bool {
        if (!JsValues.isObject(a) || !JsValues.isObject(b) || !JsValues.truthy(a) || !JsValues.truthy(b)) {
            return valueEquals(a, b);
        }
        if (JsValues.isArray(a) || JsValues.isArray(b)) {
            if (!(JsValues.isArray(a) && JsValues.isArray(b))) {
                return false;
            }
            final aa:Array<Any> = a;
            final ba:Array<Any> = b;
            if (aa.length != ba.length) {
                return false;
            }
            for (i in 0...aa.length) {
                if (!valueEquals(aa[i], ba[i])) {
                    return false;
                }
            }
            return true;
        }
        final aKeys = Reflect.fields(a);
        if (aKeys.length != Reflect.fields(b).length) {
            return false;
        }
        for (key in aKeys) {
            if (!_deepEquals(Reflect.field(a, key), Reflect.field(b, key))) {
                return false;
            }
        }
        return true;
    }

    /**
     * JavaScript's `===`: numbers, booleans and strings by value, the rest by
     * reference.
     */
    static function valueEquals(a:Any, b:Any):Bool {
        if (JsValues.isNumber(a) && JsValues.isNumber(b)) {
            return (a : Float) == (b : Float);
        }
        if (JsValues.isString(a) && JsValues.isString(b)) {
            return (a : String) == (b : String);
        }
        if (JsValues.isBoolean(a) && JsValues.isBoolean(b)) {
            return (a : Bool) == (b : Bool);
        }
        if (JsValues.isFunction(a) || JsValues.isFunction(b)) {
            return Reflect.compareMethods(a, b);
        }
        return a == b;
    }

    public static function checkEquals(a:ComputedEditorOptions, b:ComputedEditorOptions):Null<ConfigurationChangedEvent> {
        final result:Array<Bool> = [];
        var somethingChanged = false;
        for (editorOption in EditorOptions.editorOptionsRegistry) {
            if (editorOption == null) {
                continue;
            }
            final changed = !EditorOptionsUtil._deepEquals(a._read(cast editorOption.id), b._read(cast editorOption.id));
            result[editorOption.id] = changed;
            if (changed) {
                somethingChanged = true;
            }
        }
        return (somethingChanged ? new ConfigurationChangedEvent(result) : null);
    }

    /**
     * Returns true if something changed.
     * Modifies `options`.
     */
    public static function applyUpdate(options:IEditorOptions, update:IEditorOptions):Bool {
        var changed = false;
        for (editorOption in EditorOptions.editorOptionsRegistry) {
            if (editorOption == null) {
                continue;
            }
            if (Reflect.hasField(update, editorOption.name)) {
                final result = editorOption.applyUpdate(Reflect.field(options, editorOption.name), Reflect.field(update, editorOption.name));
                Reflect.setField(options, editorOption.name, result.newValue);
                changed = changed || result.didChange;
            }
        }
        return changed;
    }

}
