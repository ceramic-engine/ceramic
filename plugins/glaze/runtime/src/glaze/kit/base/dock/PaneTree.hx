// Ported from gpui-kit 0.8.1: crates/base/src/dock/layout/tree.rs, crates/base/src/dock/layout/edit.rs,
// crates/base/src/dock/layout/normalize.rs, crates/base/src/dock/layout/builder.rs (`PaneTree::from_layout`),
// crates/base/src/dock/state_convert.rs (`PaneTree::to_state`, `PaneTree::from_state`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.dock;

import glaze.Axis;
import glaze.Pixels;
import glaze.SpringMath;
import glaze.kit.base.Geometry.Placement;
import glaze.kit.base.dock.JsonValue;
import glaze.kit.base.dock.PaneNode;

using glaze.kit.base.dock.PanelInfo.PanelInfoTools;

/**
 * Path from the root as a sequence of child indices (Rust `NodePath`).
 */
typedef NodePath = Array<Int>;

/**
 * One region's layout, as pure data.
 *
 * A `DockArea` owns one of these per region: the center plus each dock it
 * has. Containers are addressed by `NodeId` and panels by `PanelId`; no
 * entity handle lives in here, so a tree can be built, edited, compared and
 * serialized with no `App` in sight.
 *
 * Every edit method normalizes before returning and reports what it did as
 * an `EditResult`, so there is no window in which a caller can observe a tree
 * with an empty container, a one-child split, or an out-of-range active index.
 *
 * Rust spreads the `impl PaneTree` blocks over the layout modules and
 * `state_convert.rs`; they are gathered here.
 */
class PaneTree {

    /**
     * Upper bound on `normalize` passes. Every pass that changes anything
     * strictly reduces node count or nesting depth, so real dock layouts
     * converge in a small handful of passes; this is a generous ceiling
     * against a future rule change that fights another rule rather than a
     * bound tuned to today's rule set.
     */
    static inline final MAX_NORMALIZE_PASSES:Int = 64;

    /**
     * The names written to persisted layouts. These are contract, not type
     * names: they must keep their values even if the types are renamed.
     */
    public static inline final STACK_PANEL_NAME:String = 'StackPanel';

    public static inline final TAB_PANEL_NAME:String = 'TabPanel';

    /**
     * Source of every `NodeId`, shared by every tree in the process.
     *
     * A per-tree counter would restart at the same value in each tree, and a
     * `DockArea` owns four of them (the center plus one per dock). Its entity
     * cache is keyed by `NodeId` alone, so two trees minting the same id would
     * hand two different containers the same cache slot. Allocating globally
     * is what makes `NodeId` the stable container identity its documentation
     * claims, rather than an identity that is only unique within one tree.
     */
    static var NEXT_NODE_ID:Int = 0;

    static function nextNodeId():NodeId {
        return NodeId.fromU64(NEXT_NODE_ID++);
    }

    var rootValue:PaneNode;

    var rootKindValue:RootKind;

    public function new(rootKind:RootKind) {
        rootValue = new PaneNode(nextNodeId(), NodeKind.Split(Axis.Horizontal, [], []));
        rootKindValue = rootKind;
    }

    public inline function root():PaneNode {
        return rootValue;
    }

    public inline function rootKind():RootKind {
        return rootKindValue;
    }

    @:allow(glaze.kit.base.dock)
    function allocateNodeId():NodeId {
        return nextNodeId();
    }

    /**
     * Every container id in the tree, in pre-order.
     */
    public function nodeIds():Array<NodeId> {
        final ids:Array<NodeId> = [];
        rootValue.walk(node -> ids.push(node.id()));
        return ids;
    }

    /**
     * Every panel in the tree, in pre-order.
     */
    public function panels():Array<PanelId> {
        final found:Array<PanelId> = [];
        rootValue.walk(node -> switch node.kindRef() {
            case Tabs(panels, _): for (panel in panels) found.push(panel);
            case Split(_, _, _):
        });
        return found;
    }

    public function findNode(id:NodeId):Null<PaneNode> {
        final path = pathOfNode(id);
        return path != null ? nodeAt(path) : null;
    }

