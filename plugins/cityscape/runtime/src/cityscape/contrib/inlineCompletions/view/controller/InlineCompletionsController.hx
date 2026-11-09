// Ported from vscode src/vs/editor/contrib/inlineCompletions/browser/controller/inlineCompletionsController.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.inlineCompletions.view.controller;

import cityscape.base.common.Lifecycle;
import cityscape.base.common.Observable;
import cityscape.base.common.observableInternal.Base;
import cityscape.common.CursorEvents;
import cityscape.common.EditorCommon.IEditorContribution;
import cityscape.common.Model.ITextModel;
import cityscape.common.config.EditorOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.services.LanguageFeatureDebounce;
import cityscape.contrib.inlineCompletions.view.model.GhostText;
import cityscape.contrib.inlineCompletions.view.model.InlineCompletionsModel;
import cityscape.contrib.inlineCompletions.view.model.SuggestWidgetAdaptor;
import cityscape.contrib.inlineCompletions.view.view.GhostTextView;
import cityscape.view.CoreCommands.CoreEditingCommands;
import cityscape.view.EditorBrowser.ICodeEditor;
import cityscape.view.ObservableCodeEditor;

/**
 * The inline completions of an editor (Monaco's
 * `InlineCompletionsController`): creates the model of the editor's text
 * model, triggers it when the user types, stops it when the cursor moves or
 * the editor loses the focus, and shows the ghost texts.
 *
 * Not ported: the hints toolbar (`InlineCompletionsHintsWidget`), the
 * accessibility signal and the screen reader announcements, the accessible
 * view, the `fontFamily` of `inlineSuggest` (the decoration styles have no
 * font family), the `editorDictation.inProgress` and screen reader checks of
 * `_enabled` (both false here).
 */
class InlineCompletionsController extends Disposable implements IEditorContribution {

    public static inline final ID = 'editor.contrib.inlineCompletionsController';

    public static function get(editor:ICodeEditor):Null<InlineCompletionsController> {
        return editor.getContribution(InlineCompletionsController.ID);
    }

    public final editor:ICodeEditor;

    final _editorObs:ObservableCodeEditor;
    final _positions:IObservable<Array<Position>>;
    final _suggestWidgetAdaptor:SuggestWidgetAdaptor;
    final _suggestWidgetSelectedItem:IObservable<Null<SuggestItemInfo>>;
    final _enabledInConfig:IObservable<Bool>;
    final _enabled:IObservable<Bool>;
    final _debounceValue:IFeatureDebounceInformation;

    public final model:IObservable<Null<InlineCompletionsModel>>;

    final _ghostTexts:IObservable<Array<GhostTextOrReplacement>>;
    final _stablizedGhostTexts:IObservable<Array<IObservable<Null<GhostTextOrReplacement>>>>;
    final _ghostTextWidgets:Array<GhostTextView> = [];
    final _ghostTextWidgetSources:Array<IObservable<Null<GhostTextOrReplacement>>> = [];

