// Ported from vscode src/vs/editor/contrib/codelens/browser/codelensController.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.codelens.view;

import cityscape.base.common.Async;
import cityscape.base.common.Cancellation;
import cityscape.base.common.Errors;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Promise;
import cityscape.common.EditorCommon.IEditorContribution;
import cityscape.common.Languages.CodeLens;
import cityscape.common.Languages.CodeLensProvider;
import cityscape.common.Model.IModelDecorationsChangeAccessor;
import cityscape.common.config.EditorOptions;
import cityscape.contrib.codelens.view.CodeLensModel;
import cityscape.contrib.codelens.view.CodeLensWidget;
import cityscape.contrib.inlayHints.view.InlayHintsController.FeatureDebounceInformation;
import cityscape.view.EditorBrowser;
import cityscape.view.EditorExtensions;
import cityscape.view.EditorWidgets;
import cityscape.view.StableEditorScroll;

/**
 * Monaco's `CancelablePromise` (`createCancelablePromise`): the promise of
 * a computation given a token, rejected with a `CancellationError` once
 * cancelled.
 */
private class CancelablePromise<T> {

    final _source = new CancellationTokenSource();
    final _promise:Promise<T>;

    public function new(callback:(token:CancellationToken) -> Promise<T>) {
        final token = _source.token;
        final inner = callback(token);
        _promise = new Promise<T>((resolve, reject) -> {
            inner.done(value -> {
                if (token.isCancellationRequested) {
                    reject(new CancellationError());
                } else {
                    resolve(value);
                }
            }, err -> reject(err));
            token.onCancellationRequested(() -> reject(new CancellationError()));
        });
    }

    public function cancel():Void {
        _source.cancel();
    }

    public function then(onResolve:(value:Null<T>) -> Void, onReject:(error:Any) -> Void):Void {
        _promise.done(onResolve, onReject);
    }

    public function promise():Promise<T> {
        return _promise;
    }

}

/**
 * Shows the code lenses of the providers above their lines (Monaco's
 * `CodeLensContribution`): a view zone above each line with lenses, the
 * lenses of the visible lines resolved, a click on a lens runs its command.
 *
 * Monaco's content widget of the lenses is painted by the view zone
 * (`CodeLensContentWidget.paint`); a click on the zone finds the lens from
 * the x of the mouse. `codelens.showLensesInCurrentLine` (a quick pick of
 * the commands of the cursor line) is not ported: there is no quick input.
 */
class CodeLensContribution implements IEditorContribution {

    public static inline final ID:String = 'css.editor.codeLens';

    public static function get(editor:ICodeEditor):Null<CodeLensContribution> {
        return editor.getContribution(CodeLensContribution.ID);
    }

    final _disposables = new DisposableStore();
    final _localToDispose = new DisposableStore();

    final _lenses:Array<CodeLensWidget> = [];

    final _provideCodeLensDebounce:FeatureDebounceInformation;
    final _resolveCodeLensesDebounce:FeatureDebounceInformation;
    final _resolveCodeLensesScheduler:RunOnceScheduler;

    var _getCodeLensModelPromise:Null<CancelablePromise<CodeLensModel>> = null;
    final _oldCodeLensModels:Array<CodeLensModel> = [];
    var _currentCodeLensModel:Null<CodeLensModel> = null;
    var _resolveCodeLensesPromise:Null<CancelablePromise<Any>> = null;

    /**
     * The scheduler of the provider requests (tests flush it).
     */
    var _provideScheduler:Null<RunOnceScheduler> = null;

    /**
     * What the lenses paint with (Monaco's CSS variables).
     */
    final _style = new CodeLensPaintStyle();
    var _cursorSet = false;

    final _editor:ICodeEditor;
    final _codeLensCache:CodeLensCache;

