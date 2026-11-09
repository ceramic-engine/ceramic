// Ported from vscode src/vs/editor/common/model/bracketPairsTextModelPart/bracketPairsTree/tokenizer.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree;

import cityscape.base.common.RegExp;
import cityscape.common.EncodedTokenAttributes;
import cityscape.common.Model.ITextModel;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Ast;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Brackets;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Length;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.SmallImmutableSet;
import cityscape.common.tokens.LineTokens.IViewLineTokens;

interface Tokenizer {
    var offset(get, never):Length;
    var length(get, never):Length;

    function read():Null<Token>;
    function peek():Null<Token>;
    function skip(length:Length):Void;

    function getText():String;
}

enum abstract TokenKind(Int) from Int to Int {
    var Text = 0;
    var OpeningBracket = 1;
    var ClosingBracket = 2;
}

typedef OpeningBracketId = Int;

class Token {

    public final length:Length;
    public final kind:TokenKind;
    /**
     * If this token is an opening bracket, this is the id of the opening bracket.
     * If this token is a closing bracket, this is the id of the first opening bracket that is closed by this bracket.
     * Otherwise, it is -1.
     */
    public final bracketId:OpeningBracketId;
    /**
     * If this token is an opening bracket, this just contains `bracketId`.
     * If this token is a closing bracket, this lists all opening bracket ids, that it closes.
     * Otherwise, it is empty.
     */
    public final bracketIds:SmallImmutableSet<OpeningBracketId>;
    /**
     * A `BracketAstNode` or a `TextAstNode`.
     */
    public final astNode:Null<AstNode>;

    public function new(length:Length, kind:TokenKind, bracketId:OpeningBracketId, bracketIds:SmallImmutableSet<OpeningBracketId>, astNode:Null<AstNode>) {
        this.length = length;
        this.kind = kind;
        this.bracketId = bracketId;
        this.bracketIds = bracketIds;
        this.astNode = astNode;
    }

}

/**
 * The text and tokens the `TextBufferTokenizer` reads (Monaco's structural
 * type, which a text model satisfies: `TextModelTokenizerSource` adapts an
 * `ITextModel`). Monaco's `tokenization.getLineTokens` is `getLineTokens`
 * here.
 */
interface ITokenizerSource {
    function getValue():String;
    function getLineCount():Int;
    function getLineLength(lineNumber:Int):Int;
    function getLineTokens(lineNumber:Int):IViewLineTokens;
}

/**
 * An `ITextModel` as an `ITokenizerSource`.
 */
class TextModelTokenizerSource implements ITokenizerSource {

    final textModel:ITextModel;

    public function new(textModel:ITextModel) {
        this.textModel = textModel;
    }

    public function getValue():String {
        return textModel.getValue();
    }

    public function getLineCount():Int {
        return textModel.getLineCount();
    }

    public function getLineLength(lineNumber:Int):Int {
        return textModel.getLineLength(lineNumber);
    }

    public function getLineTokens(lineNumber:Int):IViewLineTokens {
        return textModel.tokenization.getLineTokens(lineNumber);
    }

}

class TextBufferTokenizer implements Tokenizer {

    final textBufferLineCount:Int;
    final textBufferLastLineLength:Int;

    final reader:NonPeekableTextBufferTokenizer;

    final textModel:ITokenizerSource;
    final bracketTokens:LanguageAgnosticBracketTokens;

    public function new(textModel:ITokenizerSource, bracketTokens:LanguageAgnosticBracketTokens) {
        this.textModel = textModel;
        this.bracketTokens = bracketTokens;
        reader = new NonPeekableTextBufferTokenizer(textModel, bracketTokens);
        textBufferLineCount = textModel.getLineCount();
        textBufferLastLineLength = textModel.getLineLength(textBufferLineCount);
    }

    var _offset:Length = Length.lengthZero;

    public var offset(get, never):Length;
    function get_offset():Length {
        return _offset;
    }

    public var length(get, never):Length;
    function get_length():Length {
        return Length.toLength(textBufferLineCount - 1, textBufferLastLineLength);
    }

    public function getText():String {
        return textModel.getValue();
    }

    public function skip(length:Length):Void {
        didPeek = false;
        _offset = Length.lengthAdd(_offset, length);
        final obj = Length.lengthToObj(_offset);
        reader.setPosition(obj.lineCount, obj.columnCount);
    }

    var didPeek = false;
    var peeked:Null<Token> = null;

    public function read():Null<Token> {
        var token:Null<Token>;
        if (peeked != null) {
            didPeek = false;
            token = peeked;
        }
        else {
            token = reader.read();
        }
        if (token != null) {
            _offset = Length.lengthAdd(_offset, token.length);
        }
        return token;
    }

    public function peek():Null<Token> {
        if (!didPeek) {
            peeked = reader.read();
            didPeek = true;
        }
        return peeked;
    }

}

/**
 * Does not support peek.
 */
