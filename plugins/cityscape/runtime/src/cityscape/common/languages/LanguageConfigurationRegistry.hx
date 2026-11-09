// Ported from vscode src/vs/editor/common/languages/languageConfigurationRegistry.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.languages;

import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.RegExp;
import cityscape.base.common.Strings;
import cityscape.common.Model.ITextModel;
import cityscape.common.config.EditorOptions.EditorAutoIndentStrategy;
import cityscape.common.core.WordHelper;
import cityscape.common.languages.Language.ILanguageService;
import cityscape.common.languages.LanguageConfiguration;
import cityscape.common.languages.ModesRegistry.EditorModesRegistry;
import cityscape.common.languages.supports.CharacterPair;
import cityscape.common.languages.supports.ElectricCharacter;
import cityscape.common.languages.supports.IndentRules;
import cityscape.common.languages.supports.LanguageBracketsConfiguration;
import cityscape.common.languages.supports.OnEnter;
import cityscape.common.languages.supports.RichEditBrackets;

/**
 * Interface used to support insertion of mode specific comments.
 */
typedef ICommentsConfiguration = {
    @:optional var lineCommentToken:String;
    @:optional var blockCommentStartToken:String;
    @:optional var blockCommentEndToken:String;
}

/**
 * The language configurations of a `Cityscape` context
 * (`Cityscape.languageConfigurationService`).
 */
interface ILanguageConfigurationService {

    var onDidChange(default, null):Event<LanguageConfigurationServiceChangeEvent>;

    /**
     * @param priority Use a higher number for higher priority
     */
    function register(languageId:String, configuration:LanguageConfiguration, ?priority:Int):IDisposable;

    function getLanguageConfiguration(languageId:String):ResolvedLanguageConfiguration;

}

class LanguageConfigurationServiceChangeEvent {

    public final languageId:Null<String>;

    public function new(languageId:Null<String>) {
        this.languageId = languageId;
    }

    public function affects(languageId:String):Bool {
        return (this.languageId == null || this.languageId == '') ? true : this.languageId == languageId;
    }

}

/**
 * The language configuration service of a `Cityscape` context.
 *
 * Monaco's service also reads the user settings `editor.language.brackets`
 * and `editor.language.colorizedBracketPairs` from its configuration service
 * (with per language overrides) and merges them into the registered
 * configurations. Cityscape has no configuration service: these settings are
 * not supported, the registered configurations are used as they are.
 */
class LanguageConfigurationService extends Disposable implements ILanguageConfigurationService {

    final _registry:LanguageConfigurationRegistry;

    final onDidChangeEmitter:Emitter<LanguageConfigurationServiceChangeEvent>;

    public var onDidChange(default, null):Event<LanguageConfigurationServiceChangeEvent>;

    final configurations = new Map<String, ResolvedLanguageConfiguration>();

    final languageService:ILanguageService;

    public function new(languageService:ILanguageService) {
        super();
        this.languageService = languageService;

        _registry = _register(new LanguageConfigurationRegistry());
        onDidChangeEmitter = _register(new Emitter<LanguageConfigurationServiceChangeEvent>());
        onDidChange = onDidChangeEmitter.event;

        _register(_registry.onDidChange((e) -> {
            configurations.remove(e.languageId);
            onDidChangeEmitter.fire(new LanguageConfigurationServiceChangeEvent(e.languageId));
        }));
    }

    public function register(languageId:String, configuration:LanguageConfiguration, ?priority:Int):IDisposable {
        return _registry.register(languageId, configuration, priority);
    }

    public function getLanguageConfiguration(languageId:String):ResolvedLanguageConfiguration {
        var result = configurations.get(languageId);
        if (result == null) {
            result = computeConfig(languageId, _registry, languageService);
            configurations.set(languageId, result);
        }
        return result;
    }

