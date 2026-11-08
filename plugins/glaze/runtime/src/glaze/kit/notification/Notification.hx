// Ported from gpui-kit 0.8.1: crates/component/src/notification.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.notification;

import glaze.Anchor;
import glaze.Animation;
import glaze.AnyElement;
import glaze.App;
import glaze.AppContext;
import glaze.ClickEvent;
import glaze.Context;
import glaze.DismissEvent;
import glaze.Edges;
import glaze.ElementId;
import glaze.ElementIdArg;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Model;
import glaze.Pixels;
import glaze.Render;
import glaze.SpringMath.f32;
import glaze.StyleRefinement;
import glaze.Styled;
import glaze.Subscription;
import glaze.SystemNotification;
import glaze.SystemNotificationResponse;
import glaze.WeakEntity;
import glaze.Window;
import glaze.kit.base.Toast;
import glaze.kit.base.animation.Easings;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.TitleBar;
import glaze.kit.button.Button;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.ClickEvent.ClickEventTools;
using glaze.kit.base.StyledExt;
using glaze.kit.ThemeStyled;

/**
 * The kind of a notification: its default icon and color.
 */
enum abstract NotificationType(Int) {
    var Info = 0;
    var Success = 1;
    var Warning = 2;
    var Error = 3;

    @:allow(glaze.kit)
    function icon(cx:App):Icon {
        final theme = Theme.global(cx);
        return switch (cast this : NotificationType) {
            case Info: Icon.component(IconName.Info).textColor(theme.info);
            case Success: Icon.component(IconName.CircleCheck).textColor(theme.success);
            case Warning: Icon.component(IconName.TriangleAlert).textColor(theme.warning);
            case Error: Icon.component(IconName.CircleX).textColor(theme.danger);
        }
    }
}

/**
 * Where a notification is presented: as an in-app toast, in the operating
 * system's notification center, or both.
 */
enum abstract NotificationDelivery(Int) {
    /** Show only the in-app toast (the default). */
    var InApp = 0;
    /** Post only to the OS notification center; no in-app toast is shown. */
    var System = 1;
    /** Show the in-app toast and post to the OS notification center. */
    var InAppAndSystem = 2;

    /** Whether this delivery shows an in-app toast. */
    public inline function includesInApp():Bool {
        return (cast this : NotificationDelivery) == InApp || (cast this : NotificationDelivery) == InAppAndSystem;
    }

    /** Whether this delivery posts to the OS notification center. */
    public inline function includesSystem():Bool {
        return (cast this : NotificationDelivery) == System || (cast this : NotificationDelivery) == InAppAndSystem;
    }
}

/**
 * Namespaces the library's system-notification tags away from tags the
 * application posts itself.
 */
private final SYSTEM_TAG_PREFIX = 'gpui-component/notification/';

/**
 * The id of a notification: a marker type (Rust `TypeId`, here the class
 * name of the marker class), optionally paired with an element id.
 */
enum NotificationId {
    Id(typeId:String);
    IdAndElementId(typeId:String, id:ElementId);
}

class NotificationIdTools {

    /**
     * Stable OS-notification tag for this id within a running binary.
     */
    public static function systemTag(self:NotificationId):String {
        return SYSTEM_TAG_PREFIX + Std.string(self);
    }

    /** The marker type of the id. */
    public static function typeId(self:NotificationId):String {
        return switch self {
            case Id(t) | IdAndElementId(t, _): t;
        }
    }

    public static inline function typeIdOf(type:Class<Dynamic>):String {
        return Type.getClassName(type);
    }

}

/**
 * Rust `impl Into<Notification>`: a notification, a message, or a
 * `{type, message}` pair (Rust `(NotificationType, T)`).
 */
abstract IntoNotification(Notification) from Notification to Notification {

    @:from static inline function fromString(message:String):IntoNotification {
        return new Notification().message(message);
    }

    @:from static inline function fromTyped(pair:{type:NotificationType, message:String}):IntoNotification {
        return new Notification().message(pair.message).withType(pair.type);
    }

}

/** The event a notification emits to ask its list to dismiss it. */
private class DismissRequest {

    public static final instance = new DismissRequest();

    function new() {}

}

private class DefaultIdType {}

/**
 * A notification element.
 *
 * Rust builds the struct and moves it into an entity on push: here the
 * object is a `Model` from the start, attached to the app on push.
 */
@:allow(glaze.kit, tests)
class Notification extends Model implements Render implements Styled {

