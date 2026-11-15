// New tests for the Haxe port of gpui-kit (no gpui-kit origin): the kit additions without upstream
// equivalent (KIT-nnn in docs/DEVIATIONS.md). See NOTICE.md.
package tests.kit;

import glaze.AnyView;
import glaze.Context;
import glaze.ElementId;
import glaze.Entity;
import glaze.IntoElement;
import glaze.Model;
import glaze.Modifiers;
import glaze.MouseDownEvent;
import glaze.MouseUpEvent;
import glaze.Point;
import glaze.Render;
import glaze.Window;
import glaze.kit.list.ListItem;
import glaze.kit.theme.Theme;
import glaze.kit.tree.Tree;
import glaze.kit.tree.Tree.TreeEvent;
import glaze.kit.tree.Tree.TreeItem;
import glaze.kit.tree.Tree.TreeState;
import testing.VisualTestContext;

import glaze.Prelude.*;

/**
 * The tree additions without upstream equivalent (KIT-004): explicit
 * folders, the selection kept across `setItems`, no toggle on a single
 * click, the navigation keys, drag and drop of the rows.
 */
class KitTreeAdditionsTest extends KitAdditionsTestCase {

    var tree:Entity<TreeState>;

    function newTree(items:Array<TreeItem>):Entity<TreeState> {
        tree = app.update(cx -> cx.newEntity((tc:Context<TreeState>) -> new TreeState(tc).items(items)));
        return tree;
    }

    function state():TreeState {
        return tree.read(app);
    }

    /** A 300 x 240 tree in a kit root, focused; `configure` sets its options. */
    function show(?configure:(Tree) -> Tree):VisualTestContext {
        final cx = open((_, _) -> {
            final tree = Tree.component(tree, (ix, entry, _, _, _) -> new ListItem(ElementId.NamedInteger('file', ix)).child(probe('row-' + entry.item().id, div().child(entry.item().label))));
            return div().w(px(300.)).h(px(240.)).child(configure != null ? configure(tree) : tree);
        }, 480, 320, true);
        cx.update((window, app) -> tree.update(app, (tree, cx) -> tree.focus(window, cx)));
        frame(cx);
        return cx;
    }

    function frame(cx:VisualTestContext):Void {
        cx.runUntilParked();
        cx.update((window, _) -> {
            window.refresh();
            window.draw();
        });
        cx.runUntilParked();
    }

    function click(cx:VisualTestContext, id:String, count:Int = 1):Void {
        final position = boundsOf(cx, 'row-$id').center();
        cx.simulateMouseMove(position);
        for (n in 1...count + 1) {
            cx.simulateEvent(new MouseDownEvent(Left, position, Modifiers.none(), n, false));
            cx.simulateEvent(new MouseUpEvent(Left, position, Modifiers.none(), n));
        }
        frame(cx);
    }

    function project():Array<TreeItem> {
        return [
            new TreeItem('src', 'src').child(new TreeItem('main', 'main.lor')).child(new TreeItem('lib', 'lib.lor')),
            new TreeItem('empty', 'empty').folder(true),
            new TreeItem('readme', 'readme'),
        ];
    }

    function testAnItemIsAFolderByItsChildrenUnlessToldOtherwise() {
        assertFalse(new TreeItem('a', 'a').isFolder());
        assertTrue(new TreeItem('a', 'a').child(new TreeItem('b', 'b')).isFolder());
        assertTrue(new TreeItem('a', 'a').folder(true).isFolder());
        assertTrue(new TreeItem('a', 'a').folder(true).clone().isFolder());
        assertFalse(new TreeItem('a', 'a').child(new TreeItem('b', 'b')).folder(false).isFolder());
    }

    function testAnEmptyFolderExpandsAndCollapses() {
        newTree(project());
        final events:Array<String> = [];
        app.update(cx -> cx.subscribe(tree, TreeEvent, (_, event:TreeEvent, _) -> events.push(Std.string(event))));
        final cx = show();
        assertTrue(state().entry(1).isFolder());
        assertFalse(state().entry(2).isFolder());
        click(cx, 'empty');
        assertTrue(state().entry(1).isExpanded());
        assertEquals(3, @:privateAccess state().entries.length);
        click(cx, 'empty');
        assertFalse(state().entry(1).isExpanded());
        // A leaf is selected, nothing more.
        click(cx, 'readme');
        assertEquals(2, state().selectedIndex());
        assertEquals('Expanded(empty),Collapsed(empty)', events.join(','));
    }

