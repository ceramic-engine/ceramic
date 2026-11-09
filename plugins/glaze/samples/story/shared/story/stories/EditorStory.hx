// Adapted from gpui-kit 0.8.1: crates/story/src/stories/editor_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: the code editor of the story is Cityscape (plugin `cityscape`),
// Glaze's code editor, instead of gpui-kit's. See NOTICE.md.
package story.stories;

#if plugin_cityscape

import cityscape.Cityscape;
import cityscape.CityscapeEditor;
import cityscape.base.common.Cancellation.CancellationToken;
import cityscape.common.Languages.CompletionContext;
import cityscape.common.Languages.CompletionItem;
import cityscape.common.Languages.CompletionItemProvider;
import cityscape.common.Languages.CompletionList;
import cityscape.common.Model.ITextModel;
import cityscape.common.config.EditorOptions.IEditorOptions;
import cityscape.common.core.Position;
import cityscape.common.core.Range;
import cityscape.common.languages.CompletionItemKind;
import cityscape.common.model.TextModel;
import cityscape.kit.KitGrammars;
import cityscape.standalone.common.VSCodeDefaultThemes;
import glaze.AnyView;
import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Pixels;
import glaze.Window;
import glaze.kit.button.Button;
import glaze.kit.label.Label;
import glaze.kit.menu.PopupMenu.PopupMenuItem;
import glaze.kit.tab.Tab;
import glaze.kit.tab.TabBar;
import glaze.kit.theme.Theme;
import story.Story;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Lib.*;

using glaze.kit.base.StyledExt;

/**
 * The code editor story: gpui-kit's editor story with Glaze's code editor,
 * Cityscape (`CityscapeEditor`, a port of Monaco). Three tabs:
 *
 * - Code: a Rust file (the bundled TextMate grammar) with folding;
 * - Decorations: Cityscape's typed decoration styles (text color, weight,
 *   italic, underline, and boxes behind a range: a fill and a frame) that
 *   follow the edits;
 * - Completions: a completion provider (Monaco's API) with words chosen so
 *   that `fl` and `log` match different spans with Monaco's fuzzy filter.
 *
 * The editors follow the kit theme mode with VS Code's Dark+ and Light+
 * themes. The Options menu sets read-only, the font family and the size.
 */
class EditorStory extends Model implements Story {

    static final EXAMPLE_CODE:String = story.Include.str('editor_preview.rs');

    /** Words chosen so `fl` and `log` light up different spans. */
    static final COMPLETION_WORDS:Array<String> = ['flag', 'profile', 'file_loader', 'fallback', 'dialog_log', 'catalog'];

    /** The font families to offer beside the theme's own monospace one. */
    static final FONT_FAMILIES:Array<String> = ['Menlo', 'Consolas', 'Monaco'];

    /** The font sizes to switch the editor between. */
    static final FONT_SIZES:Array<Pixels> = [px(11.), px(13.), px(16.), px(20.)];

    static final DECORATION_TEXT = 'Decoration styles\nColor highlights important text.\nItalic adds emphasis.\nUnderline marks review text.\n\nFill: marks a tracked range.\n\nFrame: outlines a tracked range.';

    /** The Cityscape context of the story's editors (languages, theme, providers). */
    final context:Cityscape;

    final codeModel:TextModel;
    final decorationsModel:TextModel;
    final completionsModel:TextModel;
    var activeTab:Int;
    var readonly:Bool;
    var fontFamily:Null<String>;
    var fontSize:Pixels;
    var grammarRequested:Bool = false;

    public static function title():String {
        return 'Editor';
    }