    static var nextDefaultId:Int = 0;

    /**
     * The id is used make the notification unique.
     * When you push a notification with the same id, the previous notification will be replaced.
     */
    var idValue:NotificationId;

    final notificationStyle:StyleRefinement = new StyleRefinement();

    var typeValue:Null<NotificationType> = null;

    var titleValue:Null<String> = null;

    var messageValue:Null<String> = null;

    var iconValue:Null<Icon> = null;

    var placementValue:Null<Anchor> = null;

    var deliveryValue:Null<NotificationDelivery> = null;

    var autohideValue:Bool = true;

    var actionBuilder:Null<(Notification, Window, Context<Notification>) -> Button> = null;

    var contentBuilder:Null<(Notification, Window, Context<Notification>) -> AnyElement> = null;

    var onClickHandler:Null<(ClickEvent, Window, App) -> Void> = null;

    var onCloseHandler:Null<(Window, App) -> Void> = null;

    var transitionStatus:ToastTransitionStatus = Starting;

    /**
     * Create a new notification.
     *
     * The default id is unique (Rust: a random UUID; here a process-wide
     * counter, so ids stay deterministic).
     */
    public function new() {
        super();
        idValue = IdAndElementId(NotificationIdTools.typeIdOf(DefaultIdType), ElementId.Name('default-' + (nextDefaultId++)));
    }

    public inline function style():StyleRefinement {
        return notificationStyle;
    }

    /** Set the message of the notification, default is null. */
    public function message(message:String):Notification {
        messageValue = message;
        return this;
    }

    /** Create an info notification with the given message. */
    public static function info(message:String):Notification {
        return new Notification().message(message).withType(Info);
    }

    /** Create a success notification with the given message. */
    public static function success(message:String):Notification {
        return new Notification().message(message).withType(Success);
    }

    /** Create a warning notification with the given message. */
    public static function warning(message:String):Notification {
        return new Notification().message(message).withType(Warning);
    }

    /** Create an error notification with the given message. */
    public static function error(message:String):Notification {
        return new Notification().message(message).withType(Error);
    }

    /**
     * Set the type for unique identification of the notification (Rust
     * `id::<T>()`: here the marker class; `withId`, since `id` is an
     * inherited Ceramic member).
     */
    public function withId(type:Class<Dynamic>):Notification {
        idValue = Id(NotificationIdTools.typeIdOf(type));
        return this;
    }

    /** Set the type and id of the notification, used to uniquely identify the notification (Rust `id1::<T>(key)`). */
    public function id1(type:Class<Dynamic>, key:ElementIdArg):Notification {
        idValue = IdAndElementId(NotificationIdTools.typeIdOf(type), key);
        return this;
    }

    /**
     * Set the title of the notification, default is null.
     *
     * If title is null, the notification will not have a title.
     */
    public function title(title:String):Notification {
        titleValue = title;
        return this;
    }

    /**
     * Set the icon of the notification.
     *
     * If icon is null, the notification will use the default icon of the type.
     */
    public function icon(icon:Icon):Notification {
        iconValue = icon;
        return this;
    }

    /** Set the type of the notification, default is `NotificationType.Info`. */
    public function withType(type:NotificationType):Notification {
        typeValue = type;
        return this;
    }

    /**
     * Set the placement of the notification, overriding the global
     * `NotificationSettings.placement`.
     *
     * Notifications are stacked separately for each placement.
     */
    public function placement(placement:Anchor):Notification {
        placementValue = placement;
        return this;
    }

    /**
     * Set where this notification is delivered, overriding the global
     * `NotificationSettings.delivery`.
     *
     * System delivery uses the OS notification center: the title and message
     * become the system notification's title and body (a notification with
     * neither is not posted). Pushing again with the same id replaces the
     * previous system notification. Clicking the system notification
     * activates the window, closes the in-app toast (if any), and fires
     * `onClick`; with `NotificationDelivery.System` the toast never exists,
     * so `onClose` is never called.
     *
     * Platform requirements (the Ceramic `notifications` plugin, without
     * which nothing is posted): on macOS the application must run from its
     * signed `.app` bundle (the first post triggers the authorization
     * prompt); on Windows the application must call `App.setAppIdentity`
     * early in startup; on Linux a notification service must be present.
     */
    public function delivery(delivery:NotificationDelivery):Notification {
        deliveryValue = delivery;
        return this;
    }