    public function new(editor:ICodeEditor) {
        this._editor = editor;
        this._codeLensCache = editor.context.codeLensCache;
        final codeLensProvider = editor.context.languageFeaturesService.codeLensProvider;
        this._provideCodeLensDebounce = new FeatureDebounceInformation(250);
        this._resolveCodeLensesDebounce = new FeatureDebounceInformation(250);
        this._resolveCodeLensesScheduler = new RunOnceScheduler(() -> this._resolveCodeLensesInViewport(), this._resolveCodeLensesDebounce.defaultValue());

        this._disposables.add(this._editor.onDidChangeModel(_ -> this._onModelChange()));
        this._disposables.add(this._editor.onDidChangeModelLanguage(_ -> this._onModelChange()));
        this._disposables.add(this._editor.onDidChangeConfiguration(e -> {
            if (e.hasChanged(EditorOption.fontInfo) || e.hasChanged(EditorOption.codeLensFontSize) || e.hasChanged(EditorOption.codeLensFontFamily)) {
                this._updateLensStyle();
            }
            if (e.hasChanged(EditorOption.codeLens)) {
                this._onModelChange();
            }
        }));
        this._disposables.add(codeLensProvider.onDidChange(_ -> this._onModelChange()));
        this._onModelChange();

        this._updateLensStyle();
    }

    public function saveViewState():Any {
        return null;
    }

    public function restoreViewState(state:Any):Void {}

    public function dispose():Void {
        this._localDispose();
        this._disposables.dispose();
        this._clearOldModels();
        if (this._currentCodeLensModel != null) {
            this._currentCodeLensModel.dispose();
        }
    }

    function _clearOldModels():Void {
        for (m in this._oldCodeLensModels) {
            m.dispose();
        }
        this._oldCodeLensModels.resize(0);
    }

    function _getLayoutInfo():{fontSize:Float, codeLensHeight:Float} {
        final lineHeightFactor = Math.max(1.3, this._editor.getOption(EditorOption.lineHeight) / this._editor.getOption(EditorOption.fontSize));
        var fontSize:Float = this._editor.getOption(EditorOption.codeLensFontSize);
        if (fontSize == 0 || fontSize < 5) {
            fontSize = Std.int(this._editor.getOption(EditorOption.fontSize) * .9);
        }
        return {
            fontSize: fontSize,
            codeLensHeight: Std.int(fontSize * lineHeightFactor)
        };
    }

    function _updateLensStyle():Void {

        final layout = this._getLayoutInfo();
        final fontFamily = this._editor.getOption(EditorOption.codeLensFontFamily);

        // the CSS variables of the editor's container
        this._style.lineHeight = layout.codeLensHeight;
        this._style.fontSize = layout.fontSize;
        this._style.fontFamily = fontFamily != null ? fontFamily : '';

        //
        this._editor.changeViewZones(accessor -> {
            for (lens in this._lenses) {
                lens.updateHeight(layout.codeLensHeight, accessor);
            }
        });
    }

    function _localDispose():Void {
        if (this._getCodeLensModelPromise != null) {
            this._getCodeLensModelPromise.cancel();
        }
        this._getCodeLensModelPromise = null;
        if (this._resolveCodeLensesPromise != null) {
            this._resolveCodeLensesPromise.cancel();
        }
        this._resolveCodeLensesPromise = null;
        this._localToDispose.clear();
        this._clearOldModels();
        if (this._currentCodeLensModel != null) {
            this._currentCodeLensModel.dispose();
        }
        this._provideScheduler = null;
    }