    public function new(editor:ICodeEditor) {
        super();
        this.editor = editor;
        final context = editor.context;
        GhostTextView.registerDecorationStyles(context);

        this._editorObs = this._register(new ObservableCodeEditor(editor));
        this._positions = Observable.derived(reader -> {
            final selections = this._editorObs.selections.read(reader);
            return selections != null ? [for (s in selections) s.getEndPosition()] : [new Position(1, 1)];
        });

        this._suggestWidgetAdaptor = this._register(new SuggestWidgetAdaptor(
            this.editor,
            () -> {
                this._editorObs.forceUpdate();
                final m = this.model.get();
                final c = m != null ? m.selectedInlineCompletion.get() : null;
                return c != null ? c.toSingleTextEdit(null) : null;
            },
            (item) -> this._editorObs.forceUpdate(_tx -> {
                /** @description InlineCompletionsController.handleSuggestAccepted */
                final m = this.model.get();
                if (m != null) {
                    m.handleSuggestAccepted(item);
                }
            })
        ));

        this._suggestWidgetSelectedItem = Observable.observableFromEvent(cb -> this._suggestWidgetAdaptor.onDidSelectedItemChange(() -> {
            this._editorObs.forceUpdate(_tx -> cb());
        }), () -> this._suggestWidgetAdaptor.selectedItem);

        this._enabledInConfig = Observable.observableFromEvent(cb -> this.editor.onDidChangeConfiguration(_ -> cb()), () -> this.editor.getOption(EditorOption.inlineSuggest).enabled);
        this._enabled = Observable.derived(reader -> this._enabledInConfig.read(reader));

        // Monaco's `ILanguageFeatureDebounceService.for(inlineCompletionsProvider,
        // 'InlineCompletionsDebounce', {min: 50, max: 50})`: clamped to 50 ms
        this._debounceValue = new NullDebounceInformation(50);

        this.model = Observable.derivedDisposable(reader -> {
            if (this._editorObs.isReadonly.read(reader)) {
                return null;
            }
            final textModel = this._editorObs.model.read(reader);
            if (textModel == null) {
                return null;
            }

            final model = new InlineCompletionsModel(
                textModel,
                this._suggestWidgetSelectedItem,
                this._editorObs.versionId,
                this._positions,
                this._debounceValue,
                Observable.observableFromEvent(cb -> this.editor.onDidChangeConfiguration(_ -> cb()), () -> this.editor.getOption(EditorOption.suggest).preview),
                Observable.observableFromEvent(cb -> this.editor.onDidChangeConfiguration(_ -> cb()), () -> this.editor.getOption(EditorOption.suggest).previewMode),
                Observable.observableFromEvent(cb -> this.editor.onDidChangeConfiguration(_ -> cb()), () -> this.editor.getOption(EditorOption.inlineSuggest).mode),
                this._enabled,
                context
            );
            return model;
        }).recomputeInitiallyAndOnChange(this._store);

        this._ghostTexts = Observable.derived(reader -> {
            final model = this.model.read(reader);
            final g = model != null ? model.ghostTexts.read(reader) : null;
            return g != null ? g : [];
        });
        this._stablizedGhostTexts = convertItemsToStableObservables(this._ghostTexts, this._store);

        // Monaco's `mapObservableArrayCached`: one `GhostTextView` per
        // stable observable, created and disposed as the list changes
        this._register(Observable.autorun(reader -> {
            final items = this._stablizedGhostTexts.read(reader);
            var i = this._ghostTextWidgetSources.length - 1;
            while (i >= 0) {
                if (items.indexOf(this._ghostTextWidgetSources[i]) == -1) {
                    this._ghostTextWidgets[i].dispose();
                    this._ghostTextWidgets.splice(i, 1);
                    this._ghostTextWidgetSources.splice(i, 1);
                }
                i--;
            }
            final widgets:Array<GhostTextView> = [];
            for (ghostText in items) {
                final index = this._ghostTextWidgetSources.indexOf(ghostText);
                if (index != -1) {
                    widgets.push(this._ghostTextWidgets[index]);
                }
                else {
                    widgets.push(new GhostTextView(this.editor, {
                        ghostText: ghostText,
                        minReservedLineCount: Observable.constObservable(0),
                        targetTextModel: this.model.map((v, _) -> v != null ? v.textModel : null),
                    }));
                }
            }
            this._ghostTextWidgets.resize(0);
            this._ghostTextWidgetSources.resize(0);
            for (k in 0...items.length) {
                this._ghostTextWidgets.push(widgets[k]);
                this._ghostTextWidgetSources.push(items[k]);
            }
        }));
        this._register(Lifecycle.toDisposable(() -> {
            for (w in this._ghostTextWidgets) {
                w.dispose();
            }
            this._ghostTextWidgets.resize(0);
            this._ghostTextWidgetSources.resize(0);
        }));

        this._register(new InlineCompletionContextKeys(this.editor.contextKeyService, this.model));

        this._register(ObservableCodeEditor.reactToChange(this._editorObs.onDidType, (_value, _changes) -> {
            if (this._enabled.get()) {
                final m = this.model.get();
                if (m != null) {
                    m.trigger();
                }
            }
        }));

        // These commands don't trigger onDidType.
        final commands = [
            CoreEditingCommands.Tab.id,
            CoreEditingCommands.DeleteLeft.id,
            CoreEditingCommands.DeleteRight.id,
            CommandIds.inlineSuggestCommitId,
            'acceptSelectedSuggestion',
        ];
        this._register(context.commandService.onDidExecuteCommand(e -> {
            if (commands.indexOf(e.commandId) != -1 && editor.hasTextFocus() && this._enabled.get()) {
                this._editorObs.forceUpdate(tx -> {
                    /** @description onDidExecuteCommand */
                    final m = this.model.get();
                    if (m != null) {
                        m.trigger(tx);
                    }
                });
            }
        }));

        this._register(ObservableCodeEditor.reactToChange(this._editorObs.selections, (_value, changes) -> {
            for (change in changes) {
                final e:ICursorSelectionChangedEvent = change;
                if (e.reason == CursorChangeReason.Explicit || e.source == 'api') {
                    final m = this.model.get();
                    if (m != null) {
                        m.stop();
                    }
                    break;
                }
            }
        }));

        this._register(this.editor.onDidBlurEditorWidget(() -> {
            // This is a hidden setting very useful for debugging
            if (editor.getOption(EditorOption.inlineSuggest).keepOnBlur) {
                return;
            }

            Observable.transaction(tx -> {
                /** @description InlineCompletionsController.onDidBlurEditorWidget */
                final m = this.model.get();
                if (m != null) {
                    m.stop(tx);
                }
            });
        }));

        this._register(Observable.autorun(reader -> {
            /** @description InlineCompletionsController.forceRenderingAbove */
            final m = this.model.read(reader);
            final state = m != null ? m.state.read(reader) : null;
            if (state != null && state.suggestItem != null) {
                if (state.primaryGhostText.lineCount >= 2) {
                    this._suggestWidgetAdaptor.forceRenderingAbove();
                }
            }
            else {
                this._suggestWidgetAdaptor.stopForceRenderingAbove();
            }
        }));
        this._register(Lifecycle.toDisposable(() -> {
            this._suggestWidgetAdaptor.stopForceRenderingAbove();
        }));
    }

