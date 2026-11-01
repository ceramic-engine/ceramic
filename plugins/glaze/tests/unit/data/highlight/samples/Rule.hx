// Ported from vscode-textmate 9.2.0: src/rule.ts
// Original code Copyright (C) Microsoft Corporation, licensed under MIT.
// Modified: translated to Haxe. See README.md.

package textmate;

import textmate.OnigLib;
import textmate.RawGrammar;
import textmate.Utils.RegexSource;
import textmate.grammar.GrammarDependencies;

/**
 * Rule ids are positive integers. `endRuleId` (-1) and `whileRuleId` (-2)
 * are special values in compiled rules.
 */
typedef RuleId = Int;

interface IRuleRegistry {
    function getRule(ruleId:RuleId):Rule;
    function registerRule<T:Rule>(factory:RuleId->T):T;
}

interface IGrammarRegistry {
    function getExternalGrammar(scopeName:String, ?repository:IRawRepository):Null<IRawGrammar>;
}

interface IRuleFactoryHelper extends IRuleRegistry extends IGrammarRegistry {}

/**
 * What `compile` and `compileAG` need: `IRuleRegistry & IOnigLib`.
 */
interface IRuleCompileHelper extends IRuleRegistry extends IOnigLib {}

class Rules {
    // This is a special constant to indicate that the end regexp matched.
    public static inline var endRuleId = -1;

    // This is a special constant to indicate that the while regexp matched.
    public static inline var whileRuleId = -2;

    public static inline function ruleIdFromNumber(id:Int):RuleId {
        return id;
    }

    public static inline function ruleIdToNumber(id:RuleId):Int {
        return id;
    }

    /** `/\\(\d+)/.test(source)` */
    public static function hasBackReferences(source:Null<String>):Bool {
        if (source == null) {
            return false;
        }
        var len = source.length;
        for (i in 0...len - 1) {
            if (StringTools.fastCodeAt(source, i) == '\\'.code) {
                var c = StringTools.fastCodeAt(source, i + 1);
                if (c >= '0'.code && c <= '9'.code) {
                    return true;
                }
            }
        }
        return false;
    }
}

abstract class Rule {
    public final location:Null<ILocation>;
    public final id:RuleId;

    final _nameIsCapturing:Bool;
    final _name:Null<String>;

    final _contentNameIsCapturing:Bool;
    final _contentName:Null<String>;

    public function new(location:Null<ILocation>, id:RuleId, name:Null<String>, contentName:Null<String>) {
        this.location = location;
        this.id = id;
        this._name = (name == null || name.length == 0) ? null : name;
        this._nameIsCapturing = RegexSource.hasCaptures(this._name);
        this._contentName = (contentName == null || contentName.length == 0) ? null : contentName;
        this._contentNameIsCapturing = RegexSource.hasCaptures(this._contentName);
    }

    public abstract function dispose():Void;

    public var debugName(get, never):String;

    function get_debugName():String {
        var location = this.location != null ? Utils.basename(this.location.filename != null ? this.location.filename : 'null') + ':' + this.location.line : 'unknown';
        var className = Type.getClassName(Type.getClass(this));
        var dot = className.lastIndexOf('.');
        if (dot != -1) {
            className = className.substring(dot + 1);
        }
        return '$className#$id @ $location';
    }

    public function getName(lineText:Null<String>, captureIndices:Null<Array<IOnigCaptureIndex>>):Null<String> {
        if (!_nameIsCapturing || _name == null || lineText == null || captureIndices == null) {
            return _name;
        }
        return RegexSource.replaceCaptures(_name, lineText, captureIndices);
    }

    public function getContentName(lineText:String, captureIndices:Array<IOnigCaptureIndex>):Null<String> {
        if (!_contentNameIsCapturing || _contentName == null) {
            return _contentName;
        }
        return RegexSource.replaceCaptures(_contentName, lineText, captureIndices);
    }

    public abstract function collectPatterns(grammar:IRuleRegistry, out:RegExpSourceList):Void;

    public abstract function compile(grammar:IRuleCompileHelper, endRegexSource:Null<String>):CompiledRule;

    public abstract function compileAG(grammar:IRuleCompileHelper, endRegexSource:Null<String>, allowA:Bool, allowG:Bool):CompiledRule;
}

class ICompilePatternsResult {
    public final patterns:Array<RuleId>;
    public final hasMissingPatterns:Bool;

    public function new(patterns:Array<RuleId>, hasMissingPatterns:Bool) {
        this.patterns = patterns;
        this.hasMissingPatterns = hasMissingPatterns;
    }
}

class CaptureRule extends Rule {
    /** A rule id, or 0. */
    public final retokenizeCapturedWithRuleId:RuleId;

    public function new(location:Null<ILocation>, id:RuleId, name:Null<String>, contentName:Null<String>, retokenizeCapturedWithRuleId:RuleId) {
        super(location, id, name, contentName);
        this.retokenizeCapturedWithRuleId = retokenizeCapturedWithRuleId;
    }

    public function dispose():Void {
        // nothing to dispose
    }

    public function collectPatterns(grammar:IRuleRegistry, out:RegExpSourceList):Void {
        throw 'Not supported!';
    }

    public function compile(grammar:IRuleCompileHelper, endRegexSource:Null<String>):CompiledRule {
        throw 'Not supported!';
    }

    public function compileAG(grammar:IRuleCompileHelper, endRegexSource:Null<String>, allowA:Bool, allowG:Bool):CompiledRule {
        throw 'Not supported!';
    }
}

