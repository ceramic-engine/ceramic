// Ported from vscode src/vs/editor/test/common/model/bracketPairColorizer/tokenizer.test.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.model.bracketPairColorizer;

import cityscape.common.EncodedTokenAttributes;
import cityscape.common.Languages;
import cityscape.common.Model.ITextModel;
import haxe.io.UInt32Array;


import cityscape.Cityscape;
import cityscape.base.common.Lifecycle;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Brackets;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Length;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.SmallImmutableSet;
import cityscape.common.model.bracketPairsTextModelPart.bracketPairsTree.Tokenizer;
import testing.TestCase;
import tests.TestTextModel;

/**
 * suite('Bracket Pair Colorizer - Tokenizer')
 *
 * Needs a text model with tokens: compiled with `-D cityscape_text_model`
 * once the text model is ported (`tests.TestTextModel.instantiateTextModel(context, text, languageId)`
 * is the port of `instantiateTextModel` of testTextModel.ts). Not
 * registered in Tests.hx yet. `TokenizedDocument` and `TokenInfo` (below)
 * are compiled already.
 */
class TokenizerTest extends TestCase {

    function testBasic() {
        final mode1 = 'testMode1';
        final disposableStore = new DisposableStore();
        final context = new Cityscape();
        final languageConfigurationService = context.languageConfigurationService;
        final languageService = context.languageService;
        disposableStore.add(languageService.registerLanguage({id: mode1}));
        final encodedMode1 = languageService.languageIdCodec.encodeLanguageId(mode1);

        final denseKeyProvider = new DenseKeyProvider<String>();

        final tStandard = (text:String) -> new TokenInfo(text, encodedMode1, StandardTokenType.Other, true);
        final tComment = (text:String) -> new TokenInfo(text, encodedMode1, StandardTokenType.Comment, true);
        final document = new TokenizedDocument([
            tStandard(' { } '), tStandard('be'), tStandard('gin end'), tStandard('\n'),
            tStandard('hello'), tComment('{'), tStandard('}'),
        ]);

        disposableStore.add(context.tokenizationRegistry.register(mode1, document.getTokenizationSupport()));
        disposableStore.add(languageConfigurationService.register(mode1, {
            brackets: [['{', '}'], ['[', ']'], ['(', ')'], ['begin', 'end']],
        }));

        final model = TestTextModel.instantiateTextModel(context, document.getText(), mode1);
        // ITextModel is not an IDisposable in Cityscape (it has `dispose`)
        disposableStore.add(Lifecycle.toDisposable(() -> model.dispose()));
        model.tokenization.forceTokenization(model.getLineCount());

        final brackets = new LanguageAgnosticBracketTokens(denseKeyProvider, l -> languageConfigurationService.getLanguageConfiguration(l));

        final tokens = readAllTokens(new TextBufferTokenizer(new TextModelTokenizerSource(model), brackets));

        assertDeepEquals(toArr(tokens, model, denseKeyProvider), [
            {text: ' ', bracketId: null, bracketIds: [], kind: 'Text'},
            {
                text: '{',
                bracketId: 'testMode1:::{',
                bracketIds: ['testMode1:::{'],
                kind: 'OpeningBracket',
            },
            {text: ' ', bracketId: null, bracketIds: [], kind: 'Text'},
            {
                text: '}',
                bracketId: 'testMode1:::{',
                bracketIds: ['testMode1:::{'],
                kind: 'ClosingBracket',
            },
            {text: ' ', bracketId: null, bracketIds: [], kind: 'Text'},
            {
                text: 'begin',
                bracketId: 'testMode1:::begin',
                bracketIds: ['testMode1:::begin'],
                kind: 'OpeningBracket',
            },
            {text: ' ', bracketId: null, bracketIds: [], kind: 'Text'},
            {
                text: 'end',
                bracketId: 'testMode1:::begin',
                bracketIds: ['testMode1:::begin'],
                kind: 'ClosingBracket',
            },
            {text: '\nhello{', bracketId: null, bracketIds: [], kind: 'Text'},
            {
                text: '}',
                bracketId: 'testMode1:::{',
                bracketIds: ['testMode1:::{'],
                kind: 'ClosingBracket',
            },
        ]);

        disposableStore.dispose();
    }

    static function readAllTokens(tokenizer:Tokenizer):Array<Token> {
        final tokens = new Array<Token>();
        while (true) {
            final token = tokenizer.read();
            if (token == null) {
                break;
            }
            tokens.push(token);
        }
        return tokens;
    }

