// Ported from gpui-kit 0.8.1: crates/component/src/clipboard.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.clipboard;

import glaze.App;
import glaze.ClipboardItem;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.IntoElement;
import glaze.RenderOnce;
import glaze.Window;
import glaze.kit.I18n;
import glaze.kit.IconName;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.button.Button;

/**
 * An element that provides clipboard copy functionality.
 */
class Clipboard implements RenderOnce implements Sizable {

    final id:ElementId;

    var valueValue:String = '';

    var valueFnValue:Null<(Window, App) -> String> = null;

    var onCopiedFn:Null<(String, Window, App) -> Void> = null;

    var tooltipText:Null<String> = null;

    var tooltipShowDelayValue:Null<Float> = null;

    var accessibilityLabelValue:Null<String> = null;

    var size:Size = XSmall;

    /**
     * Create a new Clipboard element with the given ID.
     */
    public function new(id:ElementIdArg) {
        this.id = id;
    }

    public function withSize(size:IntoSize):Clipboard {
        this.size = size;
        return this;
    }

    public function setSize(size:Size):Void {
        this.size = size;
    }

    /**
     * Set tooltip text for the clipboard button.
     */
    public function tooltip(tooltip:String):Clipboard {
        tooltipText = tooltip;
        return this;
    }

    /**
     * Overrides how long the pointer must rest before the tooltip shows
     * (seconds).
     */
    public function tooltipShowDelay(delay:Float):Clipboard {
        tooltipShowDelayValue = delay;
        return this;
    }

    /**
     * Set the name a screen reader announces. Defaults to the localized "Copy".
     */
    public function accessibilityLabel(label:String):Clipboard {
        accessibilityLabelValue = label;
        return this;
    }

    /**
     * Set the value for copying to the clipboard. Default is an empty string.
     */
    public function value(value:String):Clipboard {
        valueValue = value;
        return this;
    }

    /**
     * Set the value of the clipboard to the result of the given function.
     * When set, the copy value is the result of the function.
     */
    public function valueFn(value:(Window, App) -> String):Clipboard {
        valueFnValue = value;
        return this;
    }

    /**
     * Set a callback to be invoked when the content is copied to the clipboard.
     */
    public function onCopied(handler:(String, Window, App) -> Void):Clipboard {
        onCopiedFn = handler;
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final state = window.useKeyedState(id, cx, _ -> new ClipboardState());

        final value = valueValue;
        final copied = state.read(cx).value.copied;
        final valueFn = valueFnValue;
        final onCopied = onCopiedFn;

        final button = Button.component(id)
            .icon(copied ? IconName.Check : IconName.Copy)
            .ghost()
            .withSize(size);
        if (tooltipText != null) button.tooltip(tooltipText);
        if (tooltipShowDelayValue != null) button.tooltipShowDelay(tooltipShowDelayValue);
        button.accessibilityLabel(accessibilityLabelValue != null ? accessibilityLabelValue : I18n.t('Copy'));
        if (!copied) {
            button.onClick((_, window, cx) -> {
                cx.stopPropagation();
                final value = valueFn != null ? valueFn(window, cx) : value;
                cx.writeToClipboard(ClipboardItem.newString(value));
                state.update(cx, (state, cx) -> {
                    state.value.copied = true;
                    cx.notify();
                });

                cx.spawn(acx -> acx.backgroundExecutor().timer(2.0).then(_ -> {
                    state.update(acx, (state, cx) -> {
                        state.value.copied = false;
                        cx.notify();
                    });
                }));

                if (onCopied != null) {
                    onCopied(value, window, cx);
                }
            });
        }
        return button;
    }

}

/**
 * Whether the button shows its "copied" check (for 2 seconds after a copy).
 */
class ClipboardState {

    public var copied:Bool = false;

    public function new() {}

}
