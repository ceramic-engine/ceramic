// New code for the Haxe port of GPUI (no GPUI origin): short forms of the
// element listeners of gpui-pre 0.3.10 (src/elements/div.rs). See NOTICE.md.
package glaze;

/**
 * The listeners of the elements (`onClick`, `onKeyDown`, `onMouseDown`...)
 * take `(event, window, cx)` like GPUI. These abstracts also accept the
 * short forms `() -> Void` and `event -> Void`, so that
 * `div().onClick(() -> save())` and `.onKeyDown(e -> ...)` compile to the
 * same listener type. Code written with the full form is unchanged.
 */

typedef ClickHandler = (event:ClickEvent, window:Window, cx:App) -> Void;

@:callable
abstract ClickListener(ClickHandler) from ClickHandler to ClickHandler {
    inline function new(f:ClickHandler) this = f;
    @:from static inline function fromVoid(f:() -> Void):ClickListener {
        final g:ClickHandler = (_, _, _) -> f();
        return new ClickListener(g);
    }
    @:from static inline function fromEvent(f:(event:ClickEvent) -> Void):ClickListener {
        final g:ClickHandler = (event, _, _) -> f(event);
        return new ClickListener(g);
    }
}

typedef MouseDownHandler = (event:MouseDownEvent, window:Window, cx:App) -> Void;

@:callable
abstract MouseDownListener(MouseDownHandler) from MouseDownHandler to MouseDownHandler {
    inline function new(f:MouseDownHandler) this = f;
    @:from static inline function fromVoid(f:() -> Void):MouseDownListener {
        final g:MouseDownHandler = (_, _, _) -> f();
        return new MouseDownListener(g);
    }
    @:from static inline function fromEvent(f:(event:MouseDownEvent) -> Void):MouseDownListener {
        final g:MouseDownHandler = (event, _, _) -> f(event);
        return new MouseDownListener(g);
    }
}

typedef MouseUpHandler = (event:MouseUpEvent, window:Window, cx:App) -> Void;

@:callable
abstract MouseUpListener(MouseUpHandler) from MouseUpHandler to MouseUpHandler {
    inline function new(f:MouseUpHandler) this = f;
    @:from static inline function fromVoid(f:() -> Void):MouseUpListener {
        final g:MouseUpHandler = (_, _, _) -> f();
        return new MouseUpListener(g);
    }
    @:from static inline function fromEvent(f:(event:MouseUpEvent) -> Void):MouseUpListener {
        final g:MouseUpHandler = (event, _, _) -> f(event);
        return new MouseUpListener(g);
    }
}

typedef MouseMoveHandler = (event:MouseMoveEvent, window:Window, cx:App) -> Void;

@:callable
abstract MouseMoveListener(MouseMoveHandler) from MouseMoveHandler to MouseMoveHandler {
    inline function new(f:MouseMoveHandler) this = f;
    @:from static inline function fromVoid(f:() -> Void):MouseMoveListener {
        final g:MouseMoveHandler = (_, _, _) -> f();
        return new MouseMoveListener(g);
    }
    @:from static inline function fromEvent(f:(event:MouseMoveEvent) -> Void):MouseMoveListener {
        final g:MouseMoveHandler = (event, _, _) -> f(event);
        return new MouseMoveListener(g);
    }
}

typedef MouseExitHandler = (event:MouseExitEvent, window:Window, cx:App) -> Void;

@:callable
abstract MouseExitListener(MouseExitHandler) from MouseExitHandler to MouseExitHandler {
    inline function new(f:MouseExitHandler) this = f;
    @:from static inline function fromVoid(f:() -> Void):MouseExitListener {
        final g:MouseExitHandler = (_, _, _) -> f();
        return new MouseExitListener(g);
    }
    @:from static inline function fromEvent(f:(event:MouseExitEvent) -> Void):MouseExitListener {
        final g:MouseExitHandler = (event, _, _) -> f(event);
        return new MouseExitListener(g);
    }
}

typedef ScrollHandler = (event:ScrollEvent, window:Window, cx:App) -> Void;

@:callable
abstract ScrollListener(ScrollHandler) from ScrollHandler to ScrollHandler {
    inline function new(f:ScrollHandler) this = f;
    @:from static inline function fromVoid(f:() -> Void):ScrollListener {
        final g:ScrollHandler = (_, _, _) -> f();
        return new ScrollListener(g);
    }
    @:from static inline function fromEvent(f:(event:ScrollEvent) -> Void):ScrollListener {
        final g:ScrollHandler = (event, _, _) -> f(event);
        return new ScrollListener(g);
    }
}

typedef KeyDownHandler = (event:KeyDownEvent, window:Window, cx:App) -> Void;

