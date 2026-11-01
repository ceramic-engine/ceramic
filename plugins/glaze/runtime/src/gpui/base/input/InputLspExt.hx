// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/lsp/mod.rs, lsp/completions.rs, lsp/overlay.rs,
// lsp/hover.rs, lsp/definitions.rs, lsp/code_actions.rs (`impl InputBaseState<EditorMode>`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base.input;

import gpui.App;
import gpui.Context;
import gpui.HighlightStyle;
import gpui.Hitbox;
import gpui.MouseDownEvent;
import gpui.MouseMoveEvent;
import gpui.Range;
import gpui.UnderlineStyle;
import gpui.Window;

import gpui.base.input.InputActions;

using gpui.base.input.RopeExt;

/**
 * The LSP methods of an editor state, as static extensions (see
 * `InputSearchExt`). They only exist for the code editor.
 *
 * The provider requests (completion, inline completion, hover, definitions,
 * code actions) are wave 11. The methods that only read or reset the editor's
 * LSP state are ported: with no provider configured (every Input and Textarea,
 * and an editor nothing configured) they are all an editor ever runs.
 */
@:access(gpui.base.input.InputBaseState)
class InputLspExt {

    static inline function extras(state:InputBaseState):EditorExtras {
        return cast state.extras;
    }

/// lsp/mod.rs

    /** Apply a list of LSP text edits to mutate the text. */
    public static function applyLspEdits(self:InputBaseState, textEdits:Array<LspTextEdit>, window:Window, cx:Context<InputBaseState>):Void {
        for (edit in textEdits) {
            final start = self.text.positionToOffset(edit.range.start);
            final end = self.text.positionToOffset(edit.range.end);

            final rangeUtf16 = self.rangeToUtf16(new Range(start, end));
            self.replaceTextInRangeSilent(rangeUtf16, edit.newText, window, cx);
        }
    }

/// lsp/completions.rs

    public static function handleCompletionTrigger(self:InputBaseState, range:Range, newText:String, window:Window, cx:Context<InputBaseState>):Void {
        if (self.completionInserting)
            return;

        final provider = extras(self).lsp.completionProvider;
        if (provider == null)
            return;

        // Always schedule inline completion (debounced).
        // It will check if menu is open before showing the suggestion.
        scheduleInlineCompletion(self, window, cx);

        final newOffset = self.cursor();
        // Measure the inserted text in the current document. The replaced range
        // uses pre-edit coordinates, which preceding multi-cursor edits can
        // shift. The active caret ends immediately after the normalized input,
        // including selection replacements and IME commits.
        final start = newOffset - gpui.util.Utf8.byteLength(newText);
        if (start < 0)
            return;

        if (!provider.isCompletionTrigger(start, newText, cx.app))
            return;

        // `trigger_start_offset` latches where the word a menu was opened for
        // begins, so later keystrokes refine the same query instead of starting
        // over at each character. It only describes this edit while the edit
        // continues that word: the document between the latch and the edit
        // must still read as a prefix of the last query. Deleting back into
        // the word keeps it; typing somewhere else, or into a document that
        // has since been replaced, starts a new query at this edit instead of
        // handing the provider text the user never typed as a prefix.
        final completion = extras(self).contextMenuContent.completion;
        var latched:Null<Int> = completion.triggerStartOffset;
        if (latched != null) {
            final l:Int = latched;
            if (!(l <= start
                && start <= l + gpui.util.Utf8.byteLength(completion.query)
                && self.text.isCharBoundary(l)
                && self.text.isCharBoundary(start)
                && StringTools.startsWith(completion.query, self.text.slice(l, start).toString())))
                latched = null;
        }
        final startOffset:Int = latched != null ? latched : start;
        if (newOffset < startOffset)
            return;

        final text = self.textForRange(self.rangeToUtf16(new Range(startOffset, newOffset)), new gpui.util.Ref(null), window, cx);
        final query = text != null ? trimRust(text) : '';
        requestCompletions(self, provider, startOffset, query, new CompletionContext(2 /* CompletionTriggerKind::TRIGGER_CHARACTER */, query), window, cx);
    }

