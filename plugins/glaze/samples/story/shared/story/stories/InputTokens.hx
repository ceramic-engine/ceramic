// Ported from gpui-kit 0.8.1: crates/story/src/stories/input_tokens.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.

package story.stories;

import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Range;
import glaze.Render;
import glaze.Subscription;
import glaze.Window;
import glaze.kit.base.input.InlineToken;
import glaze.kit.base.input.InlineTokenClickEvent;
import glaze.kit.base.input.InlineTokenContext;
import glaze.kit.base.input.InlineTokenException;
import glaze.kit.base.input.InputBaseState;
import glaze.kit.base.input.InputContent;
import glaze.kit.base.input.InputEvent;
import glaze.kit.base.input.InputState;
import glaze.kit.base.input.TextareaState;
import glaze.kit.IconName;
import glaze.kit.button.Button;
import glaze.kit.checkbox.Checkbox;
import glaze.kit.input.Input;
import glaze.kit.input.InputGroup;
import glaze.kit.input.InputGroup.InputGroupAddon;
import glaze.kit.input.InputGroup.InputGroupAddonAlignment;
import glaze.kit.input.InputGroup.InputGroupButton;
import glaze.kit.input.InputToken;
import glaze.kit.input.Textarea;
import glaze.kit.theme.Theme;
import glaze.util.Utf8;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.base.StyledExt;

/**
 * A chat composer shared by the Input and Textarea stories. Commands,
 * images, skills and people are inserted as atomic inline tokens; the
 * application maps a token's ID back to the resource it names.
 */
class InputTokens {}

/** What a token refers to, recovered from the prefix of its ID. */
enum abstract Reference(Int) {
    var Command;
    var Image;
    var Skill;
    var Person;

    public static final ALL:Array<Reference> = [Command, Image, Skill, Person];

    public static function of(token:InlineToken):Null<Reference> {
        final colon = token.id().indexOf(':');
        if (colon < 0) return null;
        final prefix = token.id().substr(0, colon);
        for (reference in ALL) if (reference.prefix() == prefix) return reference;
        return null;
    }

    public function prefix():String {
        return switch (cast this:Reference) {
            case Command: 'command';
            case Image: 'image';
            case Skill: 'skill';
            case Person: 'person';
        }
    }

    /**
     * The icon of the reference. `Image`, `Sparkles` and `AtSign` come from
     * gpui-kit's full icon catalog (not bundled by default): their SVGs are
     * in the project assets.
     */
    public function icon():IconName {
        return switch (cast this:Reference) {
            case Command: IconName.SquareTerminal;
            case Image: cast 'icons/image.svg';
            case Skill: cast 'icons/sparkles.svg';
            case Person: cast 'icons/at-sign.svg';
        }
    }

    /** The button that inserts a sample of this reference. */
    public function action():{id:String, label:String} {
        return switch (cast this:Reference) {
            case Command: {id: 'insert-command', label: 'Insert command'};
            case Image: {id: 'insert-image', label: 'Attach image'};
            case Skill: {id: 'insert-skill', label: 'Insert skill'};
            case Person: {id: 'insert-person', label: 'Mention someone'};
        }
    }

    /**
     * The sample the story inserts. A real composer resolves this from a
     * picker or completion; the ID is what the application looks up later.
     */
    public function sample():InlineToken {
        return switch (cast this:Reference) {
            case Command: new InlineToken('command:commit-pr', '/commit-pr');
            case Image: new InlineToken('image:1', '[Image 1]').withLabel('Image 1');
            case Skill: new InlineToken('skill:gpui-kit', '$$gpui-kit').withLabel('gpui-kit');
            case Person: new InlineToken('person:alice', '@alice').withLabel('Alice');
        }
    }
}

/** Rust `State`: the composer is an `Input` or a `Textarea`. */
enum TokenState {
    Input(state:Entity<InputState>);
    Textarea(state:Entity<TextareaState>);
}

class TokenExample extends Model implements Render {

    final state:TokenState;

    var saved:InputContent;

    @observe var readonly:Bool = false;

    @observe var disabled:Bool = false;

    @observe var status:String = '';

    final subscription:Subscription;

