// Ported from gpui-kit 0.8.1: crates/story/src/lib.rs (StoryRoot)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story;

import glaze.AnyView;
import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.Window;
import glaze.kit.base.IndexPath;
import glaze.kit.TitleBar;
import glaze.kit.command.Command;
import glaze.kit.command.CommandItem.CommandEntry;
import glaze.kit.command.CommandState;
import glaze.kit.notification.Notification;
import glaze.kit.theme.Theme;
import story.StoryActions;
import story.Themes.SelectTheme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.WindowExt;

/** Notification ids (Rust local `struct Info;` and `struct Search;`). */
private class InfoNote {}

private class SearchNote {}

/**
 * The root view of a gallery window: the app title bar above the view, the
 * theme palette (`SelectTheme`) and the component palette
 * (`OpenCommandPalette`).
 */
class StoryRoot extends Model implements Render {

    public var focusHandle:FocusHandle;

    public var titleBar:Entity<AppTitleBar>;

    public var view:AnyView;

    public var embedded:Bool;

    /** The palette behind `SelectTheme`, rebuilt every time it opens. */
    var themePalette:Entity<CommandState>;

    /** Theme commands owned by this root and refreshed before the palette opens. */
    var themeEntries:Array<CommandEntry>;

    /** The component palette for Gallery windows. */
    var componentPalette:Entity<CommandState>;

    /** Component commands owned by this root and refreshed before the palette opens. */
    var componentEntries:Array<CommandEntry>;

    /** Whether this root currently owns an open component palette dialog. */
    var componentPaletteOpen:Bool;

    var gallery:Null<Entity<Gallery>>;

    /**
     * The theme in force when the palette opened, put back if the user
     * cancels out of the preview.
     */
    var themeBeforePreview:Null<String>;

    /**
     * Identifies the current preview session so deferred selection callbacks
     * from a closed palette cannot affect a newly opened one.
     */
    var themePreviewGeneration:Int;

    public function new(title:String, view:AnyView, window:Window, cx:Context<StoryRoot>) {
        super();
        final titleBar = cx.newEntity((cx:Context<AppTitleBar>) -> new AppTitleBar(title, window, cx));
        withTitleBar(titleBar, view, false, window, cx);
    }

    /**
     * Rust `StoryRoot::embedded`.
     */
    public static function embeddedRoot(view:AnyView, window:Window, cx:Context<StoryRoot>):StoryRoot {
        return new StoryRoot('', view, window, cx).markEmbedded();
    }

    function markEmbedded():StoryRoot {
        embedded = true;
        return this;
    }

    function withTitleBar(titleBar:Entity<AppTitleBar>, view:AnyView, embedded:Bool, window:Window, cx:Context<StoryRoot>):Void {
        final gallery = Std.downcast((view : Model), Gallery);
        final themePalette = cx.newEntity((cx:Context<CommandState>) -> new CommandState(window, cx));
        final componentPalette = cx.newEntity((cx:Context<CommandState>) -> new CommandState(window, cx));

        this.focusHandle = cx.focusHandle();
        this.titleBar = titleBar;
        this.view = view;
        this.embedded = embedded;
        this.themePalette = themePalette;
        this.themeEntries = [];
        this.componentPalette = componentPalette;
        this.componentEntries = [];
        this.componentPaletteOpen = false;
        this.gallery = gallery;
        this.themeBeforePreview = null;
        this.themePreviewGeneration = 0;
    }

    function onComponentPaletteConfirm(index:IndexPath, window:Window, cx:Context<StoryRoot>):Void {
        final gallery = this.gallery;
        if (gallery != null) {
            gallery.update(cx, (gallery, cx) -> {
                gallery.selectStoryIndex(index, window, cx);
            });
        }
        componentPaletteOpen = false;
        window.closeDialog(cx.app);
    }

    /**
     * Preview the highlighted theme while the palette is open: moving the
     * highlight applies the theme, Enter keeps it, Escape puts back the one
     * that was in force when the palette opened.
     */
    function onThemePaletteSelect(index:IndexPath, generation:Int, cx:Context<StoryRoot>):Void {
        if (themeBeforePreview == null || themePreviewGeneration != generation) {
            return;
        }

        final name = Themes.themeNameAt(index, cx);
        if (name != null) {
            Themes.applyTheme(name, cx);
        }
    }

    function onThemePaletteConfirm(window:Window, cx:Context<StoryRoot>):Void {
        themeBeforePreview = null;
        Themes.finishThemePreview(cx);
        window.closeDialog(cx.app);
    }

    function finishThemePreview(cx:Context<StoryRoot>):Void {
        final name = themeBeforePreview;
        themeBeforePreview = null;
        if (name != null) {
            Themes.applyTheme(name, cx);
        }
        Themes.finishThemePreview(cx);
    }

    function onActionPanelInfo(_:ShowPanelInfo, window:Window, cx:Context<StoryRoot>):Void {
        final note = new Notification().message('You have clicked panel info.').withId(InfoNote);
        window.pushNotification(note, cx.app);
    }