    /** Rust `str::trim` (Unicode White_Space at both ends). */
    static function trimRust(s:String):String {
        final chars = [for (c in new haxe.iterators.StringIteratorUnicode(s)) c];
        var start = 0;
        var end = chars.length;
        while (start < end && gpui.util.Utf8.isWhitespace(chars[start]))
            start++;
        while (end > start && gpui.util.Utf8.isWhitespace(chars[end - 1]))
            end--;
        final buf = new StringBuf();
        for (i in start...end)
            buf.addChar(chars[i]);
        return buf.toString();
    }

    /** Rust `char::is_alphanumeric` (letters and numbers, Unicode). */
    static function isAlphanumeric(c:Int):Bool {
        if (c < 128)
            return gpui.util.Utf8.isAsciiAlphanumeric(c);
        return unicode_segmentation.Tables.isAlphanumeric(c);
    }

    public static function onActionShowCompletions(self:InputBaseState, action:ShowCompletions, window:Window, cx:Context<InputBaseState>):Void {
        showCompletions(self, window, cx);
    }

    /**
     * Request completions at the caret and focus the editor, without editing text.
     */
    public static function showCompletions(self:InputBaseState, window:Window, cx:Context<InputBaseState>):Void {
        if (self.disabled || self.readonly || self.completionInserting || self.imeMarkedRange != null || extras(self).contextMenuContent.completion.open)
            return;
        final provider = extras(self).lsp.completionProvider;
        if (provider == null)
            return;

        final offset = self.cursor();
        var wordLen = 0;
        final chars = self.text.charsAt(offset).reversed();
        while (true) {
            final ch = chars.next();
            if (ch < 0 || !(isAlphanumeric(ch) || ch == '_'.code))
                break;
            wordLen += gpui.util.Utf8.codePointLength(ch);
        }
        final startOffset = offset - wordLen;
        final query = self.text.slice(startOffset, offset).toString();

        hideContextMenu(self, cx);
        clearInlineCompletion(self, cx);
        self.focus(window, cx);

        requestCompletions(self, provider, startOffset, query, new CompletionContext(1 /* CompletionTriggerKind::INVOKED */, null), window, cx);
    }

    /** Record the word a menu is for and ask `provider` about the caret. */
    static function requestCompletions(self:InputBaseState, provider:CompletionProvider, startOffset:Int, query:String, completionContext:CompletionContext,
            window:Window, cx:Context<InputBaseState>):Void {
        final newOffset = self.cursor();
        final revision = self.documentRevision;
        final extras = extras(self);
        extras.contextMenuTask.cancel();
        extras.contextMenuTask = gpui.Task.done();
        extras.contextMenuContent.codeAction.open = false;
        extras.contextMenuContent.completion.triggerStartOffset = startOffset;
        extras.contextMenuContent.completion.query = query;

        final providerResponses = provider.completions(self.text, newOffset, completionContext, window, cx.app);
        extras.contextMenuTask = cx.spawn((editor, acx) -> providerResponses.catchError(_ -> null).then((response:Null<Array<CompletionItem>>) -> {
            final completions:Array<CompletionItem> = [];
            if (response != null) {
                for (item in response)
                    completions.push(item);
            }

            if (window.isDestroyed())
                return;
            editor.tryUpdate(acx, (editor, cx) -> {
                if (!editor.focusHandle.isFocused(window)
                    || editor.documentRevision != revision
                    || editor.cursor() != newOffset
                    || editor.imeMarkedRange != null
                    || editor.disabled
                    || editor.readonly)
                    return;

                final completion = InputLspExt.extras(editor).contextMenuContent.completion;
                completion.open = completions.length > 0;
                completion.items = completions;
                completion.bump();
                cx.notify();
            });
        }));
    }

    public static function hideContextMenu(self:InputBaseState, cx:Context<InputBaseState>):Void {
        final extras = extras(self);
        extras.contextMenuContent.completion.open = false;
        extras.contextMenuContent.codeAction.open = false;
        extras.contextMenuTask.cancel();
        extras.contextMenuTask = gpui.Task.done();
        cx.notify();
    }

