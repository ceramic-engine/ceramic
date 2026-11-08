// Ported from gpui-kit 0.8.1: crates/component/src/attachment.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.attachment;

import glaze.AbsoluteLength;
import glaze.AnyElement;
import glaze.App;
import glaze.Axis;
import glaze.Bounds;
import glaze.ClickEvent;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.Hsla;
import glaze.ImageSource;
import glaze.IntoElement;
import glaze.IntoHsla;
import glaze.IntoImageSource;
import glaze.MouseButton;
import glaze.ObjectFit;
import glaze.ParentElement;
import glaze.Path;
import glaze.PathBuilder;
import glaze.Pixels;
import glaze.Point;
import glaze.RenderOnce;
import glaze.ScrollHandle;
import glaze.StyleBuilder;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Window;
import glaze.kit.base.ScrollableMask;
import glaze.kit.base.motion.Motion;
import glaze.kit.base.motion.Transition;
import glaze.kit.base.motion.TransitionId;
import glaze.kit.I18n;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.Sizable;
import glaze.kit.Size;
import glaze.kit.Size.IntoSize;
import glaze.kit.button.Button;
import glaze.kit.progress.ProgressCircle;
import glaze.kit.shimmer.ShimmerText;
import glaze.kit.spinner.Spinner;
import glaze.kit.theme.Theme;
import glaze.kit.tooltip.Tooltip;

import glaze.Prelude.*;

using glaze.kit.base.InteractiveElementExt;
using glaze.kit.base.StyledExt;
using glaze.kit.Size.SizeTools;

/**
 * The lifecycle status of an attachment.
 */
enum abstract AttachmentStatus(Int) {

    /** The attachment has been selected and is waiting to be uploaded. */
    var Pending;

    /** The attachment is currently being uploaded. */
    var Uploading;

    /** The upload has completed and the attachment is being processed. */
    var Processing;

    /** The attachment failed to upload or process. */
    var Failed;

    /** The attachment is ready (the default). */
    var Complete;

    /** Returns whether the attachment is waiting to start. */
    public inline function isPending():Bool {
        return abstract == Pending;
    }

    /** Returns whether the attachment is being uploaded. */
    public inline function isUploading():Bool {
        return abstract == Uploading;
    }

    /** Returns whether the attachment is being processed. */
    public inline function isProcessing():Bool {
        return abstract == Processing;
    }

    /** Returns whether the attachment has failed. */
    public inline function isFailed():Bool {
        return abstract == Failed;
    }

    /** Returns whether the attachment is ready. */
    public inline function isComplete():Bool {
        return abstract == Complete;
    }

    /** Returns whether the attachment is in an in-progress state. */
    public inline function isInProgress():Bool {
        return abstract == Uploading || abstract == Processing;
    }

    /** `AttachmentStatus::default()`. */
    public static inline function defaultValue():AttachmentStatus {
        return Complete;
    }

}

/**
 * A pointer handler for one of the card's built-in controls.
 */
typedef ControlHandler = (ClickEvent, Window, App) -> Void;

/**
 * A built-in control with the identity its element state is keyed on
 * (Rust `(ElementId, ControlHandler)`).
 */
class AttachmentControl {

    public final id:ElementId;

    public final handler:ControlHandler;

    public function new(id:ElementId, handler:ControlHandler) {
        this.id = id;
        this.handler = handler;
    }

}

/**
 * What the root hands its slots at layout time.
 */
@:allow(glaze.kit.attachment, tests)
class SlotLayout {

    public final size:Size;

    public final status:AttachmentStatus;

    public final axis:Axis;

    /** Whether the media fills a vertical card flush with its border. */
    public final flush:Bool;

    /** The retry control, only while failed and identified. */
    public final retry:Null<AttachmentControl>;

    /** Upload progress in percent, only while uploading. */
    public final progress:Null<Float>;

    /** The attachment's identity, keying the progress ring's state. */
    public final id:Null<ElementId>;

    public function new(size:Size, status:AttachmentStatus, axis:Axis, flush:Bool, retry:Null<AttachmentControl>, progress:Null<Float>, id:Null<ElementId>) {
        this.size = size;
        this.status = status;
        this.axis = axis;
        this.flush = flush;
        this.retry = retry;
        this.progress = progress;
        this.id = id;
    }

}

/**
 * The geometry a named size resolves to, in rems so it follows the root font size.
 */
private class CardMetrics {

    /** The height of a horizontal card and the side of a square image tile. */
    public final height:AbsoluteLength;

    /** The fixed width of a horizontal card that carries content. */
    public final chipWidth:AbsoluteLength;

    /** The side of the square media slot of a horizontal card. */
    public final media:AbsoluteLength;

    /**
     * The glyph size inside the media slot: an icon child without its own
     * size, and the status glyphs.
     */
    public final mediaGlyph:AbsoluteLength;

    /** The padding before the media slot. */
    public final paddingStart:AbsoluteLength;

    /** The padding after the content and actions. */
    public final paddingEnd:AbsoluteLength;

    /** The padding of a vertical card that carries content. */
    public final cardPadding:AbsoluteLength;

    public final gap:AbsoluteLength;

    public final text:AbsoluteLength;

    public final description:AbsoluteLength;

    public function new(height:AbsoluteLength, chipWidth:AbsoluteLength, media:AbsoluteLength, mediaGlyph:AbsoluteLength, paddingStart:AbsoluteLength,
            paddingEnd:AbsoluteLength, cardPadding:AbsoluteLength, gap:AbsoluteLength, text:AbsoluteLength, description:AbsoluteLength) {
        this.height = height;
        this.chipWidth = chipWidth;
        this.media = media;
        this.mediaGlyph = mediaGlyph;
        this.paddingStart = paddingStart;
        this.paddingEnd = paddingEnd;
        this.cardPadding = cardPadding;
        this.gap = gap;
        this.text = text;
        this.description = description;
    }

}