    function _onModelChange():Void {

        this._localDispose();

        final model = this._editor.getModel();
        if (model == null) {
            return;
        }

        if (!this._editor.getOption(EditorOption.codeLens) || model.isTooLargeForTokenization()) {
            return;
        }

        final cachedLenses = this._codeLensCache.get(model);
        if (cachedLenses != null) {
            this._renderCodeLensSymbols(cachedLenses);
        }

        final codeLensProvider = this._editor.context.languageFeaturesService.codeLensProvider;
        if (!codeLensProvider.has(model)) {
            // no provider -> return but check with
            // cached lenses. they expire after 30 seconds
            if (cachedLenses != null) {
                final cancel = Async.setTimeout(() -> {
                    final cachedLensesNow = this._codeLensCache.get(model);
                    if (cachedLenses == cachedLensesNow) {
                        this._codeLensCache.delete(model);
                        this._onModelChange();
                    }
                }, 30 * 1000);
                this._localToDispose.add(Lifecycle.toDisposable(cancel));
            }
            return;
        }

        var scheduler:Null<RunOnceScheduler> = null;

        for (provider in codeLensProvider.all(model)) {
            final onDidChange = provider.onDidChange;
            if (onDidChange != null) {
                final registration = onDidChange(_ -> scheduler.schedule());
                this._localToDispose.add(registration);
            }
        }

        scheduler = new RunOnceScheduler(() -> {
            final t1 = haxe.Timer.stamp();

            if (this._getCodeLensModelPromise != null) {
                this._getCodeLensModelPromise.cancel();
            }
            final request = new CancelablePromise<CodeLensModel>(token -> CodeLensModel.getCodeLensModel(codeLensProvider, model, token));
            this._getCodeLensModelPromise = request;

            request.then(result -> {
                if (this._currentCodeLensModel != null) {
                    this._oldCodeLensModels.push(this._currentCodeLensModel);
                }
                this._currentCodeLensModel = result;

                // cache model to reduce flicker
                this._codeLensCache.put(model, result);

                // update moving average
                final newDelay = this._provideCodeLensDebounce.update(model, (haxe.Timer.stamp() - t1) * 1000);
                scheduler.delay = newDelay;

                // render lenses
                this._renderCodeLensSymbols(result);
                // dom.scheduleAtNextAnimationFrame(() => this._resolveCodeLensesInViewport());
                this._resolveCodeLensesInViewportSoon();
            }, err -> Errors.onUnexpectedError(err));

        }, this._provideCodeLensDebounce.get(model));
        this._provideScheduler = scheduler;

        this._localToDispose.add(scheduler);
        this._localToDispose.add(Lifecycle.toDisposable(() -> this._resolveCodeLensesScheduler.cancel()));
        this._localToDispose.add(this._editor.onDidChangeModelContent(_ -> {
            this._editor.changeDecorations(decorationsAccessor -> {
                this._editor.changeViewZones(viewZonesAccessor -> {
                    final toDispose:Array<CodeLensWidget> = [];
                    var lastLensLineNumber:Int = -1;

                    for (lens in this._lenses) {
                        if (!lens.isValid() || lastLensLineNumber == lens.getLineNumber()) {
                            // invalid -> lens collapsed, attach range doesn't exist anymore
                            // line_number -> lenses should never be on the same line
                            toDispose.push(lens);

                        } else {
                            lens.update(viewZonesAccessor);
                            lastLensLineNumber = lens.getLineNumber();
                        }
                    }

                    final helper = new CodeLensHelper();
                    for (l in toDispose) {
                        l.dispose(helper, viewZonesAccessor);
                        this._lenses.remove(l);
                    }
                    helper.commit(decorationsAccessor);
                });
                return null;
            });

            // Ask for all references again
            scheduler.schedule();

            // Cancel pending and active resolve requests
            this._resolveCodeLensesScheduler.cancel();
            if (this._resolveCodeLensesPromise != null) {
                this._resolveCodeLensesPromise.cancel();
            }
            this._resolveCodeLensesPromise = null;
        }));
        this._localToDispose.add(this._editor.onDidFocusEditorText(() -> {
            scheduler.schedule();
        }));
        this._localToDispose.add(this._editor.onDidBlurEditorText(() -> {
            scheduler.cancel();
        }));
        this._localToDispose.add(this._editor.onDidScrollChange(e -> {
            if (e.scrollTopChanged && this._lenses.length > 0) {
                this._resolveCodeLensesInViewportSoon();
            }
        }));
        this._localToDispose.add(this._editor.onDidLayoutChange(_ -> {
            this._resolveCodeLensesInViewportSoon();
        }));
        this._localToDispose.add(Lifecycle.toDisposable(() -> {
            if (this._editor.getModel() != null) {
                final scrollState = StableEditorScrollState.capture(new ScrollStateEditor(this._editor));
                this._editor.changeDecorations(decorationsAccessor -> {
                    this._editor.changeViewZones(viewZonesAccessor -> {
                        this._disposeAllLenses(decorationsAccessor, viewZonesAccessor);
                    });
                    return null;
                });
                scrollState.restore(new ScrollStateEditor(this._editor));
            } else {
                // No accessors available
                this._disposeAllLenses(null, null);
            }
        }));
        this._localToDispose.add(this._editor.onMouseDown(e -> {
            final hit = this._linkAt(e);
            if (hit != null) {
                final command = hit.lens.getCommand(hit.linkId);
                if (command != null) {
                    try {
                        this._editor.context.commandService.executeCommand(command.id, command.arguments != null ? command.arguments : []);
                    }
                    catch (err:Dynamic) {
                        // Monaco shows the error with the notification service
                        Errors.onUnexpectedError(err);
                    }
                }
            }
        }));
        // `a:hover`: the link under the mouse takes the active link color and
        // the pointer cursor
        this._localToDispose.add(this._editor.onMouseMove(e -> {
            final hit = this._linkAt(e);
            this._setHoveredLink(hit != null ? hit.linkId : null);
        }));
        this._localToDispose.add(this._editor.onMouseLeave(_ -> this._setHoveredLink(null)));
        scheduler.schedule();
    }