    public function saveViewState():Any {
        return null;
    }

    public function restoreViewState(state:Any):Void {}

    public function shouldShowHoverAt(range:Range):Bool {
        final m = this.model.get();
        final ghostText = m != null ? m.primaryGhostText.get() : null;
        if (ghostText != null) {
            for (p in ghostText.parts) {
                if (range.containsPosition(new Position(ghostText.lineNumber, p.column))) {
                    return true;
                }
            }
        }
        return false;
    }

    public function shouldShowHoverAtViewZone(viewZoneId:String):Bool {
        return this._ghostTextWidgets.length > 0 && this._ghostTextWidgets[0].ownsViewZone(viewZoneId);
    }

    /**
     * The views of the ghost texts (one per cursor with a ghost text).
     */
    public function getGhostTextViews():Array<GhostTextView> {
        return this._ghostTextWidgets;
    }

    public function hide():Void {
        Observable.transaction(tx -> {
            final m = this.model.get();
            if (m != null) {
                m.stop(tx);
            }
        });
    }

    static function convertItemsToStableObservables<T>(items:IObservable<Array<T>>, store:DisposableStore):IObservable<Array<IObservable<Null<T>>>> {
        final result:ISettableObservable<Array<IObservable<Null<T>>>> = Observable.observableValue('result', ([] : Array<IObservable<Null<T>>>));
        final innerObservables:Array<ISettableObservable<Null<T>>> = [];

        store.add(Observable.autorun(reader -> {
            final itemsValue = items.read(reader);

            Observable.transaction(tx -> {
                if (itemsValue.length != innerObservables.length) {
                    if (innerObservables.length > itemsValue.length) {
                        innerObservables.resize(itemsValue.length);
                    }
                    for (i in innerObservables.length...itemsValue.length) {
                        innerObservables.push(Observable.observableValue('item', (itemsValue[i] : Null<T>)));
                    }
                    result.set([for (o in innerObservables) (o : IObservable<Null<T>>)], tx);
                }
                for (i in 0...innerObservables.length) {
                    innerObservables[i].set(itemsValue[i], tx);
                }
            });
        }));

        return result;
    }

}