    static function computeConfig(
        languageId:String,
        registry:LanguageConfigurationRegistry,
        languageService:ILanguageService
    ):ResolvedLanguageConfiguration {
        var languageConfig = registry.getLanguageConfiguration(languageId);

        if (languageConfig == null) {
            if (!languageService.isRegisteredLanguageId(languageId)) {
                // this happens for the null language, which can be returned by monarch.
                // Instead of throwing an error, we just return a default config.
                return new ResolvedLanguageConfiguration(languageId, {});
            }
            languageConfig = new ResolvedLanguageConfiguration(languageId, {});
        }

        final customizedConfig = getCustomizedLanguageConfig(languageConfig.languageId);
        final data = LanguageConfigurationRegistry.combineLanguageConfigurations([languageConfig.underlyingConfig, customizedConfig]);
        final config = new ResolvedLanguageConfiguration(languageConfig.languageId, data);
        return config;
    }

    /**
     * Monaco reads `editor.language.brackets` and
     * `editor.language.colorizedBracketPairs` here; Cityscape has no user
     * settings, so they are always unset.
     */
    static function getCustomizedLanguageConfig(languageId:String):LanguageConfiguration {
        return {
            brackets: null,
            colorizedBracketPairs: null,
        };
    }

}

private class ComposedLanguageConfiguration {

    final _entries:Array<LanguageConfigurationContribution>;
    var _order:Int;
    var _resolved:Null<ResolvedLanguageConfiguration> = null;

    public final languageId:String;

    public function new(languageId:String) {
        this.languageId = languageId;
        _entries = [];
        _order = 0;
        _resolved = null;
    }

    public function register(
        configuration:LanguageConfiguration,
        priority:Int
    ):IDisposable {
        final entry = new LanguageConfigurationContribution(
            configuration,
            priority,
            ++_order
        );
        _entries.push(entry);
        _resolved = null;
        return Lifecycle.toDisposable(() -> {
            for (i in 0..._entries.length) {
                if (_entries[i] == entry) {
                    _entries.splice(i, 1);
                    _resolved = null;
                    break;
                }
            }
        });
    }

    public function getResolvedConfiguration():Null<ResolvedLanguageConfiguration> {
        if (_resolved == null) {
            final config = _resolve();
            if (config != null) {
                _resolved = new ResolvedLanguageConfiguration(
                    languageId,
                    config
                );
            }
        }
        return _resolved;
    }

    function _resolve():Null<LanguageConfiguration> {
        if (_entries.length == 0) {
            return null;
        }
        haxe.ds.ArraySort.sort(_entries, LanguageConfigurationContribution.cmp);
        return LanguageConfigurationRegistry.combineLanguageConfigurations([for (e in _entries) e.configuration]);
    }

}

private class LanguageConfigurationContribution {

    public final configuration:LanguageConfiguration;
    public final priority:Int;
    public final order:Int;

    public function new(configuration:LanguageConfiguration, priority:Int, order:Int) {
        this.configuration = configuration;
        this.priority = priority;
        this.order = order;
    }

    public static function cmp(a:LanguageConfigurationContribution, b:LanguageConfigurationContribution):Int {
        if (a.priority == b.priority) {
            // higher order last
            return a.order - b.order;
        }
        // higher priority last
        return a.priority - b.priority;
    }

}

class LanguageConfigurationChangeEvent {

    public final languageId:String;

    public function new(languageId:String) {
        this.languageId = languageId;
    }

}

class LanguageConfigurationRegistry extends Disposable {

    final _entries = new Map<String, ComposedLanguageConfiguration>();

    final _onDidChange:Emitter<LanguageConfigurationChangeEvent>;
    public final onDidChange:Event<LanguageConfigurationChangeEvent>;

    public function new() {
        super();
        _onDidChange = _register(new Emitter<LanguageConfigurationChangeEvent>());
        onDidChange = _onDidChange.event;
        _register(register(EditorModesRegistry.PLAINTEXT_LANGUAGE_ID, {
            brackets: [
                ['(', ')'],
                ['[', ']'],
                ['{', '}'],
            ],
            surroundingPairs: [
                {open: '{', close: '}'},
                {open: '[', close: ']'},
                {open: '(', close: ')'},
                {open: '<', close: '>'},
                {open: '\"', close: '\"'},
                {open: '\'', close: '\''},
                {open: '`', close: '`'},
            ],
            colorizedBracketPairs: [],
            folding: {
                offSide: true
            }
        }, 0));
    }

