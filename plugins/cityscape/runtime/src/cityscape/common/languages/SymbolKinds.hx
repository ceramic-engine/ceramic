// Ported from vscode src/vs/editor/common/languages.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.languages;

import cityscape.common.SymbolKind;

/**
 * Monaco's `SymbolKinds` namespace, `symbolKindNames` and
 * `getAriaLabelForSymbol`.
 */
class SymbolKinds {

    static final names:std.Array<std.String> = [
        'file', 'module', 'namespace', 'package', 'class', 'method', 'property', 'field', 'constructor',
        'enumeration', 'interface', 'function', 'variable', 'constant', 'string', 'number', 'boolean',
        'array', 'object', 'key', 'null', 'enumeration member', 'struct', 'event', 'operator', 'type parameter'
    ];

    static final codicons:std.Array<std.String> = [
        'symbol-file', 'symbol-module', 'symbol-namespace', 'symbol-package', 'symbol-class', 'symbol-method',
        'symbol-property', 'symbol-field', 'symbol-constructor', 'symbol-enum', 'symbol-interface', 'symbol-function',
        'symbol-variable', 'symbol-constant', 'symbol-string', 'symbol-number', 'symbol-boolean', 'symbol-array',
        'symbol-object', 'symbol-key', 'symbol-null', 'symbol-enum-member', 'symbol-struct', 'symbol-event',
        'symbol-operator', 'symbol-type-parameter'
    ];

    /**
     * The English name of a kind (Monaco's `symbolKindNames`, localized by
     * the NLS keys `Array`, `Boolean`, `Class`...).
     */
    public static function symbolKindName(kind:SymbolKind):std.String {
        final k:Int = kind;
        return k >= 0 && k < names.length ? names[k] : '';
    }

    /**
     * The codicon id of a kind (`symbol-class`...).
     */
    public static function toIcon(kind:SymbolKind):std.String {
        final k:Int = kind;
        return k >= 0 && k < codicons.length ? codicons[k] : 'symbol-property';
    }

    /**
     * Monaco's `getAriaLabelForSymbol`.
     */
    public static function getAriaLabelForSymbol(symbolName:std.String, kind:SymbolKind):std.String {
        return symbolName + ' (' + symbolKindName(kind) + ')';
    }

}
