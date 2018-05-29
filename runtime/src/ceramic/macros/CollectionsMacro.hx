package ceramic.macros;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.io.Path;
import haxe.Json;
import sys.io.File;
import sys.FileSystem;

import ceramic.Csv;

using StringTools;

class CollectionsMacro {

    macro static public function build():Array<Field> {

        var fields = Context.getBuildFields();

        #if (completion || display)
        var useDynamic = false;
        #else
        var useDynamic = Context.defined('cpp');
        #end
        
        var data = ceramic.macros.AppMacro.getComputedInfo(Context.definedValue('app_info'));
        var pos = Context.currentPos();

        var assetsPath = Context.definedValue('assets_path');
        var ceramicAssetsPath = Context.definedValue('ceramic_assets_path');
        var pluginsAssetsPaths:Array<String> = [];
        var pluginsAssetsPathsRaw = Context.definedValue('ceramic_plugins_assets_paths');
        if (pluginsAssetsPathsRaw != null) {
            pluginsAssetsPaths = Json.parse(Json.parse(pluginsAssetsPathsRaw));
        }
        var allAssetsPaths = [assetsPath].concat(pluginsAssetsPaths).concat([ceramicAssetsPath]);
        
        for (key in Reflect.fields(data.collections)) {
            for (collectionName in Reflect.fields(Reflect.field(data.collections, key))) {
                var collectionInfo:Dynamic = Reflect.field(Reflect.field(data.collections, key), collectionName);
                var collectionClass:String = collectionInfo.type;
                var collectionData:String = collectionInfo.data;
                if (collectionClass == null) collectionClass = 'ceramic.CollectionEntry';
                var collectionType = null;

                switch(Context.parse('var a:' + collectionClass, pos).expr) {
                    case EVars(vars):
                        collectionType = vars[0].type;
                    default:
                }

                var collectionConstName = toCollectionConstName(collectionName);
                var collectionFieldName = toCollectionFieldName(collectionName);

                if (collectionType != null) {

                    // Collection instance
                    //
                    var fieldType = TPath({
                        name: 'Collection',
                        pack: [],
                        params: [TPType(collectionType)]
                    });

                    fields.push({
                        pos: pos,
                        name: collectionFieldName,
                        kind: FVar(fieldType, macro new Collection()),
                        access: [APublic],
                        doc: 'Collection',
                        meta: []
                    });

                    // Collection static ids
                    //
                    if (collectionData != null) {
                        for (pathPrefix in allAssetsPaths) {
                            var csvPath = Path.join([pathPrefix, collectionData + '.csv']);
                            if (FileSystem.exists(csvPath)) {

                                var csvData = Csv.parse(File.getContent(csvPath));

                                var entries = [];
                                var entriesInInit = [];

                                for (csvEntry in csvData) {
                                    var entryId = csvEntry.get('id');
                                    if (entryId != null && entryId.trim() != '' && entryId != 'null') {
                                        if (useDynamic) {
                                            entriesInInit.push({
                                                expr: ECall({
                                                    expr: EField({
                                                            expr: EConst(CIdent('Reflect')),
                                                            pos: pos
                                                        },
                                                        'setField'
                                                    ),
                                                    pos: pos
                                                }, [
                                                    {
                                                        expr: EConst(CIdent('result')),
                                                        pos: pos
                                                    },
                                                    {
                                                        expr: EConst(CString(toCollectionConstName(entryId))),
                                                        pos: pos
                                                    },
                                                    {
                                                        expr: EConst(CString(entryId)),
                                                        pos: pos
                                                    }
                                                ]),
                                                pos: pos
                                            });
                                        }
                                        else {
                                            entries.push({
                                                expr: {
                                                    expr: EConst(CString(entryId)),
                                                    pos: pos
                                                },
                                                field: toCollectionConstName(entryId)
                                            });
                                        }
                                    }
                                }

                                var kind;
                                
                                if (useDynamic) {
                                    // On some targets, we need to compile the mapping as Dynamic
                                    // because they don't play well with static ones.
                                    // This doesn't affect code completion which is always static
                                    kind = FProp('default', 'null', macro :Dynamic, { expr: ECall({ expr: EConst(CIdent('_' + collectionConstName + '_init')), pos: pos }, []), pos: pos });

                                    fields.push({
                                        pos: pos,
                                        name: '_' + collectionConstName + '_init',
                                        kind: FFun({
                                            args: [],
                                            ret: macro :Dynamic,
                                            expr: macro {
                                                var result:Dynamic = {};
                                                $b{entriesInInit}
                                                return result;
                                            }
                                        }),
                                        access: [APrivate, AStatic],
                                        doc: '',
                                        meta: [{
                                            name: ':noCompletion',
                                            params: [],
                                            pos: pos
                                        }]
                                    });
                                } else {
                                    kind = FProp('default', 'null', null, { expr: EObjectDecl(entries), pos: pos });
                                }

                                fields.push({
                                    pos: pos,
                                    name: collectionConstName,
                                    kind: kind,
                                    access: [APublic, AStatic],
                                    doc: 'Collection IDs',
                                    meta: []
                                });

                                break;
                            }
                        }
                    }

                }
            }
        }

        return fields;

    } //build

/// Internal

    static var reAsciiChar = ~/^[a-zA-Z0-9]$/;

    static function toCollectionConstName(input:String):String {

        var res = new StringBuf();
        var len = input.length;
        var i = 0;
        var canAddSpace = false;

        while (i < len) {

            var c = input.charAt(i);
            if (c == '/') {
                res.add('__');
                canAddSpace = false;
            }
            else if (c == '.') {
                res.add('_');
                canAddSpace = false;
            }
            else if (reAsciiChar.match(c)) {

                var uc = c.toUpperCase();
                var isUpperCase = (c == uc);

                if (canAddSpace && isUpperCase) {
                    res.add('_');
                    canAddSpace = false;
                }

                res.add(uc);
                canAddSpace = !isUpperCase;
            }
            else {
                res.add('_');
                canAddSpace = false;
            }

            i++;
        }

        var str = res.toString();
        if (str.endsWith('_')) str = str.substr(0, str.length - 1);

        return str;

    } //toCollectionConstName

    static function toCollectionFieldName(input:String):String {

        if (input.toUpperCase() == input.toLowerCase()) {
            return input.toLowerCase();
        }

        return input.charAt(0).toLowerCase() + input.substring(1);

    } //toCollectionFieldName

} //CollectionsMacro
