// Ported from vscode src/vs/editor/common/model/bracketPairsTextModelPart/fixBrackets.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.model.bracketPairsTextModelPart;

import cityscape.common.languages.LanguageConfigurationRegistry.ILanguageConfigurationService;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Ast;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Brackets;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Length;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Parser;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.SmallImmutableSet;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Tokenizer;
import cityscape.common.tokens.LineTokens.IViewLineTokens;

/**
 * Module functions of fixBrackets.ts.
 */
class FixBrackets {

    public static function fixBracketsInLine(tokens:IViewLineTokens, languageConfigurationService:ILanguageConfigurationService):String {
        final denseKeyProvider = new DenseKeyProvider<String>();
        final bracketTokens = new LanguageAgnosticBracketTokens(denseKeyProvider, (languageId) ->
            languageConfigurationService.getLanguageConfiguration(languageId)
        );
        final tokenizer = new TextBufferTokenizer(
            new StaticTokenizerSource([tokens]),
            bracketTokens
        );
        final node = Parser.parseDocument(tokenizer, [], null, true);

        final str = new StringBuf();
        final line = tokens.getLineContent();

        function processNode(node:AstNode, offset:Length):Void {
            if (node.kind == AstNodeKind.Pair) {
                final pair:PairAstNode = cast node;
                processNode(pair.openingBracket, offset);
                offset = Length.lengthAdd(offset, pair.openingBracket.length);

                if (pair.child != null) {
                    processNode(pair.child, offset);
                    offset = Length.lengthAdd(offset, pair.child.length);
                }
                if (pair.closingBracket != null) {
                    processNode(pair.closingBracket, offset);
                    offset = Length.lengthAdd(offset, pair.closingBracket.length);
                }
                else {
                    final singleLangBracketTokens = bracketTokens.getSingleLanguageBracketTokens(pair.openingBracket.languageId);

                    final closingTokenText = singleLangBracketTokens.findClosingTokenText(pair.openingBracket.bracketIds);
                    // JavaScript's `str += undefined` appends 'undefined'
                    str.add(closingTokenText != null ? closingTokenText : 'undefined');
                }
            }
            else if (node.kind == AstNodeKind.UnexpectedClosingBracket) {
                // remove the bracket
            }
            else if (node.kind == AstNodeKind.Text || node.kind == AstNodeKind.Bracket) {
                str.add(line.substring(
                    Length.lengthGetColumnCountIfZeroLineCount(offset),
                    Length.lengthGetColumnCountIfZeroLineCount(Length.lengthAdd(offset, node.length))
                ));
            }
            else if (node.kind == AstNodeKind.List) {
                for (child in node.children) {
                    processNode(child, offset);
                    offset = Length.lengthAdd(offset, child.length);
                }
            }
        }

        processNode(node, Length.lengthZero);

        return str.toString();
    }

}

private class StaticTokenizerSource implements ITokenizerSource {

    final lines:Array<IViewLineTokens>;

    public function new(lines:Array<IViewLineTokens>) {
        this.lines = lines;
    }

    public function getValue():String {
        return [for (l in lines) l.getLineContent()].join('\n');
    }

    public function getLineCount():Int {
        return lines.length;
    }

    public function getLineLength(lineNumber:Int):Int {
        return lines[lineNumber - 1].getLineContent().length;
    }

    public function getLineTokens(lineNumber:Int):IViewLineTokens {
        return lines[lineNumber - 1];
    }

}