    /**
     * The tab node holding `panel`.
     */
    public function findPanelNode(panel:PanelId):Null<NodeId> {
        var found:Null<NodeId> = null;
        rootValue.walk(node -> {
            final holds = switch node.kindRef() {
                case Tabs(panels, _): panels.contains(panel);
                case Split(_, _, _): false;
            }
            if (holds) found = node.id();
        });
        return found;
    }

    @:allow(glaze.kit.base.dock)
    function pathOfNode(id:NodeId):Null<NodePath> {
        final path:NodePath = [];
        return search(rootValue, id, path) ? path : null;
    }

    static function search(node:PaneNode, id:NodeId, path:NodePath):Bool {
        if (node.id() == id) return true;
        switch node.kindRef() {
            case Split(_, children, _):
                for (ix in 0...children.length) {
                    path.push(ix);
                    if (search(children[ix], id, path)) return true;
                    glaze.util.Stacks.drop(path);
                }
            case Tabs(_, _):
        }
        return false;
    }

    @:allow(glaze.kit.base.dock)
    function nodeAt(path:NodePath):PaneNode {
        var node = rootValue;
        for (ix in path) {
            switch node.kindRef() {
                case Split(_, children, _): node = children[ix];
                case Tabs(_, _): throw 'path traverses a non-split node';
            }
        }
        return node;
    }

    /**
     * Rust `*self.node_at_mut(path) = node`.
     */
    function replaceAt(path:NodePath, node:PaneNode):Void {
        if (path.length == 0) {
            rootValue = node;
            return;
        }
        final parent = nodeAt(path.slice(0, path.length - 1));
        switch parent.kindRef() {
            case Split(_, children, _): children[path[path.length - 1]] = node;
            case Tabs(_, _): throw 'path traverses a non-split node';
        }
    }

    /**
     * Replace the whole tree with `node`, keeping `node`'s own id and
     * `rootKind` unchanged. Used by normalization's root-collapse rule.
     */
    @:allow(glaze.kit.base.dock)
    function replaceRoot(node:PaneNode):Void {
        rootValue = node;
    }

    /**
     * Rust derived `Clone`: a deep copy.
     */
    public function clone():PaneTree {
        final tree = Type.createEmptyInstance(PaneTree);
        @:privateAccess tree.rootValue = rootValue.clone();
        @:privateAccess tree.rootKindValue = rootKindValue;
        return tree;
    }

    /**
     * Rust derived `PartialEq`.
     */
    public function equals(other:PaneTree):Bool {
        return rootKindValue == other.rootKindValue && rootValue.equals(other.rootValue);
    }

/// Editing (edit.rs)

    public function insertPanel(panel:PanelId, target:InsertTarget):EditResult {
        return edit(tree -> tree.applyInsert(panel, target));
    }

    public function removePanel(panel:PanelId):EditResult {
        return edit(tree -> tree.detachPanel(panel));
    }

    /**
     * Move a panel to a new home without ever removing it from the tree's
     * perspective, so the caller never fires `onRemoved` for a drag.
     */
    public function movePanel(panel:PanelId, target:InsertTarget):EditResult {
        return edit(tree -> {
            final detached = tree.detachPanel(panel);
            final inserted = tree.applyInsert(panel, target);
            detached || inserted;
        });
    }

    public function split(at:NodeId, panel:PanelId, placement:Placement, size:Null<Pixels>):EditResult {
        return insertPanel(panel, InsertTarget.Split(at, placement, size));
    }

    public function setActive(node:NodeId, ix:Int):EditResult {
        return edit(tree -> {
            final path = tree.pathOfNode(node);
            if (path == null) return false;
            final target = tree.nodeAt(path);
            switch target.kindRef() {
                case Tabs(panels, activeIx):
                    if (activeIx == ix) return false;
                    target.kindValue = NodeKind.Tabs(panels, ix);
                    true;
                case Split(_, _, _):
                    false;
            }
        });
    }

