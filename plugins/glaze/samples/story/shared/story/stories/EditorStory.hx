// Ported from gpui-kit 0.8.1: crates/story/src/stories/editor_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story.stories;

import gpui.AnyView;
import gpui.App;
import gpui.Context;
import gpui.Entity;
import gpui.FontStyle;
import gpui.FontWeight;
import gpui.HighlightStyle;
import gpui.IntoElement;
import gpui.Model;
import gpui.Pixels;
import gpui.Range;
import gpui.Task;
import gpui.UnderlineStyle;
import gpui.Window;
import gpui.base.input.CompletionContext;
import gpui.base.input.CompletionHighlighter;
import gpui.base.input.CompletionItem;
import gpui.base.input.CompletionProvider.CompletionProviderBase;
import gpui.base.input.Completions;
import gpui.base.input.EditorState;
import gpui.base.input.RangeDecoration;
import gpui.base.input.RangeDecorationCollection;
import gpui.base.input.RangeDecorationStyle;
import gpui.base.input.TabSize;
import gpui.base.input.TextDecoration;
import gpui.base.input.TextDecorationCollection;
import gpui.component.button.Button;
import gpui.component.input.Editor;
import gpui.component.label.Label;
import gpui.component.menu.PopupMenu.PopupMenuItem;
import gpui.component.tab.Tab;
import gpui.component.tab.TabBar;
import gpui.component.theme.Theme;
import ropey.Rope;
import story.Story;

import gpui.Prelude.*;
import gpui.base.Prelude.*;
import story.Lib.*;

using gpui.base.StyledExt;
using gpui.base.input.InputDecorationsExt;
using gpui.base.input.InputIndentExt;
using gpui.base.input.InputLspExt;

enum StoryCompletionHighlight {
    Prefix;
    Contains;
    Characters;
}

class StoryCompletionHighlightTools {

    public static function highlighter(self:StoryCompletionHighlight):CompletionHighlighter {
        return switch self {
            case Prefix: Completions.highlightPrefix;
            case Contains: Completions.highlightContains;
            case Characters: Completions.highlightCharacters;
        }
    }

    public static function label(self:StoryCompletionHighlight):String {
        return switch self {
            case Prefix: 'Prefix';
            case Contains: 'Contains';
            case Characters: 'Characters';
        }
    }

    /**
     * Whether `label` should stay in the menu for this highlighter.
     *
     * An empty query keeps every word. Prefix checks the start of the label;
     * the other two keep a word only when their highlighter finds a match.
     */
    public static function matches(self:StoryCompletionHighlight, query:String, label:String):Bool {
        if (query == '') {
            return true;
        }

        return switch self {
            case Prefix: EditorStory.startsWithIgnoreCase(label, query);
            case Contains: Completions.highlightContains(query, EditorStory.completionItem(label)).length > 0;
            case Characters: Completions.highlightCharacters(query, EditorStory.completionItem(label)).length > 0;
        }
    }

}

/** A mutable cell shared by the story and its completion provider (Rust `Rc<Cell<_>>`). */
private class HighlightCell {

    public var value:StoryCompletionHighlight;

    public function new(value:StoryCompletionHighlight) {
        this.value = value;
    }

}

class EditorStory extends Model implements Story {

    static final EXAMPLE_CODE:String = story.Include.str('editor_preview.rs');

    /** Words chosen so `fl` and `log` light up different spans under each highlighter. */
    static final COMPLETION_WORDS:Array<String> = ['flag', 'profile', 'file_loader', 'fallback', 'dialog_log', 'catalog'];

    static final COMPLETION_HIGHLIGHTS:Array<StoryCompletionHighlight> = [Prefix, Contains, Characters];

    /** The font families to offer beside the theme's own monospace one. */
    static final FONT_FAMILIES:Array<String> = ['Menlo', 'Consolas', 'Monaco'];

    /** The font sizes to switch the editor between. */
    static final FONT_SIZES:Array<Pixels> = [px(11.), px(13.), px(16.), px(20.)];

    final editorState:Entity<EditorState>;
    final decorationsState:Entity<EditorState>;
    final completionsState:Entity<EditorState>;
    final decorations:TextDecorationCollection;
    final rangeDecorations:RangeDecorationCollection;
    var activeTab:Int;
    var readonly:Bool;
    var fontFamily:Null<String>;
    var fontSize:Pixels;
    final completionHighlight:HighlightCell;

    public static function title():String {
        return 'Editor';
    }

    public static function description():String {
        return 'Code editor with theme-aware syntax highlighting and folding.';
    }

    public static function closable():Bool {
        return false;
    }

    public static function newView(window:Window, cx:App):AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<EditorStory> {
        return cx.newEntity((cx:Context<EditorStory>) -> new EditorStory(window, cx));
    }