/**
 * A file or image attachment composed from media, content, and actions slots.
 */
class Attachment implements RenderOnce implements Styled implements Sizable {

    /** How far the remove control rides outside the card's upper trailing corner. */
    static inline final REMOVE_OVERHANG:Pixels = 6.;

    /** The remove control: a small surface-colored disc with a hairline border. */
    static inline final REMOVE_BUTTON_SIZE:Pixels = 20.;

    /** The retry control over an image preview. */
    @:allow(glaze.kit.attachment)
    static inline final RETRY_BUTTON_SIZE:Pixels = 24.;

    /**
     * The hover group the remove control appears for. Siblings may share the
     * name: a group resolves to its nearest ancestor.
     */
    static inline final REMOVE_GROUP:String = 'attachment-remove';

    /** How much an image preview is darkened while it uploads or processes. */
    @:allow(glaze.kit.attachment)
    static inline final PROGRESS_SCRIM:Float = 0.35;

    /** How much an image preview is darkened once it has failed. */
    @:allow(glaze.kit.attachment)
    static inline final FAILED_SCRIM:Float = 0.55;

    /** The upload bar's thickness. */
    static inline final UPLOAD_BAR_THICKNESS:Float = 2.;

    /** The card's border width; the padding box's corners are this much tighter. */
    static inline final CARD_BORDER:Float = 1.;

    @:allow(tests)
    var idValue:Null<ElementId> = null;

    final attachmentStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    var statusValue:AttachmentStatus = Complete;

    @:allow(tests)
    var size:Size = Medium;

    @:allow(tests)
    var axisValue:Axis = Horizontal;

    @:allow(tests)
    var mediaValue:Null<AttachmentMedia> = null;

    @:allow(tests)
    var contentValue:Null<AttachmentContent> = null;

    @:allow(tests)
    var actionsValue:Null<AttachmentActions> = null;

    @:allow(tests)
    var onClickValue:Null<ControlHandler> = null;

    @:allow(tests)
    var onRemoveValue:Null<ControlHandler> = null;

    @:allow(tests)
    var onRetryValue:Null<ControlHandler> = null;

    @:allow(tests)
    var progressValue:Null<Float> = null;

    @:allow(tests)
    var tooltipValue:Null<String> = null;

    /** Create an attachment in the `AttachmentStatus.Complete` state. */
    public function new() {}

    /**
     * Set a stable identity for the built-in controls: the whole-card click
     * layer, the remove control, and the retry control.
     */
    public function id(id:ElementIdArg):Attachment {
        idValue = id;
        return this;
    }

    /**
     * Make the whole card clickable, e.g. to open a preview.
     *
     * The click layer is painted below the actions slot, so action buttons
     * stay independently clickable. Click state needs a stable identity, so
     * the handler takes effect only together with `id`.
     */
    public function onClick(handler:ControlHandler):Attachment {
        onClickValue = handler;
        return this;
    }

    /**
     * Show a remove control riding the card's upper trailing corner.
     *
     * The control appears on hover on desktop and stays visible on touch
     * platforms. It needs a stable identity, so it takes effect only together
     * with `id`.
     */
    public function onRemove(handler:ControlHandler):Attachment {
        onRemoveValue = handler;
        return this;
    }

    /**
     * Offer a retry control while the attachment is `AttachmentStatus.Failed`:
     * a round button over an image preview, or a link after the typed
     * description. It takes effect only together with `id`.
     */
    public function onRetry(handler:ControlHandler):Attachment {
        onRetryValue = handler;
        return this;
    }

    /**
     * Report upload progress as a percentage from 0 to 100.
     *
     * While `AttachmentStatus.Uploading`, the media shows a progress ring
     * instead of the spinner, a horizontal card draws a thin bar along its
     * bottom edge, and a typed description gains the percentage.
     */
    public function progress(percent:Float):Attachment {
        progressValue = percent < 0. ? 0. : (percent > 100. ? 100. : percent);
        return this;
    }

    /**
     * Show a tooltip while the card is hovered, e.g. the reason an upload
     * failed. It takes effect only together with `id`.
     */
    public function tooltip(text:String):Attachment {
        tooltipValue = text;
        return this;
    }

    /** Set the attachment lifecycle status. */
    public function status(status:AttachmentStatus):Attachment {
        statusValue = status;
        return this;
    }

    /** Set the attachment layout axis. */
    public function axis(axis:Axis):Attachment {
        axisValue = axis;
        return this;
    }

    /** Set the media slot. */
    public function media(media:AttachmentMedia):Attachment {
        mediaValue = media;
        return this;
    }

    /** Set the metadata content slot. */
    public function content(content:AttachmentContent):Attachment {
        contentValue = content;
        return this;
    }

    /** Set the actions slot. */
    public function actions(actions:AttachmentActions):Attachment {
        actionsValue = actions;
        return this;
    }

    public function withSize(size:IntoSize):Attachment {
        this.size = size;
        return this;
    }

    public inline function style():StyleRefinement {
        return attachmentStyle;
    }

