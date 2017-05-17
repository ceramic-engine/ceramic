package ceramic.macros;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.Json;
import haxe.io.Path;
import sys.io.File;

using StringTools;

class AssetsMacro {

    static var backendInfo:backend.Info = null;

    static var allAssets:Array<{name:String}> = null;

    static var reAsciiChar = ~/^[a-zA-Z0-9]$/;

    macro static public function build(kind:String):Array<Field> {
        
        if (backendInfo == null) backendInfo = new backend.Info();
        if (allAssets == null) {
            var assetsPath = Context.definedValue('assets_path');
            allAssets = Json.parse(File.getContent(Path.join([assetsPath, '_assets.json']))).assets;
        }

        var fields = Context.getBuildFields();

        var extensions = switch (kind) {
            case 'image': backendInfo.imageExtensions();
            case 'text': backendInfo.textExtensions();
            case 'sound': backendInfo.soundExtensions();
            case 'font': ['fnt'];
            default: [];
        }

        if (extensions.length == 0) return fields;

        var used = new Map<String,String>();

        for (ext in extensions) {

            for (file in allAssets) {

                var lowerName = file.name.toLowerCase();
                var dotIndex = lowerName.lastIndexOf('.');
                var fileExt = null;
                var baseName = null;
                var fieldName = null;

                if (dotIndex != -1) {
                    fileExt = lowerName.substr(dotIndex + 1);

                    if (fileExt == ext) {

                        var trucatedName = file.name.substr(0, dotIndex);
                        var baseAtIndex = file.name.lastIndexOf('@');
                        if (baseAtIndex == -1) baseAtIndex = dotIndex;

                        baseName = file.name.substr(0, cast Math.min(baseAtIndex, dotIndex));
                        fieldName = toAssetConstName(baseName);
                    
                        if (fieldName != null && !used.exists(fieldName) && fileExt != null) {
                            used.set(fieldName, baseName);
                        }
                    }
                }
            }
        }

        for (fieldName in used.keys()) {
            var value = kind + ':' + used.get(fieldName);

            var expr = { expr: ECast({ expr: EConst(CString(value)), pos: Context.currentPos() }, null), pos: Context.currentPos() };

            var field = {
                pos: Context.currentPos(),
                name: fieldName,
                kind: FProp('default', 'null', macro :ceramic.Assets.AssetId, expr),
                access: [AStatic, APublic],
                doc: '',
                meta: []
            };

            fields.push(field);
        }

        return fields;

    } //build

    static function toAssetConstName(input:String):String {

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

        return res.toString();

    } //toAssetConstName

}