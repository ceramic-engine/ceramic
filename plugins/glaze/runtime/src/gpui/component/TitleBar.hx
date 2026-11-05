// Ported from gpui-kit 0.8.1: crates/component/src/title_bar.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component;

import gpui.AnyElement;
import gpui.App;
import gpui.Background;
import gpui.ClickEvent;
import gpui.Decorations;
import gpui.Hsla;
import gpui.IntoElement;
import gpui.OperatingSystem;
import gpui.ParentElement;
import gpui.Pixels;
import gpui.RenderOnce;
import gpui.Rgba;
import gpui.StyleRefinement;
import gpui.Styled;
import gpui.Window;
import gpui.WindowControlArea;
import gpui.component.Icon;
import gpui.component.IconName;
import gpui.component.theme.Theme;

import gpui.Prelude.*;
import gpui.base.Prelude.*;

using gpui.base.InteractiveElementExt;
using gpui.base.StyledExt;

/**
 * TitleBar used to customize the appearance of the title bar.
 *
 * We can put some elements inside the title bar.
 *
 * Rust decides the platform at compile time (`cfg!(target_os = ...)`,
 * `cfg!(target_family = "wasm")`); the port reads `OperatingSystem.current`
 * and `TitleBar.isWeb` when it renders:
 *
 * - macOS: 80px left padding (room for the traffic lights the system
 *   draws), no window controls, a double click runs the system action
 *   (`Window.titlebarDoubleClick`);
 * - Windows: 12px padding, minimize / maximize / close buttons that are
 *   window control areas (the system handles their clicks);
 * - Linux: 12px padding, the same buttons with click handlers (minimize,
 *   zoom, close) when the window is client decorated, a double click zooms,
 *   a right click opens the window menu;
 * - the web (and Unity, see `isWeb`): 12px padding, no window controls,
 *   no drag area.
 *
 * Dragging the bar starts a system window move on every platform but the
 * web. The window operations go through `Window` (see
 * `PlatformWindowOperations`: Ceramic does not expose them yet).
 */
class TitleBar implements RenderOnce implements Styled implements ParentElement {

    public static inline final TITLE_BAR_HEIGHT:Pixels = 34.;

    /**
     * Whether the title bar renders like gpui-kit's web build (Rust
     * `cfg!(target_family = "wasm")`): true on the web target, and on Unity,
     * where the app draws inside a Unity view like a page in a browser (no
     * system title bar buttons such as the macOS traffic lights, no window
     * moves: Ceramic's window operations are no-ops there). Writable so
     * that tests and golden scenes can render the native paths.
     */
    public static var isWeb:Bool = #if ((js && !node) || unity) true #else false #end;

    static inline function isLinux():Bool {
        return !isWeb && OperatingSystem.current == Linux;
    }

    static inline function isWindows():Bool {
        return !isWeb && OperatingSystem.current == Windows;
    }

    static inline function isMacos():Bool {
        return !isWeb && OperatingSystem.current == Mac;
    }

    /** 80px on macOS, 12px elsewhere (Rust `TITLE_BAR_LEFT_PADDING`). */
    static function titleBarLeftPadding():Pixels {
        return isMacos() ? gpui.Prelude.px(80.) : gpui.Prelude.px(12.);
    }

    @:allow(tests)
    static function defaultTitleBarBackground(titleBar:Hsla, background:Hsla):Background {
        final titleBarRgb = titleBar.toRgb();
        final backgroundRgb = background.toRgb();
        inline function mix(a:Float, b:Float):Float {
            // f32 arithmetic, like Rust
            return f32(f32(a * f32(0.55)) + f32(b * f32(0.45)));
        }
        final mixed = Hsla.fromRgba(new Rgba(
            mix(titleBarRgb.r, backgroundRgb.r),
            mix(titleBarRgb.g, backgroundRgb.g),
            mix(titleBarRgb.b, backgroundRgb.b),
            mix(titleBarRgb.a, backgroundRgb.a)
        ));

        return linearGradient(
            180.,
            linearColorStop(mixed, 0.),
            linearColorStop(titleBar, 1.)
        );
    }

    static inline function f32(value:Float):Float {
        return gpui.SpringMath.f32(value);
    }

    final titleBarStyle:StyleRefinement = new StyleRefinement();

    final childElements:Array<AnyElement> = [];

    var onCloseWindowHandler:Null<(ClickEvent, Window, App) -> Void> = null;

    /**
     * Create a new TitleBar.
     */
    public function new() {}