    /** Deliver this notification only to the OS notification center. */
    public function system():Notification {
        return delivery(System);
    }

    /** Deliver this notification as an in-app toast and to the OS notification center. */
    public function inAppAndSystem():Notification {
        return delivery(InAppAndSystem);
    }

    /** Set the auto hide of the notification, default is true. */
    public function autohide(autohide:Bool):Notification {
        autohideValue = autohide;
        return this;
    }

    /** Set the click callback of the notification. */
    public function onClick(onClick:(ClickEvent, Window, App) -> Void):Notification {
        onClickHandler = onClick;
        return this;
    }

    /**
     * Set the close callback of the notification.
     *
     * Triggered when the notification is closed by any means
     * (close button, middle-click, autohide, click handler, or programmatic close).
     */
    public function onClose(onClose:(Window, App) -> Void):Notification {
        onCloseHandler = onClose;
        return this;
    }

    /**
     * Set the action button of the notification.
     *
     * When an action is set, the notification will not autohide.
     */
    public function action(action:(Notification, Window, Context<Notification>) -> Button):Notification {
        actionBuilder = action;
        autohideValue = false;
        return this;
    }

    /** Dismiss the notification. */
    public function dismiss(window:Window, cx:Context<Notification>):Void {
        cx.emit(DismissRequest.instance);
    }

    function beginClose(cx:Context<Notification>):Void {
        if (transitionStatus != Ending) {
            transitionStatus = Ending;
            cx.notify();
        }
    }

    function completeEnter(cx:Context<Notification>):Void {
        if (transitionStatus == Starting) {
            transitionStatus = Present;
            cx.notify();
        }
    }

    function completeClose(window:Window, cx:Context<Notification>):Void {
        cx.emit(DismissEvent.instance);
        final onClose = onCloseHandler;
        if (onClose != null) {
            onClose(window, cx.app);
        }
    }

    /** Set the content of the notification. */
    public function content(content:(Notification, Window, Context<Notification>) -> AnyElement):Notification {
        contentBuilder = content;
        return this;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final cx:Context<Notification> = cast cx;
        final theme = Theme.global(cx.app);
        final content = contentBuilder != null ? contentBuilder(this, window, cx) : null;
        final action = actionBuilder != null ? actionBuilder(this, window, cx).small().mr3p5() : null;

        final transitionStatus = this.transitionStatus;
        final closing = transitionStatus == Ending;
        final icon = typeValue == null ? (iconValue != null ? iconValue.clone() : null) : typeValue.icon(cx.app);
        final hasIcon = icon != null;
        final placement = placementValue != null ? placementValue : theme.notification.placement;

        final toast = Toast.component('notification')
            .transitionStatus(transitionStatus)
            .hFlex()
            .group('')
            .occlude()
            .relative()
            .wFull()
            .border1()
            .borderColor(theme.border)
            .bg(theme.tokens.popover.background)
            .rounded(theme.radiusLg)
            .shadow(ThemeStyled.toastShadow(1.))
            .py3p5()
            .px4()
            .gap3()
            .refineStyle(notificationStyle);
        if (icon != null) {
            toast.child(div().absolute().top(glaze.Prelude.px(18.)).left4().child(icon));
        }
        final column = vFlex()
            .flex1()
            .overflowHidden()
            .when(hasIcon, c -> c.pl6());
        if (titleValue != null) {
            column.child(div().textSm().fontSemibold().child(titleValue));
        }
        if (messageValue != null) {
            column.child(div().textSm().child(messageValue));
        }
        if (content != null) {
            column.child(content);
        }
        toast.child(column);
        if (action != null) {
            toast.child(action);
        }
        toast.child(div()
            .absolute()
            .top1()
            .right1()
            .invisible()
            .groupHover('', s -> s.visible())
            .child(Button.component('close')
                .icon(IconName.Close)
                .ghost()
                .xsmall()
                .onClick(cx.listener((this:Notification, _, window, cx) -> {
                    cx.stopPropagation();
                    this.dismiss(window, cx);
                }))));
        final onClick = onClickHandler;
        if (onClick != null) {
            toast.onClick(cx.listener((view:Notification, event:ClickEvent, window, cx) -> {
                view.dismiss(window, cx);
                onClick(event, window, cx.app);
            }));
        }
        toast.onAuxClick(cx.listener((view:Notification, event:ClickEvent, window, cx) -> {
            if (event.isMiddleClick()) {
                view.dismiss(window, cx);
            }
        }));

        final offset:Float = NotificationList.NOTIFICATION_TRANSITION_OFFSET;
        // Rust animates the `Toast` itself; its style is refined last, so
        // animating the `Div` it renders is the same (see `Toast.intoDiv`).
        return toast.intoDiv().withAnimation(
            ElementId.NamedInteger('slide-down', closing ? 1 : 0),
            new Animation(closing ? NotificationList.NOTIFICATION_EXIT_DURATION : NotificationList.NOTIFICATION_TRANSITION_DURATION)
                .withEasing(Easings.cubicBezier(0.25, 0.1, 0.25, 1.)),
            (element, delta) -> {
                if (closing) {
                    final opacity = f32(1. - delta);
                    final that = element.opacity(opacity).shadow(ThemeStyled.toastShadow(f32(opacity * opacity * opacity)));
                    final yOffset:Float = switch placement {
                        case TopLeft | TopRight | TopCenter: f32(-delta * offset);
                        case BottomLeft | BottomRight | BottomCenter: f32(delta * offset);
                        case _: 0.;
                    };
                    return that.top(glaze.Prelude.px(yOffset));
                }
                else {
                    final yOffset:Float = switch placement {
                        case TopLeft | TopRight | TopCenter: f32(-offset + f32(delta * offset));
                        case BottomLeft | BottomRight | BottomCenter: f32(offset - f32(delta * offset));
                        case _: 0.;
                    };
                    final opacity = delta;
                    // GPUI paints a drop shadow under the card and has no
                    // group compositing, so a card that is still translucent
                    // does not hide its own shadow and it shows through as a
                    // dark slab. Ramping the ink by the cube of the fade
                    // keeps it out of sight until the card can cover it.
                    return element.top(glaze.Prelude.px(f32(0. + yOffset)))
                        .opacity(opacity)
                        .shadow(ThemeStyled.toastShadow(f32(f32(opacity * opacity) * opacity)));
                }
            });
    }

}

