// New code for the Haxe port of GPUI: adds the default methods of the
// `EntityInputHandler` trait of gpui-pre 0.3.10 (src/input.rs, Zed Industries,
// Apache-2.0) to implementing classes. See NOTICE.md.
package glaze;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type.ClassType;
#end

/**
 * Build macro of `EntityInputHandler` implementations: adds the trait's
 * default methods that the class (or one of its superclasses) doesn't define.
 */
class EntityInputHandlerMacro {

    #if macro
    public static function build():Array<Field> {
        final fields = Context.getBuildFields();
        final localClass = Context.getLocalClass();
        if (localClass == null)
            return null;
        final cls = localClass.get();
        if (cls.isInterface)
            return null;

        final existing = new Map<String, Bool>();
        for (field in fields) {
            existing.set(field.name, true);
        }
        var parent = cls.superClass;
        while (parent != null) {
            final parentClass:ClassType = parent.t.get();
            for (field in parentClass.fields.get()) {
                existing.set(field.name, true);
            }
            parent = parentClass.superClass;
        }

        final defaults = (macro class {
            public function paste(item:glaze.ClipboardItem, window:glaze.Window, cx:glaze.Context<Dynamic>):Void {
                final text = item.text();
                if (text != null) {
                    replaceTextInRange(null, text, window, cx);
                }
            }

            public function selectionBoundsForRange(rangeUtf16:glaze.Range, elementBounds:glaze.Bounds, window:glaze.Window, cx:glaze.Context<Dynamic>):Array<glaze.Bounds> {
                return [];
            }

            public function setSelectedTextRange(rangeUtf16:glaze.Range, window:glaze.Window, cx:glaze.Context<Dynamic>):Void {}

            public function textLengthUtf16(window:glaze.Window, cx:glaze.Context<Dynamic>):Null<Int> {
                return null;
            }

            public function acceptsTextInput(window:glaze.Window, cx:glaze.Context<Dynamic>):Bool {
                return true;
            }

            public function textInputConfiguration(window:glaze.Window, cx:glaze.Context<Dynamic>):glaze.TextInputConfiguration {
                return glaze.TextInputConfiguration.defaultValue();
            }

            public function textInputEditableRange(window:glaze.Window, cx:glaze.Context<Dynamic>):Null<glaze.Range> {
                return null;
            }
        }).fields;

        var changed = false;
        for (field in defaults) {
            if (!existing.exists(field.name)) {
                fields.push(field);
                changed = true;
            }
        }
        return changed ? fields : null;
    }
    #end

}