    public static function isContextMenuOpen(self:InputBaseState, cx:App):Bool {
        final extras = extras(self);
        return extras.contextMenuContent.completion.open || extras.contextMenuContent.codeAction.open;
    }

    public static function handleActionForContextMenu(self:InputBaseState, action:gpui.Action, window:Window, cx:Context<InputBaseState>):Bool {
        final closesOverlay = Enter.isPrimary(action) || action.partialEq(new Escape());
        final extras = extras(self);
        final kind:Null<InputOverlayKind> = if (extras.contextMenuContent.completion.open) {
            InputOverlayKind.Completion;
        } else if (extras.contextMenuContent.codeAction.open) {
            InputOverlayKind.CodeAction;
        } else {
            null;
        }
        final handler = self.overlayActionHandler;
        if (kind == null || handler == null)
            return false;
        final handled = handler(kind, action, window, cx);
        if (handled && closesOverlay)
            hideContextMenu(self, cx);
        return handled;
    }

    public static function setOverlayActionHandler(self:InputBaseState, handler:InputBaseState.OverlayActionHandler):Void {
        self.overlayActionHandler = handler;
    }

    public static function hasOverlayActionHandler(self:InputBaseState):Bool {
        return self.overlayActionHandler != null;
    }

    /** Schedule an inline completion request after debouncing. */
    public static function scheduleInlineCompletion(self:InputBaseState, window:Window, cx:Context<InputBaseState>):Void {
        // Clear any existing inline completion on text change
        clearInlineCompletion(self, cx);

        final provider = extras(self).lsp.completionProvider;
        if (provider == null)
            return;

        final offset = self.cursor();
        final text = self.text.clone();
        final debounce = provider.inlineCompletionDebounce();

        extras(self).inlineCompletion.task = cx.spawn((editor, acx) -> {
            // Debounce: wait before fetching to avoid unnecessary requests while typing
            return acx.backgroundExecutor().timer(debounce / 1000.).andThen(_ -> {
                // Now fetch the inline completion after the debounce period
                if (window.isDestroyed())
                    return null;
                final task = editor.update(acx, (editor, cx) -> {
                    // Check if cursor has moved during debounce
                    if (editor.cursor() != offset)
                        return null;

                    // Don't fetch if completion menu is open
                    if (isContextMenuOpen(editor, cx.app))
                        return null;

                    final trigger = new InlineCompletionContext(1 /* InlineCompletionTriggerKind::Automatic */);
                    return provider.inlineCompletion(text, offset, trigger, window, cx.app);
                });

                if (task == null)
                    return gpui.Task.ready(([] : Array<InlineCompletionItem>));

                return task.map(response -> {
                    if (window.isDestroyed())
                        return response;
                    editor.update(acx, (editor, cx) -> {
                        // Only apply if cursor still hasn't moved
                        if (editor.cursor() != offset)
                            return;

                        // Don't show if completion menu opened while we were fetching
                        if (isContextMenuOpen(editor, cx.app))
                            return;

                        if (response != null && response.length > 0) {
                            InputLspExt.extras(editor).inlineCompletion.item = response[0];
                            cx.notify();
                        }
                    });
                    return response;
                });
            });
        });
    }

    /** Check if an inline completion suggestion is currently displayed. */
    public static inline function hasInlineCompletion(self:InputBaseState):Bool {
        return extras(self).inlineCompletion.item != null;
    }

    /** Clear the inline completion suggestion. */
    public static function clearInlineCompletion(self:InputBaseState, cx:Context<InputBaseState>):Void {
        extras(self).inlineCompletion = new InlineCompletion();
        cx.notify();
    }

    /**
     * Accept the inline completion, inserting it at the cursor position.
     * Returns true if a completion was accepted, false if there was none.
     */
    public static function acceptInlineCompletion(self:InputBaseState, window:Window, cx:Context<InputBaseState>):Bool {
        final completionItem = extras(self).inlineCompletion.item;
        if (completionItem == null)
            return false;
        extras(self).inlineCompletion.item = null;

        final cursor = self.cursor();
        final rangeUtf16 = self.rangeToUtf16(new Range(cursor, cursor));
        self.replaceTextInRangeSilent(rangeUtf16, completionItem.insertText, window, cx);
        return true;
    }

/// lsp/overlay.rs

