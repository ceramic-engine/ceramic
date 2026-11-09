// Ported from vscode src/vs/editor/contrib/inlayHints/browser/inlayHintsController.ts
// and inlayHintsContribution.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.inlayHints.view;

import cityscape.Cityscape;
import cityscape.base.common.Async.RunOnceScheduler;
import cityscape.base.common.Cancellation;
import cityscape.base.common.Errors;
import cityscape.base.common.Lifecycle;
import cityscape.common.DecorationStyle.IDecorationStyle;
import cityscape.common.EditorCommon.IEditorContribution;
import cityscape.common.Languages;
import cityscape.common.Model;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.EditOperation;
import cityscape.common.core.Range;
import cityscape.common.languages.LanguageKinds.InlayHintKind;
import cityscape.common.model.TextModel.ModelDecorationInjectedTextOptions;
import cityscape.contrib.gotoSymbol.view.GoToCommands.ClickLinkGesture;
import cityscape.contrib.gotoSymbol.view.GoToCommands.ClickLinkMouseEvent;
import cityscape.contrib.hover.view.ContentHoverController;
import cityscape.contrib.inlayHints.view.InlayHints;
import cityscape.platform.keybinding.common.Keybinding.IKeyboardEvent;
import cityscape.view.EditorBrowser;
import cityscape.view.EditorExtensions;
import cityscape.view.EditorWidgets;
import cityscape.view.StableEditorScroll.StableEditorScrollState;
import cityscape.common.Languages.Command;

// --- hint caching service (per session)

/**
 * The inlay hints of the models, kept when an editor switches models so
 * that they show at once when the model comes back (Monaco's
 * `IInlayHintsCache`, a service of the page; here a field of the context,
 * `Cityscape.inlayHintsCache`).
 */
class InlayHintsCache {

    final _entries = new LRUCache<Array<InlayHintItem>>(50);

    public function new() {}

    public function get(model:ITextModel):Null<Array<InlayHintItem>> {
        final key = InlayHintsCache._key(model);
        return this._entries.get(key);
    }

    public function set(model:ITextModel, value:Array<InlayHintItem>):Void {
        final key = InlayHintsCache._key(model);
        this._entries.set(key, value);
    }

    static function _key(model:ITextModel):String {
        return '${model.uri.toString()}/${model.getVersionId()}';
    }

}

/**
 * Monaco's `LRUCache` (base/common/map.ts) with string keys: a read moves
 * an entry to the most recent end, and the oldest entries go when there
 * are more than `limit` (down to `limit * ratio`).
 */
class LRUCache<V> {

    final _map = new Map<String, V>();
    final _keys:Array<String> = [];
    final _limit:Int;
    final _ratio:Float;

    public function new(limit:Int, ratio:Float = 1) {
        this._limit = limit;
        this._ratio = Math.min(Math.max(0, ratio), 1);
    }

    public var size(get, never):Int;
    inline function get_size():Int {
        return _keys.length;
    }

    public function get(key:String):Null<V> {
        if (!_map.exists(key)) {
            return null;
        }
        _touch(key);
        return _map.get(key);
    }

    public function set(key:String, value:V):Void {
        _map.set(key, value);
        _touch(key);
        if (_keys.length > _limit) {
            final keep = Math.round(_limit * _ratio);
            while (_keys.length > keep) {
                _map.remove(_keys.shift());
            }
        }
    }

    public function delete(key:String):Bool {
        if (!_map.exists(key)) {
            return false;
        }
        _map.remove(key);
        _keys.remove(key);
        return true;
    }

    /**
     * The keys, the least recently used first (Monaco's iteration order).
     */
    public function keys():Array<String> {
        return _keys.copy();
    }

    function _touch(key:String):Void {
        _keys.remove(key);
        _keys.push(key);
    }

}

/**
 * The moving average of how long a language feature request takes, which
 * sets the delay before the next request (Monaco's
 * `FeatureDebounceInformation` of `ILanguageFeatureDebounceService`): a
 * sliding window of 6 values per model, between `min` and `max` (`min`
 * squared by default), `min * 1.5` before any value. Monaco keeps it in a
 * global service; here each controller has its own, like the folding.
 */
class FeatureDebounceInformation {

    final _min:Float;
    final _max:Float;
    final _default:Float;
    final _cache = new LRUCache<SlidingWindowAverage>(50, 0.7);

    public function new(min:Float, ?max:Float) {
        this._min = min;
        this._max = max != null ? max : min * min;
        this._default = min * 1.5;
    }