    /**
     * @param priority Use a higher number for higher priority
     */
    public function register(languageId:String, configuration:LanguageConfiguration, ?priority:Int):IDisposable {
        if (priority == null) {
            priority = 0;
        }
        var entries = _entries.get(languageId);
        if (entries == null) {
            entries = new ComposedLanguageConfiguration(languageId);
            _entries.set(languageId, entries);
        }

        final disposable = entries.register(configuration, priority);
        _onDidChange.fire(new LanguageConfigurationChangeEvent(languageId));

        return Lifecycle.toDisposable(() -> {
            disposable.dispose();
            _onDidChange.fire(new LanguageConfigurationChangeEvent(languageId));
        });
    }

    public function getLanguageConfiguration(languageId:String):Null<ResolvedLanguageConfiguration> {
        final entries = _entries.get(languageId);
        return entries != null ? entries.getResolvedConfiguration() : null;
    }

    /**
     * `getIndentationAtPosition` of languageConfigurationRegistry.ts.
     */
    public static function getIndentationAtPosition(model:ITextModel, lineNumber:Int, column:Int):String {
        final lineText = model.getLineContent(lineNumber);
        var indentation = Strings.getLeadingWhitespace(lineText);
        if (indentation.length > column - 1) {
            indentation = indentation.substring(0, column - 1);
        }
        return indentation;
    }

    /**
     * `combineLanguageConfigurations` of languageConfigurationRegistry.ts.
     * A later configuration overrides a field when its value is set (not
     * null, and not an empty `autoCloseBefore`: JavaScript's `||`).
     */
    @:allow(cityscape.common.languages)
    static function combineLanguageConfigurations(configs:Array<LanguageConfiguration>):LanguageConfiguration {
        var comments:Null<CommentRule> = null;
        var brackets:Null<Array<CharacterPair>> = null;
        var wordPattern:Null<RegExp> = null;
        var indentationRules:Null<IndentationRule> = null;
        var onEnterRules:Null<Array<OnEnterRule>> = null;
        var autoClosingPairs:Null<Array<IAutoClosingPairConditional>> = null;
        var surroundingPairs:Null<Array<IAutoClosingPair>> = null;
        var autoCloseBefore:Null<String> = null;
        var folding:Null<FoldingRules> = null;
        var colorizedBracketPairs:Null<Array<CharacterPair>> = null;
        var electricCharacterSupport = null;
        for (entry in configs) {
            if (entry.comments != null) comments = entry.comments;
            if (entry.brackets != null) brackets = entry.brackets;
            if (entry.wordPattern != null) wordPattern = entry.wordPattern;
            if (entry.indentationRules != null) indentationRules = entry.indentationRules;
            if (entry.onEnterRules != null) onEnterRules = entry.onEnterRules;
            if (entry.autoClosingPairs != null) autoClosingPairs = entry.autoClosingPairs;
            if (entry.surroundingPairs != null) surroundingPairs = entry.surroundingPairs;
            autoCloseBefore = (entry.autoCloseBefore != null && entry.autoCloseBefore.length > 0) ? entry.autoCloseBefore : autoCloseBefore;
            if (entry.folding != null) folding = entry.folding;
            if (entry.colorizedBracketPairs != null) colorizedBracketPairs = entry.colorizedBracketPairs;
            if (entry.__electricCharacterSupport != null) electricCharacterSupport = entry.__electricCharacterSupport;
        }

        return {
            comments: comments,
            brackets: brackets,
            wordPattern: wordPattern,
            indentationRules: indentationRules,
            onEnterRules: onEnterRules,
            autoClosingPairs: autoClosingPairs,
            surroundingPairs: surroundingPairs,
            autoCloseBefore: autoCloseBefore,
            folding: folding,
            colorizedBracketPairs: colorizedBracketPairs,
            __electricCharacterSupport: electricCharacterSupport,
        };
    }

}

/**
 * Immutable.
 */
class ResolvedLanguageConfiguration {