    function testSetItemsKeepsTheSelectionByIdWhenAsked() {
        newTree(project());
        final cx = show();
        click(cx, 'readme');
        assertEquals(2, state().selectedIndex());

        // The watcher rebuilt the list: a file appeared before the selection.
        final rebuilt = project();
        rebuilt.insert(0, new TreeItem('assets', 'assets').folder(true));
        cx.update((_, app) -> tree.update(app, (tree, cx) -> tree.setItems(rebuilt, cx, true)));
        frame(cx);
        assertEquals(3, state().selectedIndex());
        assertEquals('readme', state().selectedItem().id);

        // Its item gone, the selection goes.
        cx.update((_, app) -> tree.update(app, (tree, cx) -> tree.setItems([new TreeItem('other', 'other')], cx, true)));
        assertEquals(null, state().selectedIndex());

        // gpui-kit's behaviour without the argument: the selection is dropped.
        cx.update((_, app) -> tree.update(app, (tree, cx) -> {
            tree.setItems(project(), cx);
            tree.setSelectedIndex(2, cx);
            tree.setItems(project(), cx);
        }));
        assertEquals(null, state().selectedIndex());
    }

    function testWithoutToggleOnClickAClickOnlySelects() {
        newTree(project());
        final cx = show(tree -> tree.toggleOnClick(false));
        click(cx, 'src');
        assertEquals(0, state().selectedIndex());
        assertFalse(state().entry(0).isExpanded());
        // A double click toggles, and so do the keys and the state.
        click(cx, 'src', 2);
        assertTrue(state().entry(0).isExpanded());
        cx.simulateKeystrokes('left');
        frame(cx);
        assertFalse(state().entry(0).isExpanded());
        cx.update((_, app) -> tree.update(app, (tree, cx) -> tree.toggleExpanded(0, cx)));
        assertTrue(state().entry(0).isExpanded());
    }

    function testByDefaultAClickTogglesAFolder() {
        newTree(project());
        final cx = show();
        click(cx, 'src');
        assertTrue(state().entry(0).isExpanded());
        click(cx, 'src');
        assertFalse(state().entry(0).isExpanded());
    }

    function many():Array<TreeItem> {
        return [for (i in 0...40) new TreeItem('item-$i', 'Item $i')];
    }

    function testNavigationKeysMoveTheSelection() {
        newTree(many());
        final cx = show(tree -> tree.navigationKeys(true));
        cx.simulateKeystrokes('end');
        frame(cx);
        assertEquals(39, state().selectedIndex());
        cx.simulateKeystrokes('home');
        frame(cx);
        assertEquals(0, state().selectedIndex());
        cx.simulateKeystrokes('pagedown');
        frame(cx);
        final page = state().selectedIndex();
        assertTrue(page > 1 && page < 20, 'a page is $page entries');
        // The page is what fits in the tree, less one entry.
        final rowHeight = boundsOf(cx, 'row-item-${page + 1}').top() - boundsOf(cx, 'row-item-$page').top();
        assertEquals(Math.floor(240. / rowHeight) - 1, page);
        cx.simulateKeystrokes('pagedown');
        frame(cx);
        assertEquals(page * 2, state().selectedIndex());
        cx.simulateKeystrokes('pageup');
        frame(cx);
        assertEquals(page, state().selectedIndex());
        cx.simulateKeystrokes('pageup pageup');
        frame(cx);
        assertEquals(0, state().selectedIndex());
        cx.simulateKeystrokes('end pagedown');
        frame(cx);
        assertEquals(39, state().selectedIndex());
        // The selection is scrolled into view.
        final last = boundsOf(cx, 'row-item-39');
        assertTrue(last.bottom() <= 240.5 && last.top() >= 0., 'last row at ${last.top()}');
    }

    function testLeftGoesToTheParent() {
        newTree([new TreeItem('src', 'src').expanded(true).child(new TreeItem('sub', 'sub').folder(true)).child(new TreeItem('main', 'main.lor'))]);
        final cx = show(tree -> tree.navigationKeys(true));
        click(cx, 'main');
        assertEquals(2, state().selectedIndex());
        cx.simulateKeystrokes('left');
        frame(cx);
        assertEquals(0, state().selectedIndex());
        assertTrue(state().entry(0).isExpanded());
        // On the expanded parent, left collapses as before.
        cx.simulateKeystrokes('left');
        frame(cx);
        assertFalse(state().entry(0).isExpanded());
        // A root has no parent.
        cx.simulateKeystrokes('left');
        frame(cx);
        assertEquals(0, state().selectedIndex());
    }