    /**
     * Replace a split's slot sizes wholesale.
     *
     * A no-op, like every other operation given input it cannot resolve, if
     * `newSizes.length` does not match the split's child count: no rule in
     * `normalize` repairs a length mismatch.
     */
    public function setSizes(node:NodeId, newSizes:Array<Null<Pixels>>):EditResult {
        return edit(tree -> {
            final path = tree.pathOfNode(node);
            if (path == null) return false;
            final target = tree.nodeAt(path);
            switch target.kindRef() {
                case Split(axis, children, sizes):
                    if (newSizes.length != children.length || PaneNode.sameSizes(sizes, newSizes)) return false;
                    target.kindValue = NodeKind.Split(axis, children, newSizes.copy());
                    true;
                case Tabs(_, _):
                    false;
            }
        });
    }

    /**
     * Replace every split's slot sizes with what that split is actually drawn
     * at.
     *
     * A layout is usually built with unconstrained slots, and `null` stays
     * `null` in the tree no matter how the split is later measured or dragged.
     * That is fine until an edit has to divide space: dropping a panel beside
     * another one has to halve something, and it cannot halve an unknown.
     * Adopting the measured sizes first turns the question into arithmetic on
     * real pixels, and it matches what the person dragging sees.
     */
    @:allow(glaze.kit.base.dock)
    function adoptMeasuredSizes(measured:Map<Int, Array<Pixels>>):Void {
        adoptWalk(rootValue, measured);
    }

    static function adoptWalk(node:PaneNode, measured:Map<Int, Array<Pixels>>):Void {
        switch node.kindRef() {
            case Split(_, children, sizes):
                final actual = measured.get(node.id().asU64());
                if (actual != null && actual.length == sizes.length) {
                    for (ix in 0...sizes.length) {
                        // A zero means the split has not been laid out yet, so
                        // the slot keeps whatever it already had.
                        if ((actual[ix] : Float) > 0) sizes[ix] = actual[ix];
                    }
                }
                for (child in children) adoptWalk(child, measured);
            case Tabs(_, _):
        }
    }

    /**
     * Apply one mutation, then collapse.
     *
     * `apply` reports whether it changed anything and normalization reports
     * the same, so no snapshot of the previous tree is needed. A mutation that
     * cannot resolve its target returns `false` and the whole edit is a no-op.
     */
    function edit(apply:(PaneTree) -> Bool):EditResult {
        final mutated = apply(this);
        final collapsed = normalizeReporting();
        return new EditResult(mutated || collapsed);
    }

    /**
     * Whether `panel` is anywhere in this tree.
     */
    public function containsPanel(panel:PanelId):Bool {
        return panels().contains(panel);
    }

    /**
     * Returns whether the panel actually landed. A target this tree cannot
     * resolve (a stale node id, or one whose kind does not match the target)
     * is a no-op rather than an error, and reports `false`.
     */
    function applyInsert(panel:PanelId, target:InsertTarget):Bool {
        return switch target {
            case Tabs(node, ix, activate):
                final path = pathOfNode(node);
                if (path == null) return false;
                final tabsNode = nodeAt(path);
                switch tabsNode.kindRef() {
                    case Tabs(panels, activeIx):
                        final at = ix != null ? (ix < panels.length ? ix : panels.length) : panels.length;
                        panels.insert(at, panel);
                        if (activate) {
                            activeIx = at;
                        }
                        else if (at <= activeIx && panels.length > 1) {
                            // Keep the displayed panel displayed.
                            activeIx += 1;
                        }
                        tabsNode.kindValue = NodeKind.Tabs(panels, activeIx);
                        true;
                    case Split(_, _, _):
                        false;
                }
            case Split(node, placement, size):
                insertBeside(node, panel, placement, size);
        }
    }