    // Not ported: `title_bar_options()` and `window_options()`, the GPUI
    // `TitlebarOptions` / `WindowOptions` of a window with a transparent
    // system title bar. The port's windows have no platform title bar; a
    // Ceramic API would be needed to hide it and to place the macOS traffic
    // lights (`traffic_light_position` 9, 9), and to let the app own the
    // title bar drag (`app_owns_titlebar_drag`).

    /**
     * Add custom for close window event, default is None, then click X button will call `window.removeWindow()`.
     * Linux only, this will do nothing on other platforms.
     */
    public function onCloseWindow(f:(ClickEvent, Window, App) -> Void):TitleBar {
        if (isLinux()) {
            onCloseWindowHandler = f;
        }
        return this;
    }

    public inline function style():StyleRefinement {
        return titleBarStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):TitleBar {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):TitleBar {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final isClientDecorated = switch window.windowDecorations() {
            case Client(_): true;
            case Server: false;
        };
        final isWeb = TitleBar.isWeb;
        final isLinux = TitleBar.isLinux();
        final isMacos = TitleBar.isMacos();

        final state = window.useState(cx, _ -> new TitleBarState());

        final bar = div()
            .id('title-bar')
            .flex()
            .flexRow()
            .itemsCenter()
            .justifyBetween()
            .h(TITLE_BAR_HEIGHT)
            .pl(titleBarLeftPadding())
            .borderB1()
            .borderColor(theme.titleBarBorder)
            .bg(defaultTitleBarBackground(theme.titleBar, theme.background))
            .refineStyle(titleBarStyle);
        if (isLinux) {
            bar.onDoubleClick((_, window, _) -> window.zoomWindow());
        }
        if (isMacos) {
            bar.onDoubleClick((_, window, _) -> window.titlebarDoubleClick());
        }
        bar.onMouseDownOut((_, _, cx) -> {
            state.read(cx).value.shouldMove = false;
        })
            .onMouseDown(Left, (_, _, cx) -> {
                state.read(cx).value.shouldMove = true;
            })
            .onMouseUp(Left, (_, _, cx) -> {
                state.read(cx).value.shouldMove = false;
            })
            .onMouseMove((_, window, cx) -> {
                final s = state.read(cx).value;
                if (s.shouldMove) {
                    s.shouldMove = false;
                    window.startWindowMove();
                }
            });

        final inner = hFlex()
            .id('bar')
            .hFull()
            .justifyBetween()
            .flexShrink0()
            .flex1();
        if (!isWeb) {
            inner.windowControlArea(Drag);
            if (window.isFullscreen()) inner.pl3();
            if (isLinux && isClientDecorated) {
                inner.child(div()
                    .top0()
                    .left0()
                    .absolute()
                    .sizeFull()
                    .hFull()
                    .onMouseDown(Right, (ev, window, _) -> {
                        window.showWindowMenu(ev.position);
                    }));
            }
        }
        inner.extend(childElements);
        bar.child(inner)
            .child(new WindowControls(onCloseWindowHandler));

        return div().flexShrink0().child(bar);
    }

}

/**
 * The state of a title bar kept across frames (Rust `TitleBarState`).
 */
private class TitleBarState {

    public var shouldMove:Bool = false;

    public function new() {}

}

/**
 * A window control button. The Windows control buttons have a fixed width
 * of 35px.
 *
 * We don't need implementation the click event for the control buttons on
 * Windows: if the user clicks in the bounds, the window event is triggered.
 */
@:allow(gpui.component, tests)
private enum ControlIcon {
    Minimize;
    Restore;
    Maximize;
    Close(onCloseWindow:Null<(ClickEvent, Window, App) -> Void>);
}

@:allow(gpui.component, tests)
private class ControlIconTools {

    public static function id(self:ControlIcon):String {
        return switch self {
            case Minimize: 'minimize';
            case Restore: 'restore';
            case Maximize: 'maximize';
            case Close(_): 'close';
        }
    }

    public static function icon(self:ControlIcon):IconName {
        return switch self {
            case Minimize: IconName.WindowMinimize;
            case Restore: IconName.WindowRestore;
            case Maximize: IconName.WindowMaximize;
            case Close(_): IconName.WindowClose;
        }
    }

    public static function windowControlArea(self:ControlIcon):WindowControlArea {
        return switch self {
            case Minimize: Min;
            case Restore | Maximize: Max;
            case Close(_): Close;
        }
    }

    public static function isClose(self:ControlIcon):Bool {
        return switch self {
            case Close(_): true;
            case _: false;
        }
    }

    public static function hoverFg(self:ControlIcon, cx:App):Hsla {
        return isClose(self) ? Theme.global(cx).dangerForeground : Theme.global(cx).secondaryForeground;
    }