    /**
     * The geometry of a named size (Rust `card_metrics`).
     */
    @:allow(glaze.kit.attachment)
    static function cardMetrics(size:Size):CardMetrics {
        inline function r(value:Float):AbsoluteLength {
            return AbsoluteLength.Rems(rems(value));
        }
        return switch size {
            case XSmall: new CardMetrics(r(2.5), r(11.), r(1.75), r(0.875), r(0.25), r(0.375), r(0.25), r(0.375), r(0.6875), r(0.625));
            case Small: new CardMetrics(r(3.), r(12.5), r(2.), r(1.), r(0.375), r(0.5), r(0.375), r(0.5), r(0.75), r(0.6875));
            case Medium: new CardMetrics(r(3.5), r(14.5), r(2.375), r(1.25), r(0.5), r(0.75), r(0.5), r(0.625), r(0.8125), r(0.75));
            case Large: new CardMetrics(r(4.), r(17.), r(2.75), r(1.5), r(0.625), r(1.), r(0.75), r(0.75), r(0.875), r(0.8125));
            // A custom density scales the medium geometry from its base value.
            case Size(value):
                inline function p(factor:Float):AbsoluteLength {
                    return AbsoluteLength.Pixels(f32(value * factor));
                }
                new CardMetrics(p(3.5), p(14.5), p(2.375), p(1.25), p(0.5), p(0.75), p(0.5), p(0.625), p(0.8125), p(0.75));
        }
    }

    /**
     * The card's corner radius for a size (Rust `card_radius`).
     */
    @:allow(glaze.kit.attachment)
    static function cardRadius(size:Size, cx:App):Pixels {
        final tokens = Theme.global(cx).semanticTokens();
        return size.equals(XSmall) ? tokens.radius.md : tokens.radius.lg;
    }

    static inline function f32(value:Float):Float {
        return glaze.SpringMath.f32(value);
    }

    /**
     * The retry control the slots may render: only while failed, and only
     * with an identity to key its state on.
     */
    function retryControl():Null<AttachmentControl> {
        if (!statusValue.isFailed()) {
            return null;
        }
        if (idValue == null || onRetryValue == null) {
            return null;
        }
        return new AttachmentControl(idValue, onRetryValue);
    }

    @:allow(tests)
    function layoutSlots():Void {
        final layout = new SlotLayout(
            size,
            statusValue,
            axisValue,
            // A vertical card without content is an image tile: the media
            // fills the card flush with its border.
            axisValue == Vertical && contentValue == null,
            retryControl(),
            // Progress is only meaningful while uploading; processing is
            // indeterminate.
            statusValue.isUploading() ? progressValue : null,
            idValue
        );

        if (mediaValue != null) mediaValue = mediaValue.layout(layout);
        if (contentValue != null) contentValue = contentValue.layout(layout);
        if (actionsValue != null) actionsValue = actionsValue.layoutForAxis(layout.axis);
    }

    public function render(_:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final tokens = theme.semanticTokens();
        final size = this.size;
        final axis = axisValue;
        final status = statusValue;
        final hasMedia = mediaValue != null;
        final hasContent = contentValue != null;
        final clickable = idValue != null && onClickValue != null;
        final remove:Null<AttachmentControl> = idValue != null && onRemoveValue != null ? new AttachmentControl(idValue, onRemoveValue) : null;
        onRemoveValue = null;
        final tooltipText:Null<String> = idValue != null ? tooltipValue : null;
        tooltipValue = null;
        final progressBar:Null<Float> = status.isUploading() && axis == Horizontal ? progressValue : null;
        final metrics = cardMetrics(size);
        final radius = cardRadius(size, cx);
        final flush = axis == Vertical && !hasContent;

        layoutSlots();

        final card = div()
            .relative()
            .flex()
            .flexNone()
            .maxWFull()
            .minW0()
            .rounded(radius)
            .border1()
            .borderColor(status.isFailed() ? tokens.colors.destructive : tokens.colors.border);
        if (status.isPending()) card.borderDashed();
        card
            .bg(tokens.colors.background)
            .textColor(tokens.colors.foreground)
            // Register `hover` unconditionally: a conditionally registered
            // hover style stays cached when the condition later flips off.
            .hover(style -> clickable ? style.bg(tokens.colors.muted.opacity(0.5)) : style)
            .lineHeight(glaze.Prelude.relative(1.25))
            .textSize(metrics.text);
        switch axis {
            // A chip: fixed height, fixed width once it carries content, the
            // media slot flush to the leading padding.
            case Horizontal:
                card
                    .itemsCenter()
                    .h(metrics.height)
                    .gap(metrics.gap)
                    .pl(metrics.paddingStart)
                    .pr(metrics.paddingEnd);
                if (hasContent) card.w(metrics.chipWidth);
                if (!hasContent && !hasMedia) card.pl(metrics.paddingEnd);
            // An image tile: a square the media fills edge to edge.
            case Vertical if (flush):
                card.size(metrics.height);
            // A preview card: media above the metadata.
            case Vertical:
                card
                    .w(rems(7.5))
                    .flexCol()
                    .itemsStart()
                    .gap(metrics.gap)
                    .p(metrics.cardPadding);
        }
        if (mediaValue != null) card.child(mediaValue);
        if (contentValue != null) card.child(contentValue);
        // A thin bar along the bottom edge tracks the upload, hugging the
        // card's rounded corners.
        if (progressBar != null) card.child(uploadBar(progressBar, radius, tokens.colors.primary));
        if (idValue != null && onClickValue != null) {
            final onClick = onClickValue;
            // The click layer is painted before the actions slot, so the
            // actions' hitboxes stay on top and their buttons keep working.
            card.child(
                div()
                    .id(idValue)
                    .absolute()
                    .inset0()
                    .onClick((event, window, cx) -> onClick(event, window, cx))
            );
        }
        if (actionsValue != null) card.child(actionsValue);
        card.refineStyle(attachmentStyle);
        if (tooltipText != null) {
            final text = tooltipText;
            card
                .id(ElementId.NamedChild(idValue, 'card'))
                .tooltip((window, cx) -> new Tooltip(text).build(window, cx));
        }

        if (remove == null) {
            return card;
        }
        // The remove control rides outside the card, so the card gets a
        // hover group and room for the overhang.
        final corner = div()
            .absolute()
            .top0()
            .right0();
        if (!glaze.kit.base.Prelude.isMobile()) {
            corner.invisible().groupHover(REMOVE_GROUP, style -> style.visible());
        }
        corner.child(removeButton(remove.id, remove.handler, cx));
        return div()
            .relative()
            .flexNone()
            .maxWFull()
            .minW0()
            .group(REMOVE_GROUP)
            .pt(REMOVE_OVERHANG)
            .pr(REMOVE_OVERHANG)
            .child(card)
            .child(corner);
    }