    /**
     * The lens link under the mouse: the zone of a lens widget (Monaco's
     * `CONTENT_WIDGET` target on the link element), the segment at the x
     * of the mouse.
     */
    function _linkAt(e:IEditorMouseEvent):Null<{lens:CodeLensWidget, linkId:String}> {
        if (e.target.type != MouseTargetType.CONTENT_VIEW_ZONE || e.target.viewZoneData == null) {
            return null;
        }
        final zoneId = e.target.viewZoneData.viewZoneId;
        for (lens in this._lenses) {
            if (lens.getViewZoneId() != zoneId) {
                continue;
            }
            final widget = lens.getContentWidget();
            if (widget == null) {
                return null;
            }
            final segment = widget.linkAt(e.event.posx, this._style);
            return segment != null ? {lens: lens, linkId: segment.linkId} : null;
        }
        return null;
    }

    function _setHoveredLink(linkId:Null<String>):Void {
        if (this._style.hoveredLinkId == linkId) {
            return;
        }
        this._style.hoveredLinkId = linkId;
        if (linkId != null) {
            this._cursorSet = true;
            EditorWidgets.setMouseCursor(this._editor, glaze.CursorStyle.PointingHand);
        } else if (this._cursorSet) {
            this._cursorSet = false;
            EditorWidgets.setMouseCursor(this._editor, null);
        }
        this._editor.render();
    }

    function _disposeAllLenses(decChangeAccessor:Null<IModelDecorationsChangeAccessor>, viewZoneChangeAccessor:Null<IViewZoneChangeAccessor>):Void {
        final helper = new CodeLensHelper();
        for (lens in this._lenses) {
            lens.dispose(helper, viewZoneChangeAccessor);
        }
        if (decChangeAccessor != null) {
            helper.commit(decChangeAccessor);
        }
        this._lenses.resize(0);
    }