    static function toArr(tokens:Array<Token>, model:ITextModel, keyProvider:DenseKeyProvider<String>):Array<Any> {
        final result = new Array<Any>();
        var offset = Length.lengthZero;
        for (token in tokens) {
            result.push(tokenToObj(token, offset, model, keyProvider));
            offset = Length.lengthAdd(offset, token.length);
        }
        return result;
    }

    static function tokenToObj(token:Token, offset:Length, model:ITextModel, keyProvider:DenseKeyProvider<String>):Any {
        final bracketId = keyProvider.reverseLookup(token.bracketId);
        return {
            text: model.getValueInRange(Length.lengthsToRange(offset, Length.lengthAdd(offset, token.length))),
            bracketId: (bracketId != null && bracketId.length > 0) ? bracketId : null,
            bracketIds: keyProvider.reverseLookupSet(cast token.bracketIds),
            kind: switch (token.kind) {
                case TokenKind.ClosingBracket: 'ClosingBracket';
                case TokenKind.OpeningBracket: 'OpeningBracket';
                case TokenKind.Text: 'Text';
                case _: null;
            }
        };
    }

}



class TokenizedDocument {

    final tokensByLine:Array<Array<TokenInfo>>;

    public function new(tokens:Array<TokenInfo>) {
        final tokensByLine = new Array<Array<TokenInfo>>();
        var curLine = new Array<TokenInfo>();

        for (token in tokens) {
            final lines = token.text.split('\n');
            var first = true;
            while (lines.length > 0) {
                if (!first) {
                    tokensByLine.push(curLine);
                    curLine = new Array<TokenInfo>();
                }
                else {
                    first = false;
                }

                if (lines[0].length > 0) {
                    curLine.push(token.withText(lines[0]));
                }
                lines.pop();
            }
        }

        tokensByLine.push(curLine);

        this.tokensByLine = tokensByLine;
    }

    public function getText():String {
        return [for (t in tokensByLine) [for (t2 in t) t2.text].join('')].join('\n');
    }

    public function getTokenizationSupport():ITokenizationSupport {
        return new TokenizedDocumentSupport(tokensByLine);
    }

}

private class TokenizedDocumentState implements IState {

    public final lineNumber:Int;

    public function new(lineNumber:Int) {
        this.lineNumber = lineNumber;
    }

    public function clone():IState {
        return new TokenizedDocumentState(lineNumber);
    }

    public function equals(other:IState):Bool {
        return lineNumber == (cast other : TokenizedDocumentState).lineNumber;
    }

}

private class TokenizedDocumentSupport implements ITokenizationSupport {

    final tokensByLine:Array<Array<TokenInfo>>;

    public function new(tokensByLine:Array<Array<TokenInfo>>) {
        this.tokensByLine = tokensByLine;
    }

    public function getInitialState():IState {
        return new TokenizedDocumentState(0);
    }

    public function tokenize(line:String, hasEOL:Bool, state:IState):TokenizationResult {
        throw 'Method not implemented.';
    }

    public function tokenizeEncoded(line:String, hasEOL:Bool, state:IState):EncodedTokenizationResult {
        final state2:TokenizedDocumentState = cast state;
        final tokens = tokensByLine[state2.lineNumber];
        final arr = new Array<Int>();
        var offset = 0;
        for (t in tokens) {
            arr.push(offset);
            arr.push(t.getMetadata());
            offset += t.text.length;
        }

        return new EncodedTokenizationResult(UInt32Array.fromArray(arr), new TokenizedDocumentState(state2.lineNumber + 1));
    }

    public function createBackgroundTokenizer(textModel:ITextModel, store:IBackgroundTokenizationStore):Null<IBackgroundTokenizer> {
        return null;
    }

}

class TokenInfo {

    public final text:String;
    public final languageId:LanguageId;
    public final tokenType:StandardTokenType;
    public final hasBalancedBrackets:Bool;

    public function new(text:String, languageId:LanguageId, tokenType:StandardTokenType, hasBalancedBrackets:Bool) {
        this.text = text;
        this.languageId = languageId;
        this.tokenType = tokenType;
        this.hasBalancedBrackets = hasBalancedBrackets;
    }

    public function getMetadata():Int {
        return (
            (((languageId << MetadataConsts.LANGUAGEID_OFFSET) |
                (tokenType << MetadataConsts.TOKEN_TYPE_OFFSET)) >>>
                0) |
            (hasBalancedBrackets ? MetadataConsts.BALANCED_BRACKETS_MASK : 0)
        );
    }

    public function withText(text:String):TokenInfo {
        return new TokenInfo(text, languageId, tokenType, hasBalancedBrackets);
    }

}
