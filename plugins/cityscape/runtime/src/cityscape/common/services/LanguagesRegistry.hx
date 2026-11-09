// Ported from vscode src/vs/editor/common/services/languagesRegistry.ts and languagesAssociations.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.services;

import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.RegExp;
import cityscape.base.common.Strings;
import cityscape.base.common.Uri;
import cityscape.common.EncodedTokenAttributes.LanguageId;
import cityscape.common.Languages.ILanguageIdCodec;
import cityscape.common.languages.Language;
import cityscape.common.languages.ModesRegistry;

private typedef IResolvedLanguage = {
    var identifier:String;
    var name:Null<String>;
    var mimetypes:Array<String>;
    var aliases:Array<String>;
    var extensions:Array<String>;
    var filenames:Array<String>;
    var configurationFiles:Array<Uri>;
}

/**
 * A language association of languagesAssociations.ts (Monaco keeps them in
 * module globals; Cityscape keeps them in the registry of a context).
 * File patterns (globs) are not supported yet.
 */
private typedef ILanguageAssociationItem = {
    final id:String;
    final mime:String;
    @:optional final filename:String;
    @:optional final extension:String;
    @:optional final firstline:RegExp;
    @:optional final filenameLowercase:String;
    @:optional final extensionLowercase:String;
}

class LanguageIdCodec implements ILanguageIdCodec {

    public static inline final NULL_LANGUAGE_ID = 'vs.editor.nullLanguage';

    var _nextLanguageId:Int;

    final _languageIdToLanguage:Array<String> = [];

    final _languageToLanguageId = new Map<String, Int>();

    public function new() {
        _register(NULL_LANGUAGE_ID, LanguageId.Null);
        _register(EditorModesRegistry.PLAINTEXT_LANGUAGE_ID, LanguageId.PlainText);
        _nextLanguageId = 2;
    }

    function _register(language:String, languageId:LanguageId):Void {
        _languageIdToLanguage[languageId] = language;
        _languageToLanguageId.set(language, languageId);
    }

    public function register(language:String):Void {
        if (_languageToLanguageId.exists(language)) {
            return;
        }
        final languageId = _nextLanguageId++;
        _register(language, languageId);
    }

    public function encodeLanguageId(languageId:String):LanguageId {
        final id = _languageToLanguageId.get(languageId);
        return id != null ? id : LanguageId.Null;
    }

    public function decodeLanguageId(languageId:LanguageId):String {
        final language = _languageIdToLanguage[languageId];
        return language != null ? language : NULL_LANGUAGE_ID;
    }

}

class LanguagesRegistry extends Disposable {

    final _onDidChange = new VoidEmitter();

    public final onDidChange:VoidEvent;

    public final languageIdCodec:LanguageIdCodec;

    final _modesRegistry:EditorModesRegistry;

    var _dynamicLanguages:Array<ILanguageExtensionPoint>;

    var _languages:Map<String, IResolvedLanguage>;

    /**
     * Language ids in registration order (Monaco iterates `Object.keys`).
     */
    var _languageIds:Array<String>;

    var _mimeTypesMap:Map<String, String>;

    var _nameMap:Map<String, String>;

    var _nameMapKeys:Array<String>;

    var _lowercaseNameMap:Map<String, String>;

    var _associations:Array<ILanguageAssociationItem> = [];

    /**
     * @param modesRegistry the languages of the context (Monaco's global
     * `ModesRegistry`), or null to start without any language (Monaco's
     * `useModesRegistry = false`).
     */
    public function new(?modesRegistry:EditorModesRegistry) {
        super();
        onDidChange = _onDidChange.event;
        _register(_onDidChange);

        languageIdCodec = new LanguageIdCodec();
        _modesRegistry = modesRegistry;
        _dynamicLanguages = [];
        _languages = new Map();
        _languageIds = [];
        _mimeTypesMap = new Map();
        _nameMap = new Map();
        _nameMapKeys = [];
        _lowercaseNameMap = new Map();

        if (modesRegistry != null) {
            _initializeFromRegistry();
            _register(modesRegistry.onDidChangeLanguages(() -> {
                _initializeFromRegistry();
            }));
        }
    }

    public function setDynamicLanguages(def:Array<ILanguageExtensionPoint>):Void {
        _dynamicLanguages = def;
        _initializeFromRegistry();
    }

    function _initializeFromRegistry():Void {
        _languages = new Map();
        _languageIds = [];
        _mimeTypesMap = new Map();
        _nameMap = new Map();
        _nameMapKeys = [];
        _lowercaseNameMap = new Map();

        _associations = [];
        final desc:Array<ILanguageExtensionPoint> = (_modesRegistry != null ? _modesRegistry.getLanguages() : []).concat(_dynamicLanguages);
        _registerLanguages(desc);
    }

    public function registerLanguage(desc:ILanguageExtensionPoint):IDisposable {
        if (_modesRegistry == null) {
            _dynamicLanguages.push(desc);
            _initializeFromRegistry();
            return Lifecycle.toDisposable(() -> {
                _dynamicLanguages.remove(desc);
            });
        }
        return _modesRegistry.registerLanguage(desc);
    }