    /**
     * Place `panel` in a new tab group beside `node`.
     *
     * When the parent split already runs along the placement's axis the new
     * group becomes a sibling. Otherwise `node` is wrapped in a fresh split of
     * the placement's axis. Rule 3 of `normalize` then flattens any redundant
     * nesting this creates, which is why no "reuse the parent split" special
     * case is needed here.
     */
    function insertBeside(node:NodeId, panel:PanelId, placement:Placement, size:Null<Pixels>):Bool {
        final path = pathOfNode(node);
        if (path == null) return false;
        final groupId = allocateNodeId();
        final group = new PaneNode(groupId, NodeKind.Tabs([panel], 0));
        final before = placement == Placement.Left || placement == Placement.Top;

        if (path.length > 0) {
            final parentPath = path.slice(0, path.length - 1);
            final ix = path[path.length - 1];
            final parent = nodeAt(parentPath);
            switch parent.kindRef() {
                case Split(axis, children, sizes) if (axis == placement.axis()):
                    // The new group splits the slot it landed beside, rather
                    // than the whole row being re-divided: drop a panel next to
                    // one neighbour and it is that neighbour's space you take.
                    // A caller that named a size gets exactly it, and the
                    // neighbour is left alone.
                    //
                    // An unconstrained neighbour halves to another `null`,
                    // which is right for the same reason: the two of them go
                    // on sharing whatever the fixed slots leave over, now
                    // between themselves.
                    final share:Null<Pixels> = if (size != null) {
                        size;
                    }
                    else {
                        final slot = sizes[ix];
                        final half:Null<Pixels> = slot != null ? SpringMath.f32((slot : Float) / 2.) : null;
                        sizes[ix] = half;
                        half;
                    }
                    final at = before ? ix : ix + 1;
                    children.insert(at, group);
                    sizes.insert(at, share);
                    return true;
                case _:
            }
        }

        // Wrap the target in a new split of the placement's axis.
        final wrapperId = allocateNodeId();
        final target = nodeAt(path);
        final children = before ? [group, target] : [target, group];
        final sizes:Array<Null<Pixels>> = before ? [size, null] : [null, size];
        replaceAt(path, new PaneNode(wrapperId, NodeKind.Split(placement.axis(), children, sizes)));
        return true;
    }

    /**
     * Remove `panel` wherever it lives. Returns whether it was found.
     */
    function detachPanel(panel:PanelId):Bool {
        final node = findPanelNode(panel);
        if (node == null) return false;
        final path = pathOfNode(node);
        if (path == null) return false;
        final target = nodeAt(path);
        return switch target.kindRef() {
            case Tabs(panels, activeIx):
                final ix = panels.indexOf(panel);
                if (ix < 0) return false;
                panels.splice(ix, 1);
                if (ix < activeIx) activeIx -= 1;
                target.kindValue = NodeKind.Tabs(panels, activeIx);
                true;
            case Split(_, _, _):
                false;
        }
    }

/// Normalization (normalize.rs)

    /**
     * Collapse the tree to canonical shape.
     *
     * One post-order pass repeated to a fixpoint. This is the only place a
     * container is removed for being empty. It needs no parent pointers and
     * no deferred work, so the tree is self-consistent the instant an edit
     * returns.
     *
     * Rules, applied bottom up:
     *
     * 1. An empty `Tabs` or `Split` is removed from its parent.
     * 2. A `Split` with one child is replaced by that child. The child keeps
     *    its own `NodeId` and inherits the split's slot size.
     * 3. A `Split` whose child is a `Split` of the same axis splices that
     *    child's children into itself.
     * 4. `activeIx` is clamped.
     * 5. The root is preserved according to `RootKind`.
     *
     * Idempotent: `normalize(normalize(t)) == normalize(t)`.
     */
    public function normalize():Void {
        normalizeReporting();
    }

    /**
     * `normalize`, reporting whether it changed anything.
     */
    @:allow(glaze.kit.base.dock)
    function normalizeReporting():Bool {
        return runNormalizePasses().changed;
    }

    /**
     * Run passes until nothing changes, or until `MAX_NORMALIZE_PASSES` is
     * exhausted. Returns the number of passes run, and whether any pass
     * changed the tree.
     */
    function runNormalizePasses():{passes:Int, changed:Bool} {
        var passes = 0;
        var changed = true;
        var anyChange = false;
        while (changed && passes < MAX_NORMALIZE_PASSES) {
            final flag = new NormalizeFlag();
            normalizeNode(rootValue, flag);
            collapseRoot(this, flag);
            changed = flag.changed;
            anyChange = anyChange || changed;
            passes += 1;
        }

        // Rust logs this with `tracing::warn!` so a build left short of the
        // fixpoint renders a slightly non-canonical layout instead of
        // crashing.
        if (changed) {
            ceramic.Shortcuts.log.warning('PaneTree.normalize exhausted $MAX_NORMALIZE_PASSES passes without reaching '
                + 'a fixpoint; the tree may still contain an empty container, a single-child '
                + 'split, same-axis split nesting, or an unclamped Tabs activeIx');
        }

        return {passes: passes, changed: anyChange};
    }

