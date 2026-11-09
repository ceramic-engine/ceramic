// Ported from vscode src/vs/editor/test/common/modes/supports/indentationRules.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.modes.supports;

import cityscape.base.common.RegExp;
import cityscape.common.languages.LanguageConfiguration.IndentationRule;

/**
 * Test data of indentationRules.ts.
 */
class IndentationRules {

    public static final javascriptIndentationRules:IndentationRule = {
        decreaseIndentPattern: new RegExp("^((?!.*?\\/\\*).*\\*\\/)?\\s*[\\}\\]\\)].*$"),
        increaseIndentPattern: new RegExp("^((?!\\/\\/).)*(\\{([^}\"'`]*|(\\t|[ ])*\\/\\/.*)|\\([^)\"'`]*|\\[[^\\]\"'`]*)$"),
        // e.g.  * ...| or */| or *-----*/|
        unIndentedLinePattern: new RegExp("^(\\t|[ ])*[ ]\\*[^/]*\\*\\/\\s*$|^(\\t|[ ])*[ ]\\*\\/\\s*$|^(\\t|[ ])*[ ]\\*([ ]([^\\*]|\\*(?!\\/))*)?$"),
        indentNextLinePattern: new RegExp("^((.*=>\\s*)|((.*[^\\w]+|\\s*)(if|while|for)\\s*\\(.*\\)\\s*))$"),
    };

    public static final rubyIndentationRules:IndentationRule = {
        decreaseIndentPattern: new RegExp("^\\s*([}\\]]([,)]?\\s*(#|$)|\\.[a-zA-Z_]\\w*\\b)|(end|rescue|ensure|else|elsif)\\b|(in|when)\\s)"),
        increaseIndentPattern: new RegExp("^\\s*((begin|class|(private|protected)\\s+def|def|else|elsif|ensure|for|if|module|rescue|unless|until|when|in|while|case)|([^#]*\\sdo\\b)|([^#]*=\\s*(case|if|unless)))\\b([^#\\{;]|(\\\"|'|\\/).*\\4)*(#.*)?$"),
    };

    public static final phpIndentationRules:IndentationRule = {
        increaseIndentPattern: new RegExp("({(?!.*}).*|\\(|\\[|((else(\\s)?)?if|else|for(each)?|while|switch|case).*:)\\s*((\\/[/*].*|)?$|\\?>)"),
        decreaseIndentPattern: new RegExp("^(.*\\*\\/)?\\s*((\\})|(\\)+[;,])|(\\]\\)*[;,])|\\b(else:)|\\b((end(if|for(each)?|while|switch));))"),
    };

    public static final goIndentationRules:IndentationRule = {
        decreaseIndentPattern: new RegExp("^\\s*(\\bcase\\b.*:|\\bdefault\\b:|}[)}]*[),]?|\\)[,]?)$"),
        increaseIndentPattern: new RegExp("^.*(\\bcase\\b.*:|\\bdefault\\b:|(\\b(func|if|else|switch|select|for|struct)\\b.*)?{[^}\"'`]*|\\([^)\"'`]*)$"),
    };

    public static final htmlIndentationRules:IndentationRule = {
        decreaseIndentPattern: new RegExp("^\\s*(<\\/(?!html)[-_\\.A-Za-z0-9]+\\b[^>]*>|-->|\\})"),
        increaseIndentPattern: new RegExp("<(?!\\?|(?:area|base|br|col|frame|hr|html|img|input|keygen|link|menuitem|meta|param|source|track|wbr)\\b|[^>]*\\/>)([-_\\.A-Za-z0-9]+)(?=\\s|>)\\b[^>]*>(?!.*<\\/\\1>)|<!--(?!.*-->)|\\{[^}\"']*$"),
    };

    public static final latexIndentationRules:IndentationRule = {
        decreaseIndentPattern: new RegExp("^\\s*\\\\end{(?!document)"),
        increaseIndentPattern: new RegExp("\\\\begin{(?!document)([^}]*)}(?!.*\\\\end{\\1})"),
    };

    public static final luaIndentationRules:IndentationRule = {
        decreaseIndentPattern: new RegExp("^\\s*((\\b(elseif|else|end|until)\\b)|(\\})|(\\)))"),
        increaseIndentPattern: new RegExp("^((?!(\\-\\-)).)*((\\b(else|function|then|do|repeat)\\b((?!\\b(end|until)\\b).)*)|(\\{\\s*))$"),
    };

}