    /**
     * The upload bar along a card's bottom edge. gpui clips rectangularly, so
     * a plain rectangle could not follow the corner curve; the bar is a
     * filled path whose ends trace the inner corner arcs, as CSS
     * `overflow: hidden` would.
     */
    static function uploadBar(percent:Float, radius:Pixels, color:Hsla):IntoElement {
        return canvas(
            (_, _, _) -> null,
            (bounds:Bounds, _, window:Window, _) -> {
                final path = uploadBarPath(bounds, percent, radius);
                if (path != null) window.paintPath(path, color);
            }
        )
            .absolute()
            .inset0();
    }

    /**
     * The bar as the intersection of its rectangle with the card's inner
     * rounded rectangle: both ends are sampled along the corner arcs. An
     * absolutely positioned child is laid out in the card's padding box, so
     * `bounds` already sits inside the border; only the corner radius
     * shrinks by the border width. Computed in f32 like the original.
     */
    @:allow(tests)
    static function uploadBarPath(bounds:Bounds, percent:Float, radius:Pixels):Null<Path> {
        final STEPS = 6;
        final width = f32(bounds.size.width);
        final height = f32(bounds.size.height);
        final minSide = width < height ? width : height;
        final radiusLimit = f32(minSide / 2.);
        var radius = f32((radius : Float) - CARD_BORDER);
        radius = radius < 0. ? 0. : (radius > radiusLimit ? radiusLimit : radius);
        final innerLeft = 0.;
        final innerRight = width;
        final innerBottom = height;
        final top = f32(innerBottom - UPLOAD_BAR_THICKNESS);
        final fraction = f32(percent / 100.);
        final clampedFraction = fraction < 0. ? 0. : (fraction > 1. ? 1. : fraction);
        final end = f32(innerLeft + f32(f32(innerRight - innerLeft) * clampedFraction));
        if (end <= innerLeft || top <= 0.) {
            return null;
        }
        // The corner circles' centre line; rows below it lie in the arcs.
        final centreY = f32(innerBottom - radius);
        function arcDx(y:Float):Float {
            if (radius > 0. && y > centreY) {
                final dy = f32(y - centreY);
                final value = f32(f32(radius * radius) - f32(dy * dy));
                return f32(Math.sqrt(value > 0. ? value : 0.));
            }
            return radius;
        }
        function leftAt(y:Float):Float {
            return f32(f32(innerLeft + radius) - arcDx(y));
        }
        function rightAt(y:Float):Float {
            final x = f32(f32(innerRight - radius) + arcDx(y));
            return x < end ? x : end;
        }
        function at(x:Float, y:Float):Point {
            return point(f32(bounds.origin.x + x), f32(bounds.origin.y + y));
        }
        final rows = [for (i in 0...STEPS + 1) f32(top + f32(f32(UPLOAD_BAR_THICKNESS * i) / STEPS))];

        final builder = PathBuilder.fill();
        builder.moveTo(at(leftAt(top), top));
        // Down the right end, then back up the left arc.
        for (y in rows) {
            builder.lineTo(at(rightAt(y), y));
        }
        var i = rows.length - 1;
        while (i >= 0) {
            final y = rows[i];
            builder.lineTo(at(leftAt(y), y));
            i--;
        }
        try {
            return builder.build();
        } catch (_:Dynamic) {
            return null;
        }
    }

    /**
     * The corner remove control: a surface-colored disc with a hairline
     * border and the foreground glyph, the way a card's close control usually
     * looks.
     *
     * The glyphs go in as children: an icon-only `Button` scales its icon
     * with the button, and this disc wants a glyph much smaller than that.
     */
    static function removeButton(id:ElementId, onRemove:ControlHandler, cx:App):Button {
        final theme = Theme.global(cx);
        final tokens = theme.semanticTokens();
        final icon = Icon.component(IconName.Close).textColor(tokens.colors.foreground);
        new StyleBuilder(icon.style()).size(px(10.));
        return Button.component(ElementId.NamedChild(id, 'remove'))
            // The custom variant thins its color to 20%; the disc must stay
            // opaque, so the surface is set on the instance instead.
            .custom(
                new glaze.kit.button.Button.ButtonCustomVariant(cx)
                    .hover(tokens.colors.muted)
                    .active(tokens.colors.muted)
                    .foreground(tokens.colors.foreground)
            )
            .accessibilityLabel(I18n.t('Attachment.Remove'))
            .child(icon)
            .size(REMOVE_BUTTON_SIZE)
            .p0()
            .rounded(theme.radiusFull())
            .bg(tokens.colors.background)
            .border1()
            .borderColor(tokens.colors.border)
            .shadowSm()
            .onClick((event, window, cx) -> onRemove(event, window, cx));
    }