private class NonPeekableTextBufferTokenizer {

    final textBufferLineCount:Int;
    final textBufferLastLineLength:Int;

    final textModel:ITokenizerSource;
    final bracketTokens:LanguageAgnosticBracketTokens;

    public function new(textModel:ITokenizerSource, bracketTokens:LanguageAgnosticBracketTokens) {
        this.textModel = textModel;
        this.bracketTokens = bracketTokens;
        textBufferLineCount = textModel.getLineCount();
        textBufferLastLineLength = textModel.getLineLength(textBufferLineCount);
    }

    var lineIdx = 0;
    var line:Null<String> = null;
    var lineCharOffset = 0;
    var lineTokens:Null<IViewLineTokens> = null;
    var lineTokenOffset = 0;

    public function setPosition(lineIdx:Int, column:Int):Void {
        // We must not jump into a token!
        if (lineIdx == this.lineIdx) {
            lineCharOffset = column;
            if (line != null) {
                lineTokenOffset = lineCharOffset == 0 ? 0 : lineTokens.findTokenIndexAtOffset(lineCharOffset);
            }
        }
        else {
            this.lineIdx = lineIdx;
            lineCharOffset = column;
            line = null;
        }
        peekedToken = null;
    }

    /** Must be a zero line token. The end of the document cannot be peeked. */
    var peekedToken:Null<Token> = null;

    public function read():Null<Token> {
        if (peekedToken != null) {
            final token = peekedToken;
            peekedToken = null;
            lineCharOffset += Length.lengthGetColumnCountIfZeroLineCount(token.length);
            return token;
        }

        if (lineIdx > textBufferLineCount - 1 || (lineIdx == textBufferLineCount - 1 && lineCharOffset >= textBufferLastLineLength)) {
            // We are after the end
            return null;
        }

        if (line == null) {
            lineTokens = textModel.getLineTokens(lineIdx + 1);
            line = lineTokens.getLineContent();
            lineTokenOffset = lineCharOffset == 0 ? 0 : lineTokens.findTokenIndexAtOffset(lineCharOffset);
        }

        final startLineIdx = lineIdx;
        final startLineCharOffset = lineCharOffset;

        // limits the length of text tokens.
        // If text tokens get too long, incremental updates will be slow
        var lengthHeuristic = 0;
        while (true) {
            final lineTokens = this.lineTokens;
            final tokenCount = lineTokens.getCount();

            var peekedBracketToken:Null<Token> = null;

            if (lineTokenOffset < tokenCount) {
                final tokenMetadata = lineTokens.getMetadata(lineTokenOffset);
                while (lineTokenOffset + 1 < tokenCount && tokenMetadata == lineTokens.getMetadata(lineTokenOffset + 1)) {
                    // Skip tokens that are identical.
                    // Sometimes, (bracket) identifiers are split up into multiple tokens.
                    lineTokenOffset++;
                }

                final isOther = TokenMetadata.getTokenType(tokenMetadata) == StandardTokenType.Other;
                final containsBracketType = TokenMetadata.containsBalancedBrackets(tokenMetadata);

                final endOffset = lineTokens.getEndOffset(lineTokenOffset);
                // Is there a bracket token next? Only consume text.
                if (containsBracketType && isOther && lineCharOffset < endOffset) {
                    final languageId = lineTokens.getLanguageId(lineTokenOffset);
                    final text = line.substring(lineCharOffset, endOffset);

                    final brackets = bracketTokens.getSingleLanguageBracketTokens(languageId);
                    final regexp = brackets.regExpGlobal;
                    if (regexp != null) {
                        regexp.lastIndex = 0;
                        final match = regexp.exec(text);
                        if (match != null) {
                            peekedBracketToken = brackets.getToken(match[0]);
                            if (peekedBracketToken != null) {
                                // Consume leading text of the token
                                lineCharOffset += match.index;
                            }
                        }
                    }
                }

                lengthHeuristic += endOffset - lineCharOffset;

                if (peekedBracketToken != null) {
                    // Don't skip the entire token, as a single token could contain multiple brackets.

                    if (startLineIdx != lineIdx || startLineCharOffset != lineCharOffset) {
                        // There is text before the bracket
                        peekedToken = peekedBracketToken;
                        break;
                    }
                    else {
                        // Consume the peeked token
                        lineCharOffset += Length.lengthGetColumnCountIfZeroLineCount(peekedBracketToken.length);
                        return peekedBracketToken;
                    }
                }
                else {
                    // Skip the entire token, as the token contains no brackets at all.
                    lineTokenOffset++;
                    lineCharOffset = endOffset;
                }
            }
            else {
                if (lineIdx == textBufferLineCount - 1) {
                    break;
                }
                lineIdx++;
                this.lineTokens = textModel.getLineTokens(lineIdx + 1);
                lineTokenOffset = 0;
                line = this.lineTokens.getLineContent();
                lineCharOffset = 0;

                lengthHeuristic += 33; // max 1000/33 = 30 lines
                // This limits the amount of work to recompute min-indentation

                if (lengthHeuristic > 1000) {
                    // only break (automatically) at the end of line.
                    break;
                }
            }

            if (lengthHeuristic > 1500) {
                // Eventually break regardless of the line length so that
                // very long lines do not cause bad performance.
                // This effective limits max indentation to 500, as
                // indentation is not computed across multiple text nodes.
                break;
            }
        }

        // If a token contains some proper indentation, it also contains \n{INDENTATION+}(?!{INDENTATION}),
        // unless the line is too long.
        // Thus, the min indentation of the document is the minimum min indentation of every text node.
        final length = Length.lengthDiff(startLineIdx, startLineCharOffset, lineIdx, lineCharOffset);
        return new Token(length, TokenKind.Text, -1, SmallImmutableSet.getEmpty(), new TextAstNode(length));
    }

}