    public static function hoverBg(self:ControlIcon, cx:App):Hsla {
        return isClose(self) ? Theme.global(cx).danger : Theme.global(cx).secondaryHover;
    }

    public static function activeBg(self:ControlIcon, cx:App):Hsla {
        return isClose(self) ? Theme.global(cx).dangerActive : Theme.global(cx).secondaryActive;
    }

}

/**
 * Renders one `ControlIcon` (Rust `impl RenderOnce for ControlIcon`).
 */
@:allow(gpui.component, tests)
private class ControlIconElement implements RenderOnce {

    final icon:ControlIcon;

    public function new(icon:ControlIcon) {
        this.icon = icon;
    }

    public function render(window:Window, cx:App):IntoElement {
        final isLinux = @:privateAccess TitleBar.isLinux();
        final isWindows = @:privateAccess TitleBar.isWindows();
        final hoverFg = ControlIconTools.hoverFg(icon, cx);
        final hoverBg = ControlIconTools.hoverBg(icon, cx);
        final activeBg = ControlIconTools.activeBg(icon, cx);
        final icon = this.icon;
        final onCloseWindow = switch icon {
            case Close(onCloseWindow): onCloseWindow;
            case _: null;
        };

        final root = div()
            .id(ControlIconTools.id(icon))
            .flex()
            .w(TitleBar.TITLE_BAR_HEIGHT)
            .hFull()
            .flexShrink0()
            .justifyCenter()
            .contentCenter()
            .itemsCenter()
            .textColor(Theme.global(cx).foreground)
            .hover(style -> style.bg(hoverBg).textColor(hoverFg))
            .active(style -> style.bg(activeBg).textColor(hoverFg));
        if (isWindows) {
            root.windowControlArea(ControlIconTools.windowControlArea(icon));
        }
        if (isLinux) {
            root.onMouseDown(Left, (_, window, cx) -> {
                window.preventDefault();
                cx.stopPropagation();
            })
                .onClick((_, window, cx) -> {
                    cx.stopPropagation();
                    switch icon {
                        case Minimize:
                            window.minimizeWindow();
                        case Restore | Maximize:
                            window.zoomWindow();
                        case Close(_):
                            if (onCloseWindow != null) {
                                // Rust `ClickEvent::default()`
                                onCloseWindow(Mouse(new gpui.ClickEvent.MouseClickEvent(
                                    new gpui.MouseDownEvent(Left, new gpui.Point(0., 0.), null, 0),
                                    new gpui.MouseUpEvent(Left, new gpui.Point(0., 0.), null, 0)
                                )), window, cx);
                            } else {
                                window.removeWindow();
                            }
                    }
                });
        }
        return root.child(new Icon(ControlIconTools.icon(icon)).small());
    }

}

/**
 * The window control buttons of the title bar (Rust's private
 * `WindowControls`, not GPUI's `gpui.WindowControls`).
 */
@:allow(gpui.component, tests)
private class WindowControls implements RenderOnce {

    final onCloseWindow:Null<(ClickEvent, Window, App) -> Void>;

    public function new(onCloseWindow:Null<(ClickEvent, Window, App) -> Void>) {
        this.onCloseWindow = onCloseWindow;
    }

    public function render(window:Window, cx:App):IntoElement {
        if (@:privateAccess TitleBar.isMacos() || TitleBar.isWeb) {
            return div().id('window-controls');
        }

        // Under server-side decorations the window manager already renders
        // its own title bar, complete with min/max/close; drawing ours as
        // well stacks a duplicate set of controls on top of it (most
        // visibly two close buttons). gpui falls back to server-side
        // decorations on X11 sessions without a compositor, and a Wayland
        // compositor may grant server mode even when client mode was
        // requested. Skip ours unless this window is actually client-side
        // decorated, mirroring the `is_client_decorated` gating of the
        // title bar's window-menu overlay.
        if (@:privateAccess TitleBar.isLinux()) {
            switch window.windowDecorations() {
                case Client(_):
                case Server:
                    return div().id('window-controls');
            }
        }

        // The window manager declares which controls it can honor; a tiling
        // compositor may support neither minimize nor maximize. Close is
        // always ours to offer.
        final supported = window.windowControls();

        final controls = hFlex()
            .id('window-controls')
            .itemsCenter()
            .flexShrink0()
            .hFull();
        if (supported.minimize) {
            controls.child(new ControlIconElement(Minimize));
        }
        if (supported.maximize) {
            controls.child(new ControlIconElement(window.isMaximized() ? Restore : Maximize));
        }
        return controls.child(new ControlIconElement(Close(onCloseWindow)));
    }

}