class MatchRule extends Rule {
    final _match:RegExpSource;

    public final captures:Array<Null<CaptureRule>>;

    var _cachedCompiledPatterns:Null<RegExpSourceList>;

    public function new(location:Null<ILocation>, id:RuleId, name:Null<String>, match:String, captures:Array<Null<CaptureRule>>) {
        super(location, id, name, null);
        this._match = new RegExpSource(match, this.id);
        this.captures = captures;
        this._cachedCompiledPatterns = null;
    }

    public function dispose():Void {
        if (_cachedCompiledPatterns != null) {
            _cachedCompiledPatterns.dispose();
            _cachedCompiledPatterns = null;
        }
    }

    public var debugMatchRegExp(get, never):String;

    function get_debugMatchRegExp():String {
        return '${_match.source}';
    }

    public function collectPatterns(grammar:IRuleRegistry, out:RegExpSourceList):Void {
        out.push(_match);
    }

    public function compile(grammar:IRuleCompileHelper, endRegexSource:Null<String>):CompiledRule {
        return _getCachedCompiledPatterns(grammar).compile(grammar);
    }

    public function compileAG(grammar:IRuleCompileHelper, endRegexSource:Null<String>, allowA:Bool, allowG:Bool):CompiledRule {
        return _getCachedCompiledPatterns(grammar).compileAG(grammar, allowA, allowG);
    }

    function _getCachedCompiledPatterns(grammar:IRuleCompileHelper):RegExpSourceList {
        if (_cachedCompiledPatterns == null) {
            _cachedCompiledPatterns = new RegExpSourceList();
            collectPatterns(grammar, _cachedCompiledPatterns);
        }
        return _cachedCompiledPatterns;
    }
}

class IncludeOnlyRule extends Rule {
    public final hasMissingPatterns:Bool;
    public final patterns:Array<RuleId>;

    var _cachedCompiledPatterns:Null<RegExpSourceList>;

    public function new(location:Null<ILocation>, id:RuleId, name:Null<String>, contentName:Null<String>, patterns:ICompilePatternsResult) {
        super(location, id, name, contentName);
        this.patterns = patterns.patterns;
        this.hasMissingPatterns = patterns.hasMissingPatterns;
        this._cachedCompiledPatterns = null;
    }

    public function dispose():Void {
        if (_cachedCompiledPatterns != null) {
            _cachedCompiledPatterns.dispose();
            _cachedCompiledPatterns = null;
        }
    }

    public function collectPatterns(grammar:IRuleRegistry, out:RegExpSourceList):Void {
        for (pattern in patterns) {
            var rule = grammar.getRule(pattern);
            rule.collectPatterns(grammar, out);
        }
    }

    public function compile(grammar:IRuleCompileHelper, endRegexSource:Null<String>):CompiledRule {
        return _getCachedCompiledPatterns(grammar).compile(grammar);
    }

    public function compileAG(grammar:IRuleCompileHelper, endRegexSource:Null<String>, allowA:Bool, allowG:Bool):CompiledRule {
        return _getCachedCompiledPatterns(grammar).compileAG(grammar, allowA, allowG);
    }

    function _getCachedCompiledPatterns(grammar:IRuleCompileHelper):RegExpSourceList {
        if (_cachedCompiledPatterns == null) {
            _cachedCompiledPatterns = new RegExpSourceList();
            collectPatterns(grammar, _cachedCompiledPatterns);
        }
        return _cachedCompiledPatterns;
    }
}

class BeginEndRule extends Rule {
    final _begin:RegExpSource;

    public final beginCaptures:Array<Null<CaptureRule>>;

    final _end:RegExpSource;

    public final endHasBackReferences:Bool;
    public final endCaptures:Array<Null<CaptureRule>>;
    public final applyEndPatternLast:Bool;
    public final hasMissingPatterns:Bool;
    public final patterns:Array<RuleId>;

    var _cachedCompiledPatterns:Null<RegExpSourceList>;

    public function new(location:Null<ILocation>, id:RuleId, name:Null<String>, contentName:Null<String>, begin:String, beginCaptures:Array<Null<CaptureRule>>,
            end:Null<String>, endCaptures:Array<Null<CaptureRule>>, applyEndPatternLast:Bool, patterns:ICompilePatternsResult) {
        super(location, id, name, contentName);
        this._begin = new RegExpSource(begin, this.id);
        this.beginCaptures = beginCaptures;
        this._end = new RegExpSource((end != null && end.length > 0) ? end : '\u{FFFF}', -1);
        this.endHasBackReferences = this._end.hasBackReferences;
        this.endCaptures = endCaptures;
        this.applyEndPatternLast = applyEndPatternLast;
        this.patterns = patterns.patterns;
        this.hasMissingPatterns = patterns.hasMissingPatterns;
        this._cachedCompiledPatterns = null;
    }

    public function dispose():Void {
        if (_cachedCompiledPatterns != null) {
            _cachedCompiledPatterns.dispose();
            _cachedCompiledPatterns = null;
        }
    }

    public var debugBeginRegExp(get, never):String;

    function get_debugBeginRegExp():String {
        return '${_begin.source}';
    }

    public var debugEndRegExp(get, never):String;

    function get_debugEndRegExp():String {
        return '${_end.source}';
    }

    public function getEndWithResolvedBackReferences(lineText:String, captureIndices:Array<IOnigCaptureIndex>):String {
        return _end.resolveBackReferences(lineText, captureIndices);
    }