    /**
     * Test-only hook so a test can pin how many passes convergence takes.
     */
    @:allow(tests)
    function normalizePassCountForTest():Int {
        return runNormalizePasses().passes;
    }

    /**
     * Whether the tree satisfies every structural invariant.
     */
    @:allow(glaze.kit.base.dock, tests)
    function isNormalized():Bool {
        var ok = true;
        final rootId = rootValue.id();
        rootValue.walk(node -> switch node.kindRef() {
            case Split(axis, children, sizes):
                ok = ok && children.length == sizes.length;
                // The root may legitimately be an empty or single-child split.
                if (node.id() != rootId) ok = ok && children.length > 1;
                for (child in children) {
                    switch child.kindRef() {
                        case Split(inner, _, _) if (inner == axis): ok = false;
                        case _:
                    }
                }
            case Tabs(panels, activeIx):
                ok = ok && (panels.length == 0 || activeIx < panels.length);
                if (node.id() != rootId) ok = ok && panels.length > 0;
        });
        return ok;
    }

    static function normalizeNode(node:PaneNode, flag:NormalizeFlag):Void {
        switch node.kindRef() {
            case Tabs(panels, activeIx):
                final clamped = Std.int(Math.min(activeIx, panels.length > 0 ? panels.length - 1 : 0));
                if (activeIx != clamped) {
                    node.kindValue = NodeKind.Tabs(panels, clamped);
                    flag.changed = true;
                }
            case Split(axis, children, sizes):
                for (child in children) normalizeNode(child, flag);

                // Rule 1: drop empty children.
                var ix = 0;
                while (ix < children.length) {
                    if (isEmptyContainer(children[ix])) {
                        children.splice(ix, 1);
                        sizes.splice(ix, 1);
                        flag.changed = true;
                    }
                    else {
                        ix += 1;
                    }
                }

                // Rule 2: a single-child split child is replaced by its child,
                // which inherits the slot size the split occupied.
                for (ix in 0...children.length) {
                    switch children[ix].kindRef() {
                        case Split(_, inner, _) if (inner.length == 1):
                            children[ix] = inner[0];
                            flag.changed = true;
                        case _:
                    }
                }

                // Rule 3: splice same-axis nesting.
                var ix = 0;
                while (ix < children.length) {
                    switch children[ix].kindRef() {
                        case Split(inner, innerChildren, innerSizes) if (inner == axis):
                            final slot = sizes[ix];
                            final distributed = distributeSlot(slot, innerSizes);
                            final count = innerChildren.length;
                            children.splice(ix, 1);
                            sizes.splice(ix, 1);
                            for (i in 0...count) {
                                children.insert(ix + i, innerChildren[i]);
                                sizes.insert(ix + i, distributed[i]);
                            }
                            ix += count;
                            flag.changed = true;
                        case _:
                            ix += 1;
                    }
                }
        }
    }

    /**
     * Spread an outer slot size across the inner sizes that replace it.
     *
     * When the outer slot is unconstrained the inner sizes pass through. When
     * it is fixed and every inner size is known, they are scaled to fill the
     * slot; otherwise the slot is dropped, matching how an unconstrained child
     * behaves. Computed in `f32` like the original.
     */
    static function distributeSlot(slot:Null<Pixels>, inner:Array<Null<Pixels>>):Array<Null<Pixels>> {
        if (slot == null) return inner;
        // One unknown size makes the whole total unknown.
        var total:Null<Float> = 0.;
        for (size in inner) {
            if (size == null) {
                total = null;
                break;
            }
            total = SpringMath.f32(total + (size : Float));
        }
        if (total != null && total > 0) {
            final ratio = SpringMath.f32((slot : Float) / total);
            return [for (size in inner) size != null ? (SpringMath.f32((size : Float) * ratio) : Pixels) : null];
        }
        return inner;
    }

    static function isEmptyContainer(node:PaneNode):Bool {
        return switch node.kindRef() {
            case Split(_, children, _): children.length == 0;
            case Tabs(panels, _): panels.length == 0;
        }
    }