    static function clamp(value:Float, min:Float, max:Float):Float {
        return Math.min(max, Math.max(min, value));
    }

    public function get(model:ITextModel):Float {
        final avg = this._cache.get(model.id);
        return avg != null ? clamp(avg.value, this._min, this._max) : this.defaultValue();
    }

    public function update(model:ITextModel, value:Float):Float {
        var avg = this._cache.get(model.id);
        if (avg == null) {
            avg = new SlidingWindowAverage(6);
            this._cache.set(model.id, avg);
        }
        return clamp(avg.update(value), this._min, this._max);
    }

    /**
     * Monaco's `default()`: the average of the models' averages, else
     * `min * 1.5`.
     */
    public function defaultValue():Float {
        var overall = 0.0;
        var count = 0;
        for (key in this._cache.keys()) {
            // (MovingAverage of the values, without touching the entries)
            @:privateAccess final avg = this._cache._map.get(key);
            count++;
            overall += (avg.value - overall) / count;
        }
        final truncated:Float = Std.int(overall);
        final value = truncated != 0 ? truncated : this._default;
        return clamp(value, this._min, this._max);
    }

}

/**
 * Monaco's `SlidingWindowAverage` (base/common/numbers.ts).
 */
class SlidingWindowAverage {

    var _n = 0;
    var _val = 0.0;
    final _values:Array<Float> = [];
    var _index = 0;
    var _sum = 0.0;

    public function new(size:Int) {
        for (_ in 0...size) {
            _values.push(0);
        }
    }

    public var value(get, never):Float;
    inline function get_value():Float {
        return _val;
    }

    public function update(value:Float):Float {
        final oldValue = this._values[this._index];
        this._values[this._index] = value;
        this._index = (this._index + 1) % this._values.length;

        this._sum -= oldValue;
        this._sum += value;

        if (this._n < this._values.length) {
            this._n += 1;
        }

        this._val = this._sum / this._n;
        return this._val;
    }

}

// --- rendered label

/**
 * The label part of an inlay hint that an injected text shows (its
 * `attachedData`).
 */
class RenderedInlayHintLabelPart {

    public final item:InlayHintItem;
    public final index:Int;

    public function new(item:InlayHintItem, index:Int) {
        this.item = item;
        this.index = index;
    }

    /**
     * The part of a string label (kept while the label stays the same: the
     * mouse reads it at every move).
     */
    var _stringPart:Null<InlayHintLabelPart> = null;

    public var part(get, never):InlayHintLabelPart;
    function get_part():InlayHintLabelPart {
        final label:Any = this.item.hint.label;
        if (Std.isOfType(label, std.String)) {
            final text:std.String = label;
            final cached = this._stringPart;
            if (cached != null && cached.label == text) {
                return cached;
            }
            final part:InlayHintLabelPart = {label: text};
            this._stringPart = part;
            return part;
        }
        final parts:Array<InlayHintLabelPart> = label;
        return parts[this.index];
    }

}

class ActiveInlayHintInfo {

    public final part:RenderedInlayHintLabelPart;
    public final hasTriggerModifier:Bool;

    public function new(part:RenderedInlayHintLabelPart, hasTriggerModifier:Bool) {
        this.part = part;
        this.hasTriggerModifier = hasTriggerModifier;
    }

}

typedef InlayHintDecorationRenderInfo = {
    var item:InlayHintItem;
    var decoration:IModelDeltaDecoration;
}

enum abstract RenderMode(Int) {
    var Normal = 0;
    var Invisible = 1;
}

// --- controller

/**
 * Shows the inlay hints of the providers as injected text (Monaco's
 * `InlayHintsController`).
 *
 * The styles of Monaco's dynamic CSS rules (`DynamicCssRules`) are typed
 * decoration styles (`inlineStyle` of the injected text), one per set of
 * properties. The font size and family of the `inlayHints` option are not
 * applied: a view line has one font (see DEVIATIONS.md). The Ctrl+Alt
 * toggle of `onUnlessPressed`/`offUnlessPressed` follows the modifier keys
 * the editor receives (Monaco listens to the whole window). The context
 * menu of a part with a location (`showGoToContextMenu`) is not ported.
 */
class InlayHintsController implements IEditorContribution {

    public static inline final ID:String = 'editor.contrib.InlayHints';

    static inline final _MAX_DECORATORS = 1500;
    static inline final _MAX_LABEL_LEN = 43;

    public static function get(editor:ICodeEditor):Null<InlayHintsController> {
        return editor.getContribution(InlayHintsController.ID);
    }

