// Ported from vscode src/vs/editor/common/languages.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.languages;

/**
 * The kind of a completion item (Monaco's `CompletionItemKind`).
 *
 * In a module of its own: an imported enum abstract brings its values into
 * scope, and these names (`Function`, `Class`, `Color`, `Text`...) would
 * hide the types of the same name in the modules importing languages.ts.
 * Import it with care, or write its values qualified.
 */
enum abstract CompletionItemKind(Int) from Int to Int {
    var Method = 0;
    var Function = 1;
    var Constructor = 2;
    var Field = 3;
    var Variable = 4;
    var Class = 5;
    var Struct = 6;
    var Interface = 7;
    var Module = 8;
    var Property = 9;
    var Event = 10;
    var Operator = 11;
    var Unit = 12;
    var Value = 13;
    var Constant = 14;
    var Enum = 15;
    var EnumMember = 16;
    var Keyword = 17;
    var Text = 18;
    var Color = 19;
    var File = 20;
    var Reference = 21;
    var Customcolor = 22;
    var Folder = 23;
    var TypeParameter = 24;
    var User = 25;
    var Issue = 26;
    var Snippet = 27; // <- highest value (used for compare!)
}

/**
 * Monaco's `CompletionItemKinds` namespace: the codicon of a kind (its
 * name, which the suggest widget maps to an icon of the Glaze kit) and the
 * kind of a name.
 */
class CompletionItemKinds {

    static final codicons:Array<String> = [
        'symbol-method', 'symbol-function', 'symbol-constructor', 'symbol-field', 'symbol-variable',
        'symbol-class', 'symbol-struct', 'symbol-interface', 'symbol-module', 'symbol-property',
        'symbol-event', 'symbol-operator', 'symbol-unit', 'symbol-value', 'symbol-constant',
        'symbol-enum', 'symbol-enum-member', 'symbol-keyword', 'symbol-text', 'symbol-color',
        'symbol-file', 'symbol-reference', 'symbol-customcolor', 'symbol-folder', 'symbol-type-parameter',
        'account', 'issues', 'symbol-snippet'
    ];

    /**
     * The codicon id of a kind (`symbol-method`...).
     * @internal
     */
    public static function toIcon(kind:CompletionItemKind):String {
        final k:Int = kind;
        if (k >= 0 && k < codicons.length) {
            return codicons[k];
        }
        return 'symbol-property';
    }

    static var _data:Null<Map<String, CompletionItemKind>> = null;

    /**
     * The kind named `value` (`'method'`, `'enumMember'`...); `Property`
     * for an unknown name unless `strict` (then null).
     * @internal
     */
    public static function fromString(value:String, strict:Bool = false):Null<CompletionItemKind> {
        if (_data == null) {
            final data = new Map<String, CompletionItemKind>();
            data.set('method', Method);
            data.set('function', Function);
            data.set('constructor', Constructor);
            data.set('field', Field);
            data.set('variable', Variable);
            data.set('class', Class);
            data.set('struct', Struct);
            data.set('interface', Interface);
            data.set('module', Module);
            data.set('property', Property);
            data.set('event', Event);
            data.set('operator', Operator);
            data.set('unit', Unit);
            data.set('value', Value);
            data.set('constant', Constant);
            data.set('enum', Enum);
            data.set('enum-member', EnumMember);
            data.set('enumMember', EnumMember);
            data.set('keyword', Keyword);
            data.set('snippet', Snippet);
            data.set('text', Text);
            data.set('color', Color);
            data.set('file', File);
            data.set('reference', Reference);
            data.set('customcolor', Customcolor);
            data.set('folder', Folder);
            data.set('type-parameter', TypeParameter);
            data.set('typeParameter', TypeParameter);
            data.set('account', User);
            data.set('issue', Issue);
            _data = data;
        }
        var res:Null<CompletionItemKind> = _data.get(value);
        if (res == null && !strict) {
            res = Property;
        }
        return res;
    }

}
