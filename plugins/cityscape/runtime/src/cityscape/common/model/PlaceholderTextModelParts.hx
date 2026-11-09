// New code for Cityscape (not a port): stand-ins for the tokenization and
// bracket pairs parts of a text model until they are ported.
package cityscape.common.model;

import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle;
import cityscape.common.TextModelBracketPairs.IBracketPairsTextModelPart;
import cityscape.common.TextModelEvents;
import cityscape.common.TokenizationTextModelPart.ITokenizationTextModelPart;
import cityscape.common.core.Position.IPosition;
import cityscape.common.core.WordHelper;

/**
 * The tokenization part of a `TextModel` until
 * `model/tokenizationTextModelPart.ts` is ported (TODO(step 1,
 * cs1-tokens)): no tokens, the language id is stored, and words use the
 * default word definition (`WordHelper.DEFAULT_WORD_REGEXP`, Monaco's word
 * definition of a language without configuration) on a line made of a single
 * token. These are the methods `TextModel` calls; the real part keeps them.
 */
class PlaceholderTokenizationTextModelPart extends Disposable implements ITokenizationTextModelPart {

    final _textModel:TextModel;

    var _languageId:String;

    final _onDidChangeLanguage:Emitter<IModelLanguageChangedEvent>;

    public final onDidChangeLanguage:Event<IModelLanguageChangedEvent>;

    final _onDidChangeLanguageConfiguration:Emitter<IModelLanguageConfigurationChangedEvent>;

    public final onDidChangeLanguageConfiguration:Event<IModelLanguageConfigurationChangedEvent>;

    final _onDidChangeTokens:Emitter<IModelTokensChangedEvent>;

    public final onDidChangeTokens:Event<IModelTokensChangedEvent>;

    public function new(textModel:TextModel, languageId:String) {
        super();
        this._textModel = textModel;
        this._languageId = languageId;
        this._onDidChangeLanguage = this._register(new Emitter<IModelLanguageChangedEvent>());
        this.onDidChangeLanguage = this._onDidChangeLanguage.event;
        this._onDidChangeLanguageConfiguration = this._register(new Emitter<IModelLanguageConfigurationChangedEvent>());
        this.onDidChangeLanguageConfiguration = this._onDidChangeLanguageConfiguration.event;
        this._onDidChangeTokens = this._register(new Emitter<IModelTokensChangedEvent>());
        this.onDidChangeTokens = this._onDidChangeTokens.event;
    }

    public function _hasListeners():Bool {
        return (
            this._onDidChangeLanguage.hasListeners()
            || this._onDidChangeLanguageConfiguration.hasListeners()
            || this._onDidChangeTokens.hasListeners()
        );
    }

    public function handleDidChangeContent(e:IModelContentChangedEvent):Void {}

    public function handleDidChangeAttached():Void {}

    public function getLanguageId():String {
        return this._languageId;
    }

    public function getLanguageIdAtPosition(lineNumber:Int, column:Int):String {
        return this._languageId;
    }

    public function setLanguageId(languageId:String, ?source:String):Void {
        if (this._languageId == languageId) {
            // There's nothing to do
            return;
        }

        final e:IModelLanguageChangedEvent = {
            oldLanguage: this._languageId,
            newLanguage: languageId,
            source: source
        };

        this._languageId = languageId;

        this._onDidChangeLanguage.fire(e);
        this._onDidChangeLanguageConfiguration.fire({});
    }

    public function getWordAtPosition(_position:IPosition):Null<IWordAtPosition> {
        final position = this._textModel.validatePosition(_position);
        final lineContent = this._textModel.getLineContent(position.lineNumber);

        // (1). First try checking right biased word (the line is a single token)
        final rightBiasedWord = WordHelper.getWordAtText(
            position.column,
            WordHelper.DEFAULT_WORD_REGEXP,
            lineContent,
            0
        );
        // Make sure the result touches the original passed in position
        if (
            rightBiasedWord != null
            && rightBiasedWord.startColumn <= _position.column
            && _position.column <= rightBiasedWord.endColumn
        ) {
            return rightBiasedWord;
        }

        return null;
    }

    public function getWordUntilPosition(position:IPosition):IWordAtPosition {
        final wordAtPosition = this.getWordAtPosition(position);
        if (wordAtPosition == null) {
            return {word: '', startColumn: position.column, endColumn: position.column};
        }
        return {
            word: wordAtPosition.word.substr(0, position.column - wordAtPosition.startColumn),
            startColumn: wordAtPosition.startColumn,
            endColumn: position.column,
        };
    }

}

/**
 * The bracket pairs part of a `TextModel` until
 * `model/bracketPairsTextModelPart` is ported (TODO(step 1, cs1-tokens)):
 * no brackets. These are the methods `TextModel` calls.
 */
class PlaceholderBracketPairsTextModelPart extends Disposable implements IBracketPairsTextModelPart {

    public function new() {
        super();
    }

    public function handleDidChangeContent(change:IModelContentChangedEvent):Void {}

    public function handleDidChangeOptions(e:IModelOptionsChangedEvent):Void {}

}