    final _disposables = new DisposableStore();
    final _sessionDisposables = new DisposableStore();
    final _debounceInfo:FeatureDebounceInformation;
    /**
     * The decorations of the hints by id, and their ids in the order they
     * were added (Monaco's `Map` iterates in insertion order).
     */
    final _decorationsMetadata = new Map<String, InlayHintDecorationRenderInfo>();
    final _decorationIds:Array<String> = [];
    /**
     * The typed styles of the parts by their properties (Monaco's
     * `DynamicCssRules`).
     */
    final _styles = new Map<String, IDecorationStyle>();

    var _activeRenderMode = RenderMode.Normal;
    var _activeInlayHintPart:Null<ActiveInlayHintInfo> = null;

    /**
     * The scheduler of the current session (tests flush it).
     */
    var _scheduler:Null<RunOnceScheduler> = null;
    /**
     * The mouse cursor this controller set over a part (pointer, default),
     * restored when the mouse leaves the part.
     */
    var _cursorSet = false;

    final _editor:ICodeEditor;
    final _inlayHintsCache:InlayHintsCache;

    public function new(editor:ICodeEditor) {
        this._editor = editor;
        final context = editor.context;
        this._inlayHintsCache = context.inlayHintsCache;
        final provider = context.languageFeaturesService.inlayHintsProvider;
        this._debounceInfo = new FeatureDebounceInformation(25);
        this._disposables.add(provider.onDidChange(_ -> this._update()));
        this._disposables.add(editor.onDidChangeModel(_ -> this._update()));
        this._disposables.add(editor.onDidChangeModelLanguage(_ -> this._update()));
        this._disposables.add(editor.onDidChangeConfiguration(e -> {
            if (e.hasChanged(EditorOption.inlayHints)) {
                this._update();
            }
        }));
        this._update();
    }

    public function saveViewState():Any {
        return null;
    }

    public function restoreViewState(state:Any):Void {}

    public function dispose():Void {
        this._sessionDisposables.dispose();
        this._removeAllDecorations();
        this._disposables.dispose();
    }

