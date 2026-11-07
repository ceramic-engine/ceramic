// Ported from gpui-kit 0.8.1: crates/story/src/stories/tree_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.

package story.stories;

import gpui.App;
import gpui.Context;
import gpui.Entity;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.Model;
import gpui.Render;
import gpui.Window;
import gpui.Action;
import gpui.KeyBinding;
import gpui.Task;
import gpui.component.Icon;
import gpui.component.IconName;
import gpui.component.button.Button;
import gpui.component.dock.PanelControl;
import gpui.component.label.Label;
import gpui.component.list.ListItem;
import gpui.component.theme.Theme;
import gpui.component.tree.Tree;

import gpui.Prelude.*;
import gpui.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using gpui.base.StyledExt;

@:action(namespace = story) private class Rename implements Action {}

@:action(namespace = story) private class OpenFile implements Action {}

@:action(namespace = story) private class Delete implements Action {}

/**
 * The file tree story. The original lists the files of its working directory
 * on native targets (with autocorrect's `.gitignore` filter) and shows a
 * fixed example tree on the web (`target_family = "wasm"`). The port has no
 * directory listing through Ceramic, so it always shows the example tree.
 */
class TreeStory extends Model implements Story {

    static inline final CONTEXT = 'TreeStory';

    public static function title():String {
        return 'Tree';
    }

    public static function zoomable():Null<PanelControl> {
        return null;
    }

    public static function init(cx:App):Void {
        cx.bindKeys([new KeyBinding('enter', new Rename(), CONTEXT)]);
    }

    public static function newView(window:Window, cx:App):gpui.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<TreeStory> {
        return cx.newEntity((c:Context<TreeStory>) -> new TreeStory(window, c));
    }

    /** Rust `example_file_items` (the `target_family = "wasm"` variant). */
    static function exampleFileItems():Array<TreeItem> {
        return [
            new TreeItem('gpui-component', 'gpui-component')
                .expanded(true)
                .withChildren([
                    new TreeItem('gpui-component/crates', 'crates')
                        .expanded(true)
                        .withChildren([
                            new TreeItem('gpui-component/crates/component', 'ui')
                                .expanded(true)
                                .withChildren([
                                    new TreeItem('gpui-component/crates/component/src', 'src').withChildren([
                                        new TreeItem('gpui-component/crates/component/src/tree.rs', 'tree.rs'),
                                        new TreeItem('gpui-component/crates/component/src/list/mod.rs', 'mod.rs'),
                                    ]),
                                    new TreeItem('gpui-component/crates/component/Cargo.toml', 'Cargo.toml'),
                                ]),
                            new TreeItem('gpui-component/crates/story', 'story').withChildren([
                                new TreeItem('gpui-component/crates/story/src/stories/tree_story.rs', 'tree_story.rs'),
                                new TreeItem('gpui-component/crates/story/src/gallery.rs', 'gallery.rs'),
                            ]),
                        ]),
                    new TreeItem('gpui-component/README.md', 'README.md'),
                ]),
        ];
    }

    static function loadTreeItems(_:String):Array<TreeItem> {
        return exampleFileItems();
    }

    final treeState:Entity<TreeState>;

    @observe var items:Array<TreeItem> = [];

    function new(_:Window, cx:Context<TreeStory>) {
        super();
        treeState = cx.newEntity((cx:Context<TreeState>) -> new TreeState(cx));
        loadFiles(treeState, './', cx);
    }

    static function loadFiles(state:Entity<TreeState>, path:String, cx:Context<TreeStory>):Void {
        cx.spawn((weakSelf, acx) -> {
            final items = loadTreeItems(path);
            state.update(acx, (state, cx) -> state.setItems(items.copy(), cx));
            if (weakSelf.isUpgradable()) weakSelf.update(acx, (this_, _) -> this_.items = items);
            return Task.done();
        }).detach();
    }

    function onActionRename(_:Rename, _:Window, cx:App):Void {
        final entry = treeState.read(cx).selectedEntry();
        if (entry != null) {
            final item = entry.item();
            trace('Renaming item: ${item.label} (${item.id})');
        }
    }

    function onActionOpen(_:OpenFile, _:Window, cx:App):Void {
        final entry = treeState.read(cx).selectedEntry();
        if (entry != null) {
            final item = entry.item();
            trace('Opening item: ${item.label} (${item.id})');
        }
    }

    function onActionDelete(_:Delete, _:Window, cx:App):Void {
        final entry = treeState.read(cx).selectedEntry();
        if (entry != null) {
            final item = entry.item();
            trace('Deleting item: ${item.label} (${item.id})');
        }
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        final state = treeState.read(cx.app);
        final selectedIndex = state.selectedIndex();
        final selectedItem = state.selectedItem();
        return vFlex()
            .wFull()
            .gap3()
            .id('tree-story')
            .keyContext(CONTEXT)
            .onAction(Rename, onActionRename)
            .onAction(OpenFile, onActionOpen)
            .onAction(Delete, onActionDelete)
            .child(hFlex().gap3().child(new Button('select-item')
                .outline()
                .label('Select Item')
                .onClick((_, _, cx) -> {
                    if (items.length > 0) {
                        final randomItem = items[Std.random(items.length)];
                        treeState.update(cx, (state, cx) -> state.setSelectedItem(randomItem, cx));
                    }
                })))
            .child(section('File tree')
                .subTitle('Press `enter` to rename. Right-click for context menu.')
                .w(px(480.))
                .child(vFlex()
                    .wFull()
                    .gap4()
                    .child(Tree.tree(treeState, (ix, entry, _, _, cx) -> {
                        final item = entry.item();
                        final icon = if (!entry.isFolder()) {
                            IconName.File;
                        } else if (entry.isExpanded()) {
                            IconName.FolderOpen;
                        } else {
                            IconName.Folder;
                        }
                        return new ListItem(ix)
                            .wFull()
                            .rounded(Theme.global(cx).radius)
                            .px3()
                            .pl(px(16. * entry.depth() + 12.))
                            .child(hFlex().gap2().child(new Icon(icon)).child(item.label))
                            .onClick((_, _, _) -> trace('Clicked on item: ${item.label} (${item.id})'));
                    })
                        .contextMenu((_, entry, menu, _, _) -> {
                            final isFolder = entry.isFolder();
                            if (!isFolder) menu = menu.menu('Open', new OpenFile());
                            return menu.menu('Rename', new Rename())
                                .separator()
                                .menu('Delete', new Delete());
                        })
                        .p1()
                        .border1()
                        .borderColor(theme.border)
                        .rounded(theme.radius)
                        .h(px(540.)))
                    .child(hFlex()
                        .wFull()
                        .justifyBetween()
                        .gap3()
                        .children(selectedIndex != null ? [('Selected Index: $selectedIndex' : IntoElement)] : [])
                        .children(selectedItem != null ? [(new Label('Selected:').secondary(selectedItem.id) : IntoElement)] : []))));
    }

}
