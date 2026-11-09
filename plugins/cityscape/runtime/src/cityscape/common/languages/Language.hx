// Ported from vscode src/vs/editor/common/languages/language.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.languages;

import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle.IDisposable;
import cityscape.base.common.Uri;
import cityscape.common.Languages.ILanguageIdCodec;

typedef ILanguageExtensionPoint = {
    var id:String;
    @:optional var extensions:Array<String>;
    @:optional var filenames:Array<String>;
    /**
     * Not supported by Cityscape yet (glob patterns): ignored.
     */
    @:optional var filenamePatterns:Array<String>;
    @:optional var firstLine:String;
    /**
     * An empty array means that the language has no name. Haxe has a single
     * `null`: a null entry inside the array stands for Monaco's `null` alias.
     */
    @:optional var aliases:Array<Null<String>>;
    @:optional var mimetypes:Array<String>;
    @:optional var configuration:Uri;
}

/**
 * A language chosen for a model, which can change (`onDidChange`).
 */
interface ILanguageSelection {
    /**
     * A property (Monaco's is a getter: the language can change).
     */
    var languageId(get, never):String;
    final onDidChange:Event<String>;
}

typedef ILanguageNameIdPair = {
    final languageName:String;
    final languageId:String;
}

/**
 * The language service of a `Cityscape` context (Monaco's `ILanguageService`
 * singleton).
 */
interface ILanguageService {

    /**
     * A codec which can encode and decode a string `languageId` as a number.
     */
    var languageIdCodec(get, never):ILanguageIdCodec;

    /**
     * An event emitted when basic language features are requested for the first time.
     */
    var onDidRequestBasicLanguageFeatures(default, null):Event<String>;

    /**
     * An event emitted when rich language features are requested for the first time.
     */
    var onDidRequestRichLanguageFeatures(default, null):Event<String>;

    /**
     * An event emitted when languages have changed.
     */
    var onDidChange(default, null):VoidEvent;

    /**
     * Register a language.
     */
    function registerLanguage(def:ILanguageExtensionPoint):IDisposable;

    /**
     * Check if `languageId` is registered.
     */
    function isRegisteredLanguageId(languageId:Null<String>):Bool;

    /**
     * Get a list of all registered languages.
     */
    function getRegisteredLanguageIds():Array<String>;

    /**
     * Get a list of all registered languages with a name.
     * If a language is explicitly registered without a name, it will not be part of the result.
     * The result is sorted using by name case insensitive.
     */
    function getSortedRegisteredLanguageNames():Array<ILanguageNameIdPair>;

    /**
     * Get the preferred language name for a language.
     */
    function getLanguageName(languageId:String):Null<String>;

    /**
     * Get the mimetype for a language.
     */
    function getMimeType(languageId:String):Null<String>;

    /**
     * Get all file extensions for a language.
     */
    function getExtensions(languageId:String):Array<String>;

    /**
     * Get all file names for a language.
     */
    function getFilenames(languageId:String):Array<String>;

    /**
     * Get all language configuration files for a language.
     */
    function getConfigurationFiles(languageId:String):Array<Uri>;

    /**
     * Look up a language by its name case insensitive.
     */
    function getLanguageIdByLanguageName(languageName:String):Null<String>;

    /**
     * Look up a language by its mime type.
     */
    function getLanguageIdByMimeType(mimeType:Null<String>):Null<String>;

    /**
     * Guess the language id for a resource.
     */
    function guessLanguageIdByFilepathOrFirstLine(resource:Null<Uri>, ?firstLine:String):Null<String>;

    /**
     * Will fall back to 'plaintext' if `languageId` is unknown.
     */
    function createById(languageId:Null<String>):ILanguageSelection;

    /**
     * Will fall back to 'plaintext' if `mimeType` is unknown.
     */
    function createByMimeType(mimeType:Null<String>):ILanguageSelection;

    /**
     * Will fall back to 'plaintext' if the `languageId` cannot be determined.
     */
    function createByFilepathOrFirstLine(resource:Null<Uri>, ?firstLine:String):ILanguageSelection;

    /**
     * Request basic language features for a language.
     */
    function requestBasicLanguageFeatures(languageId:String):Void;

    /**
     * Request rich language features for a language.
     */
    function requestRichLanguageFeatures(languageId:String):Void;

}