    function _update():Void {
        this._sessionDisposables.clear();
        this._removeAllDecorations();
        this._scheduler = null;

        final options = this._editor.getOption(EditorOption.inlayHints);
        if (options.enabled == 'off') {
            return;
        }

        final model = this._editor.getModel();
        if (model == null || !this._editor.context.languageFeaturesService.inlayHintsProvider.has(model)) {
            return;
        }

        var scheduler:Null<RunOnceScheduler> = null;

        if (options.enabled == 'on') {
            // different "on" modes: always
            this._activeRenderMode = RenderMode.Normal;
        } else {
            // different "on" modes: offUnlessPressed, or onUnlessPressed
            var defaultMode:RenderMode;
            var altMode:RenderMode;
            if (options.enabled == 'onUnlessPressed') {
                defaultMode = RenderMode.Normal;
                altMode = RenderMode.Invisible;
            } else {
                defaultMode = RenderMode.Invisible;
                altMode = RenderMode.Normal;
            }
            this._activeRenderMode = defaultMode;

            // ModifierKeyEmitter: the modifier keys the editor receives
            final onModifiers = (e:IKeyboardEvent) -> {
                if (!this._editor.hasModel()) {
                    return;
                }
                final newRenderMode = e.altKey && e.ctrlKey && !(e.shiftKey || e.metaKey) ? altMode : defaultMode;
                if (newRenderMode != this._activeRenderMode) {
                    this._activeRenderMode = newRenderMode;
                    final model = this._editor.getModel();
                    final copies = this._copyInlayHintsWithCurrentAnchor(model);
                    this._updateHintsDecorators([model.getFullModelRange()], copies);
                    scheduler.schedule(0);
                }
            };
            this._sessionDisposables.add(this._editor.onKeyDown(onModifiers));
            this._sessionDisposables.add(this._editor.onKeyUp(onModifiers));
        }

        // iff possible, quickly update from cache
        final cached = this._inlayHintsCache.get(model);
        if (cached != null) {
            this._updateHintsDecorators([model.getFullModelRange()], cached);
        }
        this._sessionDisposables.add(Lifecycle.toDisposable(() -> {
            // cache items when switching files etc
            if (!model.isDisposed()) {
                this._cacheHintsForFastRestore(model);
            }
        }));

        var cts:Null<CancellationTokenSource> = null;
        final watchedProviders:Array<InlayHintsProvider> = [];

        scheduler = new RunOnceScheduler(() -> {
            final t1 = haxe.Timer.stamp();

            if (cts != null) {
                cts.dispose(true);
            }
            final mySource = new CancellationTokenSource();
            cts = mySource;
            final listener = model.onWillDispose(() -> mySource.cancel());

            final myToken = mySource.token;
            InlayHintsFragments.create(this._editor.context.languageFeaturesService.inlayHintsProvider, model, this._getHintsRanges(), myToken).done(inlayHints -> {
                scheduler.delay = this._debounceInfo.update(model, (haxe.Timer.stamp() - t1) * 1000);
                if (myToken.isCancellationRequested) {
                    inlayHints.dispose();
                    mySource.dispose();
                    listener.dispose();
                    return;
                }

                // listen to provider changes
                for (provider in inlayHints.provider) {
                    final onDidChangeInlayHints = provider.onDidChangeInlayHints;
                    if (onDidChangeInlayHints != null && watchedProviders.indexOf(provider) == -1) {
                        watchedProviders.push(provider);
                        this._sessionDisposables.add(onDidChangeInlayHints(() -> {
                            if (!scheduler.isScheduled()) { // ignore event when request is already scheduled
                                scheduler.schedule();
                            }
                        }));
                    }
                }

                this._sessionDisposables.add(Lifecycle.toDisposable(() -> inlayHints.dispose()));
                try {
                    this._updateHintsDecorators(inlayHints.ranges, inlayHints.items);
                    this._cacheHintsForFastRestore(model);
                }
                catch (err:Dynamic) {
                    Errors.onUnexpectedError(err);
                }
                mySource.dispose();
                listener.dispose();
            }, err -> {
                Errors.onUnexpectedError(err);
                mySource.dispose();
                listener.dispose();
            });

        }, this._debounceInfo.get(model));
        this._scheduler = scheduler;

        this._sessionDisposables.add(scheduler);
        this._sessionDisposables.add(Lifecycle.toDisposable(() -> {
            if (cts != null) {
                cts.dispose(true);
            }
        }));
        scheduler.schedule(0);

        this._sessionDisposables.add(this._editor.onDidScrollChange(e -> {
            // update when scroll position changes
            // uses scrollTopChanged has weak heuristic to differenatiate between scrolling due to
            // typing or due to "actual" scrolling
            if (e.scrollTopChanged || !scheduler.isScheduled()) {
                scheduler.schedule();
            }
        }));
        this._sessionDisposables.add(this._editor.onDidChangeModelContent(e -> {
            if (cts != null) {
                cts.cancel();
            }

            // update less aggressive when typing
            final delay = Math.max(scheduler.delay, 1250);
            scheduler.schedule(delay);
        }));

        // mouse gestures
        this._sessionDisposables.add(this._installDblClickGesture(() -> scheduler.schedule(0)));
        this._sessionDisposables.add(this._installLinkGesture());
    }

    /**
     * Runs a pending request of the hints now (tests; Monaco waits for the
     * scheduler).
     */
    public function _flush():Void {
        final scheduler = this._scheduler;
        if (scheduler != null && scheduler.isScheduled()) {
            scheduler.flush();
        }
    }

    /**
     * Whether a request of the hints is scheduled (tests).
     */
    public function _isScheduled():Bool {
        final scheduler = this._scheduler;
        return scheduler != null && scheduler.isScheduled();
    }

