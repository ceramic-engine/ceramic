// New code for Cityscape (not a port): the mapping of LSP completion item
// kinds and symbol kinds to Monaco's kinds, both directions.
package cityscape.lsp;

import cityscape.common.languages.CompletionItemKind;
import cityscape.common.SymbolKind;

/**
 * LSP kinds to Monaco kinds and back.
 *
 * In a module of its own: importing `CompletionItemKind` and `SymbolKind`
 * brings values named `String`, `Array`, `Class`, `Function` into scope, so
 * this module writes Haxe's types as `std.String`, `std.Array` and keeps
 * nothing else. `LspConversions` forwards to it.
 */
class LspKinds {

    /**
     * Monaco's completion item kinds by LSP kind (index = LSP kind, 1 to
     * 25; index 0 unused). The LSP kinds are named like Monaco's.
     */
    static final completionKinds:std.Array<CompletionItemKind> = [
        Property, // 0: unused
        Text, // 1 Text
        Method, // 2 Method
        Function, // 3 Function
        Constructor, // 4 Constructor
        Field, // 5 Field
        Variable, // 6 Variable
        Class, // 7 Class
        Interface, // 8 Interface
        Module, // 9 Module
        Property, // 10 Property
        Unit, // 11 Unit
        Value, // 12 Value
        Enum, // 13 Enum
        Keyword, // 14 Keyword
        Snippet, // 15 Snippet
        Color, // 16 Color
        File, // 17 File
        Reference, // 18 Reference
        Folder, // 19 Folder
        EnumMember, // 20 EnumMember
        Constant, // 21 Constant
        Struct, // 22 Struct
        Event, // 23 Event
        Operator, // 24 Operator
        TypeParameter // 25 TypeParameter
    ];

    /**
     * The Monaco completion item kind of an LSP kind (1 to 25).
     * `Property` for a missing or unknown kind, like vscode's converter.
     */
    public static function toCompletionItemKind(lspKind:Null<Int>):CompletionItemKind {
        if (lspKind == null || lspKind < 1 || lspKind >= completionKinds.length) {
            return Property;
        }
        return completionKinds[lspKind];
    }

    /**
     * The LSP kind of a Monaco completion item kind. Monaco's kinds without
     * an LSP equivalent: `Customcolor` gives Color (16), `User` and `Issue`
     * give Text (1).
     */
    public static function fromCompletionItemKind(kind:CompletionItemKind):Int {
        return switch kind {
            case Customcolor: 16;
            case User | Issue: 1;
            case _:
                final index = completionKinds.indexOf(kind, 1);
                index > 0 ? index : 1;
        }
    }

    /**
     * The Monaco symbol kind of an LSP symbol kind (1 to 26): Monaco's
     * values are the LSP values minus one. `Property` for an unknown kind.
     */
    public static function toSymbolKind(lspKind:Null<Int>):SymbolKind {
        if (lspKind == null || lspKind < 1 || lspKind > 26) {
            return Property;
        }
        return lspKind - 1;
    }

    /**
     * The LSP symbol kind of a Monaco symbol kind.
     */
    public static function fromSymbolKind(kind:SymbolKind):Int {
        final k:Int = kind;
        return k + 1;
    }

}
