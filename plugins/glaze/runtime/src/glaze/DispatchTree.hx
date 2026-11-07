// Ported from gpui-pre 0.3.10: src/key_dispatch.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

import gpui.util.Stacks;
import gpui.keymap.DispatchResult;
import gpui.keymap.KeyDispatch;
import gpui.keymap.Replay;
import haxe.ds.IntMap;

/**
 * A key event listener of a dispatch node (Rust `KeyListener`): gets every
 * keyboard event (key down, key up, modifiers changed), filters by kind.
 */
typedef KeyListener = (event:PlatformInput, phase:DispatchPhase, window:Window, cx:App) -> Void;

/**
 * A modifiers changed listener of a dispatch node.
 */
typedef ModifiersChangedListener = (event:ModifiersChangedEvent, window:Window, cx:App) -> Void;

/**
 * An action listener of a dispatch node: `actionType` is the exact class of
 * the actions it handles (Rust `TypeId`).
 */
class DispatchActionListener {

    public final actionType:Class<Dynamic>;

    /**
     * The listener (`null` on the subclasses that handle the call
     * themselves: dispatch through `call()`)
     */
    public final listener:Null<(action:Action, phase:DispatchPhase, window:Window, cx:App) -> Void>;

    public function new(actionType:Class<Dynamic>, listener:Null<(Action, DispatchPhase, Window, App) -> Void>) {
        this.actionType = actionType;
        this.listener = listener;
    }

    /** Call the listener */
    public function call(action:Action, phase:DispatchPhase, window:Window, cx:App):Void {
        listener(action, phase, window, cx);
    }

}

/**
 * A node of the dispatch tree: one per element painted in the frame.
 */
class DispatchNode {

    public final keyListeners:Array<KeyListener> = [];

    public final actionListeners:Array<DispatchActionListener> = [];

    public final modifiersChangedListeners:Array<ModifiersChangedListener> = [];

    public var context:Null<KeyContext> = null;

    /** The focus id of this node, or -1 */
    public var focusId:Int = -1;

    /** The view (entity id) of this node, or -1 */
    public var viewId:Int = -1;

    /** The parent node, or -1 */
    public var parent:Int = -1;

    public function new() {}

    public function reset(parent:Int):Void {
        keyListeners.resize(0);
        actionListeners.resize(0);
        modifiersChangedListeners.resize(0);
        context = null;
        focusId = -1;
        viewId = -1;
        this.parent = parent;
    }

}

/**
 * The tree of the elements painted in a frame, as far as keyboard dispatch is
 * concerned: key contexts, focus ids, views, key / action / modifiers
 * listeners. Built during prepaint (one node per element) and paint, then
 * used by the window to dispatch keystrokes and actions along the path from
 * the root to the focused element.
 *
 * `DispatchNodeId` is an `Int` (index of the node). The keystroke matching
 * itself is `gpui.keymap.KeyDispatch`, given the context stack of the path.
 * Nodes are pooled across frames.
 */
class DispatchTree {

    final nodeStack:Array<Int> = [];

    /**
     * The contexts of the nodes on the stack (the active path).
     */
    public final contextStack:Array<KeyContext> = [];

    final viewStack:Array<Int> = [];

    final nodes:Array<DispatchNode> = [];

    var nodeCount:Int = 0;

    final focusableNodeIds:IntMap<Int> = new IntMap();

    final viewNodeIds:IntMap<Int> = new IntMap();

    final keymap:Keymap;

    final keyDispatch:KeyDispatch;

    public function new(keymap:Keymap) {
        this.keymap = keymap;
        this.keyDispatch = new KeyDispatch(keymap);
    }

    public function clear():Void {
        nodeStack.resize(0);
        contextStack.resize(0);
        viewStack.resize(0);
        nodeCount = 0;
        focusableNodeIds.clear();
        viewNodeIds.clear();
    }

    public inline function len():Int {
        return nodeCount;
    }

    public function pushNode():Int {
        final parent = nodeStack.length > 0 ? nodeStack[nodeStack.length - 1] : -1;
        final nodeId = nodeCount;
        var node = nodes[nodeId];
        if (node == null) {
            node = new DispatchNode();
            nodes[nodeId] = node;
        }
        node.reset(parent);
        nodeCount++;
        nodeStack.push(nodeId);
        return nodeId;
    }

    public function setActiveNode(nodeId:Int):Void {
        final nextNodeParent = nodes[nodeId].parent;
        while (nodeStack.length > 0 && nodeStack[nodeStack.length - 1] != nextNodeParent) {
            popNode();
        }

        final last = nodeStack.length > 0 ? nodeStack[nodeStack.length - 1] : -1;
        if (last == nextNodeParent) {
            nodeStack.push(nodeId);
            final activeNode = nodes[nodeId];
            if (activeNode.viewId != -1) {
                viewStack.push(activeNode.viewId);
            }
            if (activeNode.context != null) {
                contextStack.push(activeNode.context);
            }
        }
        else {
            var currentNodeId = nodeId;
            while (currentNodeId != -1) {
                final node = nodes[currentNodeId];
                if (node.context != null) {
                    contextStack.push(node.context);
                }
                if (node.viewId != -1) {
                    viewStack.push(node.viewId);
                }
                nodeStack.push(currentNodeId);
                currentNodeId = node.parent;
            }
            contextStack.reverse();
            viewStack.reverse();
            nodeStack.reverse();
        }
    }

