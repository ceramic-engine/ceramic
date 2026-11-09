// Ported from vscode src/vs/base/common/objects.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.base.common;

/**
 * Module functions of objects.ts. Only what the ported code needs so far.
 */
class Objects {

    /**
     * A deep copy of anonymous structures and arrays (other values are
     * returned as they are, except class instances, copied into anonymous
     * structures like JavaScript's `Object.entries` copy does).
     */
    public static function deepClone<T>(obj:T):T {
        if (!JsValues.truthy(obj) || !JsValues.isObject(obj)) {
            return obj;
        }
        if (JsValues.isArray(obj)) {
            final source:Array<Any> = cast obj;
            final result:Array<Any> = [];
            for (i in 0...source.length) {
                final value = source[i];
                result[i] = JsValues.truthy(value) && JsValues.isObject(value) ? deepClone(value) : value;
            }
            return cast result;
        }
        final result = {};
        for (key in Reflect.fields(obj)) {
            final value = Reflect.field(obj, key);
            Reflect.setField(result, key, JsValues.truthy(value) && JsValues.isObject(value) ? deepClone(value) : value);
        }
        return cast result;
    }

}