    public static function presentCompletionItems(self:InputBaseState, triggerStartOffset:Int, query:String, items:Array<CompletionItem>, cx:Context<InputBaseState>):Void {
        final completion = extras(self).contextMenuContent.completion;
        completion.triggerStartOffset = triggerStartOffset;
        completion.query = query;
        completion.items = items;
        completion.open = completion.items.length > 0;
        completion.bump();
        cx.notify();
    }

    public static function presentCodeActions(self:InputBaseState, items:Array<CodeActionItem>, cx:Context<InputBaseState>):Void {
        final codeAction = extras(self).contextMenuContent.codeAction;
        codeAction.items = items;
        codeAction.open = codeAction.items.length > 0;
        codeAction.bump();
        cx.notify();
    }

    public static function presentHover(self:InputBaseState, symbolRange:Range, hover:LspHover, cx:Context<InputBaseState>):Void {
        extras(self).hoverPopover = new HoverPopoverState(symbolRange, hover);
        cx.notify();
    }

    public static function presentDiagnostic(self:InputBaseState, diagnostic:DiagnosticEntry, cx:Context<InputBaseState>):Void {
        self.diagnosticPopover = diagnostic;
        cx.notify();
    }

    public static function clearDiagnosticPopover(self:InputBaseState, cx:Context<InputBaseState>):Void {
        if (self.diagnosticPopover != null) {
            self.diagnosticPopover = null;
            cx.notify();
        }
    }

    public static function routeOverlayAction(self:InputBaseState, action:gpui.Action, window:Window, cx:Context<InputBaseState>):Bool {
        return handleActionForContextMenu(self, action, window, cx);
    }

    public static function dismissCompletionOverlay(self:InputBaseState, cx:Context<InputBaseState>):Void {
        final completion = extras(self).contextMenuContent.completion;
        if (completion.open) {
            completion.open = false;
            cx.notify();
        }
    }

    public static function dismissCodeActionOverlay(self:InputBaseState, cx:Context<InputBaseState>):Void {
        final codeAction = extras(self).contextMenuContent.codeAction;
        if (codeAction.open) {
            codeAction.open = false;
            cx.notify();
        }
    }

    public static function insertCompletion(self:InputBaseState, item:CompletionItem, fallbackRange:Range, window:Window, cx:Context<InputBaseState>):Void {
        var range = fallbackRange;
        var newText = item.label;
        if (item.textEdit != null) {
            switch item.textEdit {
                case Edit(edit):
                    newText = edit.newText;
                    range = new Range(self.text.positionToOffset(edit.range.start), self.text.positionToOffset(edit.range.end));
                case InsertAndReplace(text, _, replace):
                    newText = text;
                    range = new Range(self.text.positionToOffset(replace.start), self.text.positionToOffset(replace.end));
            }
        }
        else if (item.insertText != null) {
            newText = item.insertText;
            range = new Range(range.end, range.end);
        }
        self.completionInserting = true;
        final rangeUtf16 = self.rangeToUtf16(range);
        self.replaceTextInRangeSilent(rangeUtf16, newText, window, cx);
        self.completionInserting = false;
        self.focus(window, cx);
    }

    public static inline function completionMenuState(self:InputBaseState):CompletionMenuState {
        return extras(self).contextMenuContent.completion;
    }

    public static inline function codeActionMenuState(self:InputBaseState):CodeActionMenuState {
        return extras(self).contextMenuContent.codeAction;
    }

    public static inline function hoverPopover(self:InputBaseState):Null<HoverPopoverState> {
        return extras(self).hoverPopover;
    }

    public static function dismissLspOverlays(self:InputBaseState, cx:Context<InputBaseState>):Void {
        hideContextMenu(self, cx);
        clearHoverState(self, cx);
    }

/// lsp/hover.rs