class FastTokenizer implements Tokenizer {

    var _offset:Length = Length.lengthZero;
    final tokens:Array<Token>;
    var idx = 0;

    final text:String;

    public function new(text:String, brackets:BracketTokens) {
        this.text = text;
        final regExpStr = brackets.getRegExpStr();
        final regexp = regExpStr != null ? new RegExp(regExpStr + '|\n', 'gi') : null;

        final tokens:Array<Token> = [];

        var curLineCount = 0;
        var lastLineBreakOffset = 0;

        var lastTokenEndOffset = 0;
        var lastTokenEndLine = 0;

        final smallTextTokens0Line:Array<Token> = [];
        for (i in 0...60) {
            smallTextTokens0Line.push(
                new Token(
                    Length.toLength(0, i), TokenKind.Text, -1, SmallImmutableSet.getEmpty(),
                    new TextAstNode(Length.toLength(0, i))
                )
            );
        }

        final smallTextTokens1Line:Array<Token> = [];
        for (i in 0...60) {
            smallTextTokens1Line.push(
                new Token(
                    Length.toLength(1, i), TokenKind.Text, -1, SmallImmutableSet.getEmpty(),
                    new TextAstNode(Length.toLength(1, i))
                )
            );
        }

        if (regexp != null) {
            regexp.lastIndex = 0;
            // If a token contains indentation, it also contains \n{INDENTATION+}(?!{INDENTATION})
            var match:Null<RegExpExecArray>;
            while ((match = regexp.exec(text)) != null) {
                final curOffset = match.index;
                final value = match[0];
                if (value == '\n') {
                    curLineCount++;
                    lastLineBreakOffset = curOffset + 1;
                }
                else {
                    if (lastTokenEndOffset != curOffset) {
                        var token:Token;
                        if (lastTokenEndLine == curLineCount) {
                            final colCount = curOffset - lastTokenEndOffset;
                            if (colCount < smallTextTokens0Line.length) {
                                token = smallTextTokens0Line[colCount];
                            }
                            else {
                                final length = Length.toLength(0, colCount);
                                token = new Token(length, TokenKind.Text, -1, SmallImmutableSet.getEmpty(), new TextAstNode(length));
                            }
                        }
                        else {
                            final lineCount = curLineCount - lastTokenEndLine;
                            final colCount = curOffset - lastLineBreakOffset;
                            if (lineCount == 1 && colCount < smallTextTokens1Line.length) {
                                token = smallTextTokens1Line[colCount];
                            }
                            else {
                                final length = Length.toLength(lineCount, colCount);
                                token = new Token(length, TokenKind.Text, -1, SmallImmutableSet.getEmpty(), new TextAstNode(length));
                            }
                        }
                        tokens.push(token);
                    }

                    // value is matched by regexp, so the token must exist
                    tokens.push(brackets.getToken(value));

                    lastTokenEndOffset = curOffset + value.length;
                    lastTokenEndLine = curLineCount;
                }
            }
        }

        final offset = text.length;

        if (lastTokenEndOffset != offset) {
            final length = (lastTokenEndLine == curLineCount)
                ? Length.toLength(0, offset - lastTokenEndOffset)
                : Length.toLength(curLineCount - lastTokenEndLine, offset - lastLineBreakOffset);
            tokens.push(new Token(length, TokenKind.Text, -1, SmallImmutableSet.getEmpty(), new TextAstNode(length)));
        }

        _length = Length.toLength(curLineCount, offset - lastLineBreakOffset);
        this.tokens = tokens;
    }

    public var offset(get, never):Length;
    function get_offset():Length {
        return _offset;
    }

    final _length:Length;

    public var length(get, never):Length;
    function get_length():Length {
        return _length;
    }

    public function read():Null<Token> {
        final i = idx++;
        return i < tokens.length ? tokens[i] : null;
    }

    public function peek():Null<Token> {
        return idx < tokens.length ? tokens[idx] : null;
    }

    public function skip(length:Length):Void {
        throw 'Not supported';
    }

    public function getText():String {
        return text;
    }

}
