// Ported from vscode src/vs/editor/common/languages.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common;

// A module of its own (the other types of languages.ts are in
// Languages.hx): importing an enum abstract brings its values into scope,
// and `String`, `Array`, `Boolean`... would shadow the standard types.

/**
 * A symbol kind.
 */
enum abstract SymbolKind(Int) from Int to Int {
    var File = 0;
    var Module = 1;
    var Namespace = 2;
    var Package = 3;
    var Class = 4;
    var Method = 5;
    var Property = 6;
    var Field = 7;
    var Constructor = 8;
    var Enum = 9;
    var Interface = 10;
    var Function = 11;
    var Variable = 12;
    var Constant = 13;
    var String = 14;
    var Number = 15;
    var Boolean = 16;
    var Array = 17;
    var Object = 18;
    var Key = 19;
    var Null = 20;
    var EnumMember = 21;
    var Struct = 22;
    var Event = 23;
    var Operator = 24;
    var TypeParameter = 25;
}