    /** Handle hover trigger LSP request. */
    public static function handleHoverPopover(self:InputBaseState, offset:Int, window:Window, cx:Context<InputBaseState>):Void {
        if (self.selecting)
            return;

        final provider = extras(self).lsp.hoverProvider;
        if (provider == null)
            return;

        final hoverPopover = extras(self).hoverPopover;
        if (hoverPopover != null && hoverPopover.symbolRange.start <= offset && offset < hoverPopover.symbolRange.end)
            return;

        final text = self.text.clone();
        final wordRange = self.text.wordRange(offset);
        var symbolRange:Range = wordRange != null ? wordRange : new Range(offset, offset);
        final editor = cx.entity();
        final shouldDelay = extras(self).hoverPopover == null;
        // Ask the provider only after the delay: every mouse move replaces this
        // task, so positions the pointer merely passes over never reach it.
        extras(self).lsp._hoverTask.cancel();
        extras(self).lsp._hoverTask = cx.spawn((this_, acx) -> {
            final delay:gpui.Task<gpui.Unit> = shouldDelay ? acx.backgroundExecutor().timer(0.15) : gpui.Task.done();
            return delay.andThen(_ -> {
                if (window.isDestroyed())
                    return null;
                final task = this_.update(acx, (_, cx) -> provider.hover(text, offset, window, cx.app));
                return task.then(result -> {
                    {
                        editor.update(acx, (editor, cx) -> {
                            if (result != null) {
                                final range = result.range;
                                if (range != null) {
                                    final start = editor.text.positionToOffset(range.start);
                                    final end = editor.text.positionToOffset(range.end);
                                    symbolRange = new Range(start, end);
                                }
                                InputLspExt.extras(editor).hoverPopover = new HoverPopoverState(symbolRange, result);
                            }
                            else {
                                InputLspExt.extras(editor).hoverPopover = null;
                            }
                            cx.notify();
                        });
                    }
                });
            });
        });
    }

    public static function handleMouseMove(self:InputBaseState, offset:Int, event:MouseMoveEvent, window:Window, cx:Context<InputBaseState>):Void {
        if (event.modifiers.alt) {
            clearHoverState(self, cx);
            return;
        }
        if (event.modifiers.secondary()) {
            handleHoverDefinition(self, offset, window, cx);
        }
        else {
            // Repaint only when the definition underline goes away; the hover
            // and definition results notify when they arrive.
            if (!extras(self).hoverDefinition.isEmpty()) {
                extras(self).hoverDefinition.clear();
                cx.notify();
            }
            handleHoverPopover(self, offset, window, cx);
        }
    }

    public static function clearHoverState(self:InputBaseState, cx:Context<InputBaseState>):Void {
        final extras = extras(self);
        final changed = !extras.hoverDefinition.isEmpty() || extras.hoverPopover != null;
        extras.hoverDefinition.clear();
        extras.hoverPopover = null;
        extras.lsp._hoverTask.cancel();
        extras.lsp._hoverTask = gpui.Task.done();
        if (changed)
            cx.notify();
    }

/// lsp/definitions.rs

    public static function handleHoverDefinition(self:InputBaseState, offset:Int, window:Window, cx:Context<InputBaseState>):Void {
        final provider = extras(self).lsp.definitionProvider;
        if (provider == null)
            return;

        if (extras(self).hoverDefinition.isSame(offset))
            return;

        // Currently not implemented.
        final task = provider.definitions(self.text, offset, window, cx.app);
        final wordRange = self.text.wordRange(offset);
        var symbolRange:Range = wordRange != null ? wordRange : new Range(offset, offset);
        final editor = cx.entity();
        extras(self).lsp._hoverTask.cancel();
        extras(self).lsp._hoverTask = cx.spawn((_, acx) -> task.then(locations -> {
            editor.update(acx, (editor, cx) -> {
                final hoverDefinition = InputLspExt.extras(editor).hoverDefinition;
                if (locations.length == 0) {
                    hoverDefinition.clear();
                }
                else {
                    final location = locations[0];
                    final range = location.originSelectionRange;
                    if (range != null) {
                        final start = editor.text.positionToOffset(range.start);
                        final end = editor.text.positionToOffset(range.end);
                        symbolRange = new Range(start, end);
                    }

                    hoverDefinition.update(symbolRange, locations.copy());
                }
                cx.notify();
            });
        }));
    }

