// New code for Cityscape (not a port): copies and comparisons by content of
// option values (the options a host gives an editor, the values of the
// configuration service).
package cityscape.common.config;

import cityscape.base.common.JsValues;

/**
 * Option values compared by content. A host may build its options object
 * again at each render, or change the one it gave in place: what counts is
 * whether the content differs from the one applied last, so the applied
 * content is kept as a copy (`copy`) and compared with `equals`.
 *
 * - Anonymous structures (`{top: 6}`) and arrays are copied and compared
 *   field by field, at any depth (`padding`, `stickyScroll`, `guides`,
 *   `inlayHints`, `semanticHighlighting`, `rulers`...).
 * - Numbers, strings and booleans are compared by value.
 * - Functions are compared by identity (`Reflect.compareMethods`): a
 *   closure built again is a different value.
 * - Class instances and enum values are kept as they are and compared by
 *   identity (a change made inside one in place is not seen).
 * - A field set to `null` and a field left out are the same (Haxe's null is
 *   an option left out everywhere in the options).
 */
class OptionValues {

    /** Structures nested deeper than this are not copied, and never equal (they are applied again, the safe side). */
    static inline final MAX_DEPTH = 16;

    /**
     * A copy of `value` that later changes made in place to `value` do not
     * reach.
     */
    public static function copy<T>(value:T):T {
        return cast copyAt(value, 0);
    }

    static function copyAt(value:Any, depth:Int):Any {
        if (value == null || depth > MAX_DEPTH) {
            return value;
        }
        if (JsValues.isArray(value)) {
            final source:Array<Any> = cast value;
            final result:Array<Any> = [];
            for (i in 0...source.length) {
                result.push(copyAt(source[i], depth + 1));
            }
            return result;
        }
        if (isStructure(value)) {
            final result:Dynamic = {};
            for (field in Reflect.fields(value)) {
                final fieldValue:Any = Reflect.field(value, field);
                if (fieldValue != null) {
                    Reflect.setField(result, field, copyAt(fieldValue, depth + 1));
                }
            }
            return result;
        }
        return value;
    }

    /**
     * Whether `a` and `b` have the same content.
     */
    public static function equals(a:Any, b:Any):Bool {
        return equalsAt(a, b, 0);
    }

    static function equalsAt(a:Any, b:Any, depth:Int):Bool {
        if (a == null || b == null) {
            return a == null && b == null;
        }
        if (depth > MAX_DEPTH) {
            return false;
        }
        final aIsArray = JsValues.isArray(a);
        if (aIsArray != JsValues.isArray(b)) {
            return false;
        }
        if (aIsArray) {
            final x:Array<Any> = cast a;
            final y:Array<Any> = cast b;
            if (x.length != y.length) {
                return false;
            }
            for (i in 0...x.length) {
                if (!equalsAt(x[i], y[i], depth + 1)) {
                    return false;
                }
            }
            return true;
        }
        final aIsStructure = isStructure(a);
        if (aIsStructure != isStructure(b)) {
            return false;
        }
        if (aIsStructure) {
            // every field of `a` in `b`, then no other field set in `b`
            var count = 0;
            for (field in Reflect.fields(a)) {
                final value:Any = Reflect.field(a, field);
                if (value == null) {
                    continue;
                }
                count++;
                if (!equalsAt(value, Reflect.field(b, field), depth + 1)) {
                    return false;
                }
            }
            for (field in Reflect.fields(b)) {
                if (Reflect.field(b, field) != null) {
                    count--;
                }
            }
            return count == 0;
        }
        final aIsFunction = JsValues.isFunction(a);
        if (aIsFunction != JsValues.isFunction(b)) {
            return false;
        }
        if (aIsFunction) {
            return Reflect.compareMethods(a, b);
        }
        return JsValues.strictEquals(a, b);
    }

    /** An anonymous structure (not an array, a string, a class instance or an enum value). */
    static function isStructure(value:Any):Bool {
        return switch Type.typeof(value) {
            case TObject: !Std.isOfType(value, Class) && !Std.isOfType(value, Enum);
            case _: false;
        }
    }

}
