package ceramic.macros;

import haxe.macro.Context;
import haxe.macro.Expr;

class SerializableMacro {

    macro static public function build():Array<Field> {
        var fields = Context.getBuildFields();

        fields.push({
            pos: Context.currentPos(),
            name: '__serializeId',
            kind: FVar((macro :Bool), (macro true)),
            access: field.access,
            doc: field.doc,
            meta: [{
                name: ':noCompletion',
                params: [],
                pos: field.pos
            }]
        });

        return fields;

    } //build

    static function hasLazyMeta(field:Field):Bool {

        if (field.meta == null || field.meta.length == 0) return false;

        for (meta in field.meta) {
            if (meta.name == 'lazy') {
                return true;
            }
        }

        return false;

    } //hasComponentMeta

} //SerializableMacro