    function _installLinkGesture():IDisposable {

        final store = new DisposableStore();
        final gesture = store.add(new ClickLinkGesture(this._editor));

        final sessionStore = new DisposableStore();
        store.add(sessionStore);

        store.add(gesture.onMouseMoveOrRelevantKeyDown(e -> {
            final mouseEvent = e.mouseEvent;
            final labelPart = this._getInlayHintLabelPart(mouseEvent.target);
            final model = this._editor.getModel();

            if (labelPart == null || model == null) {
                sessionStore.clear();
                return;
            }

            // Cityscape: nothing changes while the mouse stays over the same
            // part with the same modifier (Monaco renders the line again at
            // every mouse move)
            final hovered = this._hoveredPart;
            if (hovered != null && hovered.item == labelPart.item && hovered.index == labelPart.index && this._hoveredWithModifier == mouseEvent.hasTriggerModifier) {
                return;
            }
            sessionStore.clear();
            this._hoveredPart = labelPart;
            this._hoveredWithModifier = mouseEvent.hasTriggerModifier;
            final hasLink = labelPart.part.command != null || labelPart.part.location != null;

            // resolve the item
            final cts = new CancellationTokenSource();
            sessionStore.add(Lifecycle.toDisposable(() -> cts.dispose(true)));
            labelPart.item.resolve(cts.token);

            // render link => when the modifier is pressed and when there is a command or location
            this._activeInlayHintPart = hasLink
                ? new ActiveInlayHintInfo(labelPart, mouseEvent.hasTriggerModifier)
                : null;

            // the mouse cursor of the part (Monaco's CSS `cursor`)
            this._setMouseCursor(
                this._activeInlayHintPart != null && mouseEvent.hasTriggerModifier ? glaze.CursorStyle.PointingHand
                : (labelPart.item.hint.textEdits != null && labelPart.item.hint.textEdits.length > 0 ? glaze.CursorStyle.Arrow : null)
            );

            final lineNumber = model.validatePosition(labelPart.item.hint.position).lineNumber;
            final range = new Range(lineNumber, 1, lineNumber, model.getLineMaxColumn(lineNumber));
            final lineHints = this._getInlineHintsForRange(range);
            this._updateHintsDecorators([range], lineHints);
            sessionStore.add(Lifecycle.toDisposable(() -> {
                this._hoveredPart = null;
                this._setMouseCursor(null);
                final hadActive = this._activeInlayHintPart != null;
                this._activeInlayHintPart = null;
                if (hadActive) {
                    this._updateHintsDecorators([range], lineHints);
                }
            }));
        }));
        store.add(gesture.onCancel(() -> sessionStore.clear()));
        store.add(gesture.onExecute(e -> {
            final label = this._getInlayHintLabelPart(e.target);
            if (label != null) {
                final part = label.part;
                if (part.location != null) {
                    // location -> execute go to def
                    InlayHintsLocations.goToDefinitionWithLocation(e, this._editor, part.location);
                } else if (Commands.is(part.command)) {
                    // command -> execute it
                    this._invokeCommand(part.command, label.item);
                }
            }
        }));
        return store;
    }

    var _hoveredPart:Null<RenderedInlayHintLabelPart> = null;
    var _hoveredWithModifier = false;

    function _setMouseCursor(cursor:Null<glaze.CursorStyle>):Void {
        if (cursor == null && !this._cursorSet) {
            return;
        }
        this._cursorSet = cursor != null;
        EditorWidgets.setMouseCursor(this._editor, cursor);
    }

    function _getInlineHintsForRange(range:Range):Array<InlayHintItem> {
        final lineHints:Array<InlayHintItem> = [];
        for (id in this._decorationIds) {
            final data = this._decorationsMetadata.get(id);
            if (range.containsRange(data.item.anchor.range) && lineHints.indexOf(data.item) == -1) {
                lineHints.push(data.item);
            }
        }
        return lineHints;
    }

    function _installDblClickGesture(updateInlayHints:() -> Void):IDisposable {
        return this._editor.onMouseUp(e -> {
            if (e.event.detail != 2) {
                return;
            }
            final part = this._getInlayHintLabelPart(e.target);
            if (part == null) {
                return;
            }
            part.item.resolve(CancellationTokens.None).done(_ -> {
                final textEdits = part.item.hint.textEdits;
                if (textEdits != null && textEdits.length > 0) {
                    final edits = [for (edit in textEdits) EditOperation.replace(Range.lift(edit.range), edit.text)];
                    this._editor.executeEdits('inlayHint.default', edits);
                    updateInlayHints();
                }
            });
        });
    }

    /**
     * The label part of the injected text under the mouse, or null.
     */
    function _getInlayHintLabelPart(target:Null<MouseTarget>):Null<RenderedInlayHintLabelPart> {
        return InlayHintsController.labelPartOf(target);
    }

    /**
     * The label part an injected text shows (the inlay hints hover).
     */
    public static function labelPartOf(target:Null<MouseTarget>):Null<RenderedInlayHintLabelPart> {
        if (target == null || target.type != MouseTargetType.CONTENT_TEXT || target.injectedText == null) {
            return null;
        }
        final options:Any = target.injectedText.options;
        if (Std.isOfType(options, ModelDecorationInjectedTextOptions)) {
            final attachedData:Any = (options : ModelDecorationInjectedTextOptions).attachedData;
            if (Std.isOfType(attachedData, RenderedInlayHintLabelPart)) {
                return attachedData;
            }
        }
        return null;
    }