    /**
     * Rule 5. A `RootKind.Split` tree keeps a split root no matter what, so an
     * empty center still serializes as a `StackPanel`. A `RootKind.Any` tree
     * lets rule 2 collapse the root like any other node.
     */
    static function collapseRoot(tree:PaneTree, flag:NormalizeFlag):Void {
        if (tree.rootKindValue == RootKind.Split) return;
        switch tree.rootValue.kindRef() {
            case Split(_, children, _) if (children.length == 1):
                tree.replaceRoot(children[0]);
                flag.changed = true;
            case _:
        }
    }

/// Builder (builder.rs)

    /**
     * Build a whole tree from a described layout.
     *
     * The `RootKind.Split` wrap mirrors the one in `fromState`: a center whose
     * described root is a tab group still has to serialize as a `StackPanel`.
     */
    @:allow(glaze.kit.base.dock, tests)
    static function fromLayout(layout:DockLayout, rootKind:RootKind):{tree:PaneTree, panels:Array<{id:PanelId, view:PanelView}>} {
        final tree = new PaneTree(rootKind);
        final built = layout.build(tree);
        var root = built.node;
        switch [rootKind, root.kindRef()] {
            case [RootKind.Split, Split(_, _, _)] | [RootKind.Any, _]:
            case [RootKind.Split, _]:
                final id = tree.allocateNodeId();
                root = new PaneNode(id, NodeKind.Split(Axis.Horizontal, [root], [null]));
        }
        tree.replaceRoot(root);
        tree.normalize();
        return {tree: tree, panels: built.panels};
    }

/// Persistence (state_convert.rs)

    public function toState(source:PanelSource):PanelState {
        return nodeToState(rootValue, source);
    }

    static function nodeToState(node:PaneNode, source:PanelSource):PanelState {
        return switch node.kindRef() {
            case Split(axis, children, sizes):
                // `null` is a representation this rewrite introduces, not
                // something the old writer ever produced: the schema's `sizes`
                // field has no slot for "unconstrained". `0.0` is the sentinel
                // this writer chooses for that case, and the corresponding
                // reader maps a `0.0` it loads back to `null`.
                //
                // That makes a `null` slot safe to persist only transiently: a
                // caller building a tree meant to be written out must resolve
                // every slot to concrete pixels first. An older build reading a
                // persisted `0.0` back has no notion of the sentinel and
                // constructs a real, zero-pixel-wide panel from it.
                new PanelState(STACK_PANEL_NAME, [for (child in children) nodeToState(child, source)],
                    PanelInfoTools.stack([for (size in sizes) size != null ? size : (0. : Pixels)], axis));
            case Tabs(panels, activeIx):
                // Unconditional, unlike the old writer which assigned this
                // inside its loop and left an empty group looking like a bare
                // panel.
                new PanelState(TAB_PANEL_NAME, [for (panel in panels) source.dump(panel)], PanelInfoTools.tabs(activeIx));
        }
    }

    /**
     * Read a persisted layout.
     *
     * Compatibility rules:
     *
     * - a `Tabs` whose children are themselves `Tabs` is flattened;
     * - a bare `Panel` leaf appearing where a container belongs is wrapped in
     *   a `Tabs`;
     * - a node named `TabPanel` carrying `PanelInfo.Panel` is read as an
     *   empty tab group, recovering data written by the old dump defect (an
     *   empty `TabPanel` never entered the loop that set its `info` to
     *   `Tabs`, so it kept `PanelState`'s default `Panel(Value::Null)`);
     * - a node named `StackPanel` carrying `PanelInfo.Panel` is the same
     *   defect in the old split writer, and is read as an empty split. Inside
     *   a tab group it is dropped: a placeholder built from it would dump the
     *   defective state back unchanged, so the layout could never heal.
     */
    public static function fromState(state:PanelState, rootKind:RootKind, builder:PanelBuilder):PaneTree {
        final tree = new PaneTree(rootKind);
        var root = buildNode(tree, state, builder);
        if (rootKind == RootKind.Split) {
            switch root.kindRef() {
                case Split(_, _, _):
                case _:
                    final id = tree.allocateNodeId();
                    root = new PaneNode(id, NodeKind.Split(Axis.Horizontal, [root], [null]));
            }
        }
        tree.replaceRoot(root);
        tree.normalize();
        return tree;
    }

