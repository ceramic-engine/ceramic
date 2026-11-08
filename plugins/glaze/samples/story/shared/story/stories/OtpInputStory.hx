// Ported from gpui-kit 0.8.1: crates/story/src/stories/otp_input_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.

package story.stories;

import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.Window;
import glaze.Action;
import glaze.Subscription;
import glaze.kit.base.OtpInput.OtpEvent;
import glaze.kit.base.OtpInput.OtpState;
import glaze.kit.Size;
import glaze.kit.button.Button;
import glaze.kit.input.OtpInput;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using glaze.kit.base.StyledExt;

@:action(namespace = otp_input_story, noJson) private class ToggleMasked implements Action {}

class OtpInputStory extends Model implements Story {

    public static function title():String {
        return 'OtpInput';
    }

    public static function description():String {
        return 'Enter short verification and recovery codes with clear grouping and masking controls.';
    }

    public static function closable():Bool {
        return false;
    }

    public static function init(_:App):Void {}

    public static function newView(window:Window, cx:App):glaze.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<OtpInputStory> {
        return cx.newEntity((c:Context<OtpInputStory>) -> new OtpInputStory(window, c));
    }

    @observe var otpMasked:Bool = true;

    final otpState:Entity<OtpState>;

    @observe var otpValue:Null<String> = null;

    final otpStateSmall:Entity<OtpState>;

    final otpStateLarge:Entity<OtpState>;

    final otpStateSized:Entity<OtpState>;

    final otpStateDisabled:Entity<OtpState>;

    @observe var size:Size = glaze.kit.Size.Medium;

    final subscriptions:Array<Subscription>;

    function new(window:Window, cx:Context<OtpInputStory>) {
        super();
        otpState = cx.newEntity((cx:Context<OtpState>) -> new OtpState(6, window, cx).withMasked(true));
        subscriptions = [cx.subscribe(otpState, OtpEvent, (this_, state, ev, cx) -> switch ev {
            case Complete:
                this_.otpValue = state.read(cx.app).value();
            case _:
        })];
        otpStateSmall = cx.newEntity((cx:Context<OtpState>) -> new OtpState(6, window, cx).defaultValue('123456').withMasked(true));
        otpStateLarge = cx.newEntity((cx:Context<OtpState>) -> new OtpState(6, window, cx).defaultValue('012345').withMasked(true));
        otpStateSized = cx.newEntity((cx:Context<OtpState>) -> new OtpState(4, window, cx).withMasked(true).defaultValue('654321'));
        otpStateDisabled = cx.newEntity((cx:Context<OtpState>) -> new OtpState(6, window, cx).withMasked(true).defaultValue('123456'));
    }

    function toggleOptMasked(_:Bool, window:Window, cx:App):Void {
        otpMasked = !otpMasked;
        final masked = otpMasked;
        for (state in [otpState, otpStateSmall, otpStateLarge, otpStateSized, otpStateDisabled]) {
            state.update(cx, (state, cx) -> state.setMasked(masked, window, cx));
        }
    }

    public function focusHandle(cx:App):FocusHandle {
        return otpState.read(cx).focusHandle;
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final masked = otpMasked;
        final defaultSection = section('Default')
            .description('Six cells with masking and value updates.')
            .vFlex()
            .child(OtpInput.component(otpState).withSize(size));
        if (otpValue != null) defaultSection.child('Value: $otpValue');
        return vFlex()
            .id('otp-input-story')
            .sizeFull()
            .gap5()
            .onAction(ChangeStorySize, (action, _, _) -> size = action.value)
            .onAction(ToggleMasked, (_, window, cx) -> toggleOptMasked(false, window, cx))
            .child(storyToolbar(size).dropdownChild(Button.component('otp-options').label('Options'),
                (menu, _, _) -> menu.menuWithCheck('Masked', masked, new ToggleMasked())))
            .child(defaultSection)
            .child(section('Grouping')
                .description('Cells can be shown as one or several groups.')
                .vFlex()
                .gap4()
                .child(OtpInput.component(otpStateSmall).groups(1).withSize(size))
                .child(OtpInput.component(otpStateLarge).groups(3).withSize(size)))
            .child(section('Custom size')
                .description('Custom cell dimensions.')
                .child(OtpInput.component(otpStateSized).groups(1).withSize(px(55.))))
            .child(section('Disabled')
                .description('Disabled input with a value.')
                .child(OtpInput.component(otpStateDisabled).withSize(size).disabled(true)));
    }

}