/**
 * The settings for notifications (the theme's `notification`).
 */
class NotificationSettings {

    /**
     * The placement of the notifications, default: `Anchor.TopRight`.
     *
     * A single notification can override this with `Notification.placement`.
     */
    public var placement:Anchor = TopRight;

    /** The margins of the notification with respect to the window edges. */
    public var margins:Edges;

    /** The maximum number of notifications to show at once, default: 10 */
    public var maxItems:Int = 10;

    /** The width of the notifications, default: 382px */
    public var width:Pixels = NotificationList.DEFAULT_NOTIFICATION_WIDTH;

    /**
     * Where notifications are delivered, default: `NotificationDelivery.InApp`.
     *
     * A single notification can override this with `Notification.delivery`.
     */
    public var delivery:NotificationDelivery = InApp;

    public function new() {
        final offset = 16.;
        // The top margin avoids overlap with the title bar.
        margins = new Edges(TitleBar.TITLE_BAR_HEIGHT + offset, offset, offset, offset);
    }

    public function copy():NotificationSettings {
        final settings = new NotificationSettings();
        settings.placement = placement;
        settings.margins = margins;
        settings.maxItems = maxItems;
        settings.width = width;
        settings.delivery = delivery;
        return settings;
    }

}

/**
 * Per-placement stack state, created lazily for placements in use.
 */
private class AnchorStack {

    public final state:ToastStackState;

    public final focusHandle:FocusHandle;

    public function new(state:ToastStackState, focusHandle:FocusHandle) {
        this.state = state;
        this.focusHandle = focusHandle;
    }

}

/**
 * A list of notifications.
 */
@:allow(glaze.kit, tests)
class NotificationList extends Model implements Render {

    static inline final NOTIFICATION_TRANSITION_DURATION:Float = 0.4;
    static inline final NOTIFICATION_EXIT_DURATION:Float = 0.2;
    static inline final NOTIFICATION_TRANSITION_OFFSET:Pixels = 96.;
    static inline final DEFAULT_NOTIFICATION_WIDTH:Pixels = 382.;
    static inline final NOTIFICATION_ADVANCE_INTERVAL:Float = 0.05;

    /** Notifications that will be auto hidden. */
    final notificationsManager:ToastManager<NotificationId, Entity<Notification>>;

    final stacks:Array<{anchor:Anchor, stack:AnchorStack}> = [];

    final focusHandle:FocusHandle;

