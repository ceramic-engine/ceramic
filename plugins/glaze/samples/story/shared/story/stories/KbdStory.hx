// Ported from gpui-kit 0.8.1: crates/story/src/stories/kbd_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story.stories;

import glaze.AnyView;
import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Keystroke;
import glaze.Model;
import glaze.Window;
import glaze.kit.kbd.Kbd;
import story.Story;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Lib.*;

class KbdStory extends Model implements Story {

    final focusHandle:FocusHandle;

    public static function title():String {
        return 'Kbd';
    }

    public static function description():String {
        return 'A tag style to display keyboard shortcuts';
    }

    public static function newView(window:Window, cx:App):AnyView {
        return view(window, cx);
    }

    function new(_:Window, cx:glaze.AppContext) {
        super();
        focusHandle = cx.focusHandle();
    }

    public static function view(window:Window, cx:App):Entity<KbdStory> {
        return cx.newEntity((cx:Context<KbdStory>) -> new KbdStory(window, cx));
    }

    public function render(_:Window, _:Context<Dynamic>):IntoElement {
        return vFlex()
            .wFull()
            .itemsCenter()
            .gap6()
            .child(section('Default')
                .description('Displays single keys and multi-key shortcuts.')
                .w(px(560.))
                .child(hFlex()
                    .wFull()
                    .justifyCenter()
                    .gap2()
                    .flexWrap()
                    .child(new Kbd(Keystroke.parse('cmd-shift-p')))
                    .child(new Kbd(Keystroke.parse('cmd-ctrl-t')))
                    .child(new Kbd(Keystroke.parse('cmd--')))
                    .child(new Kbd(Keystroke.parse('cmd-+')))
                    .child(new Kbd(Keystroke.parse('escape')))
                    .child(new Kbd(Keystroke.parse('backspace')))
                    .child(new Kbd(Keystroke.parse('/')))
                    .child(new Kbd(Keystroke.parse('enter')))))
            .child(section('Outlined')
                .description('An outlined treatment adds emphasis on dense surfaces.')
                .w(px(560.))
                .child(hFlex()
                    .wFull()
                    .justifyCenter()
                    .gap2()
                    .flexWrap()
                    .child(new Kbd(Keystroke.parse('cmd-shift-p')).outline())
                    .child(new Kbd(Keystroke.parse('cmd-ctrl-t')).outline())
                    .child(new Kbd(Keystroke.parse('enter')).outline())));
    }

}