    public function setKeyContext(context:KeyContext):Void {
        activeNode().context = context;
        contextStack.push(context);
    }

    public function setFocusId(focusId:Int):Void {
        final nodeId = nodeStack[nodeStack.length - 1];
        nodes[nodeId].focusId = focusId;
        focusableNodeIds.set(focusId, nodeId);
    }

    public function setViewId(viewId:Int):Void {
        if (viewStack.length == 0 || viewStack[viewStack.length - 1] != viewId) {
            final nodeId = nodeStack[nodeStack.length - 1];
            nodes[nodeId].viewId = viewId;
            viewNodeIds.set(viewId, nodeId);
            viewStack.push(viewId);
        }
    }

    public function popNode():Void {
        final node = nodes[activeNodeId()];
        if (node.context != null) {
            contextStack.pop();
        }
        if (node.viewId != -1) {
            Stacks.drop(viewStack);
        }
        Stacks.drop(nodeStack);
    }

    /**
     * Whether the subtree reused by the last `reuseSubtree()` contains the focused node.
     */
    public var reusedSubtreeContainsFocus(default, null):Bool = false;

    final reuseSourceStack:Array<Int> = [];

    /**
     * Copies a node of another tree (Rust `move_node`): pushes a node with its
     * context, focus id, view id and listeners.
     */
    function moveNode(source:DispatchNode):Void {
        pushNode();
        if (source.context != null) {
            setKeyContext(source.context);
        }
        if (source.focusId != -1) {
            setFocusId(source.focusId);
        }
        if (source.viewId != -1) {
            setViewId(source.viewId);
        }
        final target = activeNode();
        for (listener in source.keyListeners) target.keyListeners.push(listener);
        for (listener in source.actionListeners) target.actionListeners.push(listener);
        for (listener in source.modifiersChangedListeners) target.modifiersChangedListeners.push(listener);
    }

    /**
     * Copies the nodes `oldStart...oldEnd` of `source` (the previous frame's
     * tree) under the active node of this tree (Rust `reuse_subtree`), and
     * returns the index of the first copied node: a node `n` of the old range
     * becomes `n - oldStart + returned value`. Sets `reusedSubtreeContainsFocus`.
     */
    public function reuseSubtree(oldStart:Int, oldEnd:Int, source:DispatchTree, focusId:Int):Int {
        final newStart = nodeCount;
        var containsFocus = false;
        final sourceStack = reuseSourceStack;
        sourceStack.resize(0);
        for (sourceNodeId in oldStart...oldEnd) {
            final sourceNode = source.nodes[sourceNodeId];
            while (sourceStack.length > 0) {
                if (sourceNode.parent == sourceStack[sourceStack.length - 1]) {
                    break;
                }
                else {
                    Stacks.drop(sourceStack);
                    popNode();
                }
            }
            sourceStack.push(sourceNodeId);
            if (sourceNode.focusId != -1 && sourceNode.focusId == focusId) {
                containsFocus = true;
            }
            moveNode(sourceNode);
        }
        while (sourceStack.length > 0) {
            Stacks.drop(sourceStack);
            popNode();
        }
        reusedSubtreeContainsFocus = containsFocus;
        return newStart;
    }

    /**
     * The node of the given view, or -1.
     */
    public function viewNodeId(viewId:Int):Int {
        final nodeId = viewNodeIds.get(viewId);
        return nodeId != null ? nodeId : -1;
    }

    /**
     * Whether a node of this tree is the node of the given view.
     */
    public inline function containsView(viewId:Int):Bool {
        return viewNodeIds.exists(viewId);
    }

    public function onKeyEvent(listener:KeyListener):Void {
        activeNode().keyListeners.push(listener);
    }

    public function onModifiersChanged(listener:ModifiersChangedListener):Void {
        activeNode().modifiersChangedListeners.push(listener);
    }

    public function onAction(actionType:Class<Dynamic>, listener:(Action, DispatchPhase, Window, App) -> Void):Void {
        activeNode().actionListeners.push(new DispatchActionListener(actionType, listener));
    }

    /** Add an action listener entry to the active node (kept as is) */
    public function onActionEntry(entry:DispatchActionListener):Void {
        activeNode().actionListeners.push(entry);
    }

    public function focusContains(parent:Int, child:Int):Bool {
        if (parent == child) {
            return true;
        }

        final parentNodeId = focusableNodeIds.get(parent);
        if (parentNodeId != null) {
            var currentNodeId:Null<Int> = focusableNodeIds.get(child);
            while (currentNodeId != null && currentNodeId != -1) {
                if (currentNodeId == parentNodeId) {
                    return true;
                }
                currentNodeId = nodes[currentNodeId].parent;
            }
        }
        return false;
    }

