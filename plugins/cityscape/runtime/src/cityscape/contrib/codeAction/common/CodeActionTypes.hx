// Ported from vscode src/vs/editor/contrib/codeAction/common/types.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.codeAction.common;

import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.Errors;
import cityscape.base.common.HierarchicalKind;
import cityscape.base.common.JsValues;
import cityscape.base.common.Lifecycle.IDisposable;
import cityscape.base.common.Promise;
import cityscape.common.Languages;
import cityscape.common.core.Position;

/**
 * The code action kinds (Monaco's `CodeActionKind` object).
 */
class CodeActionKind {
    public static final QuickFix = new HierarchicalKind('quickfix');
    public static final Refactor = new HierarchicalKind('refactor');
    public static final RefactorExtract = Refactor.append('extract');
    public static final RefactorInline = Refactor.append('inline');
    public static final RefactorMove = Refactor.append('move');
    public static final RefactorRewrite = Refactor.append('rewrite');
    public static final Notebook = new HierarchicalKind('notebook');
    public static final Source = new HierarchicalKind('source');
    public static final SourceOrganizeImports = Source.append('organizeImports');
    public static final SourceFixAll = Source.append('fixAll');
    public static final SurroundWith = Refactor.append('surround');
}

/**
 * `'ifSingle'`, `'first'` or `'never'`.
 */
enum abstract CodeActionAutoApply(String) from String to String {
    var IfSingle = 'ifSingle';
    var First = 'first';
    var Never = 'never';
}

enum abstract CodeActionTriggerSource(String) from String to String {
    var Refactor = 'refactor';
    var RefactorPreview = 'refactor preview';
    var Lightbulb = 'lightbulb';
    var Default = 'other (default)';
    var SourceAction = 'source action';
    var QuickFix = 'quick fix action';
    var FixAll = 'fix all';
    var OrganizeImports = 'organize imports';
    var AutoFix = 'auto fix';
    var QuickFixHover = 'quick fix hover window';
    var OnSave = 'save participants';
    var ProblemsView = 'problems view';
}

typedef CodeActionFilter = {
    @:optional final include:Null<HierarchicalKind>;
    @:optional final excludes:Null<Array<HierarchicalKind>>;
    @:optional final includeSourceActions:Null<Bool>;
    @:optional final onlyIncludePreferredActions:Null<Bool>;
}

typedef CodeActionTriggerContext = {
    final notAvailableMessage:String;
    final position:Position;
}

typedef CodeActionTrigger = {
    final type:CodeActionTriggerType;
    final triggerAction:CodeActionTriggerSource;
    @:optional final filter:Null<CodeActionFilter>;
    @:optional final autoApply:Null<CodeActionAutoApply>;
    @:optional final context:Null<CodeActionTriggerContext>;
}

/**
 * Module functions of types.ts.
 */
class CodeActionFilters {

    public static function mayIncludeActionsOfKind(filter:CodeActionFilter, providedKind:HierarchicalKind):Bool {
        // A provided kind may be a subset or superset of our filtered kind.
        if (filter.include != null && !filter.include.intersects(providedKind)) {
            return false;
        }

        if (filter.excludes != null) {
            for (exclude in filter.excludes) {
                if (excludesAction(providedKind, exclude, filter.include)) {
                    return false;
                }
            }
        }

        // Don't return source actions unless they are explicitly requested
        if (filter.includeSourceActions != true && CodeActionKind.Source.contains(providedKind)) {
            return false;
        }

        return true;
    }

    public static function filtersAction(filter:CodeActionFilter, action:CodeAction):Bool {
        final actionKind = action.kind != null && action.kind.length > 0 ? new HierarchicalKind(action.kind) : null;

        // Filter out actions by kind
        if (filter.include != null) {
            if (actionKind == null || !filter.include.contains(actionKind)) {
                return false;
            }
        }

        if (filter.excludes != null) {
            if (actionKind != null) {
                for (exclude in filter.excludes) {
                    if (excludesAction(actionKind, exclude, filter.include)) {
                        return false;
                    }
                }
            }
        }

        // Don't return source actions unless they are explicitly requested
        if (filter.includeSourceActions != true) {
            if (actionKind != null && CodeActionKind.Source.contains(actionKind)) {
                return false;
            }
        }

        if (filter.onlyIncludePreferredActions == true) {
            if (action.isPreferred != true) {
                return false;
            }
        }

        return true;
    }