    function _invokeCommand(command:Command, item:InlayHintItem):Void {
        try {
            this._editor.context.commandService.executeCommand(command.id, command.arguments != null ? command.arguments : []);
        }
        catch (err:Dynamic) {
            // Monaco notifies the error with the provider's name
            Errors.onUnexpectedError(err);
        }
    }

    function _cacheHintsForFastRestore(model:ITextModel):Void {
        final hints = this._copyInlayHintsWithCurrentAnchor(model);
        this._inlayHintsCache.set(model, hints);
    }

    // return inlay hints but with an anchor that reflects "updates"
    // that happened after receiving them, e.g adding new lines before a hint
    function _copyInlayHintsWithCurrentAnchor(model:ITextModel):Array<InlayHintItem> {
        final originals:Array<InlayHintItem> = [];
        final copies:Array<InlayHintItem> = [];
        for (id in this._decorationIds) {
            final obj = this._decorationsMetadata.get(id);
            if (originals.indexOf(obj.item) != -1) {
                // an inlay item can be rendered as multiple decorations
                // but they will all uses the same range
                continue;
            }
            final range = model.getDecorationRange(id);
            if (range != null) {
                // update range with whatever the editor has tweaked it to
                final anchor = new InlayHintAnchor(range, obj.item.anchor.direction);
                final copy = obj.item.with({anchor: anchor});
                originals.push(obj.item);
                copies.push(copy);
            }
        }
        return copies;
    }

    function _getHintsRanges():Array<Range> {
        final extra = 30;
        final model = this._editor.getModel();
        final visibleRanges = this._editor.getVisibleRangesPlusViewportAboveBelow().copy();
        haxe.ds.ArraySort.sort(visibleRanges, (a, b) -> Range.compareRangesUsingStarts(a, b));
        final result:Array<Range> = [];
        for (range in visibleRanges) {
            final extendedRange = model.validateRange(new Range(range.startLineNumber - extra, range.startColumn, range.endLineNumber + extra, range.endColumn));
            if (result.length == 0 || !Range.areIntersectingOrTouching(result[result.length - 1], extendedRange)) {
                result.push(extendedRange);
            } else {
                result[result.length - 1] = Range.plusRangeStatic(result[result.length - 1], extendedRange);
            }
        }
        return result;
    }

    /**
     * The typed style of a part (Monaco's `DynamicCssRules.createClassNameRef`
     * of its CSS properties): one style object per set of properties.
     */
    function _styleOf(kind:Null<InlayHintKind>, fontSize:Float, padding:Bool, isFirst:Bool, isLast:Bool, activeLink:Bool, activeWithModifier:Bool):IDecorationStyle {
        final kindKey = kind == InlayHintKind.Parameter ? 'p' : (kind == InlayHintKind.Type ? 't' : 'o');
        final key = kindKey + '|' + fontSize + '|' + (padding ? (isFirst ? 'f' : '') + (isLast ? 'l' : '') + 'p' : '') + '|' + (activeLink ? (activeWithModifier ? 'm' : 'a') : '');
        final existing = this._styles.get(key);
        if (existing != null) {
            return existing;
        }
        // _fillInColors
        final colors = kind == InlayHintKind.Parameter
            ? {background: 'editorInlayHint.parameterBackground', foreground: 'editorInlayHint.parameterForeground'}
            : (kind == InlayHintKind.Type
                ? {background: 'editorInlayHint.typeBackground', foreground: 'editorInlayHint.typeForeground'}
                : {background: 'editorInlayHint.background', foreground: 'editorInlayHint.foreground'});
        final style:IDecorationStyle = {
            color: activeLink && activeWithModifier ? {id: 'editorLink.activeForeground'} : {id: colors.foreground},
            background: {id: colors.background},
            underline: activeLink ? {} : null,
            // the background of the parts of a hint is one box (Monaco
            // rounds the outer corners of the first and last parts)
            join: true
        };
        if (padding) {
            // `padding: 1px <fontSize / 4>px` on the outer sides
            final horizontal:Float = Std.int(Math.max(1, fontSize / 4));
            style.paddingTop = 1;
            style.paddingBottom = 1;
            style.borderRadius = Std.int(fontSize / 4);
            if (isFirst) {
                style.paddingLeft = horizontal;
            }
            if (isLast) {
                style.paddingRight = horizontal;
            }
        }
        this._styles.set(key, style);
        return style;
    }