    /**
     * The actions handled along the dispatch path to the given node, one
     * instance per action type, sorted by name (Rust sorts by `TypeId`).
     */
    public function availableActions(target:Int, actions:ActionRegistry):Array<Action> {
        final result:Array<Action> = [];
        final seen = new Map<String, Bool>();
        for (nodeId in dispatchPath(target)) {
            final node = nodes[nodeId];
            for (listener in node.actionListeners) {
                final name = Type.getClassName(listener.actionType);
                if (!seen.exists(name)) {
                    seen.set(name, true);
                    var action:Null<Action> = null;
                    try {
                        action = actions.buildActionType(cast listener.actionType);
                    }
                    catch (e:Dynamic) {}
                    if (action != null) {
                        result.push(action);
                    }
                }
            }
        }
        result.sort((a, b) -> Reflect.compare(a.name(), b.name()));
        return result;
    }

    public function isActionAvailable(action:Action, target:Int):Bool {
        final type = Type.getClass(action);
        for (nodeId in dispatchPath(target)) {
            final node = nodes[nodeId];
            for (listener in node.actionListeners) {
                if (listener.actionType == type) {
                    return true;
                }
            }
        }
        return false;
    }

    public function bindingsForAction(action:Action, contextStack:Array<KeyContext>):Array<KeyBinding> {
        return keyDispatch.bindingsForAction(action, contextStack);
    }

    public function highestPrecedenceBindingForAction(action:Action, contextStack:Array<KeyContext>):Null<KeyBinding> {
        return keyDispatch.highestPrecedenceBindingForAction(action, contextStack);
    }

    /**
     * The key contexts of the nodes of the given dispatch path, root first.
     */
    public function contextStackForPath(dispatchPath:Array<Int>):Array<KeyContext> {
        final stack:Array<KeyContext> = [];
        for (nodeId in dispatchPath) {
            final context = nodes[nodeId].context;
            if (context != null) {
                stack.push(context);
            }
        }
        return stack;
    }

    public function possibleNextBindingsForInput(input:Array<Keystroke>, contextStack:Array<KeyContext>):Array<KeyBinding> {
        return keymap.possibleNextBindingsForInput(input, contextStack);
    }

    /**
     * Matches the keystroke, after the pending `input`, against the bindings
     * of the contexts of the dispatch path (see `KeyDispatch.dispatchKey`).
     */
    public function dispatchKey(input:Array<Keystroke>, keystroke:Keystroke, dispatchPath:Array<Int>):DispatchResult {
        return keyDispatch.dispatchKey(input, keystroke, contextStackForPath(dispatchPath));
    }

    /**
     * Converts pending input to replay events after a timeout.
     */
    public function flushDispatch(input:Array<Keystroke>, dispatchPath:Array<Int>):Array<Replay> {
        return keyDispatch.flushDispatch(input, contextStackForPath(dispatchPath));
    }

    /**
     * The path from the root to the given node.
     */
    public function dispatchPath(target:Int):Array<Int> {
        final path:Array<Int> = [];
        var currentNodeId = target;
        while (currentNodeId != -1 && currentNodeId < nodeCount) {
            path.push(currentNodeId);
            currentNodeId = nodes[currentNodeId].parent;
        }
        path.reverse(); // Reverse the path so it goes from the root to the focused node.
        return path;
    }

    /**
     * The focus ids of the focusable ancestors of the given focus id (itself included), root first.
     */
    public function focusPath(focusId:Int):Array<Int> {
        final path:Array<Int> = [];
        var currentNodeId:Null<Int> = focusableNodeIds.get(focusId);
        while (currentNodeId != null && currentNodeId != -1) {
            final node = nodes[currentNodeId];
            if (node.focusId != -1) {
                path.push(node.focusId);
            }
            currentNodeId = node.parent;
        }
        path.reverse(); // Reverse the path so it goes from the root to the focused node.
        return path;
    }

    /**
     * The views from the given one up to the root.
     */
    public function viewPathReversed(viewId:Int):Array<Int> {
        final result:Array<Int> = [];
        var currentNodeId:Null<Int> = viewNodeIds.get(viewId);
        while (currentNodeId != null && currentNodeId != -1) {
            final node = nodes[currentNodeId];
            if (node.viewId != -1) {
                result.push(node.viewId);
            }
            currentNodeId = node.parent;
        }
        return result;
    }

    public inline function node(nodeId:Int):DispatchNode {
        return nodes[nodeId];
    }

    function activeNode():DispatchNode {
        return nodes[activeNodeId()];
    }

    /**
     * The node of the given focus id, or -1.
     */
    public function focusableNodeId(target:Int):Int {
        final nodeId = focusableNodeIds.get(target);
        return nodeId != null ? nodeId : -1;
    }

    public inline function rootNodeId():Int {
        return 0;
    }

    /**
     * The node on top of the stack, or -1.
     */
    public inline function activeNodeId():Int {
        return nodeStack.length > 0 ? nodeStack[nodeStack.length - 1] : -1;
    }

}