    static function excludesAction(providedKind:HierarchicalKind, exclude:HierarchicalKind, include:Null<HierarchicalKind>):Bool {
        if (!exclude.contains(providedKind)) {
            return false;
        }
        if (include != null && exclude.contains(include)) {
            // The include is more specific, don't filter out
            return false;
        }
        return true;
    }

}

class CodeActionCommandArgs {

    public static function fromUser(arg:Any, defaults:{kind:HierarchicalKind, apply:CodeActionAutoApply}):CodeActionCommandArgs {
        if (arg == null || !JsValues.isObject(arg)) {
            return new CodeActionCommandArgs(defaults.kind, defaults.apply, false);
        }
        return new CodeActionCommandArgs(
            CodeActionCommandArgs.getKindFromUser(arg, defaults.kind),
            CodeActionCommandArgs.getApplyFromUser(arg, defaults.apply),
            CodeActionCommandArgs.getPreferredUser(arg));
    }

    static function getApplyFromUser(arg:Any, defaultAutoApply:CodeActionAutoApply):CodeActionAutoApply {
        final apply:Any = JsValues.field(arg, 'apply');
        return switch (JsValues.isString(apply) ? (apply : String).toLowerCase() : '') {
            case 'first': CodeActionAutoApply.First;
            case 'never': CodeActionAutoApply.Never;
            case 'ifsingle': CodeActionAutoApply.IfSingle;
            default: defaultAutoApply;
        };
    }

    static function getKindFromUser(arg:Any, defaultKind:HierarchicalKind):HierarchicalKind {
        final kind:Any = JsValues.field(arg, 'kind');
        return JsValues.isString(kind)
            ? new HierarchicalKind(kind)
            : defaultKind;
    }

    static function getPreferredUser(arg:Any):Bool {
        final preferred:Any = JsValues.field(arg, 'preferred');
        return JsValues.isBoolean(preferred)
            ? (preferred : Bool)
            : false;
    }

    public final kind:HierarchicalKind;
    public final apply:CodeActionAutoApply;
    public final preferred:Bool;

    function new(kind:HierarchicalKind, apply:CodeActionAutoApply, preferred:Bool) {
        this.kind = kind;
        this.apply = apply;
        this.preferred = preferred;
    }
}

/**
 * A code action and the provider that gave it.
 */
class CodeActionItem {

    public final action:CodeAction;
    public final provider:Null<CodeActionProvider>;
    public var highlightRange:Bool;

    public function new(action:CodeAction, provider:Null<CodeActionProvider>, highlightRange:Bool = false) {
        this.action = action;
        this.provider = provider;
        this.highlightRange = highlightRange;
    }

    /**
     * Fills in the edit of the action with its provider when it has none.
     */
    public function resolve(token:CancellationToken):Promise<CodeActionItem> {
        final resolveCodeAction = provider != null ? provider.resolveCodeAction : null;
        if (resolveCodeAction != null && this.action.edit == null) {
            return Promise.fromCallback(done -> {
                try {
                    resolveCodeAction(this.action, token, done);
                }
                catch (err:Dynamic) {
                    Errors.onUnexpectedExternalError(err);
                    done(null);
                }
            }).then(action -> {
                if (action != null) {
                    this.action.edit = action.edit;
                }
                return this;
            });
        }
        return Promise.resolve(this);
    }
}

/**
 * The code actions of a request (Monaco's `CodeActionSet`).
 */
interface CodeActionSet extends IDisposable {
    var validActions(default, null):Array<CodeActionItem>;
    var allActions(default, null):Array<CodeActionItem>;
    var documentation(default, null):Array<Command>;
    var hasAutoFix(get, never):Bool;
    var hasAIFix(get, never):Bool;
    var allAIFixes(get, never):Bool;
}