    public static function onActionGoToDefinition(self:InputBaseState, action:GoToDefinition, window:Window, cx:Context<InputBaseState>):Void {
        final offset = self.cursor();
        // A keyboard action must also work before the symbol has been hovered.
        final provider = extras(self).lsp.definitionProvider;
        if (provider == null)
            return;
        final text = self.text.clone();
        final response = provider.definitions(text, offset, window, cx.app);
        final blurSubscription = cx.onBlur(self.focusHandle, window, (editor, _, _) -> {
            final lsp = InputLspExt.extras(editor).lsp;
            lsp._definitionTask.cancel();
            lsp._definitionTask = gpui.Task.done();
        });
        extras(self).lsp._definitionTask.cancel();
        final task = cx.spawn((editor, acx) -> response.then(locations -> {
            if (window.isDestroyed())
                return;
            editor.update(acx, (editor, cx) -> {
                if (editor.cursor() != offset
                    || !editor.text.equals(text)
                    || !editor.focusHandle.isFocused(window))
                    return;
                if (locations.length > 0)
                    goToDefinition(editor, locations[0], window, cx);
            });
        }));
        // The blur subscription lives as long as the task (Rust moves it into the task).
        task.onComplete(() -> blurSubscription.dispose());
        extras(self).lsp._definitionTask = task;
    }

    /** Return true if handled. */
    public static function handleClickHoverDefinition(self:InputBaseState, event:MouseDownEvent, offset:Int, window:Window, cx:Context<InputBaseState>):Bool {
        if (!event.modifiers.secondary() || event.modifiers.alt)
            return false;
        final hoverDefinition = extras(self).hoverDefinition;
        if (hoverDefinition.isEmpty())
            return false;
        if (!hoverDefinition.isSame(offset))
            return false;
        if (hoverDefinition.locations.length == 0)
            return false;
        goToDefinition(self, hoverDefinition.locations[0], window, cx);
        return true;
    }

    public static function goToDefinition(self:InputBaseState, location:LspLocationLink, window:Window, cx:Context<InputBaseState>):Void {
        final scheme = uriScheme(location.targetUri);
        final external = scheme == "https" || scheme == "http";

        // Give the host a chance to show the document first (window/showDocument),
        // e.g. to open virtual/external documents (stdlib docs) in an app window.
        final handler = extras(self).lsp.showDocument;
        if (handler != null) {
            final params = new LspShowDocumentParams(location.targetUri, external, true, location.targetSelectionRange);
            if (handler(params, window, cx.app))
                return;
        }

        if (external) {
            cx.app.openUrl(location.targetUri);
        }
        else {
            // Move to the location.
            final targetRange = location.targetSelectionRange;
            final start = self.text.positionToOffset(targetRange.start);
            final end = self.text.positionToOffset(targetRange.end);

            InputMovement.moveTo(self, start, null, cx);
            self.selectTo(end, cx);
        }
    }

    /** The scheme of a URI (`fluent_uri::Uri::scheme`), or null when it has none. */
    static function uriScheme(uri:String):Null<String> {
        final colon = uri.indexOf(':');
        if (colon <= 0)
            return null;
        for (i in 0...colon) {
            final c = StringTools.fastCodeAt(uri, i);
            final alpha = (c >= 'a'.code && c <= 'z'.code) || (c >= 'A'.code && c <= 'Z'.code);
            if (i == 0 ? !alpha : !(alpha || (c >= '0'.code && c <= '9'.code) || c == '+'.code || c == '-'.code || c == '.'.code))
                return null;
        }
        return uri.substr(0, colon);
    }

