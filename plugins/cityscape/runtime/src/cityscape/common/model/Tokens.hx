// Ported from vscode src/vs/editor/common/model/tokens.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.common.model;

import cityscape.base.common.Arrays;
import cityscape.base.common.Async.RunOnceScheduler;
import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle;
import cityscape.common.EncodedTokenAttributes.StandardTokenType;
import cityscape.common.Languages.ILanguageIdCodec;
import cityscape.common.Model.IAttachedView;
import cityscape.common.Model.ITextModel;
import cityscape.common.TextModelEvents.IModelContentChangedEvent;
import cityscape.common.TextModelEvents.IModelTokensChangedEvent;
import cityscape.common.TokenizationTextModelPart.BackgroundTokenizationState;
import cityscape.common.core.LineRange;
import cityscape.common.core.Position.IPosition;
import cityscape.common.tokens.LineTokens;

/**
 * The visible line ranges of an attached view; `state` is null when the view
 * is detached.
 */
typedef IAttachedViewChange = {
    final view:IAttachedView;
    final state:Null<IAttachedViewState>;
}

/**
 * The views (editors) attached to a model and their visible lines.
 * @internal
 */
class AttachedViews {

    final _onDidChangeVisibleRanges = new Emitter<IAttachedViewChange>();

    public final onDidChangeVisibleRanges:Event<IAttachedViewChange>;

    final _views:Array<AttachedViewImpl> = [];

    public function new() {
        onDidChangeVisibleRanges = _onDidChangeVisibleRanges.event;
    }

    public function attachView():IAttachedView {
        var view:AttachedViewImpl = null;
        view = new AttachedViewImpl(state -> {
            _onDidChangeVisibleRanges.fire({view: view, state: state});
        });
        _views.push(view);
        return view;
    }

    public function detachView(view:IAttachedView):Void {
        _views.remove(cast view);
        _onDidChangeVisibleRanges.fire({view: view, state: null});
    }

}

/**
 * @internal
 */
typedef IAttachedViewState = {
    final visibleLineRanges:Array<LineRange>;
    final stabilized:Bool;
}

private class AttachedViewImpl implements IAttachedView {

    final handleStateChange:(state:IAttachedViewState) -> Void;

    public function new(handleStateChange:(state:IAttachedViewState) -> Void) {
        this.handleStateChange = handleStateChange;
    }

    public function setVisibleLines(visibleLines:Array<{startLineNumber:Int, endLineNumber:Int}>, stabilized:Bool):Void {
        final visibleLineRanges = [for (line in visibleLines) new LineRange(line.startLineNumber, line.endLineNumber + 1)];
        handleStateChange({visibleLineRanges: visibleLineRanges, stabilized: stabilized});
    }

}

class AttachedViewHandler extends Disposable {

    final runner:RunOnceScheduler;

    var _computedLineRanges:Array<LineRange> = [];

    var _lineRanges:Array<LineRange> = [];

    public var lineRanges(get, never):Array<LineRange>;
    inline function get_lineRanges():Array<LineRange> {
        return _lineRanges;
    }

    final _refreshTokens:() -> Void;

    public function new(refreshTokens:() -> Void) {
        super();
        _refreshTokens = refreshTokens;
        runner = _register(new RunOnceScheduler(() -> update(), 50));
    }

    function update():Void {
        if (Arrays.equals(_computedLineRanges, _lineRanges, (a, b) -> a.equals(b))) {
            return;
        }
        _computedLineRanges = _lineRanges;
        _refreshTokens();
    }

    public function handleStateChange(state:IAttachedViewState):Void {
        _lineRanges = state.visibleLineRanges;
        if (state.stabilized) {
            runner.cancel();
            update();
        }
        else {
            runner.schedule();
        }
    }

}

/**
 * The tokens of a model (Monaco has the TextMate based `GrammarTokens` and
 * the tree sitter based `TreeSitterTokens`; Cityscape has the first only).
 */
class AbstractTokens extends Disposable {

    var _backgroundTokenizationState:BackgroundTokenizationState = BackgroundTokenizationState.InProgress;

    public var backgroundTokenizationState(get, never):BackgroundTokenizationState;
    inline function get_backgroundTokenizationState():BackgroundTokenizationState {
        return _backgroundTokenizationState;
    }

    final _onDidChangeBackgroundTokenizationState = new VoidEmitter();

    /** @internal, should not be exposed by the text model! */
    public final onDidChangeBackgroundTokenizationState:VoidEvent;

    final _onDidChangeTokens = new Emitter<IModelTokensChangedEvent>();

    /** @internal, should not be exposed by the text model! */
    public final onDidChangeTokens:Event<IModelTokensChangedEvent>;

    final _languageIdCodec:ILanguageIdCodec;

    final _textModel:ITextModel;

    final getLanguageId:() -> String;

    public function new(languageIdCodec:ILanguageIdCodec, textModel:ITextModel, getLanguageId:() -> String) {
        super();
        _register(_onDidChangeBackgroundTokenizationState);
        _register(_onDidChangeTokens);
        onDidChangeBackgroundTokenizationState = _onDidChangeBackgroundTokenizationState.event;
        onDidChangeTokens = _onDidChangeTokens.event;
        _languageIdCodec = languageIdCodec;
        _textModel = textModel;
        this.getLanguageId = getLanguageId;
    }

    public function resetTokenization(fireTokenChangeEvent:Bool = true):Void {
        throw 'abstract';
    }

    public function handleDidChangeAttached():Void {
        throw 'abstract';
    }

    public function handleDidChangeContent(e:IModelContentChangedEvent):Void {
        throw 'abstract';
    }

    public function forceTokenization(lineNumber:Int):Void {
        throw 'abstract';
    }

    public function hasAccurateTokensForLine(lineNumber:Int):Bool {
        throw 'abstract';
    }

    public function isCheapToTokenize(lineNumber:Int):Bool {
        throw 'abstract';
    }

    public function tokenizeIfCheap(lineNumber:Int):Void {
        if (isCheapToTokenize(lineNumber)) {
            forceTokenization(lineNumber);
        }
    }

    public function getLineTokens(lineNumber:Int):LineTokens {
        throw 'abstract';
    }

    public function getTokenTypeIfInsertingCharacter(lineNumber:Int, column:Int, character:String):StandardTokenType {
        throw 'abstract';
    }

    public function tokenizeLineWithEdit(position:IPosition, length:Int, newText:String):Null<LineTokens> {
        throw 'abstract';
    }

    public var hasTokens(get, never):Bool;
    function get_hasTokens():Bool {
        throw 'abstract';
    }

}
