// Ported from vscode src/vs/editor/contrib/inlineCompletions/browser/model/suggestWidgetAdaptor.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.inlineCompletions.view.model;

import cityscape.base.common.Event;
import cityscape.base.common.Lifecycle;
import cityscape.common.Languages;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.core.TextEdit.SingleTextEdit;
import cityscape.common.languages.CompletionItemKind;
import cityscape.contrib.inlineCompletions.view.model.SingleTextEdit.SingleTextEditUtils;
import cityscape.contrib.snippet.view.SnippetParser;
import cityscape.contrib.snippet.view.SnippetSession;
import cityscape.contrib.suggest.view.Suggest.CompletionItem;
import cityscape.contrib.suggest.view.Suggest.ISuggestItemPreselector;
import cityscape.contrib.suggest.view.SuggestController;
import cityscape.view.EditorBrowser.ICodeEditor;

/**
 * Follows the focused item of the suggest widget, for the ghost text of its
 * preview (Monaco's `SuggestWidgetAdaptor`).
 */
class SuggestWidgetAdaptor extends Disposable {

    var isSuggestWidgetVisible:Bool = false;
    var isShiftKeyPressed:Bool = false;
    var _isActive:Bool = false;
    var _currentSuggestItemInfo:Null<SuggestItemInfo> = null;

    public var selectedItem(get, never):Null<SuggestItemInfo>;
    function get_selectedItem():Null<SuggestItemInfo> {
        return this._currentSuggestItemInfo;
    }

    final _onDidSelectedItemChange = new VoidEmitter();
    public final onDidSelectedItemChange:VoidEvent;

    final editor:ICodeEditor;
    final suggestControllerPreselector:() -> Null<SingleTextEdit>;
    final onWillAccept:(item:SuggestItemInfo) -> Void;

    public function new(editor:ICodeEditor, suggestControllerPreselector:() -> Null<SingleTextEdit>, onWillAccept:(item:SuggestItemInfo) -> Void) {
        super();
        this.editor = editor;
        this.suggestControllerPreselector = suggestControllerPreselector;
        this.onWillAccept = onWillAccept;
        this.onDidSelectedItemChange = _onDidSelectedItemChange.event;
        this._register(_onDidSelectedItemChange);

        // See the command acceptAlternativeSelectedSuggestion that is bound to shift+tab
        this._register(editor.onKeyDown(e -> {
            if (e.shiftKey && !this.isShiftKeyPressed) {
                this.isShiftKeyPressed = true;
                this.update(this._isActive);
            }
        }));
        this._register(editor.onKeyUp(e -> {
            if (e.shiftKey && this.isShiftKeyPressed) {
                this.isShiftKeyPressed = false;
                this.update(this._isActive);
            }
        }));

        final suggestController = SuggestController.get(this.editor);
        if (suggestController != null) {
            this._register(suggestController.registerSelector(new InlineCompletionPreselector(this, suggestController)));

            var isBoundToSuggestWidget = false;
            final bindToSuggestWidget = () -> {
                if (isBoundToSuggestWidget) {
                    return;
                }
                isBoundToSuggestWidget = true;

                this._register(suggestController.widget.onDidShow(_ -> {
                    this.isSuggestWidgetVisible = true;
                    this.update(true);
                }));
                this._register(suggestController.widget.onDidHide(_ -> {
                    this.isSuggestWidgetVisible = false;
                    this.update(false);
                }));
                this._register(suggestController.widget.onDidFocus(_ -> {
                    this.isSuggestWidgetVisible = true;
                    this.update(true);
                }));
            };

            // Event.once(suggestController.model.onDidTrigger)
            var once:Null<IDisposable> = null;
            var fired = false;
            once = suggestController.model.onDidTrigger(_ -> {
                if (fired) {
                    return;
                }
                fired = true;
                if (once != null) {
                    once.dispose();
                }
                bindToSuggestWidget();
            });
            if (fired) {
                once.dispose();
            }
            this._register(once);

            this._register(suggestController.onWillInsertSuggestItem(e -> {
                final position = this.editor.getPosition();
                final model = this.editor.getModel();
                if (position == null || model == null) {
                    return;
                }

                final suggestItemInfo = SuggestItemInfo.fromSuggestion(
                    suggestController,
                    model,
                    position,
                    e.item,
                    this.isShiftKeyPressed
                );

                this.onWillAccept(suggestItemInfo);
            }));
        }
        this.update(this._isActive);
    }