    /** Mounted notifications that hide themselves after a timeout (keys of `NotificationId`s). */
    final autohideIds:Map<String, Bool> = new Map();

    /** Whether the lifecycle clock is running. The loop clears it as it exits. */
    var isAdvancing:Bool = false;

    final subscriptions:Map<String, Subscription> = new Map();

    /**
     * Registers the app-global system-notification response handler (Rust
     * `notification::init`).
     *
     * GPUI keeps a single such handler (later registrations replace earlier
     * ones), so gpui-kit owns it: applications must not call
     * `App.onSystemNotificationResponse` after `Kit.init`. Responses
     * to notifications the application posts itself are ignored here.
     */
    public static function init(cx:AppContext):Void {
        final app:App = cx;
        app.onSystemNotificationResponse(SystemNotificationRegistry.handleResponse);
    }

    public function new(_:Window, cx:Context<NotificationList>) {
        super();
        notificationsManager = new ToastManager(ToastMotion.sonner());
        focusHandle = cx.focusHandle().tabStop(true);
    }

    static inline function key(id:NotificationId):String {
        return Std.string(id);
    }

    /**
     * Tick the toast lifecycle while a notification still has time to track.
     *
     * It advances the transition phases and samples the pause input (stack
     * expansion) that reaches the list through no event. With nothing
     * mounted, or only persistent notifications at rest, there is nothing to
     * do, so the window arms no timer until a push or close.
     */
    function startAdvancing(window:Window, cx:Context<NotificationList>):Void {
        if (isAdvancing) {
            return;
        }
        isAdvancing = true;
        // Rust spawns a detached loop awaiting a timer between ticks: here each
        // tick arms the next timer.
        scheduleAdvance(cx.weakEntity(), window, cx.app);
    }

    static function scheduleAdvance(view:WeakEntity<NotificationList>, window:Window, app:App):Void {
        app.backgroundExecutor().timer(NOTIFICATION_ADVANCE_INTERVAL).then(_ -> {
            if (window.isDestroyed() || !view.isUpgradable()) {
                return;
            }
            final running = view.update(app, (view, cx) -> {
                view.advance(window, cx);
                view.isAdvancing = view.needsClock();
                return view.isAdvancing;
            });
            if (running) {
                scheduleAdvance(view, window, app);
            }
        });
    }

    /**
     * Whether a mounted notification is in transition or counting down to
     * autohide. A paused countdown still needs its last sample kept current.
     */
    function needsClock():Bool {
        for (entry in notificationsManager.iter()) {
            final needs = switch entry.status {
                case Present: autohideIds.exists(key(entry.id));
                case Starting | Ending: true;
            };
            if (needs) return true;
        }
        return false;
    }

    function isExpanded():Bool {
        for (entry in stacks) {
            if (entry.stack.state.isExpanded()) return true;
        }
        return false;
    }

    /**
     * Group the visible notifications by their effective placement, pairing
     * each group with the element id its stack renders under and preserving
     * the display order within each group.
     */
    function grouped(cx:App):Array<{anchor:Anchor, stackId:ElementId, items:Array<{id:NotificationId, item:Entity<Notification>}>}> {
        final settings = Theme.global(cx).notification;
        final maxItems = settings.maxItems;
        final placement = settings.placement;

        final groups:Array<{anchor:Anchor, items:Array<{id:NotificationId, item:Entity<Notification>}>}> = [];
        for (entry in notificationsManager.visible(maxItems)) {
            final itemPlacement = entry.value.read(cx).placementValue;
            final anchor = itemPlacement != null ? itemPlacement : placement;
            var group = null;
            for (candidate in groups) {
                if (candidate.anchor == anchor) {
                    group = candidate;
                    break;
                }
            }
            if (group != null) {
                group.items.push({id: entry.id, item: entry.value});
            }
            else {
                groups.push({anchor: anchor, items: [{id: entry.id, item: entry.value}]});
            }
        }
        return [for (group in groups) {anchor: group.anchor, stackId: stackId(group.anchor), items: group.items}];
    }

    /**
     * The element id a placement's stack renders under.
     *
     * Keyed by the placement itself rather than by position among the mounted
     * stacks: a stack whose id changes loses the element state of its whole
     * subtree, which replays the enter animation of every notification in it.
     */
    static function stackId(anchor:Anchor):ElementId {
        final ix = switch anchor {
            case TopLeft: 0;
            case TopCenter: 1;
            case TopRight: 2;
            case BottomLeft: 3;
            case BottomCenter: 4;
            case BottomRight: 5;
            case LeftCenter: 6;
            case RightCenter: 7;
        };
        return ElementId.NamedInteger('notification-list', ix);
    }