    /**
     * The retry control over a failed image preview: a surface-colored disc
     * with the destructive refresh glyph.
     */
    @:allow(glaze.kit.attachment)
    static function retryButton(id:ElementId, onRetry:ControlHandler, cx:App):Button {
        final theme = Theme.global(cx);
        final tokens = theme.semanticTokens();
        final icon = Icon.component(IconName.RefreshCw).textColor(tokens.colors.destructive);
        new StyleBuilder(icon.style()).size(px(12.));
        return Button.component(ElementId.NamedChild(id, 'retry'))
            .ghost()
            .accessibilityLabel(I18n.t('Attachment.Retry'))
            .child(icon)
            .size(RETRY_BUTTON_SIZE)
            .p0()
            .rounded(theme.radiusFull())
            .bg(tokens.colors.background)
            .shadowSm()
            .onClick((event, window, cx) -> onRetry(event, window, cx));
    }

}

/**
 * The media slot for an attachment.
 *
 * Add an icon or another element as a child for an icon-style preview. Use
 * `src` when the attachment has an image preview.
 */
class AttachmentMedia implements RenderOnce implements Styled implements ParentElement implements Sizable {

    final mediaStyle:StyleRefinement = new StyleRefinement();

    @:allow(glaze.kit.attachment, tests)
    var size:Null<Size> = null;

    @:allow(glaze.kit.attachment, tests)
    var status:AttachmentStatus = Complete;

    @:allow(glaze.kit.attachment, tests)
    var axis:Axis = Horizontal;

    /** Whether the media fills a vertical card flush with its border. */
    @:allow(glaze.kit.attachment, tests)
    var flush:Bool = false;

    @:allow(glaze.kit.attachment, tests)
    var retry:Null<AttachmentControl> = null;

    /** Upload progress in percent, while uploading. */
    @:allow(glaze.kit.attachment, tests)
    var progress:Null<Float> = null;

    /** The attachment's identity, keying the progress ring's state. */
    @:allow(glaze.kit.attachment, tests)
    var id:Null<ElementId> = null;

    @:allow(tests)
    var source:Null<ImageSource> = null;

    @:allow(tests)
    final childElements:Array<AnyElement> = [];

    @:allow(tests)
    final overlays:Array<AnyElement> = [];

    /** Create an empty media slot. */
    public function new() {}

    /** Set an image preview source. */
    public function src(source:IntoImageSource):AttachmentMedia {
        this.source = source;
        return this;
    }

    /** Add centered content above the preview and above the status treatment. */
    public function overlay(overlay:IntoElement):AttachmentMedia {
        if (overlay != null) overlays.push(
            div()
                .absolute()
                .inset0()
                .flex()
                .itemsCenter()
                .justifyCenter()
                .child(overlay)
                .intoAnyElement()
        );
        return this;
    }

    @:allow(glaze.kit.attachment, tests)
    function layout(layout:SlotLayout):AttachmentMedia {
        if (size == null) {
            size = layout.size;
        }
        status = layout.status;
        axis = layout.axis;
        flush = layout.flush;
        retry = layout.retry;
        progress = layout.progress;
        id = layout.id;
        return this;
    }

    public function withSize(size:IntoSize):AttachmentMedia {
        this.size = size;
        return this;
    }