    /** The range highlighted while Cmd-hovering a symbol, with its style. */
    public static function hoverDefinitionStyle(self:InputBaseState):Null<StyledRange> {
        final hoverDefinition = extras(self).hoverDefinition;
        if (hoverDefinition.isEmpty())
            return null;

        final resolved = self.editorStyle.highlightStyles.style("link_text");
        if (resolved == null)
            return null;

        // Rust receives the style by value: copy it before changing it
        final highlightStyle = new HighlightStyle(resolved.color, resolved.fontWeight, resolved.fontStyle, resolved.backgroundColor, new UnderlineStyle(1.), resolved.strikethrough, resolved.fadeOut);

        return new StyledRange(hoverDefinition.symbolRange, highlightStyle);
    }

    /** The hitbox that makes a Cmd-hovered symbol clickable. */
    public static function hoverDefinitionHitbox(self:InputBaseState, window:Window):Null<Hitbox> {
        final hoverDefinition = extras(self).hoverDefinition;
        if (hoverDefinition.isEmpty())
            return null;

        final bounds = self.rangeToBounds(hoverDefinition.symbolRange);
        if (bounds == null)
            return null;

        return window.insertHitbox(bounds, gpui.HitboxBehavior.Normal);
    }

/// lsp/code_actions.rs

    public static function onActionToggleCodeActions(self:InputBaseState, action:ToggleCodeActions, window:Window, cx:Context<InputBaseState>):Void {
        handleCodeActionTrigger(self, window, cx);
    }

    /** Show code actions for the cursor. */
    public static function handleCodeActionTrigger(self:InputBaseState, window:Window, cx:Context<InputBaseState>):Void {
        final providers = extras(self).lsp.codeActionProviders.copy();
        final range = self.selectedRange();

        final state = cx.entity();
        extras(self).contextMenuTask.cancel();
        extras(self).contextMenuTask = cx.spawn((editor, acx) -> {
            final providerResponses:Array<{id:String, task:gpui.Task<Array<LspCodeAction>>}> = [];
            if (!window.isDestroyed()) {
                acx.update(cx -> {
                    for (provider in providers) {
                        final task = provider.codeActions(state, range, window, cx);
                        providerResponses.push({id: provider.id(), task: task});
                    }
                });
            }

            final codeActions:Array<CodeActionItem> = [];
            // Await each provider in order, ignoring the failed ones.
            var chain:gpui.Task<gpui.Unit> = gpui.Task.done();
            for (response in providerResponses) {
                chain = chain.andThen(_ -> response.task.catchError(_ -> null).then(actions -> {
                    if (actions != null) {
                        for (action in actions)
                            codeActions.push(new CodeActionItem(response.id, action));
                    }
                }));
            }

            return chain.then(_ -> {
                if (codeActions.length == 0) {
                    editor.update(acx, (editor, cx) -> {
                        final codeAction = InputLspExt.extras(editor).contextMenuContent.codeAction;
                        codeAction.open = false;
                        codeAction.items = [];
                        codeAction.bump();
                        cx.notify();
                    });
                    return;
                }
                if (window.isDestroyed())
                    return;
                editor.tryUpdate(acx, (editor, cx) -> {
                    if (!editor.focusHandle.isFocused(window))
                        return;

                    final codeAction = InputLspExt.extras(editor).contextMenuContent.codeAction;
                    codeAction.items = codeActions;
                    codeAction.open = codeAction.items.length > 0;
                    // The overlay rebuilds on a new revision, so a refresh
                    // while the menu is already open must bump it too.
                    codeAction.bump();

                    cx.notify();
                });
            });
        });
    }

    public static function performCodeAction(self:InputBaseState, item:CodeActionItem, window:Window, cx:Context<InputBaseState>):Void {
        final providers = extras(self).lsp.codeActionProviders.copy();
        var provider:Null<CodeActionProvider> = null;
        for (p in providers) {
            if (p.id() == item.providerId) {
                provider = p;
                break;
            }
        }
        if (provider == null)
            return;

        final state = cx.entity();
        final task = provider.performCodeAction(state, item.action, true, window, cx.app);

        cx.spawn((_, _) -> task.catchError(_ -> gpui.Unit.unit)).detach();
    }

}