    public function push(notification:IntoNotification, window:Window, cx:Context<NotificationList>):Void {
        final notification:Notification = notification;
        final delivery = notification.deliveryValue != null ? notification.deliveryValue : Theme.global(cx.app).notification.delivery;
        if (delivery.includesSystem()) {
            pushSystem(notification, window, cx);
        }
        if (!delivery.includesInApp()) {
            return;
        }

        final id = notification.idValue;
        final autohide = notification.autohideValue;

        final notification:Entity<Notification> = cx.newEntity((_:Context<Notification>) -> notification);

        final dismissId = id;
        final previous = subscriptions.get(key(id));
        if (previous != null) previous.dispose();
        subscriptions.set(key(id), cx.subscribeIn(notification, DismissRequest, window, (view:NotificationList, _, _, window, cx) -> {
            if (view.notificationsManager.dismiss(dismissId, cx.backgroundExecutor().now())) {
                final note = view.notificationsManager.get(dismissId);
                if (note != null) {
                    note.update(cx, (note, cx) -> note.beginClose(cx));
                }
                SystemNotificationRegistry.dismiss(cx.app, dismissId, window);
                view.startAdvancing(window, cx);
            }
        }));
        if (autohide) {
            autohideIds.set(key(id), true);
        }
        else {
            autohideIds.remove(key(id));
        }

        notificationsManager.push(id, notification, new ToastOptions(autohide ? 5. : null), cx.backgroundExecutor().now());
        startAdvancing(window, cx);
        cx.notify();
    }

    /**
     * Post the notification to the OS notification center and register the
     * state needed to dispatch the user's response back to this window
     * (Rust `push_system`).
     */
    static function pushSystem(notification:Notification, window:Window, cx:Context<NotificationList>):Void {
        var title:String;
        var body:String;
        if (notification.titleValue != null) {
            title = notification.titleValue;
            body = notification.messageValue != null ? notification.messageValue : '';
        }
        else if (notification.messageValue != null) {
            title = notification.messageValue;
            body = '';
        }
        else {
            // A content-only notification has nothing textual to show.
            return;
        }
        final tag = NotificationIdTools.systemTag(notification.idValue);
        SystemNotificationRegistry.insert(cx.app, tag, new SystemNotificationEntry(window, cx.weakEntity(), notification.idValue, notification.onClickHandler));
        cx.app.showSystemNotification(new SystemNotification(tag, title, body, []));
    }

    function advance(window:Window, cx:Context<NotificationList>):Void {
        final changes = notificationsManager.advance(cx.backgroundExecutor().now(), isExpanded());
        for (id in changes.presented) {
            final note = notificationsManager.get(id);
            if (note != null) {
                note.update(cx, (note, cx) -> note.completeEnter(cx));
            }
        }
        for (id in changes.ending) {
            final note = notificationsManager.get(id);
            if (note != null) {
                note.update(cx, (note, cx) -> note.beginClose(cx));
            }
        }
        for (removed in changes.removed) {
            final subscription = subscriptions.get(key(removed.id));
            if (subscription != null) {
                subscription.dispose();
                subscriptions.remove(key(removed.id));
            }
            autohideIds.remove(key(removed.id));
            removed.value.update(cx, (note, cx) -> note.completeClose(window, cx));
        }
        if (changes.changed) {
            cx.notify();
        }
    }

    function close(id:NotificationId, window:Window, cx:Context<NotificationList>):Void {
        // Unconditional: a system-only notification has no toast to dismiss,
        // but its system counterpart must still be retracted.
        SystemNotificationRegistry.dismiss(cx.app, id, window);
        if (notificationsManager.dismiss(id, cx.backgroundExecutor().now())) {
            final note = notificationsManager.get(id);
            if (note != null) {
                note.update(cx, (note, cx) -> note.beginClose(cx));
            }
            startAdvancing(window, cx);
        }
        cx.notify();
    }