    public inline function style():StyleRefinement {
        return mediaStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):AttachmentMedia {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):AttachmentMedia {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    /** Copies the corner radii a caller set on the slot (Rust `corner_radii.refine`). */
    function refineCorners(target:StyleRefinement):Void {
        if (mediaStyle.cornerRadiusTopLeft != null) target.cornerRadiusTopLeft = mediaStyle.cornerRadiusTopLeft;
        if (mediaStyle.cornerRadiusTopRight != null) target.cornerRadiusTopRight = mediaStyle.cornerRadiusTopRight;
        if (mediaStyle.cornerRadiusBottomRight != null) target.cornerRadiusBottomRight = mediaStyle.cornerRadiusBottomRight;
        if (mediaStyle.cornerRadiusBottomLeft != null) target.cornerRadiusBottomLeft = mediaStyle.cornerRadiusBottomLeft;
    }

    public function render(_:Window, cx:App):IntoElement {
        final theme = Theme.global(cx);
        final tokens = theme.semanticTokens();
        final resolvedSize:Size = size != null ? size : Medium;
        final metrics = Attachment.cardMetrics(resolvedSize);
        // Flush media sits inside the card's 1px border, so its corners are
        // one border width tighter than the card's to stay concentric.
        final radius:Pixels = if (flush) {
            final r = Attachment.cardRadius(resolvedSize, cx) - 1.;
            r > 0. ? r : 0.;
        } else if (resolvedSize.equals(XSmall)) {
            tokens.radius.sm;
        } else {
            tokens.radius.md;
        }
        final glyphSize = metrics.mediaGlyph;
        final spinnerSize:Size = resolvedSize.equals(XSmall) ? XSmall : Small;
        final ringSize:Pixels = resolvedSize.equals(XSmall) ? 14. : 20.;
        final status = this.status;
        final source = this.source;
        final hasSource = source != null;
        final failedMedia = status.isFailed() && !hasSource;
        final ringId:ElementId = id != null ? ElementId.NamedChild(id, 'progress') : ElementId.Name('attachment-progress');
        final progress = this.progress;
        // In progress: a determinate ring while uploading with a known
        // percentage, a spinner otherwise.
        function busy(color:Hsla):AnyElement {
            if (progress != null) {
                final ring = ProgressCircle.component(ringId)
                    .value(progress)
                    .color(color);
                new StyleBuilder(ring.style()).size(ringSize);
                return (ring : IntoElement);
            }
            return (Spinner.component()
                .withSize(spinnerSize)
                .color(color) : IntoElement);
        }
        // An icon slot shows the status itself; children come back with
        // `Complete`.
        final glyph:Null<AnyElement> = if (hasSource) {
            null;
        } else if (status.isInProgress()) {
            busy(tokens.colors.primary);
        } else if (status.isFailed()) {
            if (retry != null) {
                (Attachment.retryButton(retry.id, retry.handler, cx) : IntoElement);
            } else {
                final icon = Icon.component(IconName.Ban);
                new StyleBuilder(icon.style()).size(glyphSize);
                (icon : IntoElement);
            }
        } else {
            null;
        }
        // An image keeps its colors and takes a scrim instead, so the white
        // control on top stays legible on any picture.
        var scrimOpacity:Float = 0.;
        final scrimControl:Null<AnyElement> = if (!hasSource) {
            null;
        } else if (status.isInProgress()) {
            scrimOpacity = Attachment.PROGRESS_SCRIM;
            busy(white());
        } else if (status.isFailed()) {
            scrimOpacity = Attachment.FAILED_SCRIM;
            if (retry != null) {
                (Attachment.retryButton(retry.id, retry.handler, cx) : IntoElement);
            } else {
                final icon = Icon.component(IconName.Ban).textColor(white());
                new StyleBuilder(icon.style()).size(glyphSize);
                (icon : IntoElement);
            }
        } else {
            null;
        }

        final element = div()
            .relative()
            .flex()
            .flexShrink0()
            .itemsCenter()
            .justifyCenter()
            .overflowHidden();
        if (axis == Horizontal) element.size(metrics.media);
        // An icon child without its own size follows the slot's text size.
        element.textSize(glyphSize);
        if (axis == Vertical) element.wFull().aspectRatio(1.);
        element
            .rounded(radius)
            .bg(failedMedia ? tokens.colors.destructive.opacity(0.1) : tokens.colors.muted)
            .textColor(failedMedia ? tokens.colors.destructive : tokens.colors.foreground);
        if (source != null) {
            // gpui clips rectangularly, so the slot's `overflowHidden` cannot
            // round the image: it carries the slot's radius itself, including
            // a caller's `rounded()` refinement.
            final image = img(source)
                .absolute()
                .inset0()
                .sizeFull()
                .rounded(radius)
                .objectFit(ObjectFit.Cover);
            refineCorners(image.style());
            element.child(image);
        }
        if (glyph != null) {
            element.child(glyph);
        } else {
            element.extend(childElements);
        }
        if (scrimControl != null) {
            // The scrim is clipped rectangularly like the image, so it rounds
            // itself the same way, refinement included.
            final scrim = div()
                .absolute()
                .inset0()
                .flex()
                .itemsCenter()
                .justifyCenter()
                .rounded(radius)
                .bg(black().opacity(scrimOpacity))
                .child(scrimControl);
            refineCorners(scrim.style());
            element.child(scrim);
        }
        element.extend(overlays);
        element.refineStyle(mediaStyle);
        return element;
    }

}

/**
 * A child of `AttachmentContent`: a typed title, a typed description, or any
 * element.
 */
enum AttachmentContentChild {
    Title(title:AttachmentTitle);
    Description(description:AttachmentDescription);
    Element(element:AnyElement);
}

/**
 * The metadata slot for an attachment.
 */
class AttachmentContent implements RenderOnce implements Styled implements ParentElement {

    final contentStyle:StyleRefinement = new StyleRefinement();

    @:allow(glaze.kit.attachment, tests)
    var verticalLayout:Bool = false;

    @:allow(glaze.kit.attachment, tests)
    var status:AttachmentStatus = Complete;

    @:allow(glaze.kit.attachment, tests)
    var retry:Null<AttachmentControl> = null;

    @:allow(glaze.kit.attachment, tests)
    var progress:Null<Float> = null;

    @:allow(tests)
    final childElements:Array<AttachmentContentChild> = [];

    /** Create an empty metadata slot. */
    public function new() {}

    /** Add a status-aware single-line title. */
    public function title(title:AttachmentTitle):AttachmentContent {
        childElements.push(Title(title));
        return this;
    }

    /** Add a status-aware single-line description. */
    public function description(description:AttachmentDescription):AttachmentContent {
        childElements.push(Description(description));
        return this;
    }

    @:allow(glaze.kit.attachment, tests)
    function layout(layout:SlotLayout):AttachmentContent {
        verticalLayout = layout.axis == Vertical;
        status = layout.status;
        retry = layout.retry;
        progress = layout.progress;

        for (child in childElements) {
            switch child {
                case Title(title):
                    if (title.statusValue == null) {
                        title.statusValue = layout.status;
                    }
                case Description(description):
                    if (description.statusValue == null) {
                        description.statusValue = layout.status;
                    }
                    if (description.size == null) {
                        description.size = layout.size;
                    }
                case Element(_):
            }
        }

        return this;
    }

    public inline function style():StyleRefinement {
        return contentStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(Element(element));
    }

    public function child(child:IntoElement):AttachmentContent {
        if (child != null) childElements.push(Element(child));
        return this;
    }

    public function children(children:Array<IntoElement>):AttachmentContent {
        for (child in children) if (child != null) childElements.push(Element(child));
        return this;
    }

