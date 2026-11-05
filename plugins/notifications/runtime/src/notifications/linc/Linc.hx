package notifications.linc;

#if macro
import haxe.io.Path;
import haxe.macro.Context;
import haxe.macro.Expr;

using haxe.macro.PositionTools;
#end

/**
 * Adds the native build file of the notifications plugin
 * (`linc_notifications.xml`, next to this file) to the class it builds.
 */
class Linc {

    macro public static function xml():Array<Field> {

        final pos = Context.currentPos();
        var sourcePath = Path.directory(pos.getInfos().file);
        if (!Path.isAbsolute(sourcePath)) {
            sourcePath = Path.join([Sys.getCwd(), sourcePath]);
        }
        sourcePath = Path.normalize(sourcePath);

        final define = '<set name="LINC_NOTIFICATIONS_PATH" value="$sourcePath/"/>';
        final include = '<include name="$${LINC_NOTIFICATIONS_PATH}linc_notifications.xml" />';
        Context.getLocalClass().get().meta.add(':buildXml', [{ expr: EConst(CString('$define\n$include')), pos: pos }], pos);

        return Context.getBuildFields();

    }

    /**
     * Adds a field set to the build time, so that changes of the native files
     * get compiled again with the class (like clay's `Linc.touch`).
     */
    macro public static function touch():Array<Field> {

        final fields = Context.getBuildFields();
        fields.push({
            name: '__touch',
            pos: Context.currentPos(),
            access: [APrivate, AStatic, AInline],
            kind: FVar(macro :String, macro $v{Std.string(Date.now().getTime())})
        });
        return fields;

    }

}