    @:allow(story.stories)
    static function startsWithIgnoreCase(label:String, query:String):Bool {
        final labelChars = new haxe.iterators.StringIteratorUnicode(label);
        for (queryChar in new haxe.iterators.StringIteratorUnicode(query)) {
            if (!labelChars.hasNext()) return false;
            final labelChar = labelChars.next();
            if (queryChar == labelChar) continue;
            final q = String.fromCharCode(queryChar);
            final l = String.fromCharCode(labelChar);
            if (q.toLowerCase() != l.toLowerCase()) return false;
        }
        return true;
    }

    @:allow(story.stories)
    static function completionItem(label:String):CompletionItem {
        return new CompletionItem(label);
    }

    static function completionItems(mode:StoryCompletionHighlight, query:String):Array<CompletionItem> {
        return [for (label in COMPLETION_WORDS) if (StoryCompletionHighlightTools.matches(mode, query, label)) completionItem(label)];
    }

    /** Rust `str::find` as a byte offset (0 when missing, like `unwrap_or_default`). */
    static function find(text:String, needle:String):Int {
        final ix = text.indexOf(needle);
        return ix < 0 ? 0 : gpui.util.Utf8.indexToByteOffset(text, ix);
    }

    function new(window:Window, cx:Context<EditorStory>) {
        super();
        editorState = cx.newEntity((cx:Context<EditorState>) -> {
            final state = new EditorState(window, cx)
                .language('rust')
                .folding(true);
            state.tabSize(new TabSize(4, false));
            return state.defaultValue(EXAMPLE_CODE);
        });

        // Rust swaps in a `syntect` highlighter on WASM here (no tree-sitter
        // grammars there). The port uses its TextMate highlighter on every
        // target, see `gpui.component.highlighter.Highlighter`.

        final decorationText = 'Decoration styles\nColor highlights important text.\nItalic adds emphasis.\nUnderline marks review text.\n\nFill: marks a tracked range.\n\nFrame: outlines a tracked range.';
        decorationsState = cx.newEntity((cx:Context<EditorState>) -> new EditorState(window, cx)
            .language('text')
            .defaultValue(decorationText));

        final marker = 'Decoration styles';
        final colorRange = 'Color';
        final italicRange = 'Italic';
        final underlineRange = 'Underline';
        final fillRange = 'marks a tracked range.';
        final frameRange = 'outlines a tracked range.';
        final markerStart = find(decorationText, marker);
        final colorStart = find(decorationText, colorRange);
        final italicStart = find(decorationText, italicRange);
        final underlineStart = find(decorationText, underlineRange);
        final fillStart = find(decorationText, fillRange);
        final frameStart = find(decorationText, frameRange);
        final len = gpui.util.Utf8.byteLength;
        decorations = decorationsState.update(cx, (state, cx) -> {
            final theme = Theme.global(cx.app);
            return state.createDecorationsCollection([
                new TextDecoration(new Range(markerStart, markerStart + len(marker)), new HighlightStyle(theme.danger, FontWeight.BOLD, null,
                    theme.warning.opacity(0.2))),
                new TextDecoration(new Range(colorStart, colorStart + len(colorRange)), new HighlightStyle(theme.success, FontWeight.BOLD,
                    FontStyle.Italic)),
                new TextDecoration(new Range(italicStart, italicStart + len(italicRange)), new HighlightStyle(theme.info, null, FontStyle.Italic)),
                new TextDecoration(new Range(underlineStart, underlineStart + len(underlineRange)), new HighlightStyle(null, null, null, null,
                    new UnderlineStyle(px(2.), theme.warning, true))),
            ], cast cx);
        });

        // Geometry is a separate owner from text styling. Both follow edits,
        // including newlines inserted before these ranges.
        rangeDecorations = decorationsState.update(cx, (state, cx) -> state.createRangeDecorationsCollection([
            new RangeDecoration(new Range(fillStart, fillStart + len(fillRange))).withStyle(RangeDecorationStyle.Fill),
            new RangeDecoration(new Range(frameStart, frameStart + len(frameRange))),
        ], cast cx));

        completionHighlight = new HighlightCell(Prefix);
        final providerHighlight = completionHighlight;
        completionsState = cx.newEntity((cx:Context<EditorState>) -> {
            final state = new EditorState(window, cx).language('text');
            state.lsp().completionProvider = new StoryCompletions(providerHighlight);
            return state;
        });

        activeTab = 0;
        readonly = false;
        fontFamily = null;
        fontSize = Theme.global(cx.app).monoFontSize;
    }