    var _brackets:Null<RichEditBrackets>;
    var _electricCharacter:Null<BracketElectricCharacterSupport>;
    final _onEnterSupport:Null<OnEnterSupport>;

    public final comments:Null<ICommentsConfiguration>;
    public final characterPair:CharacterPairSupport;
    public final wordDefinition:RegExp;
    public final indentRulesSupport:Null<IndentRulesSupport>;
    public final indentationRules:Null<IndentationRule>;
    public final foldingRules:FoldingRules;
    public final bracketsNew:LanguageBracketsConfiguration;

    public final languageId:String;
    public final underlyingConfig:LanguageConfiguration;

    public function new(languageId:String, underlyingConfig:LanguageConfiguration) {
        this.languageId = languageId;
        this.underlyingConfig = underlyingConfig;
        _brackets = null;
        _electricCharacter = null;
        _onEnterSupport =
            underlyingConfig.brackets != null
                || underlyingConfig.indentationRules != null
                || underlyingConfig.onEnterRules != null
                ? new OnEnterSupport(underlyingConfig)
                : null;
        comments = ResolvedLanguageConfiguration._handleComments(underlyingConfig);
        characterPair = new CharacterPairSupport(underlyingConfig);

        wordDefinition = underlyingConfig.wordPattern != null ? underlyingConfig.wordPattern : WordHelper.DEFAULT_WORD_REGEXP;
        indentationRules = underlyingConfig.indentationRules;
        if (underlyingConfig.indentationRules != null) {
            indentRulesSupport = new IndentRulesSupport(
                underlyingConfig.indentationRules
            );
        }
        else {
            indentRulesSupport = null;
        }
        foldingRules = underlyingConfig.folding != null ? underlyingConfig.folding : {};

        bracketsNew = new LanguageBracketsConfiguration(
            languageId,
            underlyingConfig
        );
    }

    public function getWordDefinition():RegExp {
        return WordHelper.ensureValidWordDefinition(wordDefinition);
    }

    public var brackets(get, never):Null<RichEditBrackets>;
    function get_brackets():Null<RichEditBrackets> {
        if (_brackets == null && underlyingConfig.brackets != null) {
            _brackets = new RichEditBrackets(
                languageId,
                underlyingConfig.brackets
            );
        }
        return _brackets;
    }

    public var electricCharacter(get, never):Null<BracketElectricCharacterSupport>;
    function get_electricCharacter():Null<BracketElectricCharacterSupport> {
        if (_electricCharacter == null) {
            _electricCharacter = new BracketElectricCharacterSupport(
                brackets
            );
        }
        return _electricCharacter;
    }

    public function onEnter(
        autoIndent:EditorAutoIndentStrategy,
        previousLineText:String,
        beforeEnterText:String,
        afterEnterText:String
    ):Null<EnterAction> {
        if (_onEnterSupport == null) {
            return null;
        }
        return _onEnterSupport.onEnter(
            autoIndent,
            previousLineText,
            beforeEnterText,
            afterEnterText
        );
    }

    public function getAutoClosingPairs():AutoClosingPairs {
        return new AutoClosingPairs(characterPair.getAutoClosingPairs());
    }

    public function getAutoCloseBeforeSet(forQuotes:Bool):String {
        return characterPair.getAutoCloseBeforeSet(forQuotes);
    }

    public function getSurroundingPairs():Array<IAutoClosingPair> {
        return characterPair.getSurroundingPairs();
    }

    static function _handleComments(
        conf:LanguageConfiguration
    ):Null<ICommentsConfiguration> {
        final commentRule = conf.comments;
        if (commentRule == null) {
            return null;
        }

        // comment configuration
        final comments:ICommentsConfiguration = {};

        if (commentRule.lineComment != null && commentRule.lineComment.length > 0) {
            comments.lineCommentToken = commentRule.lineComment;
        }
        if (commentRule.blockComment != null) {
            final blockStart = commentRule.blockComment[0];
            final blockEnd = commentRule.blockComment[1];
            comments.blockCommentStartToken = blockStart;
            comments.blockCommentEndToken = blockEnd;
        }

        return comments;
    }

}