    @:allow(cityscape.contrib.inlineCompletions.view.model)
    function preselect(suggestController:SuggestController, pos:IPosition, suggestItems:Array<CompletionItem>):Int {
        final textModel = this.editor.getModel();
        if (textModel == null) {
            // Should not happen
            return -1;
        }

        final i = this.suggestControllerPreselector();
        final itemToPreselect = i != null ? SingleTextEditUtils.singleTextRemoveCommonPrefix(i, textModel) : null;
        if (itemToPreselect == null) {
            return -1;
        }
        final position = Position.lift(pos);

        // findFirstMax(candidates, compareBy(s => s.prefixLength, numberComparator))
        var resultIndex = -1;
        var resultPrefixLength = -1;
        for (index in 0...suggestItems.length) {
            final suggestItem = suggestItems[index];
            final suggestItemInfo = SuggestItemInfo.fromSuggestion(suggestController, textModel, position, suggestItem, this.isShiftKeyPressed);
            final suggestItemTextEdit = SingleTextEditUtils.singleTextRemoveCommonPrefix(suggestItemInfo.toSingleTextEdit(), textModel);
            final valid = SingleTextEditUtils.singleTextEditAugments(itemToPreselect, suggestItemTextEdit);
            final prefixLength = suggestItemTextEdit.text.length;
            if (valid && prefixLength > 0 && prefixLength > resultPrefixLength) {
                resultIndex = index;
                resultPrefixLength = prefixLength;
            }
        }
        return resultIndex;
    }

    function update(newActive:Bool):Void {
        final newInlineCompletion = this.getSuggestItemInfo();

        if (this._isActive != newActive || !suggestItemInfoEquals(this._currentSuggestItemInfo, newInlineCompletion)) {
            this._isActive = newActive;
            this._currentSuggestItemInfo = newInlineCompletion;

            this._onDidSelectedItemChange.fire();
        }
    }

    function getSuggestItemInfo():Null<SuggestItemInfo> {
        final suggestController = SuggestController.get(this.editor);
        if (suggestController == null || !this.isSuggestWidgetVisible) {
            return null;
        }

        final focusedItem = suggestController.widget.getFocusedItem();
        final position = this.editor.getPosition();
        final model = this.editor.getModel();

        if (focusedItem == null || position == null || model == null) {
            return null;
        }

        return SuggestItemInfo.fromSuggestion(
            suggestController,
            model,
            position,
            focusedItem.item,
            this.isShiftKeyPressed
        );
    }

    public function stopForceRenderingAbove():Void {
        final suggestController = SuggestController.get(this.editor);
        if (suggestController != null) {
            suggestController.widget.stopForceRenderingAbove();
        }
    }

    public function forceRenderingAbove():Void {
        final suggestController = SuggestController.get(this.editor);
        if (suggestController != null) {
            suggestController.widget.forceRenderingAbove();
        }
    }

    static function suggestItemInfoEquals(a:Null<SuggestItemInfo>, b:Null<SuggestItemInfo>):Bool {
        if (a == b) {
            return true;
        }
        if (a == null || b == null) {
            return false;
        }
        return a.equals(b);
    }

}

/**
 * The selector the adaptor registers in the suggest controller (Monaco's
 * object literal with `priority: 100`).
 */
private class InlineCompletionPreselector implements ISuggestItemPreselector {

    public var priority(default, null):Int = 100;

    final adaptor:SuggestWidgetAdaptor;
    final suggestController:SuggestController;

    public function new(adaptor:SuggestWidgetAdaptor, suggestController:SuggestController) {
        this.adaptor = adaptor;
        this.suggestController = suggestController;
    }

    public function select(model:ITextModel, pos:IPosition, items:Array<CompletionItem>):Int {
        return adaptor.preselect(suggestController, pos, items);
    }

}

class SuggestItemInfo {

    public static function fromSuggestion(suggestController:SuggestController, model:ITextModel, position:Position, item:CompletionItem, toggleMode:Bool):SuggestItemInfo {
        var insertText = item.completion.insertText;
        var isSnippetText = false;
        final rules:Int = item.completion.insertTextRules != null ? item.completion.insertTextRules : 0;
        if ((rules & (CompletionItemInsertTextRule.InsertAsSnippet : Int)) != 0) {
            final snippet = new SnippetParser().parse(insertText);

            if (snippet.children.length < 100) {
                // Adjust whitespace is expensive.
                SnippetSession.adjustWhitespace(model, position, true, snippet);
            }

            insertText = snippet.toString();
            isSnippetText = true;
        }

        final info = suggestController.getOverwriteInfo(item, toggleMode);

        return new SuggestItemInfo(
            Range.fromPositions(
                position.delta(0, -info.overwriteBefore),
                position.delta(0, Std.int(Math.max(info.overwriteAfter, 0)))
            ),
            insertText,
            item.completion.kind,
            isSnippetText
        );
    }

    public final range:Range;
    public final insertText:String;
    public final completionItemKind:CompletionItemKind;
    public final isSnippetText:Bool;

    function new(range:Range, insertText:String, completionItemKind:CompletionItemKind, isSnippetText:Bool) {
        this.range = range;
        this.insertText = insertText;
        this.completionItemKind = completionItemKind;
        this.isSnippetText = isSnippetText;
    }

    public function equals(other:SuggestItemInfo):Bool {
        return this.range.equalsRange(other.range)
            && this.insertText == other.insertText
            && this.completionItemKind == other.completionItemKind
            && this.isSnippetText == other.isSnippetText;
    }

    public function toSelectedSuggestionInfo():SelectedSuggestionInfo {
        return new SelectedSuggestionInfo(this.range, this.insertText, this.completionItemKind, this.isSnippetText);
    }

    public function toSingleTextEdit():SingleTextEdit {
        return new SingleTextEdit(this.range, this.insertText);
    }

}