    function renderToolbar(cx:Context<EditorStory>):IntoElement {
        final story = cx.entity();
        final readonly = this.readonly;
        final family = this.fontFamily;
        final size = this.fontSize;
        final highlight = completionHighlight.value;

        return storyToolbarGroup().dropdownChild(new Button('editor-options').label('Options'), (menu, window, _) -> {
            menu = menu.item(PopupMenuItem.create('Readonly').checked(readonly).onClick((_, _, cx) -> story.update(cx, (this_, cx) -> {
                this_.readonly = !this_.readonly;
                cx.notify();
            })));

            menu = menu.separator().label('Font family');
            final items:Array<Null<String>> = [null].concat(FONT_FAMILIES);
            for (item in items) {
                final label = item != null ? item : 'Theme default';
                menu = menu.item(PopupMenuItem.create(label).checked(family == item).onClick((_, _, cx) -> story.update(cx, (this_, cx) -> {
                    this_.fontFamily = item;
                    cx.notify();
                })));
            }

            menu = menu.separator().label('Font size');
            for (item in FONT_SIZES) {
                menu = menu.item(PopupMenuItem.create(pixelsLabel(item)).checked(size == item).onClick((_, _, cx) -> story.update(cx, (this_, cx) -> {
                    this_.fontSize = item;
                    cx.notify();
                })));
            }

            menu = menu.separator().label('Completion highlight');
            for (mode in COMPLETION_HIGHLIGHTS) {
                menu = menu.item(PopupMenuItem.create(StoryCompletionHighlightTools.label(mode))
                    .checked(highlight == mode)
                    .onClick((_, _, cx) -> story.update(cx, (this_, cx) -> {
                        this_.setCompletionHighlight(mode, cx);
                    })));
            }
            return menu;
        });
    }

    /** Rust `Pixels::to_string` (`11px`). */
    static function pixelsLabel(value:Pixels):String {
        final f:Float = value;
        return (f == Math.ffloor(f) ? Std.string(Std.int(f)) : Std.string(f)) + 'px';
    }

    function setCompletionHighlight(mode:StoryCompletionHighlight, cx:Context<EditorStory>):Void {
        completionHighlight.value = mode;
        completionsState.update(cx, (state, cx) -> {
            state.lsp().setCompletionHighlighter(StoryCompletionHighlightTools.highlighter(mode));
            final menu = state.completionMenuState();
            final open = menu.open;
            final query = menu.query;
            final start = menu.triggerStartOffset != null ? menu.triggerStartOffset : 0;
            if (open) {
                state.presentCompletionItems(start, query, completionItems(mode, query), cast cx);
            } else {
                cx.notify();
            }
        });
        cx.notify();
    }

    function styledEditor(state:Entity<EditorState>):Editor {
        final editor = new Editor(state);
        if (fontFamily != null) editor.fontFamily(fontFamily);
        return editor
            .textSize(fontSize)
            .readonly(readonly)
            .sizeFull();
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final self:Context<EditorStory> = cast cx;
        final theme = Theme.global(cx.app);
        final content:IntoElement = switch activeTab {
            case 0: styledEditor(editorState);
            case 1: styledEditor(decorationsState);
            case _: vFlex()
                    .sizeFull()
                    .gap2()
                    .child(new Label('Type fl or log to compare highlights.')
                        .textSm()
                        .textColor(theme.mutedForeground))
                    .child(styledEditor(completionsState)
                        .flex1()
                        .minH0());
        }

        return vFlex()
            .sizeFull()
            .gap3()
            .child(hFlex()
                .justifyBetween()
                .child(new TabBar('editor-story-tabs')
                    .w(px(420.))
                    .underline()
                    .selectedIndex(activeTab)
                    .onClick(self.listener((this_:EditorStory, selected:Int, _, cx) -> {
                        this_.activeTab = selected;
                        cx.notify();
                    }))
                    .child(Tab.fromLabel('Code'))
                    .child(Tab.fromLabel('Decorations'))
                    .child(Tab.fromLabel('Completions')))
                .child(renderToolbar(self)))
            .child(div().minH0().flex1().child(content));
    }

}

private class StoryCompletions extends CompletionProviderBase {

    final highlight:HighlightCell;

    public function new(highlight:HighlightCell) {
        this.highlight = highlight;
    }

    public function completions(_text:Rope, _offset:Int, trigger:CompletionContext, _window:Window, _cx:App):Task<Array<CompletionItem>> {
        final query = trigger.triggerCharacter != null ? trigger.triggerCharacter : '';
        @:privateAccess final items = EditorStory.completionItems(highlight.value, query);
        return Task.ready(items);
    }

    public function isCompletionTrigger(_offset:Int, _newText:String, _cx:App):Bool {
        return true;
    }

}