    /**
     * Build content from prose, attaching each sample token at its first
     * occurrence so the byte ranges never drift from the text.
     */
    static function content(text:String, references:Array<Reference>):InputContent {
        var result = new InputContent(text);
        for (reference in references) {
            final token = reference.sample();
            final index = text.indexOf(token.text());
            final start = Utf8.indexToByteOffset(text, index);
            result = result.withToken(new Range(start, start + Utf8.byteLength(token.text())), token);
        }
        return result;
    }

    static function describe(content:InputContent):String {
        return [for (span in content.tokens()) '${span.token().id()} ${span.range().toString()}'].join(', ');
    }

    /** Rust `TokenExample::new`. */
    public static function create(multiline:Bool, window:Window, cx:App):Entity<TokenExample> {
        return cx.newEntity((cx:Context<TokenExample>) -> new TokenExample(multiline, window, cx));
    }

    function new(multiline:Bool, window:Window, cx:Context<TokenExample>) {
        super();
        if (multiline) {
            final input = cx.newEntity((cx:Context<TextareaState>) -> new TextareaState(window, cx).autoGrow(2, 6));
            saved = content('/commit-pr for the token composer, then ask @alice to review [Image 1] against $$gpui-kit 🙂\nSelect part of a reference, delete it, and undo.',
                Reference.ALL);
            state = Textarea(input);
        } else {
            final input = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx));
            saved = content('Ask @alice to review [Image 1] 🙂', [Reference.Person, Reference.Image]);
            state = Input(input);
        }
        final saved = this.saved;
        subscription = switch state {
            case Input(input):
                input.update(cx, (input, cx) -> input.setValue(saved, window, cast cx));
                cx.subscribe(input, InputEvent, (_, _, event, cx) -> if (event.match(Change)) cx.notify());
            case Textarea(input):
                input.update(cx, (input, cx) -> input.setValue(saved, window, cast cx));
                cx.subscribe(input, InputEvent, (_, _, event, cx) -> if (event.match(Change)) cx.notify());
        }
    }

    function base():Entity<InputBaseState> {
        return switch state {
            case Input(input): cast input;
            case Textarea(input): cast input;
        }
    }

    function readContent(cx:App):InputContent {
        return switch state {
            case Input(input): input.read(cx).content();
            case Textarea(input): input.read(cx).content();
        }
    }

    /**
     * Insert a reference the way a picker would: separated from the
     * surrounding words, with the caret ready for the next one.
     */
    function insert(reference:Reference, window:Window, cx:Context<TokenExample>):Void {
        final error = base().update(cx, (input, cx) -> {
            final start = input.selectedRange().start;
            final text = input.value();
            // Rust `text[..start].ends_with(|c: char| !c.is_whitespace())`
            if (start > 0 && !Utf8.isWhitespace(Utf8.codePointAtByte(text, lastCharStart(text, start)))) {
                input.replace(' ', window, cx);
            }
            final error = switch state {
                case Input(_): (cast input : InputState).replaceWithToken(reference.sample(), window, cx);
                case Textarea(_): (cast input : TextareaState).replaceWithToken(reference.sample(), window, cx);
            }
            if (error != null) return error;
            input.replace(' ', window, cx);
            input.focus(window, cx);
            return null;
        });
        if (error != null) {
            status = error.toString();
        }
        cx.notify();
    }

    /** The byte offset of the char that ends at `end`. */
    static function lastCharStart(text:String, end:Int):Int {
        var ix = end - 1;
        while (ix > 0 && !Utf8.isCharBoundary(text, ix)) ix--;
        return ix;
    }

    function open(event:InlineTokenClickEvent):Void {
        final token = event.token();
        final reference = Reference.of(token);
        status = if (reference == null) {
            'Unknown reference ${token.id()}';
        } else switch reference {
            case Command: 'Would run ${token.text()}';
            case Image: 'Would preview ${token.label()}';
            case Skill: 'Would open the ${token.label()} skill';
            case Person: "Would open " + token.label() + "'s profile";
        }
    }

    /** Rust `{:?}` of a string. */
    static function debugString(value:String):String {
        return '"' + value.split('\\').join('\\\\').split('"').join('\\"').split('\n').join('\\n') + '"';
    }

    function send(cx:App):Void {
        final content = readContent(cx);
        status = 'Sent ${debugString(StringTools.trim(content.text()))} with ${content.tokens().length} references';
    }

    static function token(token:InlineTokenContext):IntoElement {
        final reference = Reference.of(token.token());
        final element = new InputToken(token);
        if (reference != null) element.icon(reference.icon());
        return element;
    }

    function insertButton(reference:Reference):InputGroupButton {
        final action = reference.action();
        return new InputGroupButton(action.id)
            .icon(reference.icon())
            .accessibilityLabel(action.label)
            .tooltip(action.label)
            .disabled(readonly)
            .onClick((_, window, cx) -> self().update(cx, (this_, cx) -> this_.insert(reference, window, cx)));
    }

    var selfEntity:Null<Entity<TokenExample>> = null;

    function self():Entity<TokenExample> {
        return selfEntity;
    }

    function sendButton():InputGroupButton {
        return new InputGroupButton('send-message')
            .primary()
            .label('Send')
            .onClick((_, _, cx) -> self().update(cx, (this_, _) -> this_.send(cx)));
    }

    function composer():InputGroup {
        final inserts:Array<IntoElement> = [for (reference in Reference.ALL) insertButton(reference)];
        final open = (event:InlineTokenClickEvent, _:Window, cx:App) -> self().update(cx, (this_, _) -> this_.open(event));
        final group = switch state {
            case Input(input): new InputGroup('token-composer')
                .input(new Input(input)
                    .ariaLabel('Message')
                    .token((token, _, _) -> TokenExample.token(token))
                    .onTokenClick(open))
                .addon(new InputGroupAddon('composer-actions')
                    .align(InputGroupAddonAlignment.InlineEnd)
                    .children(inserts)
                    .child(sendButton()));
            case Textarea(input): new InputGroup('token-composer')
                .input(new Textarea(input)
                    .ariaLabel('Message')
                    .token((token, _, _) -> TokenExample.token(token))
                    .onTokenClick(open))
                .addon(new InputGroupAddon('composer-actions')
                    .align(InputGroupAddonAlignment.BlockEnd)
                    .children(inserts)
                    .child(sendButton().mlAuto()));
        }
        return group.readonly(readonly).disabled(disabled);
    }

    function readout(cx:App):IntoElement {
        final theme = Theme.global(cx);
        final content = readContent(cx);
        final row = (label:String, value:String) -> hFlex()
            .itemsStart()
            .gap3()
            .child(div().flexShrink0().w(rems(5.5)).textColor(theme.mutedForeground).child(label))
            .child(div().minW0().flex1().child(value));
        return vFlex()
            .wFull()
            .gap1()
            .textSm()
            .child(row('Text', content.text()))
            .child(row('References', describe(content)))
            .when(status != '', this_ -> this_.child(row('Status', status)));
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        selfEntity = cast cx.entity();
        return vFlex()
            .wFull()
            .gap4()
            .child(composer())
            .child(hFlex()
                .gap6()
                .child(hFlex()
                    .gap2()
                    .child(new Button('save-draft')
                        .outline()
                        .small()
                        .label('Save draft')
                        .onClick((_, _, cx) -> {
                            saved = readContent(cx);
                            status = 'Draft saved';
                        }))
                    .child(new Button('restore-draft')
                        .outline()
                        .small()
                        .label('Restore draft')
                        .disabled(readonly || disabled)
                        .onClick((_, window, cx) -> {
                            final saved = this.saved;
                            base().update(cx, (input, cx) -> input.setValue(saved, window, cx));
                            status = 'Draft restored';
                        })))
                .child(hFlex()
                    .gap4()
                    .child(new Checkbox('tokens-readonly')
                        .small()
                        .label('Readonly')
                        .checked(readonly)
                        .onClick((value, _, _) -> readonly = value))
                    .child(new Checkbox('tokens-disabled')
                        .small()
                        .label('Disabled')
                        .checked(disabled)
                        .onClick((value, _, _) -> disabled = value))))
            .child(readout(cx.app));
    }

}
