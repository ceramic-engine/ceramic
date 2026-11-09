// Ported from vscode src/vs/editor/test/common/modes/supports/onEnterRules.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.modes.supports;

import cityscape.base.common.RegExp;
import cityscape.common.languages.LanguageConfiguration;

/**
 * Test data of onEnterRules.ts.
 */
class OnEnterRules {

    public static final javascriptOnEnterRules:Array<OnEnterRule> = [
        {
            // e.g. /** | */
            beforeText: new RegExp("^\\s*\\/\\*\\*(?!\\/)([^\\*]|\\*(?!\\/))*$"),
            afterText: new RegExp("^\\s*\\*\\/$"),
            action: { indentAction: IndentAction.IndentOutdent, appendText: ' * ' }
        }, {
            // e.g. /** ...|
            beforeText: new RegExp("^\\s*\\/\\*\\*(?!\\/)([^\\*]|\\*(?!\\/))*$"),
            action: { indentAction: IndentAction.None, appendText: ' * ' }
        }, {
            // e.g.  * ...|
            beforeText: new RegExp("^(\\t|[ ])*[ ]\\*([ ]([^\\*]|\\*(?!\\/))*)?$"),
            previousLineText: new RegExp("(?=^(\\s*(\\/\\*\\*|\\*)).*)(?=(?!(\\s*\\*\\/)))"),
            action: { indentAction: IndentAction.None, appendText: '* ' }
        }, {
            // e.g.  */|
            beforeText: new RegExp("^(\\t|[ ])*[ ]\\*\\/\\s*$"),
            action: { indentAction: IndentAction.None, removeText: 1 }
        },
        {
            // e.g.  *-----*/|
            beforeText: new RegExp("^(\\t|[ ])*[ ]\\*[^/]*\\*\\/\\s*$"),
            action: { indentAction: IndentAction.None, removeText: 1 }
        },
        {
            beforeText: new RegExp("^\\s*(\\bcase\\s.+:|\\bdefault:)$"),
            afterText: new RegExp("^(?!\\s*(\\bcase\\b|\\bdefault\\b))"),
            action: { indentAction: IndentAction.Indent }
        },
        {
            previousLineText: new RegExp("^\\s*(((else ?)?if|for|while)\\s*\\(.*\\)\\s*|else\\s*)$"),
            beforeText: new RegExp("^\\s+([^{i\\s]|i(?!f\\b))"),
            action: { indentAction: IndentAction.Outdent }
        },
        // Indent when pressing enter from inside ()
        {
            beforeText: new RegExp("^.*\\([^\\)]*$"),
            afterText: new RegExp("^\\s*\\).*$"),
            action: { indentAction: IndentAction.IndentOutdent, appendText: '\t' }
        },
        // Indent when pressing enter from inside {}
        {
            beforeText: new RegExp("^.*\\{[^\\}]*$"),
            afterText: new RegExp("^\\s*\\}.*$"),
            action: { indentAction: IndentAction.IndentOutdent, appendText: '\t' }
        },
        // Indent when pressing enter from inside []
        {
            beforeText: new RegExp("^.*\\[[^\\]]*$"),
            afterText: new RegExp("^\\s*\\].*$"),
            action: { indentAction: IndentAction.IndentOutdent, appendText: '\t' }
        },
    ];

    public static final phpOnEnterRules:Array<OnEnterRule> = [
        {
            beforeText: new RegExp("^\\s*\\/\\*\\*(?!\\/)([^\\*]|\\*(?!\\/))*$"),
            afterText: new RegExp("^\\s*\\*\\/$"),
            action: {
                indentAction: IndentAction.IndentOutdent,
                appendText: ' * ',
            }
        },
        {
            beforeText: new RegExp("^\\s*\\/\\*\\*(?!\\/)([^\\*]|\\*(?!\\/))*$"),
            action: {
                indentAction: IndentAction.None,
                appendText: ' * ',
            }
        },
        {
            beforeText: new RegExp("^(\\t|(\\ \\ ))*\\ \\*(\\ ([^\\*]|\\*(?!\\/))*)?$"),
            action: {
                indentAction: IndentAction.None,
                appendText: '* ',
            }
        },
        {
            beforeText: new RegExp("^(\\t|(\\ \\ ))*\\ \\*\\/\\s*$"),
            action: {
                indentAction: IndentAction.None,
                removeText: 1,
            }
        },
        {
            beforeText: new RegExp("^(\\t|(\\ \\ ))*\\ \\*[^/]*\\*\\/\\s*$"),
            action: {
                indentAction: IndentAction.None,
                removeText: 1,
            }
        },
        {
            beforeText: new RegExp("^\\s+([^{i\\s]|i(?!f\\b))"),
            previousLineText: new RegExp("^\\s*(((else ?)?if|for(each)?|while)\\s*\\(.*\\)\\s*|else\\s*)$"),
            action: {
                indentAction: IndentAction.Outdent
            }
        },
    ];

    public static final cppOnEnterRules:Array<OnEnterRule> = [
        {
            previousLineText: new RegExp("^\\s*(((else ?)?if|for|while)\\s*\\(.*\\)\\s*|else\\s*)$"),
            beforeText: new RegExp("^\\s+([^{i\\s]|i(?!f\\b))"),
            action: {
                indentAction: IndentAction.Outdent
            }
        }
    ];

    public static final htmlOnEnterRules:Array<OnEnterRule> = [
        {
            beforeText: new RegExp("<(?!(?:area|base|br|col|embed|hr|img|input|keygen|link|menuitem|meta|param|source|track|wbr))([_:\\w][_:\\w\\-.\\d]*)(?:(?:[^'\"/>]|\"[^\"]*\"|'[^']*')*?(?!\\/)>)[^<]*$", "i"),
            afterText: new RegExp("^<\\/([_:\\w][_:\\w\\-.\\d]*)\\s*>", "i"),
            action: {
                indentAction: IndentAction.IndentOutdent
            }
        },
        {
            beforeText: new RegExp("<(?!(?:area|base|br|col|embed|hr|img|input|keygen|link|menuitem|meta|param|source|track|wbr))([_:\\w][_:\\w\\-.\\d]*)(?:(?:[^'\"/>]|\"[^\"]*\"|'[^']*')*?(?!\\/)>)[^<]*$", "i"),
            action: {
                indentAction: IndentAction.Indent
            }
        }
    ];

}