    public function render(_:Window, cx:App):IntoElement {
        final tokens = Theme.global(cx).semanticTokens();
        // The retry link follows the first typed description while failed;
        // the percentage joins it while uploading.
        var retry:Null<AttachmentControl> = status.isFailed() ? this.retry : null;
        final progress:Null<Float> = status.isUploading() ? this.progress : null;
        final element = glaze.kit.base.Prelude.vFlex()
            .maxWFull()
            .minW0()
            .flex1()
            .gap0p5()
            .lineHeight(glaze.Prelude.relative(1.25));
        if (verticalLayout) element.wFull().px1();
        for (child in childElements) {
            switch child {
                case Title(title):
                    element.child(title);
                case Description(description):
                    if (retry != null) {
                        final control = retry;
                        retry = null;
                        element.child(
                            glaze.kit.base.Prelude.hFlex()
                                .maxWFull()
                                .minW0()
                                .gap1()
                                .child(description)
                                .child(
                                    div()
                                        .textXs()
                                        .textColor(tokens.colors.mutedForeground)
                                        .child('·')
                                )
                                .child(
                                    Button.component(ElementId.NamedChild(control.id, 'retry'))
                                        .link()
                                        .xsmall()
                                        .label(I18n.t('Attachment.Retry'))
                                        .onClick((event, window, cx) -> control.handler(event, window, cx))
                                )
                        );
                    } else {
                        if (progress != null) {
                            description.text = description.text + ' · ' + Std.int(glaze.util.MathUtil.round(progress)) + '%';
                        }
                        element.child(description);
                    }
                case Element(e):
                    element.child(e);
            }
        }
        element.refineStyle(contentStyle);
        return element;
    }

}

/**
 * A single-line attachment title.
 */
class AttachmentTitle implements RenderOnce implements Styled {

    final titleStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    final text:String;

    @:allow(glaze.kit.attachment, tests)
    var statusValue:Null<AttachmentStatus> = null;

    @:allow(tests)
    var shimmerStyle:Null<ShimmerStyle> = null;

    /** Create an attachment title. */
    public function new(text:String) {
        this.text = text;
    }

    /** Override the attachment lifecycle status used for the loading shimmer. */
    public function status(status:AttachmentStatus):AttachmentTitle {
        statusValue = status;
        return this;
    }

    /** Customize the shimmer used while this attachment is uploading or processing. */
    public function withShimmerStyle(style:ShimmerStyle):AttachmentTitle {
        shimmerStyle = style;
        return this;
    }

    public inline function style():StyleRefinement {
        return titleStyle;
    }

    public function render(_:Window, _:App):IntoElement {
        final loading = statusValue != null && (statusValue : AttachmentStatus).isInProgress();

        final element = div()
            .maxWFull()
            .minW0()
            .truncate()
            .fontMedium();
        if (loading) {
            final shimmer = ShimmerText.component(text);
            if (shimmerStyle != null) shimmer.withShimmerStyle(shimmerStyle);
            element.child(shimmer);
        } else {
            element.child(text);
        }
        element.refineStyle(titleStyle);
        return element;
    }

}

/**
 * A single-line attachment description or status message.
 */
class AttachmentDescription implements RenderOnce implements Styled {

    final descriptionStyle:StyleRefinement = new StyleRefinement();

    @:allow(glaze.kit.attachment, tests)
    var text:String;

    @:allow(glaze.kit.attachment, tests)
    var statusValue:Null<AttachmentStatus> = null;

    /** The card size whose type scale the description follows. */
    @:allow(glaze.kit.attachment, tests)
    var size:Null<Size> = null;

    /** Create an attachment description. */
    public function new(text:String) {
        this.text = text;
    }

    /** Set the status used for the semantic description color. */
    public function status(status:AttachmentStatus):AttachmentDescription {
        statusValue = status;
        return this;
    }

    public inline function style():StyleRefinement {
        return descriptionStyle;
    }

    public function render(_:Window, cx:App):IntoElement {
        final tokens = Theme.global(cx).semanticTokens();
        final color = statusValue != null && (statusValue : AttachmentStatus).isFailed() ? tokens.colors.destructive : tokens.colors.mutedForeground;

        return div()
            .maxWFull()
            .minW0()
            .truncate()
            .textSize(Attachment.cardMetrics(size != null ? size : Medium).description)
            .lineHeight(glaze.Prelude.relative(1.25))
            .textColor(color)
            .child(text)
            .refineStyle(descriptionStyle);
    }

}

/**
 * A composition slot for attachment actions.
 *
 * Add existing `glaze.kit.button.Button` or other controls as
 * children. A separate attachment-specific action wrapper is intentionally
 * unnecessary.
 */
class AttachmentActions implements RenderOnce implements Styled implements ParentElement {

    final actionsStyle:StyleRefinement = new StyleRefinement();

    @:allow(glaze.kit.attachment, tests)
    var verticalLayout:Bool = false;

    @:allow(tests)
    final childElements:Array<AnyElement> = [];

    /** Create an empty actions slot. */
    public function new() {}

    @:allow(glaze.kit.attachment, tests)
    function layoutForAxis(axis:Axis):AttachmentActions {
        verticalLayout = axis == Vertical;
        return this;
    }

    public inline function style():StyleRefinement {
        return actionsStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):AttachmentActions {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):AttachmentActions {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function render(_:Window, _:App):IntoElement {
        final element = div()
            .relative()
            .flex()
            .flexShrink0()
            .itemsCenter()
            .gap1();
        if (verticalLayout) element.absolute().top3().right3();
        // The actions cluster owns its presses: an action (or the gap between
        // actions) must not also arm the whole-card click layer below,
        // mirroring the shadcn stacking where actions sit above the trigger.
        // Buttons run first in the bubble phase, so they are unaffected.
        element.onMouseDown(MouseButton.Left, (_, _, cx) -> cx.stopPropagation());
        element.extend(childElements);
        element.refineStyle(actionsStyle);
        return element;
    }

}

/**
 * The scroll state a group keeps for itself when the caller passes none.
 */
private class AttachmentGroupScroll {