@:callable
abstract KeyDownListener(KeyDownHandler) from KeyDownHandler to KeyDownHandler {
    inline function new(f:KeyDownHandler) this = f;
    @:from static inline function fromVoid(f:() -> Void):KeyDownListener {
        final g:KeyDownHandler = (_, _, _) -> f();
        return new KeyDownListener(g);
    }
    @:from static inline function fromEvent(f:(event:KeyDownEvent) -> Void):KeyDownListener {
        final g:KeyDownHandler = (event, _, _) -> f(event);
        return new KeyDownListener(g);
    }
}

typedef KeyUpHandler = (event:KeyUpEvent, window:Window, cx:App) -> Void;

@:callable
abstract KeyUpListener(KeyUpHandler) from KeyUpHandler to KeyUpHandler {
    inline function new(f:KeyUpHandler) this = f;
    @:from static inline function fromVoid(f:() -> Void):KeyUpListener {
        final g:KeyUpHandler = (_, _, _) -> f();
        return new KeyUpListener(g);
    }
    @:from static inline function fromEvent(f:(event:KeyUpEvent) -> Void):KeyUpListener {
        final g:KeyUpHandler = (event, _, _) -> f(event);
        return new KeyUpListener(g);
    }
}

typedef ModifiersHandler = (event:ModifiersChangedEvent, window:Window, cx:App) -> Void;

@:callable
abstract ModifiersListener(ModifiersHandler) from ModifiersHandler to ModifiersHandler {
    inline function new(f:ModifiersHandler) this = f;
    @:from static inline function fromVoid(f:() -> Void):ModifiersListener {
        final g:ModifiersHandler = (_, _, _) -> f();
        return new ModifiersListener(g);
    }
    @:from static inline function fromEvent(f:(event:ModifiersChangedEvent) -> Void):ModifiersListener {
        final g:ModifiersHandler = (event, _, _) -> f(event);
        return new ModifiersListener(g);
    }
}

typedef HoverHandler = (hovered:Bool, window:Window, cx:App) -> Void;

@:callable
abstract HoverListener(HoverHandler) from HoverHandler to HoverHandler {
    inline function new(f:HoverHandler) this = f;
    @:from static inline function fromVoid(f:() -> Void):HoverListener {
        final g:HoverHandler = (_, _, _) -> f();
        return new HoverListener(g);
    }
    @:from static inline function fromEvent(f:(hovered:Bool) -> Void):HoverListener {
        final g:HoverHandler = (hovered, _, _) -> f(hovered);
        return new HoverListener(g);
    }
}

typedef ActionHandler<A> = (action:A, window:Window, cx:App) -> Void;

@:callable
abstract ActionListener<A>(ActionHandler<A>) from ActionHandler<A> to ActionHandler<A> {
    inline function new(f:ActionHandler<A>) this = f;
    @:from static inline function fromVoid<A>(f:() -> Void):ActionListener<A> {
        final g:ActionHandler<A> = (_, _, _) -> f();
        return new ActionListener<A>(g);
    }
    @:from static inline function fromEvent<A>(f:(action:A) -> Void):ActionListener<A> {
        final g:ActionHandler<A> = (action, _, _) -> f(action);
        return new ActionListener<A>(g);
    }
}

typedef DropHandler<T> = (value:T, window:Window, cx:App) -> Void;

@:callable
abstract DropListener<T>(DropHandler<T>) from DropHandler<T> to DropHandler<T> {
    inline function new(f:DropHandler<T>) this = f;
    @:from static inline function fromVoid<T>(f:() -> Void):DropListener<T> {
        final g:DropHandler<T> = (_, _, _) -> f();
        return new DropListener<T>(g);
    }
    @:from static inline function fromEvent<T>(f:(value:T) -> Void):DropListener<T> {
        final g:DropHandler<T> = (value, _, _) -> f(value);
        return new DropListener<T>(g);
    }
}

typedef DragMoveHandler<T> = (event:DragMoveEvent<T>, window:Window, cx:App) -> Void;

@:callable
abstract DragMoveListener<T>(DragMoveHandler<T>) from DragMoveHandler<T> to DragMoveHandler<T> {
    inline function new(f:DragMoveHandler<T>) this = f;
    @:from static inline function fromVoid<T>(f:() -> Void):DragMoveListener<T> {
        final g:DragMoveHandler<T> = (_, _, _) -> f();
        return new DragMoveListener<T>(g);
    }
    @:from static inline function fromEvent<T>(f:(event:DragMoveEvent<T>) -> Void):DragMoveListener<T> {
        final g:DragMoveHandler<T> = (event, _, _) -> f(event);
        return new DragMoveListener<T>(g);
    }
}
