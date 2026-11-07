// Ported from gpui-kit 0.8.1: crates/component/src/button/button_icon.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.button;

import gpui.App;
import gpui.IntoElement;
import gpui.RenderOnce;
import gpui.Window;
import gpui.component.Icon;
import gpui.component.Sizable;
import gpui.component.Size;
import gpui.component.Size.IntoSize;
import gpui.component.spinner.Spinner;

/**
 * Button icon which can be an Icon, a Spinner or a ProgressCircle, used by
 * the `icon` method of Button.
 */
enum ButtonIconVariant {
    Icon(icon:gpui.component.Icon);
    Spinner(spinner:gpui.component.spinner.Spinner);
    Progress(progress:gpui.component.progress.ProgressCircle);
}

/**
 * Rust `impl Into<ButtonIcon>`: an icon (anything `Icon` accepts), a
 * spinner, a progress circle, or a `ButtonIcon`.
 */
abstract IntoButtonIcon(ButtonIcon) from ButtonIcon to ButtonIcon {

    @:from static inline function fromIcon(icon:gpui.component.Icon):IntoButtonIcon {
        return new ButtonIcon(Icon(icon));
    }

    @:from static inline function fromIconName(name:gpui.component.IconName):IntoButtonIcon {
        return new ButtonIcon(Icon(new gpui.component.Icon(name)));
    }

    @:from static inline function fromSpinner(spinner:gpui.component.spinner.Spinner):IntoButtonIcon {
        return new ButtonIcon(Spinner(spinner));
    }

    @:from static inline function fromProgressCircle(progress:gpui.component.progress.ProgressCircle):IntoButtonIcon {
        return new ButtonIcon(Progress(progress));
    }

}

/**
 * Renders a `ButtonIconVariant`, or a spinner in its place while loading.
 */
class ButtonIcon implements RenderOnce implements Sizable {

    @:allow(gpui.component, tests)
    final icon:ButtonIconVariant;

    @:allow(gpui.component, tests)
    var loadingIconValue:Null<gpui.component.Icon> = null;

    @:allow(gpui.component, tests)
    var loadingValue:Bool = false;

    @:allow(gpui.component, tests)
    var size:Size = Medium;

    /**
     * Creates a new ButtonIcon with the given icon.
     */
    public function new(icon:ButtonIconVariant) {
        this.icon = icon;
    }

    @:allow(gpui.component, tests)
    function loadingIcon(icon:Null<gpui.component.Icon>):ButtonIcon {
        loadingIconValue = icon;
        return this;
    }

    @:allow(gpui.component, tests)
    function loading(loading:Bool):ButtonIcon {
        loadingValue = loading;
        return this;
    }

    public function withSize(size:IntoSize):ButtonIcon {
        this.size = size;
        return this;
    }

    /**
     * Returns true if the icon is a spinner.
     */
    @:allow(gpui.component, tests)
    static function isSpinner(icon:ButtonIconVariant):Bool {
        return icon.match(Spinner(_));
    }

    /**
     * Returns true if the icon is a progress circle.
     */
    @:allow(gpui.component, tests)
    static function isProgress(icon:ButtonIconVariant):Bool {
        return icon.match(Progress(_));
    }

    static function sized(icon:ButtonIconVariant, size:Size):IntoElement {
        return switch icon {
            case Icon(icon): icon.withSize(size);
            case Spinner(spinner): spinner.withSize(size);
            case Progress(progress): progress.withSize(size);
        }
    }

    public function render(window:Window, cx:App):IntoElement {
        if (loadingValue) {
            if (isSpinner(icon) || isProgress(icon)) {
                return sized(icon, size);
            } else {
                final spinner = new gpui.component.spinner.Spinner();
                if (loadingIconValue != null) spinner.icon(loadingIconValue);
                return spinner.withSize(size);
            }
        } else {
            return sized(icon, size);
        }
    }

}