    /**
     * Close all notifications whose id matches the given marker type,
     * regardless of whether they were registered via `Notification.withId`
     * or `Notification.id1`.
     */
    function closeByType(typeId:String, window:Window, cx:Context<NotificationList>):Void {
        SystemNotificationRegistry.dismissByType(cx.app, typeId, window);
        final matched = [for (entry in notificationsManager.iter()) if (NotificationIdTools.typeId(entry.id) == typeId) entry.value];
        for (note in matched) {
            final id = note.read(cx).idValue;
            if (notificationsManager.dismiss(id, cx.backgroundExecutor().now())) {
                note.update(cx, (note, cx) -> note.beginClose(cx));
                startAdvancing(window, cx);
            }
        }
        cx.notify();
    }

    public function clear(window:Window, cx:Context<NotificationList>):Void {
        SystemNotificationRegistry.dismissAll(cx.app, window);
        for (id in notificationsManager.dismissAll(cx.backgroundExecutor().now())) {
            final note = notificationsManager.get(id);
            if (note != null) {
                note.update(cx, (note, cx) -> note.beginClose(cx));
            }
            startAdvancing(window, cx);
        }
        cx.notify();
    }

    public function notifications():Array<Entity<Notification>> {
        return [for (entry in notificationsManager.iter()) entry.value];
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        final cx:Context<NotificationList> = cast cx;
        final size = window.viewportSize();
        final settings = Theme.global(cx.app).notification;
        final placement = settings.placement;
        final margins = settings.margins;
        final width = settings.width;

        final groups = grouped(cx.app);
        var index = 0;
        while (index < stacks.length) {
            var used = false;
            for (group in groups) {
                if (group.anchor == stacks[index].anchor) used = true;
            }
            if (used) index++;
            else stacks.splice(index, 1);
        }

        final defaultFocusHandle = focusHandle;
        final rendered:Array<IntoElement> = [];
        for (group in groups) {
            final anchor = group.anchor;
            var stack:Null<AnchorStack> = null;
            for (entry in stacks) {
                if (entry.anchor == anchor) {
                    stack = entry.stack;
                    break;
                }
            }
            if (stack == null) {
                stack = new AnchorStack(new ToastStackState(), anchor == placement ? defaultFocusHandle : cx.focusHandle().tabStop(true));
                stacks.push({anchor: anchor, stack: stack});
            }

            final element = ToastStack.component(group.stackId, stack.state);
            for (item in group.items) {
                element.item(key(item.id), item.item);
            }
            element
                .placement(anchor)
                .focusHandle(stack.focusHandle)
                .vFlex()
                .w(width)
                .maxH(glaze.Prelude.px(size.height))
                .absolute();
            switch anchor {
                case TopLeft: element.top(glaze.Prelude.px(margins.top)).left(glaze.Prelude.px(margins.left));
                case TopRight: element.top(glaze.Prelude.px(margins.top)).right(glaze.Prelude.px(margins.right));
                case TopCenter: element.top(glaze.Prelude.px(margins.top)).left(glaze.Prelude.relative(0.5)).ml(glaze.Prelude.px(-(width:Float) / 2.));
                case BottomLeft: element.bottom(glaze.Prelude.px(margins.bottom)).left(glaze.Prelude.px(margins.left));
                case BottomRight: element.bottom(glaze.Prelude.px(margins.bottom)).right(glaze.Prelude.px(margins.right));
                case BottomCenter: element.bottom(glaze.Prelude.px(margins.bottom)).left(glaze.Prelude.relative(0.5)).ml(glaze.Prelude.px(-(width:Float) / 2.));
                case LeftCenter: element.left(glaze.Prelude.px(margins.left)).top0().bottom0().myAuto();
                case RightCenter: element.right(glaze.Prelude.px(margins.right)).top0().bottom0().myAuto();
            }
            rendered.push(element);
        }

        return div().sizeFull().children(rendered);
    }

}

/**
 * What a system notification needs to dispatch the user's response (Rust
 * `SystemNotificationEntry`).
 */
private class SystemNotificationEntry {

    public final window:Window;

    public final list:WeakEntity<NotificationList>;

    public final id:NotificationId;

    public final onClick:Null<(ClickEvent, Window, App) -> Void>;

    public function new(window:Window, list:WeakEntity<NotificationList>, id:NotificationId, onClick:Null<(ClickEvent, Window, App) -> Void>) {
        this.window = window;
        this.list = list;
        this.id = id;
        this.onClick = onClick;
    }

}

/**
 * App-global map from system-notification tag to the state needed to
 * dispatch the user's response, ordered oldest-first so overflow prunes the
 * stalest entries (Rust `SystemNotificationRegistry`).
 */
