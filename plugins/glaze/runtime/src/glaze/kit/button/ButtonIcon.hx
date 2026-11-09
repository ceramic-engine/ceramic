// Ported from gpui-kit 0.8.1: crates/component/src/button/button_icon.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.button;

import glaze.App;
import glaze.Component;
import glaze.IntoElement;
import glaze.Window;
import glaze.kit.Icon;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.Size.IntoSize;
import glaze.kit.spinner.Spinner;

/**
 * Button icon which can be an Icon, a Spinner or a ProgressCircle, used by
 * the `icon` method of Button.
 */
enum ButtonIconVariant {
    Icon(icon:glaze.kit.Icon);
    Spinner(spinner:glaze.kit.spinner.Spinner);
    Progress(progress:glaze.kit.progress.ProgressCircle);
}

/**
 * Rust `impl Into<ButtonIcon>`: an icon (anything `Icon` accepts), a
 * spinner, a progress circle, or a `ButtonIcon`.
 */
abstract IntoButtonIcon(ButtonIcon) from ButtonIcon to ButtonIcon {

    @:from static inline function fromIcon(icon:glaze.kit.Icon):IntoButtonIcon {
        return ButtonIcon.component(Icon(icon));
    }

    @:from static inline function fromIconName(name:glaze.kit.IconName):IntoButtonIcon {
        return ButtonIcon.component(Icon(glaze.kit.Icon.component(name)));
    }

    @:from static inline function fromSpinner(spinner:glaze.kit.spinner.Spinner):IntoButtonIcon {
        return ButtonIcon.component(Spinner(spinner));
    }

    @:from static inline function fromProgressCircle(progress:glaze.kit.progress.ProgressCircle):IntoButtonIcon {
        return ButtonIcon.component(Progress(progress));
    }

}

/**
 * Renders a `ButtonIconVariant`, or a spinner in its place while loading.
 */
class ButtonIcon extends Component implements Sizable {

    @:allow(glaze.kit, tests)
    final icon:ButtonIconVariant;

    @:allow(glaze.kit, tests)
    var loadingIconValue:Null<glaze.kit.Icon> = null;

    @:allow(glaze.kit, tests)
    var loadingValue:Bool = false;

    @:allow(glaze.kit, tests)
    var size:Size = Medium;

    /**
     * Creates a new ButtonIcon with the given icon.
     */
    public function new(icon:ButtonIconVariant) {
        super();
        this.icon = icon;
    }

    @:allow(glaze.kit, tests)
    function loadingIcon(icon:Null<glaze.kit.Icon>):ButtonIcon {
        loadingIconValue = icon;
        return this;
    }

    @:allow(glaze.kit, tests)
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
    @:allow(glaze.kit, tests)
    static function isSpinner(icon:ButtonIconVariant):Bool {
        return icon.match(Spinner(_));
    }

    /**
     * Returns true if the icon is a progress circle.
     */
    @:allow(glaze.kit, tests)
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
                final spinner = glaze.kit.spinner.Spinner.component();
                if (loadingIconValue != null) spinner.icon(loadingIconValue);
                return spinner.withSize(size);
            }
        } else {
            return sized(icon, size);
        }
    }

}