    function _renderCodeLensSymbols(symbols:CodeLensModel):Void {
        if (!this._editor.hasModel()) {
            return;
        }

        final maxLineNumber = this._editor.getModel().getLineCount();
        final groups:Array<Array<CodeLensItem>> = [];
        var lastGroup:Null<Array<CodeLensItem>> = null;

        for (symbol in symbols.lenses) {
            final line = symbol.symbol.range.startLineNumber;
            if (line < 1 || line > maxLineNumber) {
                // invalid code lens
                continue;
            } else if (lastGroup != null && lastGroup[lastGroup.length - 1].symbol.range.startLineNumber == line) {
                // on same line as previous
                lastGroup.push(symbol);
            } else {
                // on later line as previous
                lastGroup = [symbol];
                groups.push(lastGroup);
            }
        }

        if (groups.length == 0 && this._lenses.length == 0) {
            // Nothing to change
            return;
        }

        final scrollState = StableEditorScrollState.capture(new ScrollStateEditor(this._editor));
        final layoutInfo = this._getLayoutInfo();

        this._editor.changeDecorations(decorationsAccessor -> {
            this._editor.changeViewZones(viewZoneAccessor -> {

                final helper = new CodeLensHelper();
                var codeLensIndex = 0;
                var groupsIndex = 0;

                while (groupsIndex < groups.length && codeLensIndex < this._lenses.length) {

                    final symbolsLineNumber = groups[groupsIndex][0].symbol.range.startLineNumber;
                    final codeLensLineNumber = this._lenses[codeLensIndex].getLineNumber();

                    if (codeLensLineNumber < symbolsLineNumber) {
                        this._lenses[codeLensIndex].dispose(helper, viewZoneAccessor);
                        this._lenses.splice(codeLensIndex, 1);
                    } else if (codeLensLineNumber == symbolsLineNumber) {
                        this._lenses[codeLensIndex].updateCodeLensSymbols(groups[groupsIndex], helper);
                        groupsIndex++;
                        codeLensIndex++;
                    } else {
                        this._lenses.insert(codeLensIndex, new CodeLensWidget(groups[groupsIndex], this._editor, helper, viewZoneAccessor, layoutInfo.codeLensHeight, () -> this._resolveCodeLensesInViewportSoon(), this._style));
                        codeLensIndex++;
                        groupsIndex++;
                    }
                }

                // Delete extra code lenses
                while (codeLensIndex < this._lenses.length) {
                    this._lenses[codeLensIndex].dispose(helper, viewZoneAccessor);
                    this._lenses.splice(codeLensIndex, 1);
                }

                // Create extra symbols
                while (groupsIndex < groups.length) {
                    this._lenses.push(new CodeLensWidget(groups[groupsIndex], this._editor, helper, viewZoneAccessor, layoutInfo.codeLensHeight, () -> this._resolveCodeLensesInViewportSoon(), this._style));
                    groupsIndex++;
                }

                helper.commit(decorationsAccessor);
            });
            return null;
        });

        scrollState.restore(new ScrollStateEditor(this._editor));
    }

    function _resolveCodeLensesInViewportSoon():Void {
        final model = this._editor.getModel();
        if (model != null) {
            this._resolveCodeLensesScheduler.schedule();
        }
    }