@:allow(glaze.kit.notification)
class SystemNotificationRegistry {

    static inline final MAX_SYSTEM_NOTIFICATION_ENTRIES = 100;

    final entries:Array<{tag:String, entry:SystemNotificationEntry}> = [];

    public function new() {}

    static function insert(cx:App, tag:String, entry:SystemNotificationEntry):Void {
        final entries = cx.defaultGlobal(SystemNotificationRegistry).entries;
        var i = entries.length - 1;
        while (i >= 0) {
            if (entries[i].tag == tag)
                entries.splice(i, 1);
            i--;
        }
        entries.push({tag: tag, entry: entry});
        if (entries.length > MAX_SYSTEM_NOTIFICATION_ENTRIES) {
            entries.splice(0, entries.length - MAX_SYSTEM_NOTIFICATION_ENTRIES);
        }
    }

    /**
     * Retract the system notification for `id`, but only if it was posted
     * from the given window: another window pushing the same id owns the tag
     * now, and this window's local dismiss must not clobber it.
     */
    static function dismiss(cx:App, id:NotificationId, window:Window):Void {
        final tag = NotificationIdTools.systemTag(id);
        final entries = cx.defaultGlobal(SystemNotificationRegistry).entries;
        for (i in 0...entries.length) {
            if (entries[i].tag == tag && entries[i].entry.window.id == window.id) {
                entries.splice(i, 1);
                cx.dismissSystemNotification(tag);
                return;
            }
        }
    }

    /**
     * Retract all of the window's system notifications whose id matches the
     * given marker type, regardless of the `NotificationId` variant.
     */
    static function dismissByType(cx:App, typeId:String, window:Window):Void {
        dismissMatching(cx, window, id -> NotificationIdTools.typeId(id) == typeId);
    }

    /** Retract all system notifications posted from the given window. */
    static function dismissAll(cx:App, window:Window):Void {
        dismissMatching(cx, window, _ -> true);
    }

    static function dismissMatching(cx:App, window:Window, matches:(NotificationId) -> Bool):Void {
        final entries = cx.defaultGlobal(SystemNotificationRegistry).entries;
        final tags:Array<String> = [];
        var i = 0;
        while (i < entries.length) {
            final item = entries[i];
            if (item.entry.window.id == window.id && matches(item.entry.id)) {
                tags.push(item.tag);
                entries.splice(i, 1);
            }
            else {
                i++;
            }
        }
        for (tag in tags) {
            cx.dismissSystemNotification(tag);
        }
    }

    static function handleResponse(response:SystemNotificationResponse, cx:App):Void {
        if (!StringTools.startsWith(response.tag, SYSTEM_TAG_PREFIX))
            return;
        // Platforms usually remove a clicked notification themselves; retract
        // explicitly for the ones that keep it in the notification center.
        cx.dismissSystemNotification(response.tag);
        // The prefix already proves the notification is ours, so activate even
        // when nothing is left to dispatch to: the platform can deliver a
        // response for a notification posted before the process restarted, and
        // entries are pruned past `MAX_SYSTEM_NOTIFICATION_ENTRIES`.
        cx.activate(true);
        final entries = cx.defaultGlobal(SystemNotificationRegistry).entries;
        var index = -1;
        for (i in 0...entries.length) {
            if (entries[i].tag == response.tag) {
                index = i;
                break;
            }
        }
        if (index == -1)
            return;
        final entry = entries.splice(index, 1)[0].entry;
        // Rust `AnyWindowHandle::update` errs when the window is already
        // closed: the entry is removed and the application is still brought
        // to the foreground.
        final window = entry.window;
        if (Window.windows.indexOf(window) == -1)
            return;
        cx.update(cx -> {
            window.activateWindow();
            final list = entry.list.upgrade();
            if (list != null) {
                // No-op when the toast already closed or was never created
                // (system-only delivery).
                list.update(cx, (list, cx) -> list.close(entry.id, window, cx));
            }
            if (entry.onClick != null) {
                entry.onClick(defaultClickEvent(), window, cx);
            }
        });
    }

    /** Rust `ClickEvent::default()`: a keyboard click (Enter) with empty bounds. */
    static function defaultClickEvent():ClickEvent {
        return ClickEvent.Keyboard(new glaze.ClickEvent.KeyboardClickEvent(glaze.KeyboardButton.Enter, new glaze.Bounds()));
    }

}