    public function _registerLanguages(desc:Array<ILanguageExtensionPoint>):Void {

        for (d in desc) {
            _registerLanguage(d);
        }

        // Rebuild fast path maps
        _mimeTypesMap = new Map();
        _nameMap = new Map();
        _nameMapKeys = [];
        _lowercaseNameMap = new Map();
        for (langId in _languageIds) {
            final language = _languages.get(langId);
            if (language.name != null && language.name.length > 0) {
                if (!_nameMap.exists(language.name)) {
                    _nameMapKeys.push(language.name);
                }
                _nameMap.set(language.name, language.identifier);
            }
            for (alias in language.aliases) {
                _lowercaseNameMap.set(alias.toLowerCase(), language.identifier);
            }
            for (mimetype in language.mimetypes) {
                _mimeTypesMap.set(mimetype, language.identifier);
            }
        }

        _onDidChange.fire();
    }

    function _registerLanguage(lang:ILanguageExtensionPoint):Void {
        final langId = lang.id;

        var resolvedLanguage:IResolvedLanguage;
        if (_languages.exists(langId)) {
            resolvedLanguage = _languages.get(langId);
        }
        else {
            languageIdCodec.register(langId);
            resolvedLanguage = {
                identifier: langId,
                name: null,
                mimetypes: [],
                aliases: [],
                extensions: [],
                filenames: [],
                configurationFiles: []
            };
            _languages.set(langId, resolvedLanguage);
            _languageIds.push(langId);
        }

        _mergeLanguage(resolvedLanguage, lang);
    }

    function _mergeLanguage(resolvedLanguage:IResolvedLanguage, lang:ILanguageExtensionPoint):Void {
        final langId = lang.id;

        var primaryMime:Null<String> = null;

        if (lang.mimetypes != null && lang.mimetypes.length > 0) {
            for (m in lang.mimetypes) {
                resolvedLanguage.mimetypes.push(m);
            }
            primaryMime = lang.mimetypes[0];
        }

        if (primaryMime == null || primaryMime.length == 0) {
            primaryMime = 'text/x-' + langId;
            resolvedLanguage.mimetypes.push(primaryMime);
        }

        if (lang.extensions != null) {
            if (lang.configuration != null) {
                // insert first as this appears to be the 'primary' language definition
                resolvedLanguage.extensions = lang.extensions.concat(resolvedLanguage.extensions);
            }
            else {
                resolvedLanguage.extensions = resolvedLanguage.extensions.concat(lang.extensions);
            }
            for (extension in lang.extensions) {
                _associations.push({id: langId, mime: primaryMime, extension: extension, extensionLowercase: extension.toLowerCase()});
            }
        }

        if (lang.filenames != null) {
            for (filename in lang.filenames) {
                _associations.push({id: langId, mime: primaryMime, filename: filename, filenameLowercase: filename.toLowerCase()});
                resolvedLanguage.filenames.push(filename);
            }
        }

        if (lang.firstLine != null && lang.firstLine.length > 0) {
            var firstLineRegexStr = lang.firstLine;
            if (firstLineRegexStr.charAt(0) != '^') {
                firstLineRegexStr = '^' + firstLineRegexStr;
            }
            try {
                final firstLineRegex = new RegExp(firstLineRegexStr);
                if (!Strings.regExpLeadsToEndlessLoop(firstLineRegex)) {
                    _associations.push({id: langId, mime: primaryMime, firstline: firstLineRegex});
                }
            }
            catch (err:Dynamic) {
                // Most likely, the regex was bad
                haxe.Log.trace('[' + lang.id + ']: Invalid regular expression `' + firstLineRegexStr + '`: ' + Std.string(err), null);
            }
        }

        resolvedLanguage.aliases.push(langId);

        var langAliases:Null<Array<Null<String>>> = null;
        if (lang.aliases != null) {
            if (lang.aliases.length == 0) {
                // signal that this language should not get a name
                langAliases = [null];
            }
            else {
                langAliases = lang.aliases;
            }
        }

        if (langAliases != null) {
            for (langAlias in langAliases) {
                if (langAlias == null || langAlias.length == 0) {
                    continue;
                }
                resolvedLanguage.aliases.push(langAlias);
            }
        }

        final containsAliases = (langAliases != null && langAliases.length > 0);
        if (containsAliases && langAliases[0] == null) {
            // signal that this language should not get a name
        }
        else {
            final first = containsAliases ? langAliases[0] : null;
            final bestName = (first != null && first.length > 0) ? first : langId;
            if (containsAliases || resolvedLanguage.name == null || resolvedLanguage.name.length == 0) {
                resolvedLanguage.name = bestName;
            }
        }

        if (lang.configuration != null) {
            resolvedLanguage.configurationFiles.push(lang.configuration);
        }
    }

    public function isRegisteredLanguageId(languageId:Null<String>):Bool {
        if (languageId == null || languageId.length == 0) {
            return false;
        }
        return _languages.exists(languageId);
    }