    public final handle:ScrollHandle;

    /**
     * Whether the frame after the first layout has been requested: the
     * scroll extent is unknown until then, so the fades need one more pass.
     */
    public var primed:Bool;

    public function new(handle:ScrollHandle, primed:Bool) {
        this.handle = handle;
        this.primed = primed;
    }

}

/**
 * A horizontally scrollable row of attachments.
 */
class AttachmentGroup implements RenderOnce implements Styled implements ParentElement {

    /** How long an edge fade takes to appear or disappear, in seconds. */
    static inline final EDGE_FADE_TRANSITION:Float = 0.2;

    final id:ElementId;

    final groupStyle:StyleRefinement = new StyleRefinement();

    @:allow(tests)
    var scrollHandle:Null<ScrollHandle> = null;

    @:allow(tests)
    var edgeFade:Null<Hsla> = null;

    @:allow(tests)
    final childElements:Array<AnyElement> = [];

    /** Create an empty attachment group with a stable scroll identifier. */
    public function new(id:ElementIdArg) {
        this.id = id;
    }

    /**
     * Scroll the row through the caller's handle.
     *
     * The group keeps its own scroll state otherwise. Pass a handle when the
     * application moves the row itself, for example from paging buttons.
     */
    public function trackScroll(handle:ScrollHandle):AttachmentGroup {
        scrollHandle = handle;
        return this;
    }

    /**
     * Fade the row's edges into `color` while attachments continue past them.
     *
     * Pass the color of the surface behind the row. Each fade shows only
     * while its edge still hides content, so a row that fits shows none; the
     * fades sit above the attachments and do not take pointer events.
     */
    public function withEdgeFade(color:IntoHsla):AttachmentGroup {
        edgeFade = color;
        return this;
    }

    public inline function style():StyleRefinement {
        return groupStyle;
    }

    public function extend(elements:Array<AnyElement>):Void {
        for (element in elements) childElements.push(element);
    }

    public function child(child:IntoElement):AttachmentGroup {
        if (child != null) childElements.push(child);
        return this;
    }

    public function children(children:Array<IntoElement>):AttachmentGroup {
        for (child in children) if (child != null) childElements.push(child);
        return this;
    }

    public function render(window:Window, cx:App):IntoElement {
        final id = this.id;
        // Element-local state keyed on the id: the fades read the offset
        // across frames, and the first layout must be followed by one more
        // render before the scroll extent is known.
        final scroll = window.useKeyedState(ElementId.NamedChild(id, 'scroll'), cx, _ -> new AttachmentGroupScroll(new ScrollHandle(), false));
        final handle = scrollHandle != null ? scrollHandle : scroll.read(cx).value.handle;
        final viewId = window.currentView();

        var fadeColor:Null<Hsla> = null;
        var leading = 0.;
        var trailing = 0.;
        if (edgeFade != null) {
            final color:Hsla = edgeFade;
            final scrollState = scroll.read(cx).value;
            if (!scrollState.primed) {
                scrollState.primed = true;
                window.onNextFrame((_, cx) -> cx.notify(viewId));
            }
            final max = handle.maxOffset().x;
            // Scrolling right makes the offset negative.
            final offset = handle.offset().x;
            final scrollable = max > 1.;
            final hidesLeading = scrollable && offset < -1.;
            final hidesTrailing = scrollable && offset > 1. - max;
            leading = Motion.transition(
                TransitionId.named(id, 'leading-fade'),
                hidesLeading ? 1. : 0.,
                new Transition(EDGE_FADE_TRANSITION),
                window,
                cx
            );
            trailing = Motion.transition(
                TransitionId.named(id, 'trailing-fade'),
                hidesTrailing ? 1. : 0.,
                new Transition(EDGE_FADE_TRANSITION),
                window,
                cx
            );
            fadeColor = color;
        }

        final row = glaze.kit.base.Prelude.hFlex()
            .id(id)
            .wFull()
            .minW0()
            .gap3()
            .py1()
            .overflowXScroll()
            .lockScrollAxis()
            .trackScroll(handle);
        // Scrolling only moves the offset; the fades need a render to follow.
        if (fadeColor != null) row.onScroll((_, _, cx) -> cx.notify(viewId));
        row.refineStyle(groupStyle);
        row.extend(childElements);

        // Gradient angle: 0 points up and increases clockwise, so 90 runs
        // from the leading edge to the trailing edge.
        function fade(color:Hsla, opacity:Float, isLeading:Bool):IntoElement {
            final from = isLeading ? color : color.opacity(0.);
            final to = isLeading ? color.opacity(0.) : color;
            final element = div()
                .absolute()
                .top0()
                .bottom0();
            if (isLeading) element.left0();
            if (!isLeading) element.right0();
            return element
                .w(rems(1.5))
                .opacity(opacity)
                .bg(linearGradient(
                    90.,
                    linearColorStop(from, 0.),
                    linearColorStop(to, 1.)
                ));
        }

        final element = div()
            .relative()
            .wFull()
            .minW0()
            .child(row)
            .child(ScrollableMask.verticalWheel(handle));
        if (fadeColor != null) {
            if (leading > 0.) element.child(fade(fadeColor, leading, true));
            if (trailing > 0.) element.child(fade(fadeColor, trailing, false));
        }
        return element;
    }

}
