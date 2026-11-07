// New code for the Haxe port of gpui-kit (no gpui-kit origin): compile time
// embedding of the theme files that gpui-kit includes with `include_str!`.
// See NOTICE.md.
package glaze.kit.theme;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/**
 * Embeds `default-colors.json` and `default-theme.json` (copied unmodified
 * from gpui-kit's `crates/component/src/theme/`, next to this file) at
 * compile time, like Rust's `include_str!`.
 */
class ThemeMacro {

    #if macro
    static function readSibling(name:String):String {

        final file = Context.getPosInfos(Context.currentPos()).file;
        final dir = haxe.io.Path.directory(sys.FileSystem.absolutePath(file));
        final path = haxe.io.Path.join([dir, name]);
        Context.registerModuleDependency('glaze.kit.theme.ThemeMacro', path);
        return sys.io.File.getContent(path);

    }
    #end

    /**
     * `default-colors.json`, reduced to the fields the palette reads
     * (`scale` and `hslChannel` of every color).
     */
    public static macro function defaultColorsJson():Expr {

        final json:Dynamic = haxe.Json.parse(readSibling('default-colors.json'));
        final compact:Dynamic = {};
        for (name in Reflect.fields(json)) {
            final value:Dynamic = Reflect.field(json, name);
            if (Std.isOfType(value, Array)) {
                final list:Array<Dynamic> = value;
                Reflect.setField(compact, name, [for (item in list) {scale: item.scale, hslChannel: item.hslChannel}]);
            }
            else if (Reflect.isObject(value) && !Std.isOfType(value, String)) {
                Reflect.setField(compact, name, {scale: Reflect.field(value, 'scale'), hslChannel: Reflect.field(value, 'hslChannel')});
            }
        }
        return macro $v{haxe.Json.stringify(compact)};

    }

    /**
     * `default-theme.json`, as is.
     */
    public static macro function defaultThemeJson():Expr {

        return macro $v{readSibling('default-theme.json')};

    }

}