    function _spacerStyleOf(fontSize:Float):IDecorationStyle {
        final key = 'spacer|' + fontSize;
        final existing = this._styles.get(key);
        if (existing != null) {
            return existing;
        }
        // `width: <fontSize / 3>px; display: inline-block`
        final style:IDecorationStyle = {width: Std.int(fontSize / 3)};
        this._styles.set(key, style);
        return style;
    }

    function _updateHintsDecorators(ranges:Array<Range>, items:Array<InlayHintItem>):Void {

        // utils to collect/create injected text decorations
        final newDecorationsData:Array<InlayHintDecorationRenderInfo> = [];
        final addInjectedText = (item:InlayHintItem, style:IDecorationStyle, content:String, cursorStops:InjectedTextCursorStops, attachedData:Null<RenderedInlayHintLabelPart>) -> {
            final opts:Null<InjectedTextOptions> = this._activeRenderMode == RenderMode.Normal ? {
                content: content,
                inlineClassNameAffectsLetterSpacing: true,
                inlineStyle: style,
                cursorStops: cursorStops,
                attachedData: attachedData
            } : null;
            final isEmpty = item.anchor.range.isEmpty();
            final options:IModelDecorationOptions = item.anchor.direction == 'before' ? {
                description: 'InlayHint',
                showIfCollapsed: isEmpty,
                collapseOnReplaceEdit: !isEmpty,
                stickiness: TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges,
                before: opts
            } : {
                description: 'InlayHint',
                showIfCollapsed: isEmpty,
                collapseOnReplaceEdit: !isEmpty,
                stickiness: TrackedRangeStickiness.AlwaysGrowsWhenTypingAtEdges,
                after: opts
            };
            newDecorationsData.push({
                item: item,
                decoration: {
                    range: item.anchor.range,
                    options: options
                }
            });
        };

        final layout = this._getLayoutInfo();
        final fontSize = layout.fontSize;
        final padding = layout.padding;

        final addInjectedWhitespace = (item:InlayHintItem, isLast:Bool) -> {
            addInjectedText(item, this._spacerStyleOf(fontSize), '\u200a', isLast ? InjectedTextCursorStops.Right : InjectedTextCursorStops.None, null);
        };

        var currentLine = 0;
        var currentTotalLen = 0;

        for (item in items) {

            if (currentLine != item.anchor.range.startLineNumber) {
                currentLine = item.anchor.range.startLineNumber;
                currentTotalLen = 0;
            }

            if (currentTotalLen > InlayHintsController._MAX_LABEL_LEN) {
                continue;
            }

            // whitespace leading the actual label
            if (item.hint.paddingLeft == true) {
                addInjectedWhitespace(item, false);
            }

            // the label with its parts
            final label:Any = item.hint.label;
            final parts:Array<InlayHintLabelPart> = Std.isOfType(label, std.String)
                ? [{label: (label : std.String)}]
                : (label : Array<InlayHintLabelPart>);

            for (i in 0...parts.length) {
                final part = parts[i];

                final isFirst = i == 0;
                final isLast = i == parts.length - 1;

                final active = this._activeInlayHintPart;
                final activeLink = (part.command != null || part.location != null) && active != null && active.part.item == item && active.part.index == i;
                final style = this._styleOf(item.hint.kind, fontSize, padding, isFirst, isLast, activeLink, activeLink && active.hasTriggerModifier);

                var textlabel = part.label;
                currentTotalLen += textlabel.length;
                var tooLong = false;
                final over = currentTotalLen - InlayHintsController._MAX_LABEL_LEN;
                if (over > 0) {
                    textlabel = textlabel.substring(0, Std.int(Math.max(0, textlabel.length - over))) + '\u2026';
                    tooLong = true;
                }

                addInjectedText(
                    item,
                    style,
                    fixSpace(textlabel),
                    isLast && item.hint.paddingRight != true ? InjectedTextCursorStops.Right : InjectedTextCursorStops.None,
                    new RenderedInlayHintLabelPart(item, i)
                );

                if (tooLong) {
                    break;
                }
            }

            // whitespace trailing the actual label
            if (item.hint.paddingRight == true) {
                addInjectedWhitespace(item, true);
            }

            if (newDecorationsData.length > InlayHintsController._MAX_DECORATORS) {
                break;
            }
        }

        // collect all decoration ids that are affected by the ranges
        // and only update those decorations
        final decorationIdsToReplace:Array<String> = [];
        final model = this._editor.getModel();
        for (id in this._decorationIds.copy()) {
            final range = model != null ? model.getDecorationRange(id) : null;
            if (range != null && Lambda.exists(ranges, r -> r.containsRange(range))) {
                decorationIdsToReplace.push(id);
                this._decorationsMetadata.remove(id);
                this._decorationIds.remove(id);
            }
        }

        final scrollState = StableEditorScrollState.capture(new ScrollStateEditor(this._editor));

        this._editor.changeDecorations(accessor -> {
            final newDecorationIds = accessor.deltaDecorations(decorationIdsToReplace, [for (d in newDecorationsData) d.decoration]);
            for (i in 0...newDecorationIds.length) {
                final data = newDecorationsData[i];
                this._decorationsMetadata.set(newDecorationIds[i], data);
                this._decorationIds.push(newDecorationIds[i]);
            }
            return null;
        });

        scrollState.restore(new ScrollStateEditor(this._editor));
    }