    static function buildNode(tree:PaneTree, state:PanelState, builder:PanelBuilder):PaneNode {
        final id = tree.allocateNodeId();
        return switch state.info {
            case Stack(sizes, axis):
                final axis = axis == 0 ? Axis.Horizontal : Axis.Vertical;
                final children = [for (child in state.children) buildNode(tree, child, builder)];
                final slotSizes:Array<Null<Pixels>> = [for (ix in 0...children.length) ix < sizes.length && (sizes[ix] : Float) > 0 ? sizes[ix] : null];
                new PaneNode(id, NodeKind.Split(axis, children, slotSizes));
            case Tabs(activeIndex):
                final panels = collectTabPanels(state.children, builder);
                new PaneNode(id, NodeKind.Tabs(panels, activeIndex));
            // A container name carrying a leaf info means the writer that
            // produced this file had the empty-container defect.
            case Panel(_) if (state.panelName == STACK_PANEL_NAME):
                new PaneNode(id, NodeKind.Split(Axis.Horizontal, [], []));
            case Panel(_):
                final panels = state.panelName == TAB_PANEL_NAME ? [] : [builder.build(state, state.info)];
                new PaneNode(id, NodeKind.Tabs(panels, 0));
        }
    }

    static function isContainerName(panelName:String):Bool {
        return panelName == TAB_PANEL_NAME || panelName == STACK_PANEL_NAME;
    }

    /**
     * Flatten one level of tab nesting, which the old writer could produce.
     */
    static function collectTabPanels(children:Array<PanelState>, builder:PanelBuilder):Array<PanelId> {
        final result:Array<PanelId> = [];
        for (child in children) {
            switch child.info {
                case Tabs(_):
                    for (panel in collectTabPanels(child.children, builder)) result.push(panel);
                case Panel(_) if (isContainerName(child.panelName)):
                case _:
                    result.push(builder.build(child, child.info));
            }
        }
        return result;
    }

/// Test support (Rust `#[cfg(test)] impl PaneTree`)

    @:allow(tests)
    function pushTabsForTest(parent:NodeId, panels:Array<PanelId>):NodeId {
        return pushSizedTabsForTest(parent, panels, null);
    }

    /**
     * Like `pushTabsForTest`, but with a concrete slot size instead of always
     * pushing `null`.
     */
    @:allow(tests)
    function pushSizedTabsForTest(parent:NodeId, panels:Array<PanelId>, size:Null<Pixels>):NodeId {
        final id = allocateNodeId();
        final path = pathOfNode(parent);
        if (path == null) throw 'parent must exist';
        switch nodeAt(path).kindRef() {
            case Split(_, children, sizes):
                children.push(new PaneNode(id, NodeKind.Tabs(panels, 0)));
                sizes.push(size);
            case Tabs(_, _):
                throw 'parent must be a split';
        }
        return id;
    }

    @:allow(tests)
    function setRootSplitForTest(axis:Axis):NodeId {
        final id = allocateNodeId();
        rootValue = new PaneNode(id, NodeKind.Split(axis, [], []));
        return id;
    }

    @:allow(tests)
    function setRootAxisForTest(newAxis:Axis):Void {
        switch rootValue.kindRef() {
            case Split(_, children, sizes): rootValue.kindValue = NodeKind.Split(newAxis, children, sizes);
            case Tabs(_, _):
        }
    }

    @:allow(tests)
    function setRootTabsForTest(panels:Array<PanelId>, activeIx:Int):NodeId {
        final id = allocateNodeId();
        rootValue = new PaneNode(id, NodeKind.Tabs(panels, activeIx));
        return id;
    }

    @:allow(tests)
    function pushSplitForTest(parent:NodeId, axis:Axis, size:Null<Pixels>):NodeId {
        final id = allocateNodeId();
        final path = pathOfNode(parent);
        if (path == null) throw 'parent must exist';
        switch nodeAt(path).kindRef() {
            case Split(_, children, sizes):
                children.push(new PaneNode(id, NodeKind.Split(axis, [], [])));
                sizes.push(size);
            case Tabs(_, _):
                throw 'parent must be a split';
        }
        return id;
    }

}

private class NormalizeFlag {

    public var changed:Bool = false;

    public function new() {}

}
