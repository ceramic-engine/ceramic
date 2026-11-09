// Ported from vscode src/vs/editor/contrib/inlineCompletions/browser/controller/inlineCompletionContextKeys.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.inlineCompletions.view.controller;

import cityscape.base.common.Lifecycle;
import cityscape.base.common.Observable;
import cityscape.base.common.Strings;
import cityscape.base.common.observableInternal.Base;
import cityscape.common.core.CursorColumns;
import cityscape.contrib.inlineCompletions.view.model.InlineCompletionsModel;
import cityscape.platform.contextkey.common.ContextKey;

class InlineCompletionContextKeys extends Disposable {

    public static final inlineSuggestionVisible = new RawContextKey<Bool>('inlineSuggestionVisible', false, 'Whether an inline suggestion is visible');
    public static final inlineSuggestionHasIndentation = new RawContextKey<Bool>('inlineSuggestionHasIndentation', false, 'Whether the inline suggestion starts with whitespace');
    public static final inlineSuggestionHasIndentationLessThanTabSize = new RawContextKey<Bool>('inlineSuggestionHasIndentationLessThanTabSize', true, 'Whether the inline suggestion starts with whitespace that is less than what would be inserted by tab');
    public static final suppressSuggestions = new RawContextKey<Null<Bool>>('inlineSuggestionSuppressSuggestions', null, 'Whether suggestions should be suppressed for the current suggestion');

    public final inlineCompletionVisible:IContextKey<Bool>;
    public final inlineCompletionSuggestsIndentation:IContextKey<Bool>;
    public final inlineCompletionSuggestsIndentationLessThanTabSize:IContextKey<Bool>;
    public final suppressSuggestionsKey:IContextKey<Null<Bool>>;

    final contextKeyService:IContextKeyService;
    final model:IObservable<Null<InlineCompletionsModel>>;

    public function new(contextKeyService:IContextKeyService, model:IObservable<Null<InlineCompletionsModel>>) {
        super();
        this.contextKeyService = contextKeyService;
        this.model = model;
        this.inlineCompletionVisible = inlineSuggestionVisible.bindTo(contextKeyService);
        this.inlineCompletionSuggestsIndentation = inlineSuggestionHasIndentation.bindTo(contextKeyService);
        this.inlineCompletionSuggestsIndentationLessThanTabSize = inlineSuggestionHasIndentationLessThanTabSize.bindTo(contextKeyService);
        this.suppressSuggestionsKey = suppressSuggestions.bindTo(contextKeyService);

        this._register(Observable.autorun(reader -> {
            /** @description update context key: inlineCompletionVisible, suppressSuggestions */
            final model = this.model.read(reader);
            final state = model != null ? model.state.read(reader) : null;

            final isInlineCompletionVisible = state != null && state.inlineCompletion != null && state.primaryGhostText != null && !state.primaryGhostText.isEmpty();
            this.inlineCompletionVisible.set(isInlineCompletionVisible);

            if (state != null && state.primaryGhostText != null && state.inlineCompletion != null) {
                this.suppressSuggestionsKey.set(state.inlineCompletion.inlineCompletion.source.inlineCompletions.suppressSuggestions);
            }
        }));

        this._register(Observable.autorun(reader -> {
            /** @description update context key: inlineCompletionSuggestsIndentation, inlineCompletionSuggestsIndentationLessThanTabSize */
            final model = this.model.read(reader);

            var startsWithIndentation = false;
            var startsWithIndentationLessThanTabSize = true;

            final ghostText = model != null ? model.primaryGhostText.read(reader) : null;
            // Monaco tests `!!model?.selectedSuggestItem` (the observable, always set)
            if (model != null && model.selectedSuggestItem != null && ghostText != null && ghostText.parts.length > 0) {
                final part = ghostText.parts[0];
                final column = part.column;
                final lines = part.lines;

                final firstLine = lines[0];

                final indentationEndColumn = model.textModel.getLineIndentColumn(ghostText.lineNumber);
                final inIndentation = column <= indentationEndColumn;

                if (inIndentation) {
                    var firstNonWsIdx = Strings.firstNonWhitespaceIndex(firstLine);
                    if (firstNonWsIdx == -1) {
                        firstNonWsIdx = firstLine.length - 1;
                    }
                    startsWithIndentation = firstNonWsIdx > 0;

                    final tabSize = model.textModel.getOptions().tabSize;
                    final visibleColumnIndentation = CursorColumns.visibleColumnFromColumn(firstLine, firstNonWsIdx + 1, tabSize);
                    startsWithIndentationLessThanTabSize = visibleColumnIndentation < tabSize;
                }
            }

            this.inlineCompletionSuggestsIndentation.set(startsWithIndentation);
            this.inlineCompletionSuggestsIndentationLessThanTabSize.set(startsWithIndentationLessThanTabSize);
        }));
    }

}
