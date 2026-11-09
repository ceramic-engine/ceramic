// Ported from vscode src/vs/editor/common/services/languageService.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.services;

import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Uri;
import cityscape.common.Languages;
import cityscape.common.languages.Language;
import cityscape.common.languages.ModesRegistry;

/**
 * The language service of a `Cityscape` context.
 *
 * `requestRichLanguageFeatures` creates the tokenizer of the language through
 * the context's tokenization registry, given to the constructor (Monaco uses
 * the global `TokenizationRegistry`).
 */
class LanguageService extends Disposable implements ILanguageService {

    final _onDidRequestBasicLanguageFeatures = new Emitter<String>();

    public var onDidRequestBasicLanguageFeatures(default, null):Event<String>;

    final _onDidRequestRichLanguageFeatures = new Emitter<String>();

    public var onDidRequestRichLanguageFeatures(default, null):Event<String>;

    final _onDidChange = new VoidEmitter();

    public var onDidChange(default, null):VoidEvent;

    final _requestedBasicLanguages = new Map<String, Bool>();

    final _requestedRichLanguages = new Map<String, Bool>();

    final _registry:LanguagesRegistry;

    final _tokenizationRegistry:Null<ITokenizationRegistry<ITokenizationSupport>>;

    public var languageIdCodec(get, never):ILanguageIdCodec;
    inline function get_languageIdCodec():ILanguageIdCodec {
        return _registry.languageIdCodec;
    }

    /**
     * @param modesRegistry the languages of the context (null: no language at all, not even plain text)
     * @param tokenizationRegistry the tokenizers of the context, created by `requestRichLanguageFeatures`
     */
    public function new(?modesRegistry:EditorModesRegistry, ?tokenizationRegistry:ITokenizationRegistry<ITokenizationSupport>) {
        super();
        onDidRequestBasicLanguageFeatures = _onDidRequestBasicLanguageFeatures.event;
        onDidRequestRichLanguageFeatures = _onDidRequestRichLanguageFeatures.event;
        onDidChange = _onDidChange.event;
        _register(_onDidRequestBasicLanguageFeatures);
        _register(_onDidRequestRichLanguageFeatures);
        _register(_onDidChange);
        _tokenizationRegistry = tokenizationRegistry;
        _registry = _register(new LanguagesRegistry(modesRegistry));
        _register(_registry.onDidChange(() -> _onDidChange.fire()));
    }

    public function registerLanguage(def:ILanguageExtensionPoint):IDisposable {
        return _registry.registerLanguage(def);
    }

    public function isRegisteredLanguageId(languageId:Null<String>):Bool {
        return _registry.isRegisteredLanguageId(languageId);
    }

    public function getRegisteredLanguageIds():Array<String> {
        return _registry.getRegisteredLanguageIds();
    }

    public function getSortedRegisteredLanguageNames():Array<ILanguageNameIdPair> {
        return _registry.getSortedRegisteredLanguageNames();
    }

    public function getLanguageName(languageId:String):Null<String> {
        return _registry.getLanguageName(languageId);
    }

    public function getMimeType(languageId:String):Null<String> {
        return _registry.getMimeType(languageId);
    }

    public function getExtensions(languageId:String):Array<String> {
        return _registry.getExtensions(languageId);
    }

    public function getFilenames(languageId:String):Array<String> {
        return _registry.getFilenames(languageId);
    }

    public function getConfigurationFiles(languageId:String):Array<Uri> {
        return _registry.getConfigurationFiles(languageId);
    }

    public function getLanguageIdByLanguageName(languageName:String):Null<String> {
        return _registry.getLanguageIdByLanguageName(languageName);
    }

    public function getLanguageIdByMimeType(mimeType:Null<String>):Null<String> {
        return _registry.getLanguageIdByMimeType(mimeType);
    }

    public function guessLanguageIdByFilepathOrFirstLine(resource:Null<Uri>, ?firstLine:String):Null<String> {
        final languageIds = _registry.guessLanguageIdByFilepathOrFirstLine(resource, firstLine);
        return languageIds.length > 0 ? languageIds[0] : null;
    }

    public function createById(languageId:Null<String>):ILanguageSelection {
        return new LanguageSelection(onDidChange, () -> {
            return _createAndGetLanguageIdentifier(languageId);
        });
    }

    public function createByMimeType(mimeType:Null<String>):ILanguageSelection {
        return new LanguageSelection(onDidChange, () -> {
            final languageId = getLanguageIdByMimeType(mimeType);
            return _createAndGetLanguageIdentifier(languageId);
        });
    }

    public function createByFilepathOrFirstLine(resource:Null<Uri>, ?firstLine:String):ILanguageSelection {
        return new LanguageSelection(onDidChange, () -> {
            final languageId = guessLanguageIdByFilepathOrFirstLine(resource, firstLine);
            return _createAndGetLanguageIdentifier(languageId);
        });
    }

    function _createAndGetLanguageIdentifier(languageId:Null<String>):String {
        if (languageId == null || languageId.length == 0 || !isRegisteredLanguageId(languageId)) {
            // Fall back to plain text if language is unknown
            languageId = EditorModesRegistry.PLAINTEXT_LANGUAGE_ID;
        }

        return languageId;
    }

    public function requestBasicLanguageFeatures(languageId:String):Void {
        if (!_requestedBasicLanguages.exists(languageId)) {
            _requestedBasicLanguages.set(languageId, true);
            _onDidRequestBasicLanguageFeatures.fire(languageId);
        }
    }

    /**
     * True when `requestRichLanguageFeatures` was called for the language
     * (Cityscape addition: a tokenizer registered later is then created at
     * once, see `TextMateService`).
     */
    public function hasRequestedRichLanguageFeatures(languageId:String):Bool {
        return _requestedRichLanguages.exists(languageId);
    }

    public function requestRichLanguageFeatures(languageId:String):Void {
        if (!_requestedRichLanguages.exists(languageId)) {
            _requestedRichLanguages.set(languageId, true);

            // Ensure basic features are requested
            requestBasicLanguageFeatures(languageId);

            // Ensure tokenizers are created
            if (_tokenizationRegistry != null) {
                _tokenizationRegistry.getOrCreate(languageId);
            }

            _onDidRequestRichLanguageFeatures.fire(languageId);
        }
    }

}

/**
 * The language chosen by a selector, followed when the languages change
 * (Monaco derives it from an observable).
 */
class LanguageSelection implements ILanguageSelection {

    final _selector:() -> String;

    final _onDidChange = new Emitter<String>();

    var _value:String;

    var _listener:Null<IDisposable> = null;

    public final onDidChange:Event<String>;

    public var languageId(get, never):String;
    function get_languageId():String {
        if (_listener == null) {
            _value = _selector();
        }
        return _value;
    }

    public function new(onDidChangeLanguages:VoidEvent, selector:() -> String) {
        _selector = selector;
        _value = selector();
        onDidChange = listener -> {
            if (_listener == null) {
                _value = _selector();
                _listener = onDidChangeLanguages(() -> {
                    final value = _selector();
                    if (value != _value) {
                        _value = value;
                        _onDidChange.fire(value);
                    }
                });
            }
            return _onDidChange.event(listener);
        };
    }

}