    public static function description():String {
        return 'Code editor (Cityscape) with syntax highlighting, folding, decorations and completions.';
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

    function new(window:Window, cx:Context<EditorStory>) {
        super();
        context = new Cityscape();
        context.languageService.registerLanguage({id: 'rust', extensions: ['.rs'], aliases: ['Rust']});
        context.languageService.registerLanguage({id: 'plaintext', extensions: ['.txt'], aliases: ['Plain Text']});
        context.languageConfigurationService.register('rust', {
            comments: {lineComment: '//', blockComment: ['/*', '*/']},
            brackets: [['{', '}'], ['[', ']'], ['(', ')']],
            autoClosingPairs: [{open: '{', close: '}'}, {open: '[', close: ']'}, {open: '(', close: ')'}, {open: '"', close: '"', notIn: ['string']}],
        });
        context.registerCompletionItemProvider('plaintext', new StoryCompletions());
        VSCodeDefaultThemes.apply(context, Theme.global(cx.app).isDark());

        codeModel = new TextModel(EXAMPLE_CODE, 'rust', TextModel.DEFAULT_CREATION_OPTIONS, null, context);
        codeModel.updateOptions({tabSize: 4, insertSpaces: true});
        decorationsModel = new TextModel(DECORATION_TEXT, 'plaintext', TextModel.DEFAULT_CREATION_OPTIONS, null, context);
        completionsModel = new TextModel('', 'plaintext', TextModel.DEFAULT_CREATION_OPTIONS, null, context);
        addDecorations();
        requestGrammar(cx);

        activeTab = 0;
        readonly = false;
        fontFamily = null;
        fontSize = Theme.global(cx.app).monoFontSize;
    }

    /**
     * The Rust grammar bundled with Glaze. On the web its file is loaded
     * first (`Highlighter.preload`), then the code is colored.
     */
    function requestGrammar(cx:Context<EditorStory>):Void {
        if (KitGrammars.register(context, 'rust') || grammarRequested) {
            return;
        }
        grammarRequested = true;
        final story = cx.weakEntity();
        final app = cx.app;
        glaze.kit.highlighter.Highlighter.preload(['rust'], ok -> {
            if (ok && KitGrammars.register(context, 'rust')) {
                story.tryUpdate(app, (_, cx) -> cx.notify());
            }
        });
    }

    /**
     * The typed decoration styles of Cityscape: what Monaco does with CSS
     * classes. The ranges follow the edits, newlines included.
     */
    function addDecorations():Void {
        final model = decorationsModel;
        function range(needle:String):Range {
            final start = model.getPositionAt(DECORATION_TEXT.indexOf(needle));
            final end = model.getPositionAt(DECORATION_TEXT.indexOf(needle) + needle.length);
            return new Range(start.lineNumber, start.column, end.lineNumber, end.column);
        }
        model.deltaDecorations([], [
            {range: range('Decoration styles'), options: {description: 'title', inlineStyle: {color: '#e5534b', fontWeight: 'bold', background: '#c69026', borderRadius: 3}}},
            {range: range('Color'), options: {description: 'color', inlineStyle: {color: '#57ab5a', fontWeight: 'bold', fontStyle: 'italic'}}},
            {range: range('Italic'), options: {description: 'italic', inlineStyle: {color: '#539bf5', fontStyle: 'italic'}}},
            {range: range('Underline'), options: {description: 'underline', inlineStyle: {underline: {color: '#c69026', thickness: 2, wavy: true}}}},
            // Geometry behind the text: a fill and a frame
            {range: range('marks a tracked range.'), options: {description: 'fill', style: {background: {id: 'editor.findMatchHighlightBackground'}, borderRadius: 3}}},
            {range: range('outlines a tracked range.'), options: {description: 'frame', style: {border: {color: {id: 'editor.foreground'}, width: 1}, borderRadius: 3}}},
        ]);
    }

    function renderToolbar(cx:Context<EditorStory>):IntoElement {
        final story = cx.entity();
        final readonly = this.readonly;
        final family = this.fontFamily;
        final size = this.fontSize;

        return storyToolbarGroup().dropdownChild(Button.component('editor-options').label('Options'), (menu, window, _) -> {
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
            return menu;
        });
    }

    /** Rust `Pixels::to_string` (`11px`). */
    static function pixelsLabel(value:Pixels):String {
        final f:Float = value;
        return (f == Math.ffloor(f) ? Std.string(Std.int(f)) : Std.string(f)) + 'px';
    }

    function editor(key:String, model:ITextModel, theme:Theme, options:IEditorOptions):CityscapeEditor {
        return CityscapeEditor.component()
            .at(key)
            .model(model)
            .context(context)
            .options(options)
            .fontFamily(fontFamily != null ? fontFamily : theme.monoFontFamily)
            .fontSize(fontSize)
            .readOnly(readonly)
            .sizeFull();
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final self:Context<EditorStory> = cast cx;
        final theme = Theme.global(cx.app);
        VSCodeDefaultThemes.apply(context, theme.isDark());
        final content:IntoElement = switch activeTab {
            case 0: editor('code', codeModel, theme, {lineNumbers: 'on', folding: true, padding: {top: 8}});
            case 1: editor('decorations', decorationsModel, theme, {lineNumbers: 'on', wordWrap: 'on', padding: {top: 8}});
            case _: vFlex()
                    .sizeFull()
                    .gap2()
                    .child(Label.component('Type fl or log to see the completions.')
                        .textSm()
                        .textColor(theme.mutedForeground))
                    .child(div().flex1().minH0().border1().borderColor(theme.border).rounded(theme.radius).overflowHidden()
                        .child(editor('completions', completionsModel, theme, {lineNumbers: 'off', padding: {top: 8}})));
        }

        return vFlex()
            .sizeFull()
            .gap3()
            .child(hFlex()
                .justifyBetween()
                .child(TabBar.component('editor-story-tabs')
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

/**
 * The completions of the story (Monaco's completion provider API): every
 * word of `COMPLETION_WORDS`, filtered and highlighted by Monaco's fuzzy
 * matching as the user types.
 */
private class StoryCompletions implements CompletionItemProvider {

    public var _debugDisplayName(default, null):Null<String> = 'story';
    public var triggerCharacters(default, null):Null<Array<String>> = null;
    public var resolveCompletionItem(default, null):Null<(item:CompletionItem, token:CancellationToken, resolve:(item:Null<CompletionItem>) -> Void) -> Void> = null;

    public function new() {}

    public function provideCompletionItems(model:ITextModel, position:Position, context:CompletionContext, token:CancellationToken,
            resolve:(list:Null<CompletionList>) -> Void):Void {
        final word = model.getWordUntilPosition(position);
        final range = new Range(position.lineNumber, word.startColumn, position.lineNumber, word.endColumn);
        resolve({
            suggestions: [
                for (label in @:privateAccess EditorStory.COMPLETION_WORDS)
                    {label: label, kind: CompletionItemKind.Text, insertText: label, range: range}
            ]
        });
    }

}

#else

import glaze.AnyView;
import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Window;
import glaze.kit.theme.Theme;
import story.Story;

import glaze.Prelude.*;

/**
 * The code editor story without the `cityscape` plugin (a project that does
 * not list it, like Glaze's golden tests): the page says so, the gallery
 * keeps its entry.
 */
class EditorStory extends Model implements Story {

    public static function title():String {
        return 'Editor';
    }

    public static function description():String {
        return 'Code editor (Cityscape) with syntax highlighting, folding, decorations and completions.';
    }

    public static function closable():Bool {
        return false;
    }

    public static function newView(window:Window, cx:App):AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<EditorStory> {
        return cx.newEntity((_:Context<EditorStory>) -> new EditorStory());
    }

    function new() {
        super();
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        return div().textColor(Theme.global(cx.app).mutedForeground).child('Glaze\'s code editor is Cityscape: list the cityscape plugin in ceramic.yml to show it here.');
    }

}

#end