    function _getLayoutInfo():{fontSize:Float, fontFamily:String, padding:Bool, isUniform:Bool} {
        final options = this._editor.getOption(EditorOption.inlayHints);
        final padding = options.padding;

        final editorFontSize:Float = this._editor.getOption(EditorOption.fontSize);
        final editorFontFamily = this._editor.getOption(EditorOption.fontFamily);

        var fontSize:Float = options.fontSize;
        if (fontSize == 0 || fontSize < 5 || fontSize > editorFontSize) {
            fontSize = editorFontSize;
        }

        final fontFamily = options.fontFamily.length > 0 ? options.fontFamily : editorFontFamily;

        final isUniform = !padding
            && fontFamily == editorFontFamily
            && fontSize == editorFontSize;

        // Cityscape: a view line has one font size and family (Monaco's
        // smaller size and other family of the hints are not applied, see
        // DEVIATIONS.md); the padding and spacers follow the editor's size
        return {fontSize: editorFontSize, fontFamily: editorFontFamily, padding: padding, isUniform: isUniform};
    }

    function _removeAllDecorations():Void {
        this._editor.removeDecorations(this._decorationIds.copy());
        this._decorationsMetadata.clear();
        this._decorationIds.resize(0);
    }

    // --- accessibility

    public function getInlayHintsForLine(line:Int):Array<InlayHintItem> {
        if (!this._editor.hasModel()) {
            return [];
        }
        final set:Array<InlayHint> = [];
        final result:Array<InlayHintItem> = [];
        final decorations = this._editor.getLineDecorations(line);
        if (decorations == null) {
            return result;
        }
        for (deco in decorations) {
            final data = this._decorationsMetadata.get(deco.id);
            if (data != null && set.indexOf(data.item.hint) == -1) {
                set.push(data.item.hint);
                result.push(data.item);
            }
        }
        return result;
    }

    // Prevents the view from potentially visible whitespace
    static function fixSpace(str:String):String {
        final noBreakWhitespace = '\u00a0';
        return str.split(' ').join(noBreakWhitespace).split('\t').join(noBreakWhitespace);
    }

}

/**
 * An editor as the editor of `StableEditorScrollState`.
 */
private class ScrollStateEditor implements cityscape.view.StableEditorScroll.IScrollStateEditor {

    final editor:ICodeEditor;

    public function new(editor:ICodeEditor) {
        this.editor = editor;
    }

    public function getScrollTop():Float {
        return editor.getScrollTop();
    }

    public function setScrollTop(newScrollTop:Float, ?scrollType:cityscape.common.EditorCommon.ScrollType):Void {
        editor.setScrollTop(newScrollTop, scrollType);
    }

    public function hasPendingScrollAnimation():Bool {
        return false;
    }

    public function getContentHeight():Float {
        return editor.getContentHeight();
    }

    public function getVisibleRanges():Array<Range> {
        return editor.getVisibleRanges();
    }

    public function getTopForLineNumber(lineNumber:Int):Float {
        return editor.getTopForLineNumber(lineNumber);
    }

    public function getTopForPosition(lineNumber:Int, column:Int):Float {
        return editor.getTopForPosition(lineNumber, column);
    }

    public function getPosition():Null<cityscape.common.core.Position> {
        return editor.getPosition();
    }

}

/**
 * The registration of inlayHintsContribution.ts (its module level code):
 * the contribution and the hover participant.
 */
class InlayHintsRegistration {

    public static function register(r:EditorExtensionsRegistry):Void {
        r.registerEditorContribution(InlayHintsController.ID, editor -> new InlayHintsController(editor), EditorContributionInstantiation.AfterFirstRender);
        ContentHoverController.registerParticipant(r.context, editor -> new InlayHintsHover(editor));
    }

}
