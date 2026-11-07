// Ported from gpui-kit 0.8.1: crates/story/src/stories/clipboard_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story.stories;

import glaze.AnyView;
import glaze.App;
import glaze.AppContext;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Model;
import glaze.Window;
import glaze.kit.base.input.InputState;
import glaze.kit.clipboard.Clipboard;
import glaze.kit.input.Input;
import glaze.kit.label.Label;
import story.Story;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Lib.*;

using glaze.kit.WindowExt;

class ClipboardStory extends Model implements Story {

    final focusHandle:FocusHandle;

    final urlState:Entity<InputState>;

    var masked:Bool;

    public static function title():String {
        return 'Clipboard';
    }

    public static function description():String {
        return 'Copy text or generated values to the clipboard.';
    }

    public static function newView(window:Window, cx:App):AnyView {
        return view(window, cx);
    }

    function new(window:Window, cx:AppContext) {
        super();
        urlState = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx).defaultValue('https://github.com'));
        focusHandle = cx.focusHandle();
        masked = false;
    }

    public static function view(window:Window, cx:App):Entity<ClipboardStory> {
        return cx.newEntity((cx:Context<ClipboardStory>) -> new ClipboardStory(window, cx));
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final view:Entity<ClipboardStory> = cast cx.entity();
        final state = urlState;
        return vFlex()
            .sizeFull()
            .justifyStart()
            .gap3()
            .child(section('Default')
                .description('Copies a value supplied by the application.')
                .w(px(480.))
                .child(hFlex()
                    .gap2()
                    .child(new Label('A clipboard button'))
                    .child(new Clipboard('clipboard1')
                        .valueFn((_, cx) -> 'masked :' + view.read(cx).masked)
                        .onCopied((value, window, cx) -> window.pushNotification('Copied value: $value', cx)))))
            .child(section('With Input')
                .description("Copies the field's current value.")
                .w(px(480.))
                .child(new Input(urlState).suffix(new Clipboard('clipboard2')
                    .valueFn((_, cx) -> state.read(cx).value())
                    .onCopied((value, window, cx) -> window.pushNotification('Copied value: $value', cx)))));
    }

}