    /**
     * Opens the theme Command palette, refreshed from the registry so that a
     * theme added while the app is running shows up, and reset to an empty
     * query.
     */
    function onActionSelectTheme(_:SelectTheme, window:Window, cx:Context<StoryRoot>):Void {
        if (themeBeforePreview != null) {
            themePalette.read(cx).focusHandle(cx.app).focus(window, cx.app);
            return;
        }

        themeEntries = Themes.themeEntries(cx);
        themeBeforePreview = Theme.global(cx).themeName();
        themePreviewGeneration = themePreviewGeneration + 1;
        final themePreviewGeneration = this.themePreviewGeneration;
        Themes.beginThemePreview(cx);
        themePalette.update(cx, (palette, cx) -> {
            palette.setQuery('', window, cx);
        });
        cx.notify();

        final themePalette = this.themePalette;
        final storyRoot = cx.weakEntity();
        var focusOnMount = true;
        window.openDialog(cx.app, (dialog, _, _) -> {
            final closeOwner = storyRoot;
            final contentOwner = storyRoot;
            return dialog
                .closeButton(false)
                .overlayClosable(false)
                .p0()
                .onClose((_, _, cx) -> {
                    final root = closeOwner.upgrade();
                    if (root != null) root.update(cx, (root, cx) -> root.finishThemePreview(cx));
                })
                .content((content, window, cx) -> {
                    if (focusOnMount) {
                        focusOnMount = false;
                        window.defer(cx, (window, cx) -> {
                            themePalette.read(cx).focusHandle(cx).focus(window, cx);
                        });
                    }
                    final root = contentOwner.upgrade();
                    final entries = root != null ? root.read(cx).themeEntries.copy() : [];
                    final selectOwner = contentOwner;
                    final confirmOwner = contentOwner;
                    return content.child(Lib.withCommandEntries(new Command(themePalette)
                        .bordered(false)
                        .rounded(Theme.global(cx).radiusLg)
                        .placeholder('Search themes...')
                        .maxH(px(400.))
                        .onSelect((index, _, cx) -> {
                            final root = selectOwner.upgrade();
                            if (root != null) root.update(cx, (root, cx) -> root.onThemePaletteSelect(index, themePreviewGeneration, cx));
                        })
                        .onConfirm((_, window, cx) -> {
                            final root = confirmOwner.upgrade();
                            if (root != null) root.update(cx, (root, cx) -> root.onThemePaletteConfirm(window, cx));
                        }), entries));
                });
        });
    }

    function onActionOpenCommandPalette(_:OpenCommandPalette, window:Window, cx:Context<StoryRoot>):Void {
        final gallery = this.gallery;
        if (gallery == null) {
            cx.propagate();
            return;
        }
        if (componentPaletteOpen) {
            componentPalette.read(cx).focusHandle(cx.app).focus(window, cx.app);
            return;
        }

        componentEntries = gallery.read(cx).commandEntries(cx);
        componentPaletteOpen = true;
        componentPalette.update(cx, (palette, cx) -> {
            palette.setQuery('', window, cx);
        });
        cx.notify();

        final componentPalette = this.componentPalette;
        final storyRoot = cx.weakEntity();
        var focusOnMount = true;
        window.openDialog(cx.app, (dialog, _, _) -> {
            final closeOwner = storyRoot;
            final contentOwner = storyRoot;
            return dialog
                .closeButton(false)
                .overlayClosable(false)
                .p0()
                .onClose((_, _, cx) -> {
                    final root = closeOwner.upgrade();
                    if (root != null) root.update(cx, (root, _) -> root.componentPaletteOpen = false);
                })
                .content((content, window, cx) -> {
                    if (focusOnMount) {
                        focusOnMount = false;
                        window.defer(cx, (window, cx) -> {
                            componentPalette.read(cx).focusHandle(cx).focus(window, cx);
                        });
                    }
                    final root = contentOwner.upgrade();
                    final entries = root != null ? root.read(cx).componentEntries.copy() : [];
                    final confirmOwner = contentOwner;
                    return content.child(Lib.withCommandEntries(new Command(componentPalette)
                        .bordered(false)
                        .rounded(Theme.global(cx).radiusLg)
                        .placeholder('Search components...')
                        .maxH(px(400.))
                        .onConfirm((index, window, cx) -> {
                            final root = confirmOwner.upgrade();
                            if (root != null) root.update(cx, (root, cx) -> root.onComponentPaletteConfirm(index, window, cx));
                        }), entries));
                });
        });
    }

    function onActionToggleSearch(_:ToggleSearch, window:Window, cx:Context<StoryRoot>):Void {
        cx.propagate();
        if (window.hasFocusedInput(cx.app)) {
            return;
        }

        final note = new Notification().message('You have toggled search.').withId(SearchNote);
        window.pushNotification(note, cx.app);
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final self:Context<StoryRoot> = cast cx;
        final showFps = AppState.global(cx).showFpsMonitor;

        final column = vFlex().sizeFull();
        if (!embedded) column.child(titleBar);
        column.child(div()
            .trackFocus(focusHandle)
            .relative()
            .flex1()
            .overflowHidden()
            .child(view));

        final root = div()
            .id('story-root')
            .onAction(ShowPanelInfo, self.listener((this_:StoryRoot, a:ShowPanelInfo, w, c) -> this_.onActionPanelInfo(a, w, c)))
            .onAction(SelectTheme, self.listener((this_:StoryRoot, a:SelectTheme, w, c) -> this_.onActionSelectTheme(a, w, c)))
            .onAction(OpenCommandPalette, self.listener((this_:StoryRoot, a:OpenCommandPalette, w, c) -> this_.onActionOpenCommandPalette(a, w, c)))
            .onAction(ToggleSearch, self.listener((this_:StoryRoot, a:ToggleSearch, w, c) -> this_.onActionToggleSearch(a, w, c)))
            .sizeFull()
            .child(column)
            .relative();
        if (showFps) {
            // TODO: gpui-fps's `fps_monitor` (frame time, CPU, GPU and memory
            // HUD) is not ported: it reads OS process counters.
            root.child(div()
                .absolute()
                .top(TitleBar.TITLE_BAR_HEIGHT)
                .left0()
                .right0());
        }
        return root;
    }

}
