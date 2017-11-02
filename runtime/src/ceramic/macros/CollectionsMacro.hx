package ceramic.macros;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.io.Path;
import sys.FileSystem;

using StringTools;

class CollectionsMacro {

    macro static public function build():Array<Field> {

        var fields = Context.getBuildFields();
        var data = ceramic.macros.AppMacro.getComputedInfo(Context.definedValue('app_info'));
        var pos = Context.currentPos();
        
        for (key in Reflect.fields(data.collections)) {
            for (collectionName in Reflect.fields(Reflect.field(data.collections, key))) {
                var collectionClass = Reflect.field(Reflect.field(data.collections, key), collectionName);
                var collectionType = null;

                switch(Context.parse('var a:' + collectionClass, pos).expr) {
                    case EVars(vars):
                        collectionType = vars[0].type;
                    default:
                }

                if (collectionType != null) {

                    var fieldType = TPath({
                        name: 'Collection',
                        pack: [],
                        params: [TPType(collectionType)]
                    });

                    fields.push({
                        pos: pos,
                        name: collectionName,
                        kind: FVar(fieldType, macro new Collection()),
                        access: [AStatic, APublic],
                        doc: 'Collection',
                        meta: []
                    });

                }
            }
        }

        return fields;

    } //build

} //CollectionsMacro