    public function getRegisteredLanguageIds():Array<String> {
        return _languageIds.copy();
    }

    public function getSortedRegisteredLanguageNames():Array<ILanguageNameIdPair> {
        final result:Array<ILanguageNameIdPair> = [];
        for (languageName in _nameMapKeys) {
            result.push({
                languageName: languageName,
                languageId: _nameMap.get(languageName)
            });
        }
        haxe.ds.ArraySort.sort(result, (a, b) -> compareIgnoreCase(a.languageName, b.languageName));
        return result;
    }

    static function compareIgnoreCase(a:String, b:String):Int {
        final la = a.toLowerCase();
        final lb = b.toLowerCase();
        return la < lb ? -1 : (la > lb ? 1 : 0);
    }

    public function getLanguageName(languageId:String):Null<String> {
        if (!_languages.exists(languageId)) {
            return null;
        }
        return _languages.get(languageId).name;
    }

    public function getMimeType(languageId:String):Null<String> {
        if (!_languages.exists(languageId)) {
            return null;
        }
        final language = _languages.get(languageId);
        return language.mimetypes.length > 0 ? language.mimetypes[0] : null;
    }

    public function getExtensions(languageId:String):Array<String> {
        if (!_languages.exists(languageId)) {
            return [];
        }
        return _languages.get(languageId).extensions;
    }

    public function getFilenames(languageId:String):Array<String> {
        if (!_languages.exists(languageId)) {
            return [];
        }
        return _languages.get(languageId).filenames;
    }

    public function getConfigurationFiles(languageId:String):Array<Uri> {
        if (!_languages.exists(languageId)) {
            return [];
        }
        return _languages.get(languageId).configurationFiles;
    }

    public function getLanguageIdByLanguageName(languageName:String):Null<String> {
        final languageNameLower = languageName.toLowerCase();
        return _lowercaseNameMap.get(languageNameLower);
    }

    public function getLanguageIdByMimeType(mimeType:Null<String>):Null<String> {
        if (mimeType == null || mimeType.length == 0) {
            return null;
        }
        return _mimeTypesMap.get(mimeType);
    }

    public function guessLanguageIdByFilepathOrFirstLine(resource:Null<Uri>, ?firstLine:String):Array<String> {
        if (resource == null && (firstLine == null || firstLine.length == 0)) {
            return [];
        }
        return getLanguageIds(resource, firstLine);
    }

    // languagesAssociations.ts

    function getLanguageIds(resource:Null<Uri>, ?firstLine:String):Array<String> {
        var path:Null<String> = null;
        if (resource != null) {
            path = resource.scheme == 'file' ? resource.fsPath : resource.path;
        }

        if (path == null || path.length == 0) {
            return ['unknown'];
        }

        path = path.toLowerCase();

        final slash = Std.int(Math.max(path.lastIndexOf('/'), path.lastIndexOf('\\')));
        final filename = path.substr(slash + 1);

        // Registered mappings have middle priority (Cityscape has no user configured mappings)
        final registeredLanguage = getAssociationByPath(filename);
        if (registeredLanguage != null) {
            return [registeredLanguage.id, EditorModesRegistry.PLAINTEXT_LANGUAGE_ID];
        }

        // Firstline has lowest priority
        if (firstLine != null && firstLine.length > 0) {
            final firstlineLanguage = getAssociationByFirstline(firstLine);
            if (firstlineLanguage != null) {
                return [firstlineLanguage.id, EditorModesRegistry.PLAINTEXT_LANGUAGE_ID];
            }
        }

        return ['unknown'];
    }

    function getAssociationByPath(filename:String):Null<ILanguageAssociationItem> {
        var filenameMatch:Null<ILanguageAssociationItem> = null;
        var extensionMatch:Null<ILanguageAssociationItem> = null;

        // We want to prioritize associations based on the order they are registered so that the last registered
        // association wins over all other.
        var i = _associations.length - 1;
        while (i >= 0) {
            final association = _associations[i];
            i--;

            // First exact name match
            if (association.filenameLowercase != null && filename == association.filenameLowercase) {
                filenameMatch = association;
                break; // take it!
            }

            // Longest extension match
            if (association.extension != null) {
                if (extensionMatch == null || association.extension.length > extensionMatch.extension.length) {
                    if (StringTools.endsWith(filename, association.extensionLowercase)) {
                        extensionMatch = association;
                    }
                }
            }
        }

        if (filenameMatch != null) {
            return filenameMatch;
        }
        return extensionMatch;
    }

    function getAssociationByFirstline(firstLine:String):Null<ILanguageAssociationItem> {
        if (Strings.startsWithUTF8BOM(firstLine)) {
            firstLine = firstLine.substr(1);
        }

        if (firstLine.length > 0) {
            var i = _associations.length - 1;
            while (i >= 0) {
                final association = _associations[i];
                i--;
                if (association.firstline == null) {
                    continue;
                }
                final regex = association.firstline;
                regex.lastIndex = 0;
                if (regex.test(firstLine)) {
                    return association;
                }
            }
        }

        return null;
    }

}
