// Ported from vscode src/vs/editor/contrib/inlineCompletions/test/browser/utils.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package tests.contrib.inlineCompletions;

import cityscape.base.common.Async;
import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.base.common.Lifecycle;
import cityscape.base.common.Observable;
import cityscape.common.Languages;
import cityscape.common.Model.ITextModel;
import cityscape.common.core.Position;
import cityscape.contrib.inlineCompletions.view.model.InlineCompletionsModel;
import cityscape.view.CoreCommands;
import testing.TestCodeEditor;
import testing.CeramicTimeTravel;

typedef ProviderCall = {
    var position:String;
    var triggerKind:Int;
    var text:String;
}

class MockInlineCompletionsProvider implements InlineCompletionsProvider {

    var returnValue:Array<InlineCompletion> = [];
    var delayMs:Float = 0;

    var callHistory:Array<ProviderCall> = [];
    var calledTwiceIn50Ms:Bool = false;

    public var handleItemDidShow(default, null):Null<(completions:InlineCompletions, item:InlineCompletion, updatedInsertText:String) -> Void> = (_, _, _) -> {};
    public var handlePartialAccept(default, null):Null<(completions:InlineCompletions, item:InlineCompletion, acceptedCharacters:Int, info:PartialAcceptInfo) -> Void> = null;
    public var groupId(default, null):Null<InlineCompletionProviderGroupId> = null;
    public var yieldsToGroupIds(default, null):Null<Array<InlineCompletionProviderGroupId>> = null;

    public function new() {}

    public function setReturnValue(value:Null<InlineCompletion>, delayMs:Float = 0):Void {
        this.returnValue = value != null ? [value] : [];
        this.delayMs = delayMs;
    }

    public function setReturnValues(values:Array<InlineCompletion>, delayMs:Float = 0):Void {
        this.returnValue = values;
        this.delayMs = delayMs;
    }

    public function getAndClearCallHistory():Array<ProviderCall> {
        final history = this.callHistory.copy();
        this.callHistory = [];
        return history;
    }

    public function assertNotCalledTwiceWithin50ms():Void {
        if (this.calledTwiceIn50Ms) {
            throw 'provideInlineCompletions has been called at least twice within 50ms. This should not happen.';
        }
    }

    var lastTimeMs:Null<Float> = null;

    public function provideInlineCompletions(model:ITextModel, position:Position, context:InlineCompletionContext, token:CancellationToken, resolve:(completions:Null<InlineCompletions>) -> Void):Void {
        final currentTimeMs = CeramicTimeTravel.now();
        if (this.lastTimeMs != null && currentTimeMs - this.lastTimeMs < 50) {
            this.calledTwiceIn50Ms = true;
        }
        this.lastTimeMs = currentTimeMs;

        this.callHistory.push({
            position: position.toString(),
            triggerKind: context.triggerKind,
            text: model.getValue()
        });
        final result:Array<InlineCompletion> = this.returnValue.copy();

        if (this.delayMs > 0) {
            Async.setTimeout(() -> resolve({items: result}), this.delayMs);
        }
        else {
            resolve({items: result});
        }
    }

    public function freeInlineCompletions(completions:InlineCompletions):Void {}

}

class GhostTextContext extends Disposable {

    public final prettyViewStates:Array<Null<String>> = [];
    var _currentPrettyViewState:Null<String> = null;
    public var currentPrettyViewState(get, never):Null<String>;
    function get_currentPrettyViewState():Null<String> {
        return this._currentPrettyViewState;
    }

    final editor:TestCodeEditor;

    public function new(model:InlineCompletionsModel, editor:TestCodeEditor) {
        super();
        this.editor = editor;

        this._register(Observable.autorun(reader -> {
            /** @description update */
            final ghostText = model.primaryGhostText.read(reader);
            var view:Null<String>;
            if (ghostText != null) {
                view = ghostText.render(this.editor.getValue(), true);
            }
            else {
                view = this.editor.getValue();
            }

            if (this._currentPrettyViewState != view) {
                this.prettyViewStates.push(view);
            }
            this._currentPrettyViewState = view;
        }));
    }

    public function getAndClearViewStates():Array<Null<String>> {
        final arr = this.prettyViewStates.copy();
        this.prettyViewStates.resize(0);
        return arr;
    }

    public function keyboardType(text:String):Void {
        this.editor.trigger('keyboard', 'type', {text: text});
    }

    public function cursorUp():Void {
        CoreNavigationCommands.CursorUp.runEditorCommand(null, this.editor, null);
    }

    public function cursorRight():Void {
        CoreNavigationCommands.CursorRight.runEditorCommand(null, this.editor, null);
    }

    public function cursorLeft():Void {
        CoreNavigationCommands.CursorLeft.runEditorCommand(null, this.editor, null);
    }

    public function cursorDown():Void {
        CoreNavigationCommands.CursorDown.runEditorCommand(null, this.editor, null);
    }

    public function cursorLineEnd():Void {
        CoreNavigationCommands.CursorLineEnd.runEditorCommand(null, this.editor, null);
    }

    public function leftDelete():Void {
        CoreEditingCommands.DeleteLeft.runEditorCommand(null, this.editor, null);
    }

}
