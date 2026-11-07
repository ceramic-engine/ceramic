// Ported from gpui-kit 0.8.1: crates/story/src/stories/input_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story.stories;

import glaze.AnyView;
import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Subscription;
import glaze.Window;
import glaze.kit.base.A11y.Role;
import glaze.kit.base.input.InputActions.Copy;
import glaze.kit.base.input.InputActions.Paste;
import glaze.kit.base.input.InputActions.SelectAll;
import glaze.kit.base.input.InputEvent;
import glaze.kit.base.input.InputState;
import glaze.kit.base.input.MaskPattern;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.Size;
import glaze.kit.button.Button;
import glaze.kit.input.Input;
import glaze.kit.input.InputContentType;
import glaze.kit.label.Label;
import glaze.kit.theme.Theme;
import story.Story;
import story.StoryActions.ChangeStorySize;
import story.stories.InputCompletion.CompletionExample;
import story.stories.InputTokens.TokenExample;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Lib.*;

using glaze.kit.base.StyledExt;
using glaze.kit.WindowExt;

private class ContentTypeInput {

    public final label:String;

    public final contentType:InputContentType;

    public final input:Entity<InputState>;

    public final maskToggle:Bool;

    public function new(label:String, contentType:InputContentType, input:Entity<InputState>, maskToggle:Bool) {
        this.label = label;
        this.contentType = contentType;
        this.input = input;
        this.maskToggle = maskToggle;
    }

}

class InputStory extends Model implements Story {

    final tokens:Entity<TokenExample>;
    final completion:Entity<CompletionExample>;
    final input1:Entity<InputState>;
    final input2:Entity<InputState>;
    final inputEsc:Entity<InputState>;
    final inputTextCentered:Entity<InputState>;
    final inputTextRight:Entity<InputState>;
    final maskInput:Entity<InputState>;
    final disabledInput:Entity<InputState>;
    final readonlyInput:Entity<InputState>;
    final prefixInput1:Entity<InputState>;
    final suffixInput1:Entity<InputState>;
    final bothInput1:Entity<InputState>;
    final completeInput:Entity<InputState>;
    final completeDisabledInput:Entity<InputState>;
    final smallInput:Entity<InputState>;
    final phoneInput:Entity<InputState>;
    final maskInput2:Entity<InputState>;
    final currencyInput:Entity<InputState>;
    final customInput:Entity<InputState>;
    final customMenuInput:Entity<InputState>;
    final colorInput:Entity<InputState>;
    final contentTypeInputs:Array<ContentTypeInput>;
    var size:Size;

    final subscriptions:Array<Subscription>;

    public static function init(_:App):Void {}

    public static function title():String {
        return 'Input';
    }

    public static function description():String {
        return 'Capture and validate short-form text, credentials, identifiers, and formatted values.';
    }

    public static function closable():Bool {
        return false;
    }

    public static function newView(window:Window, cx:App):AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<InputStory> {
        return cx.newEntity((cx:Context<InputStory>) -> new InputStory(window, cx));
    }

    /** Rust `s.parse::<f32>().is_ok()`. */
    static function parsesAsF32(s:String):Bool {
        return ~/^[+-]?(inf|infinity|nan|[0-9]+\.?[0-9]*([eE][+-]?[0-9]+)?|\.[0-9]+([eE][+-]?[0-9]+)?)$/i.match(s);
    }