    function _resolveCodeLensesInViewport():Void {

        if (this._resolveCodeLensesPromise != null) {
            this._resolveCodeLensesPromise.cancel();
        }
        this._resolveCodeLensesPromise = null;

        final model = this._editor.getModel();
        if (model == null) {
            return;
        }

        final toResolve:Array<Array<CodeLensItem>> = [];
        final lenses:Array<CodeLensWidget> = [];
        for (lens in this._lenses) {
            final request = lens.computeIfNecessary(model);
            if (request != null) {
                toResolve.push(request);
                lenses.push(lens);
            }
        }

        if (toResolve.length == 0) {
            return;
        }

        final t1 = haxe.Timer.stamp();

        final resolvePromise = new CancelablePromise<Any>(token -> {

            final promises:Array<Promise<Any>> = [];
            for (i in 0...toResolve.length) {
                final request = toResolve[i];
                final resolvedSymbols:Array<Null<CodeLens>> = [for (_ in 0...request.length) null];
                final inner:Array<Promise<Any>> = [];
                for (j in 0...request.length) {
                    final item = request[j];
                    final resolveCodeLens = item.provider.resolveCodeLens;
                    if (item.symbol.command == null && resolveCodeLens != null) {
                        inner.push(Promise.fromCallback((done:(value:Null<CodeLens>) -> Void) -> {
                            try {
                                resolveCodeLens(model, item.symbol, token, done);
                            }
                            catch (err:Dynamic) {
                                Errors.onUnexpectedExternalError(err);
                                done(null);
                            }
                        }).then(symbol -> {
                            resolvedSymbols[j] = symbol;
                            return null;
                        }));
                    } else {
                        resolvedSymbols[j] = item.symbol;
                        inner.push(Promise.resolve(null));
                    }
                }

                promises.push(Promise.all(inner).then(_ -> {
                    if (!token.isCancellationRequested && !lenses[i].isDisposed()) {
                        lenses[i].updateCommands(resolvedSymbols);
                    }
                    return null;
                }));
            }

            return Promise.all(promises).then(_ -> (null : Any));
        });
        this._resolveCodeLensesPromise = resolvePromise;

        resolvePromise.then(_ -> {

            // update moving average
            final newDelay = this._resolveCodeLensesDebounce.update(model, (haxe.Timer.stamp() - t1) * 1000);
            this._resolveCodeLensesScheduler.delay = newDelay;

            if (this._currentCodeLensModel != null) { // update the cached state with new resolved items
                this._codeLensCache.put(model, this._currentCodeLensModel);
            }
            this._clearOldModels(); // dispose old models once we have updated the UI with the current model
            if (resolvePromise == this._resolveCodeLensesPromise) {
                this._resolveCodeLensesPromise = null;
            }
        }, err -> {
            Errors.onUnexpectedError(err); // can also be cancellation!
            if (resolvePromise == this._resolveCodeLensesPromise) {
                this._resolveCodeLensesPromise = null;
            }
        });
    }

    /**
     * The current code lens model once the pending requests are done
     * (Monaco's `getModel`): `callback` gets it, or null.
     */
    public function getModel(callback:(model:Null<CodeLensModel>) -> Void):Void {
        final done = () -> {
            callback(this._currentCodeLensModel != null && !this._currentCodeLensModel.isDisposed ? this._currentCodeLensModel : null);
        };
        final afterProvide = () -> {
            final resolve = this._resolveCodeLensesPromise;
            if (resolve != null) {
                resolve.promise().finally(done);
            } else {
                done();
            }
        };
        final provide = this._getCodeLensModelPromise;
        if (provide != null) {
            provide.promise().finally(afterProvide);
        } else {
            afterProvide();
        }
    }

    /**
     * Runs the pending requests now: the lenses of the providers, then the
     * resolution of the visible ones (tests; Monaco waits for the
     * schedulers).
     */
    public function _flush():Void {
        final scheduler = this._provideScheduler;
        if (scheduler != null && scheduler.isScheduled()) {
            scheduler.flush();
        }
        if (this._resolveCodeLensesScheduler.isScheduled()) {
            this._resolveCodeLensesScheduler.flush();
        }
    }

    /**
     * The lens widgets, one per line with lenses (tests).
     */
    public function getLenses():Array<CodeLensWidget> {
        return this._lenses.copy();
    }

    /**
     * What the lenses paint with (tests, the visual scene).
     */
    public function getPaintStyle():CodeLensPaintStyle {
        return this._style;
    }

}

/**
 * An editor as the editor of `StableEditorScrollState`.
 */
private class ScrollStateEditor implements IScrollStateEditor {

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

    public function getVisibleRanges():Array<cityscape.common.core.Range> {
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
 * The registration of codelensController.ts (its module level code). The
 * colors (`editorCodeLens.foreground`) are registered by
 * `EditorColorRegistry`.
 */
class CodeLensRegistration {

    public static function register(r:EditorExtensionsRegistry):Void {
        r.registerEditorContribution(CodeLensContribution.ID, editor -> new CodeLensContribution(editor), EditorContributionInstantiation.AfterFirstRender);
    }

}