    function testWithoutNavigationKeysTheKeysDoNothing() {
        newTree([new TreeItem('src', 'src').expanded(true).child(new TreeItem('main', 'main.lor')), new TreeItem('b', 'b'), new TreeItem('c', 'c')]);
        final cx = show();
        click(cx, 'main');
        for (key in ['left', 'end', 'home', 'pagedown', 'pageup']) {
            cx.simulateKeystrokes(key);
            frame(cx);
            assertEquals(1, state().selectedIndex(), key);
        }
    }

    function dragTree(drops:Array<String>):VisualTestContext {
        newTree([
            new TreeItem('main', 'main.lor'),
            new TreeItem('docs', 'docs').folder(true),
            new TreeItem('notes', 'notes.lor'),
        ]);
        return show(tree -> tree
            .dragEntries((ix, entry) -> entry.item().id == 'docs' ? null : new DraggedFile(entry.item().id),
                (_, _, _, cx) -> (cx.newEntity((_:Context<DraggedFilePreview>) -> new DraggedFilePreview()) : AnyView))
            .dropOnEntries(DraggedFile, (file, ix, entry, _, _) -> drops.push('${file.id} on ${entry.item().id} ($ix)'),
                (file, _, entry, _, _) -> entry.isFolder() && entry.item().id != file.id)
            .dropOnRoot(DraggedFile, (file, _, _) -> drops.push('${file.id} on root'), (file, _, _) -> file.id != 'notes'));
    }

    function drag(cx:VisualTestContext, from:String, to:Point):Void {
        final start = boundsOf(cx, 'row-$from').center();
        cx.simulateMouseMove(start);
        cx.simulateMouseDown(start, Left);
        cx.simulateMouseMove(start.add(point(px(8.), px(0.))), Left);
        frame(cx);
        cx.simulateMouseMove(to, Left);
        frame(cx);
    }

    function drop(cx:VisualTestContext, at:Point):Void {
        cx.simulateEvent(new MouseUpEvent(Left, at, Modifiers.none(), 1));
        frame(cx);
    }

    function testARowDraggedOnAFolderIsDroppedOnIt() {
        final drops:Array<String> = [];
        final cx = dragTree(drops);
        final theme = cx.update((_, app) -> Theme.global(app));
        final docs = boundsOf(cx, 'row-docs').center();
        assertEquals(0, quadsFilled(cx, theme.dropTarget).length);

        drag(cx, 'main', docs);
        // The folder under the drag is highlighted (the tree too: it takes the drop elsewhere).
        final highlighted = [for (entry in quadsFilled(cx, theme.dropTarget)) if (entry.bounds.size.height < 100. && entry.bounds.contains(docs)) entry];
        assertEquals(1, highlighted.length);
        drop(cx, docs);
        assertEquals('main on docs (1)', drops.join(','));
        assertEquals(0, quadsFilled(cx, theme.dropTarget).length);
        // The press that started the drag selected nothing.
        assertEquals(null, state().selectedIndex());
    }

    function testARowThatRefusesTheDropNeitherHighlightsNorTakesIt() {
        final drops:Array<String> = [];
        final cx = dragTree(drops);
        final theme = cx.update((_, app) -> Theme.global(app));
        final notes = boundsOf(cx, 'row-notes').center();
        drag(cx, 'main', notes);
        final rows = [for (entry in quadsFilled(cx, theme.dropTarget)) if (entry.bounds.size.height < 100.) entry];
        assertEquals(0, rows.length);
        drop(cx, notes);
        assertEquals('', drops.join(','));
    }

    function testADropOutsideTheRowsGoesToTheRoot() {
        final drops:Array<String> = [];
        final cx = dragTree(drops);
        final theme = cx.update((_, app) -> Theme.global(app));
        final below = point(px(150.), px(200.));
        drag(cx, 'main', below);
        assertEquals(1, [for (entry in quadsFilled(cx, theme.dropTarget)) if (entry.bounds.size.height > 200.) entry].length);
        drop(cx, below);
        assertEquals('main on root', drops.join(','));

        // The root has its own rule.
        drag(cx, 'notes', below);
        assertEquals(0, quadsFilled(cx, theme.dropTarget).length);
        drop(cx, below);
        assertEquals('main on root', drops.join(','));
    }

    function testARowWithoutAValueDoesNotDrag() {
        final drops:Array<String> = [];
        final cx = dragTree(drops);
        final below = point(px(150.), px(200.));
        drag(cx, 'docs', below);
        drop(cx, below);
        assertEquals('', drops.join(','));
    }

}

private class DraggedFile {

    public final id:String;

    public function new(id:String) {
        this.id = id;
    }

}

private class DraggedFilePreview extends Model implements Render {

    public function new() {
        super();
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div().size(px(10.));
    }

}