    function new(window:Window, cx:Context<InputStory>) {
        super();
        input1 = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx)
            .defaultValue('Hello 世界，this is GPUI component, this is a long text.'));

        input2 = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx).withPlaceholder('Enter text here...'));
        inputEsc = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx)
            .withPlaceholder('Enter text and clear it by pressing ESC')
            .withCleanOnEscape());

        maskInput = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx)
            .withMasked(true)
            .withPlaceholder('Enter your password...')
            .defaultValue('this-is-password-中文🚀🎉'));

        prefixInput1 = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx).withPlaceholder('Search some thing...'));
        suffixInput1 = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx)
            .withPlaceholder('This input only support [a-zA-Z0-9] characters.')
            .withPattern(~/^[a-zA-Z0-9]*$/));
        bothInput1 = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx).withPlaceholder('This input have prefix and suffix.'));
        completeInput = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx)
            .withPlaceholder('Search account...')
            .defaultValue('jane.doe@example.com'));
        completeDisabledInput = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx)
            .withPlaceholder('Search account...')
            .defaultValue('disabled.account@example.com'));

        phoneInput = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx).withMaskPattern('(999)-999-9999'));
        maskInput2 = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx).withMaskPattern('AAA-###-AAA'));
        currencyInput = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx).withMaskPattern(MaskPattern.Number(','.code, 3)));
        customInput = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx)
            .withPlaceholder('Custom Input use monospace, 0123456789.')
            .contextMenu(false));

        customMenuInput = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx).withPlaceholder('Input with custom context menu...'));

        colorInput = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx)
            .withPlaceholder('Type something...')
            .defaultValue('Custom text color input'));

        inputTextCentered = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx)
            .withPlaceholder('Enter text to test center layout...')
            .defaultValue('Centered Text'));

        inputTextRight = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx)
            .withPlaceholder('Enter text to test right layout...')
            .defaultValue('Right Aligned Text'));

        contentTypeInputs = [
            newContentTypeInput(window, cx, 'Name', InputContentType.Name, 'Full name', 'Jane Doe', false),
            newContentTypeInput(window, cx, 'Username', InputContentType.Username, 'Username', 'jane.doe', false),
            newContentTypeInput(window, cx, 'Password', InputContentType.Password, 'Current password', 'current-password', true),
            newContentTypeInput(window, cx, 'New password', InputContentType.NewPassword, 'New password', 'new-password', true),
            newContentTypeInput(window, cx, 'One-time code', InputContentType.OneTimeCode, '123456', '123456', false),
            newContentTypeInput(window, cx, 'Email', InputContentType.EmailAddress, 'Email address', 'jane.doe@example.com', false),
            newContentTypeInput(window, cx, 'Telephone', InputContentType.TelephoneNumber, 'Telephone number', '+1 415 555 0198', false),
            newContentTypeInput(window, cx, 'URL', InputContentType.Url, 'Website URL', 'https://example.com', false),
            newContentTypeInput(window, cx, 'Credit card number', InputContentType.CreditCardNumber, 'Card number', '4242 4242 4242 4242', false),
            newContentTypeInput(window, cx, 'Credit card expiration', InputContentType.CreditCardExpiration, 'MM/YY', '12/28', false),
            newContentTypeInput(window, cx, 'Credit card security code', InputContentType.CreditCardSecurityCode, 'CVC', '123', true),
            newContentTypeInput(window, cx, 'Postal code', InputContentType.PostalCode, 'Postal code', '94107', false),
        ];

        subscriptions = [
            cx.subscribeIn(input1, InputEvent, window, (this_:InputStory, state, event, window, cx) -> this_.onInputEvent(state, event, window, cx)),
            cx.subscribeIn(input2, InputEvent, window, (this_:InputStory, state, event, window, cx) -> this_.onInputEvent(state, event, window, cx)),
            cx.subscribeIn(phoneInput, InputEvent, window, (this_:InputStory, state, event, window, cx) -> this_.onInputEvent(state, event, window, cx)),
        ];

        tokens = TokenExample.create(false, window, cx.app);
        completion = CompletionExample.create(window, cx.app);
        disabledInput = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx).defaultValue('This is disabled input'));
        readonlyInput = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx).defaultValue('This is read-only input'));
        smallInput = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx)
            .withValidate((s, _) -> parsesAsF32(s))
            .withPlaceholder('validate to limit float number.'));
        size = Medium;
    }

    static function newContentTypeInput(window:Window, cx:Context<InputStory>, label:String, contentType:InputContentType, placeholder:String,
            defaultValue:String, masked:Bool):ContentTypeInput {
        final input = cx.newEntity((cx:Context<InputState>) -> {
            final state = new InputState(window, cx)
                .withPlaceholder(placeholder)
                .defaultValue(defaultValue);

            return masked ? state.withMasked(true) : state;
        });

        return new ContentTypeInput(label, contentType, input, masked);
    }

    static function renderContentTypeInput(item:ContentTypeInput):IntoElement {
        final input = new Input(item.input)
            .contentType(item.contentType)
            .flex1();
        if (item.maskToggle) input.maskToggle();

        return hFlex()
            .wFull()
            .itemsCenter()
            .gap3()
            .child(new Label(item.label)
                .w48()
                .flexShrink0()
                .textSm()
                .whitespaceNowrap())
            .child(input);
    }

    function onInputEvent(state:Entity<InputState>, event:InputEvent, window:Window, cx:Context<InputStory>):Void {
        switch event {
            case Change:
                final text = state.read(cx.app).value();
                if (state == input2) {
                    trace('Set disabled value: $text');
                    disabledInput.update(cx, (this_, cx) -> {
                        this_.setValue(text, window, cast cx);
                    });
                } else {
                    trace('Change: $text');
                }
            case PressEnter(secondary, shift):
                trace('PressEnter secondary: $secondary, shift: $shift');
            case Focus:
                trace('Focus');
            case Blur:
                trace('Blur');
        }
    }

    /** Rust `{:?}` of a string. */
    static function debugString(value:String):String {
        final buf = new StringBuf();
        buf.add('"');
        for (c in new haxe.iterators.StringIteratorUnicode(value)) {
            switch c {
                case '"'.code: buf.add('\\"');
                case '\\'.code: buf.add('\\\\');
                case '\n'.code: buf.add('\\n');
                case '\r'.code: buf.add('\\r');
                case '\t'.code: buf.add('\\t');
                case _: buf.addChar(c);
            }
        }
        buf.add('"');
        return buf.toString();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final self:Context<InputStory> = cast cx;
        final theme = Theme.global(cx.app);
        final focused = window.focusedInput(cx.app);
        final focusedValue = focused != null ? 'Some(' + debugString(focused.value(cx.app)) + ')' : 'None';

        return vFlex()
            .id('input-story')
            .sizeFull()
            .justifyStart()
            .gap3()
            .onAction(ChangeStorySize, self.listener((this_:InputStory, action:ChangeStorySize, _, cx) -> {
                this_.size = action.value;
                cx.notify();
            }))
            .child(storyToolbar(size))
            .child(section('Default')
                .description('Text, email, and clearable inputs.')
                .w128()
                .child(new Input(input1)
                    .withSize(size)
                    .cleanable(true))
                .child(new Input(input2)
                    .withSize(size)
                    .role(Explicit(Role.EmailInput))))
            .child(section('States')
                .description('Disabled, read-only and revealable password inputs.')
                .w128()
                .child(new Input(disabledInput)
                    .withSize(size)
                    .disabled(true))
                .child(new Input(readonlyInput)
                    .withSize(size)
                    .readonly(true))
                .child(new Input(maskInput)
                    .withSize(size)
                    .contentType(InputContentType.Password)
                    .maskToggle()
                    .cleanable(true)))
            .child(section('Content type')
                .description('Content types adapt input behavior.')
                .w128()
                .children([for (item in contentTypeInputs) renderContentTypeInput(item)]))
            .child(section('Alignment')
                .description('Align text to the center or end.')
                .w128()
                .child(hFlex()
                    .wFull()
                    .gap4()
                    .flexWrap()
                    .child(new Input(inputTextCentered)
                        .withSize(size)
                        .textCenter()
                        .flex1())
                    .child(new Input(inputTextRight)
                        .withSize(size)
                        .textRight()
                        .flex1())))
            .child(section('Prefix and suffix')
                .description('Add icons or actions inside the field.')
                .w128()
                .child(new Input(prefixInput1)
                    .withSize(size)
                    .cleanable(true)
                    .prefix(new Icon(IconName.Search).small()))
                .child(new Input(bothInput1)
                    .withSize(size)
                    .cleanable(true)
                    .prefix(div().child(new Icon(IconName.Search).small()))
                    .suffix(new Button('info').text().icon(IconName.Info).xsmall()))
                .child(new Input(suffixInput1)
                    .withSize(size)
                    .cleanable(true)
                    .suffix(new Button('info').text().icon(IconName.Info).xsmall())))
            .child(section('Composed states')
                .description('Composed inputs support disabled state.')
                .w128()
                .child(new Input(completeInput)
                    .withSize(size)
                    .cleanable(true)
                    .prefix(new Icon(IconName.Search).small())
                    .suffix(new Button('complete-input-info')
                        .text()
                        .icon(IconName.Info)
                        .xsmall()))
                .child(new Input(completeDisabledInput)
                    .withSize(size)
                    .cleanable(true)
                    .disabled(true)
                    .prefix(new Icon(IconName.Search).small())
                    .suffix(new Button('complete-disabled-input-info')
                        .text()
                        .icon(IconName.Info)
                        .xsmall())))
            .child(section('Currency')
                .description('Format currency while retaining its value.')
                .w128()
                .child(new Input(currencyInput).withSize(size))
                .child(div().child('Value: ' + debugString(currencyInput.read(cx.app).value()))))
            .child(section('Phone mask')
                .description('Expose formatted and raw phone values.')
                .w128()
                .child(new Input(phoneInput).withSize(size))
                .child(vFlex()
                    .child('Value: ' + debugString(phoneInput.read(cx.app).value()))
                    .child('Unmask Value: ' + debugString(phoneInput.read(cx.app).unmaskValue()))))
            .child(section('Mask pattern')
                .description('Combine letter and number placeholders.')
                .w128()
                .child(new Input(maskInput2).withSize(size))
                .child(vFlex()
                    .child('Value: ' + debugString(maskInput2.read(cx.app).value()))
                    .child('Unmask Value: ' + debugString(maskInput2.read(cx.app).unmaskValue()))))
            .child(section('Validation')
                .description('Validate values while the user types.')
                .w128()
                .child(new Input(smallInput).withSize(size)))
            .child(section('Clear on Escape')
                .description('Clear a value with its action or Escape.')
                .w128()
                .child(new Input(inputEsc)
                    .withSize(size)
                    .cleanable(true)))
            .child(section('Focused value')
                .description('Read the value of the focused input.')
                .w128()
                .whitespaceNormal()
                .overflowHidden()
                .child(div().child('Value: $focusedValue')))
            .child(section('Custom appearance')
                .description('Remove the default field appearance.')
                .w128()
                .child(div()
                    .borderB2()
                    .px6()
                    .py3()
                    .fontFamily(theme.monoFontFamily)
                    .borderColor(theme.border)
                    .bg(theme.secondary)
                    .textColor(theme.secondaryForeground)
                    .wFull()
                    .child(new Input(customInput)
                        .withSize(size)
                        .appearance(false))))
            .child(section('Context menu')
                .description('Add actions to the editing menu.')
                .w128()
                .child(new Input(customMenuInput)
                    .withSize(size)
                    .contextMenu((menu, _, _) -> menu.menu('Custom Action', new SelectAll())
                        .separator()
                        .menu('Copy', new Copy())
                        .menu('Paste', new Paste()))))
            .child(section('Text color')
                .description('Apply a semantic text color.')
                .w128()
                .child(new Input(colorInput)
                    .withSize(size)
                    .textColor(theme.info)))
            .child(section('Atomic inline tokens')
                .description('References keep their identity through selection, deletion and undo. Copy returns the underlying text.')
                .wFull()
                .child(tokens))
            .child(section('Completion')
                .description('The application owns the candidates, the menu and the keys it captures; type $$ to complete a variable.')
                .w128()
                .child(completion));
    }

}
