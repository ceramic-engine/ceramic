// Ported from gpui-kit 0.8.1: crates/component/src/{kbd,spinner,empty,description_list,group_box,link,marker,shimmer,avatar/avatar,avatar/avatar_group,progress/progress}.rs (tests),
// crates/base/src/link.rs (tests), crates/kit/tests/integration/components.rs (progress observability)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package tests.kit;

import glaze.App;
import glaze.Bounds;
import glaze.ClickEvent;
import glaze.Context;
import glaze.Hsla;
import glaze.IntoElement;
import glaze.KeyDownEvent;
import glaze.KeyUpEvent;
import glaze.Keystroke;
import glaze.Model;
import glaze.OperatingSystem;
import glaze.Render;
import glaze.StyleRefinement;
import glaze.TestDispatcher;
import glaze.Window;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.PlatformUrl;
import glaze.kit.Size;
import glaze.kit.avatar.Avatar;
import glaze.kit.avatar.AvatarGroup;
import glaze.kit.descriptionlist.DescriptionList;
import glaze.kit.empty.Empty;
import glaze.kit.groupbox.GroupBox.GroupBoxVariant;
import glaze.kit.kbd.Kbd;
import glaze.kit.marker.Marker;
import glaze.kit.shimmer.ShimmerText;
import glaze.kit.spinner.Spinner;
import testing.TestCase;
import testing.VisualTestContext;

import glaze.Prelude.*;

using glaze.kit.base.ElementExt;
using glaze.kit.Size.SizeTools;
using glaze.kit.theme.Colorize;

/**
 * The `#[cfg(test)]` tests of the wave 2 leaf components.
 *
 * Not ported: tests reading accesskit nodes (the link's accessibility
 * surface is checked on the port's `A11y` record), `ProgressCircle` (with the
 * plot wave).
 */
class ComponentLeavesTest extends TestCase {

    var dispatcher:TestDispatcher;

    var app:App;

    var cx:Null<VisualTestContext> = null;

    override function setup() {
        dispatcher = new TestDispatcher();
        app = new App(dispatcher);
        PlatformUrl.openedUrl = null;
        PlatformUrl.opener = _ -> {};
        ceramic.App.app.flushImmediate();
    }

    override function teardown() {
        PlatformUrl.opener = null;
        if (cx != null) {
            cx.destroy();
            cx = null;
        }
        ceramic.App.app.flushImmediate();
    }

    function open(build:() -> IntoElement, width:Float = 1920, height:Float = 1080):Void {
        final opened = VisualTestContext.addWindowView(app, dispatcher, (_, _:Context<Host>) -> new Host(build), width, height);
        cx = opened.cx;
    }

    // kbd.rs

    function testFormat() {
        final mac = OperatingSystem.Mac;
        assertEquals('⌘A', Kbd.format(Keystroke.parse('cmd-a'), mac));
        assertEquals('⌘-', Kbd.format(Keystroke.parse('cmd--'), mac));
        assertEquals('⌘+', Kbd.format(Keystroke.parse('cmd-+'), mac));
        assertEquals('⌘⏎', Kbd.format(Keystroke.parse('cmd-enter'), mac));
        assertEquals('⌘F12', Kbd.format(Keystroke.parse('cmd-f12'), mac));
        assertEquals('⇧Page Down', Kbd.format(Keystroke.parse('shift-pagedown'), mac));
        assertEquals('⇧Page Up', Kbd.format(Keystroke.parse('shift-pageup'), mac));
        assertEquals('⇧Space', Kbd.format(Keystroke.parse('shift-space'), mac));
        assertEquals('⌃⌘A', Kbd.format(Keystroke.parse('cmd-ctrl-a'), mac));
        assertEquals('⌥⌘⌫', Kbd.format(Keystroke.parse('cmd-alt-backspace'), mac));
        assertEquals('⇧⌫', Kbd.format(Keystroke.parse('shift-delete'), mac));
        assertEquals('⌃⇧⌘A', Kbd.format(Keystroke.parse('cmd-ctrl-shift-a'), mac));
        assertEquals('⌃⌥⇧⌘A', Kbd.format(Keystroke.parse('cmd-ctrl-shift-alt-a'), mac));

        final win = OperatingSystem.Windows;
        assertEquals('A', Kbd.format(Keystroke.parse('a'), win));
        assertEquals('Ctrl+A', Kbd.format(Keystroke.parse('ctrl-a'), win));
        assertEquals('Shift+Space', Kbd.format(Keystroke.parse('shift-space'), win));
        assertEquals('Ctrl+Alt+A', Kbd.format(Keystroke.parse('ctrl-alt-a'), win));
        assertEquals('Ctrl+Alt+Shift+A', Kbd.format(Keystroke.parse('ctrl-alt-shift-a'), win));
        assertEquals('Ctrl+Alt+Shift+Win+A', Kbd.format(Keystroke.parse('ctrl-alt-shift-win-a'), win));
        assertEquals('Ctrl+Shift+Backspace', Kbd.format(Keystroke.parse('ctrl-shift-backspace'), win));
        assertEquals('Alt+Delete', Kbd.format(Keystroke.parse('alt-delete'), win));
        assertEquals('Alt+Tab', Kbd.format(Keystroke.parse('alt-tab'), win));
    }

    // spinner.rs

    function testReducedMotionSpinnerIsStaticAndRequestsNoFrame() {
        app.setReduceMotion(true);
        open(() -> glaze.kit.spinner.Spinner.component(), 100, 100);
        cx.runUntilParked();
        assertEquals(0, cx.window.simulateNextFrame());
    }

    // empty.rs

    function testMediaKeepsIntrinsicWidthAndSlotAlignment() {
        for (grouped in [false, true]) {
            for (leading in [false, true]) {
                final b = new Map<String, Bounds>();
                open(() -> {
                    final media:IntoElement = grouped
                        ? (AvatarGroup.component().small().child(Avatar.component().name('Alex')).child(Avatar.component().name('Taylor')).child(Avatar.component().name('Sam')) : IntoElement)
                        : (Avatar.component().small().name('Alex') : IntoElement);
                    final empty = Empty.component();
                    if (leading) empty.itemsStart().textLeft();
                    final content = EmptyContent.component();
                    if (leading) content.itemsStart();
                    final header = EmptyHeader.component();
                    if (leading) header.itemsStart();
                    return empty
                        .child(div().size4().onPrepaint((x, _, _) -> b.set('trailing', x)))
                        .content(content.child(div().size4().onPrepaint((x, _, _) -> b.set('content', x))))
                        .header(header
                            .description(EmptyDescription.component().child('Supporting content'))
                            .title(EmptyTitle.component().child(div().size4().onPrepaint((x, _, _) -> b.set('title', x))))
                            .media(EmptyMedia.component().child(div().onPrepaint((x, _, _) -> b.set('media-content', x)).child(media))));
                });
                for (rem in [14., 20.]) {
                    cx.update((window, _) -> {
                        window.setRemSize(rem);
                        window.draw();
                    });
                    final media = b.get('media-content');
                    final title = b.get('title');
                    final content = b.get('content');
                    final trailing = b.get('trailing');
                    assertTrue(media.size.width > 0, 'grouped: $grouped');
                    final alignment = (x:Bounds) -> leading ? x.left() : x.center().x;
                    assertFloatEquals(alignment(title), alignment(media), 0.01);
                    assertFloatEquals(alignment(title), alignment(content), 0.01);
                    assertTrue(media.bottom() <= title.top());
                    assertTrue(title.bottom() <= content.top());
                    assertTrue(content.bottom() <= trailing.top());
                }
                cx.destroy();
                cx = null;
            }
        }
    }

    function testEmptyBuilder() {
        final rootStyle = new glaze.StyleBuilder().p4().border1().style();
        final empty = Empty.component();
        empty.style().refine(rootStyle);
        empty.child('Before the named setters, still after the slots')
            .header(EmptyHeader.component().media(EmptyMedia.component()))
            .content(EmptyContent.component().child('Replaced content'))
            .header(
                EmptyHeader.component()
                    .title(EmptyTitle.component().child('Replaced title'))
                    .description(EmptyDescription.component().child('Replaced description'))
                    .media(EmptyMedia.component().child('Replaced media'))
                    .description(EmptyDescription.component().children(['Description', 'Custom content']))
                    .title(EmptyTitle.component().child('Title'))
                    .media(EmptyMedia.component().withVariant(EmptyMediaVariant.Icon).child(glaze.kit.Icon.component(IconName.Search)))
            )
            .content(EmptyContent.component().children(['First action', 'Second action']))
            .child('Trailing content');
        assertEquals(2, empty.childElements.length);
        final header = empty.headerProp;
        assertTrue(header.mediaProp.variant == EmptyMediaVariant.Icon);
        assertEquals(1, header.mediaProp.childElements.length);
        assertEquals(1, header.titleProp.childElements.length);
        assertEquals(2, header.descriptionProp.childElements.length);
        assertEquals(2, empty.contentProp.childElements.length);
        final empty = Empty.component();
        assertNull(empty.headerProp);
        assertNull(empty.contentProp);
        assertEquals(0, empty.childElements.length);
        assertTrue(EmptyMedia.component().variant == EmptyMediaVariant.Default);
    }

    // description_list.rs

    function testGroupItemRows() {
        final items = [
            DescriptionItem.create('test1'),
            DescriptionItem.create('test2').span(2),
            DescriptionItem.create('test3'),
            DescriptionItem.create('test4'),
            DescriptionItem.create('test5'),
            DescriptionItem.create('test6').span(3),
            DescriptionItem.create('test7')
        ];
        final rows = @:privateAccess DescriptionList.groupItemRows(items, 3);
        assertEquals(4, rows.length);
        assertEquals(2, rows[0].length);
        assertEquals(3, rows[1].length);
        assertEquals(1, rows[2].length);
        assertEquals(1, rows[3].length);
    }

    // group_box.rs

    function testGroupVariantFromStr() {
        assertTrue(GroupBoxVariant.fromStr('normal') == Normal);
        assertTrue(GroupBoxVariant.fromStr('fill') == Fill);
        assertTrue(GroupBoxVariant.fromStr('outline') == Outline);
        assertTrue(GroupBoxVariant.fromStr('other') == Normal);
        assertTrue(GroupBoxVariant.fromStr('FILL') == Fill);
        assertTrue(GroupBoxVariant.fromStr('OutLine') == Outline);
        assertEquals('normal', Normal.asStr());
        assertEquals('fill', Fill.asStr());
        assertEquals('outline', Outline.asStr());
    }

    // component link.rs

    function legacyLink(disabled:Bool, ?bounds:Map<String, Bounds>):{clicks:Int} {
        final state = {clicks: 0};
        open(() -> glaze.kit.link.Link.component('legacy-link')
            .href('https://example.com')
            .disabled(disabled)
            .size(px(100.))
            .child(div().onPrepaint((b, _, _) -> if (bounds != null) bounds.set('child', b)).child('Visible link'))
            .onClick((_, _, _) -> state.clicks++));
        return state;
    }

    function testLegacyLinkPrepaintsChildren() {
        final bounds = new Map<String, Bounds>();
        legacyLink(false, bounds);
        assertTrue(bounds.get('child').size.width > 0);
        assertTrue(bounds.get('child').size.height > 0);
    }

    function testLegacyLinkPreservesPointerOpenAndCallback() {
        final state = legacyLink(false);
        cx.simulateClick(point(10., 10.));
        assertEquals('https://example.com', PlatformUrl.openedUrl);
        assertEquals(1, state.clicks);
    }

    function testLegacyLinkPreservesDisabledBehavior() {
        final state = legacyLink(true);
        cx.simulateClick(point(10., 10.));
        // `disabled` was historically a stored but behaviorally inert field.
        assertEquals('https://example.com', PlatformUrl.openedUrl);
        assertEquals(1, state.clicks);
    }

    function testLegacyLinkRemainsPointerOnly() {
        final state = legacyLink(false);
        cx.simulateKeystrokes('enter space');
        assertNull(PlatformUrl.openedUrl);
        assertEquals(0, state.clicks);
    }

    // base link.rs

    function baseLink(disabled:Bool):{activations:Int, keyboard:Int, opened:Array<String>, parentClicks:Int} {
        final state = {activations: 0, keyboard: 0, opened: [], parentClicks: 0};
        open(() -> div()
            .id('link-parent')
            .tabGroup()
            .size(px(100.))
            .onClick((_, _, _) -> state.parentClicks++)
            .child(
                glaze.kit.base.Link.component('link')
                    .href('app://settings')
                    .disabled(disabled)
                    .sizeFull()
                    .openWith((href, _, _, _) -> state.opened.push(href))
                    .onActivate((event, _, _) -> {
                        state.activations++;
                        if (event.match(Keyboard(_)))
                            state.keyboard++;
                    })
            ));
        return state;
    }

    function activateKey(key:String):Void {
        final keystroke = Keystroke.parse(key);
        cx.simulateEvent(new KeyDownEvent(keystroke, false, false));
        cx.simulateEvent(new KeyUpEvent(keystroke));
    }

    function testPointerRunsInjectedOpenStrategyAndActivationOnce() {
        final state = baseLink(false);
        cx.simulateClick(point(10., 10.));
        assertEquals(1, state.activations);
        assertEquals(0, state.keyboard);
        assertEquals('app://settings', state.opened.join(','));
        assertNull(PlatformUrl.openedUrl);
    }

    function testOpenStrategyRunsBeforeActivationCallback() {
        final order:Array<String> = [];
        open(() -> glaze.kit.base.Link.component('ordered-link')
            .href('app://ordered')
            .size(px(100.))
            .openWith((_, _, _, _) -> order.push('open'))
            .onActivate((_, _, _) -> order.push('activate')));
        cx.simulateClick(point(10., 10.));
        assertEquals('open,activate', order.join(','));
    }

    function testEnterAndSpaceEachActivateOnce() {
        final state = baseLink(false);
        cx.simulateClick(point(10., 10.));
        state.activations = 0;
        state.opened.resize(0);
        cx.update((window, app) -> {
            assertTrue(window.focused(app) != null);
            window.draw();
        });
        activateKey('enter');
        activateKey('space');
        assertEquals(2, state.activations);
        assertEquals(2, state.keyboard);
        assertEquals('app://settings,app://settings', state.opened.join(','));
        assertNull(PlatformUrl.openedUrl);
    }

    function testHrefWithoutStrategyNeverOpensExternally() {
        open(() -> glaze.kit.base.Link.component('target-only').href('https://example.com').size(px(100.)));
        cx.simulateClick(point(10., 10.));
        assertNull(PlatformUrl.openedUrl);
    }

    function testDisabledLinkIsInertAndBlocksParentActivation() {
        final state = baseLink(true);
        cx.simulateClick(point(10., 10.));
        activateKey('enter');
        activateKey('space');
        assertEquals(0, state.activations);
        assertEquals(0, state.opened.length);
        assertEquals(0, state.parentClicks);
    }

    function testVisualStateStylesRemainApplicationOwned() {
        glaze.kit.base.Link.component('states')
            .styles(styles -> styles.disabled(style -> style.opacity(0.5)))
            .hover(style -> style.opacity(0.9))
            .active(style -> style.opacity(0.8))
            .focusVisible(style -> style.opacity(0.7));
        assertTrue(true);
    }

    function testDisabledStyleAppliesOnlyWhileDisabledAndThenWins() {
        final enabled = glaze.kit.base.Link.component('enabled').opacity(0.9).styles(styles -> styles.disabled(style -> style.opacity(0.5)));
        assertEquals(0.9, enabled.resolvedStyle().opacity);
        final disabled = glaze.kit.base.Link.component('disabled').styles(styles -> styles.disabled(style -> style.opacity(0.5))).opacity(0.9).disabled(true);
        assertEquals(0.5, disabled.resolvedStyle().opacity);
        final semanticOnly = glaze.kit.base.Link.component('semantic-only').styles(styles -> styles.disabled(style -> style.opacity(0.5))).disabled(true);
        assertEquals(0.5, semanticOnly.resolvedStyle().opacity);
    }

    function testAccessibilityExposesLinkRoleLabelAndActionSurface() {
        final enabled = glaze.kit.base.Link.component('enabled').href('app://settings').accessibilityLabel('Settings').openWith((_, _, _, _) -> {});
        final disabled = glaze.kit.base.Link.component('disabled').disabled(true).accessibilityLabel('Settings').onActivate((_, _, _) -> {});
        open(() -> div().child(enabled).child(disabled));
        assertTrue(enabled.a11y.role == glaze.kit.base.A11y.Role.Link);
        assertEquals('Settings', enabled.a11y.label);
        assertTrue(enabled.a11y.clickable);
        assertTrue(disabled.a11y.role == glaze.kit.base.A11y.Role.Link);
        assertFalse(disabled.a11y.clickable);
        assertFalse(enabled.a11y.disabled);
        assertTrue(disabled.a11y.disabled);
    }

    // marker.rs

    function testMarkerBuilder() {
        final marker = Marker.component()
            .withVariant(Separator)
            .loading(true)
            .withLoadingStyle(Shimmer)
            .withShimmerStyle(new ShimmerStyle().reverse(true))
            .separatorStyle(new StyleRefinement())
            .content(MarkerContent.component().child('Today'));
        assertTrue(marker.variant == Separator);
        assertTrue(marker.loadingValue);
        assertTrue(marker.loadingStyle == Shimmer);
        assertEquals(1, marker.markerChildren.length);
        assertTrue(Marker.component().variant == Plain);
        assertNull(Marker.component().alignmentValue);
        assertFalse(Marker.component().loadingValue);
        assertTrue(Marker.component().loadingStyle == Spinner);
        assertTrue(Marker.component().alignment(Center).alignmentValue == Center);

        final contentFirst = Marker.component().content(MarkerContent.component().text('Thinking')).withLoadingStyle(Shimmer).loading(true);
        assertTrue(contentFirst.loadingValue);
        assertTrue(contentFirst.markerChildren[0].match(MContent(_)));

        final customIcon = Marker.component().loading(true).icon(MarkerIcon.component().child('custom')).content(MarkerContent.component().text('Loading'));
        assertEquals(2, customIcon.markerChildren.length);
        assertTrue(customIcon.markerChildren[0].match(MIcon(_)));

        assertTrue(Marker.component().roleValue.match(Implicit));
        assertNull(Marker.component().idValue);
        final status = Marker.component().id('sync-status').role(Explicit(glaze.kit.base.A11y.Role.Status));
        assertTrue(Type.enumEq(glaze.ElementId.Name('sync-status'), status.idValue));
        assertTrue(status.roleValue.match(Explicit(Status)));

        final styled = Marker.component().opacity(0.37).child('Status').child('Details');
        assertEquals(0.37, styled.markerStyle.opacity);
        assertEquals(2, styled.markerChildren.length);
        assertEquals(1, MarkerIcon.component().child('icon').childElements.length);

        final content = MarkerContent.component().text('Thinking').child('…').text('正在思考');
        assertEquals(3, content.contentChildren.length);
        assertTrue(content.contentChildren[0].match(Text(_)));
        assertTrue(content.contentChildren[1].match(Element(_)));
        assertTrue(content.contentChildren[2].match(Text(_)));
    }

    function testMarkerResolvedAlignment() {
        assertTrue(Marker.component().resolvedAlignment() == Start);
        assertTrue(Marker.component().withVariant(Border).resolvedAlignment() == Start);
        assertTrue(Marker.component().withVariant(Separator).resolvedAlignment() == Center);
        assertTrue(Marker.component().alignment(End).withVariant(Separator).resolvedAlignment() == End);
        assertTrue(Marker.component().withVariant(Plain).alignment(Center).resolvedAlignment() == Center);
    }

    // shimmer.rs

    function testShimmerBuilder() {
        final color = Hsla.white();
        final style = new ShimmerStyle().duration(3.).highlightColor(color).spread(Relative(0.45)).reverse(true).once(true);
        assertEquals(3., style.durationValue);
        assertTrue(style.highlightColorValue.equals(color));
        assertTrue(Type.enumEq(style.spreadValue, Relative(0.45)));
        assertTrue(style.reverseValue);
        assertTrue(style.onceValue);

        final text = ShimmerText.component('Thinking').id('thinking').withShimmerStyle(style).duration(4.).spread(Relative(0.5)).reverse(false).once(false).opacity(0.8);
        assertEquals('Thinking', text.text);
        assertEquals(4., text.shimmerStyle.durationValue);
        assertTrue(Type.enumEq(text.shimmerStyle.spreadValue, Relative(0.5)));
        assertFalse(text.shimmerStyle.reverseValue);
        assertFalse(text.shimmerStyle.onceValue);
        assertEquals(0.8, text.shimmerTextStyle.opacity);
        assertTrue(Type.enumEq(glaze.ElementId.Name('thinking'), text.idProp));

        assertTrue(Type.enumEq(new ShimmerStyle().spread(Relative(0.)).spreadValue, Relative(0.05)));
        assertTrue(Type.enumEq(new ShimmerStyle().spread(Relative(2.)).spreadValue, Relative(1.)));
        assertTrue(Type.enumEq(new ShimmerStyle().spread(Relative(Math.NaN)).spreadValue, Relative(0.3)));
        assertTrue(Type.enumEq(new ShimmerStyle().spread(Absolute(0.)).spreadValue, Absolute(1.)));
        assertTrue(Type.enumEq(new ShimmerStyle().spread(Absolute(48.)).spreadValue, Absolute(48.)));
        assertTrue(Type.enumEq(new ShimmerStyle().spread(Absolute(Math.NaN)).spreadValue, Relative(0.3)));
        assertEquals(0.001, new ShimmerStyle().duration(0.).durationValue);
    }

    function testShimmerBandMovesSmoothlyAcrossText() {
        final bounds = new Bounds(point(10., 20.), size(100., 18.));
        final spread = Relative(0.3);
        assertNull(ShimmerText.shimmerBandBounds(bounds, 0., spread, 0));
        assertNull(ShimmerText.shimmerBandBounds(bounds, 1., spread, 0));
        final early = ShimmerText.shimmerBandBounds(bounds, 0.35, spread, 0);
        final late = ShimmerText.shimmerBandBounds(bounds, 0.65, spread, 0);
        assertTrue(early.origin.x < late.origin.x);
        final outer = ShimmerText.shimmerBandBounds(bounds, 0.5, spread, 0);
        final inner = ShimmerText.shimmerBandBounds(bounds, 0.5, spread, ShimmerText.SHIMMER_LAYER_COUNT - 1);
        assertTrue(inner.origin.x > outer.origin.x);
        assertTrue(inner.size.width < outer.size.width);
        assertNull(ShimmerText.shimmerBandBounds(bounds, 0.5, spread, ShimmerText.SHIMMER_LAYER_COUNT));
        assertNull(ShimmerText.shimmerBandBounds(new Bounds(bounds.origin, size(0., 18.)), 0.5, spread, 0));
        final narrow = ShimmerText.shimmerBandBounds(bounds, 0.5, Relative(0.1), 0);
        final wide = ShimmerText.shimmerBandBounds(bounds, 0.5, Relative(0.5), 0);
        assertTrue(narrow.size.width < wide.size.width);
        final band = ShimmerText.shimmerBandBounds(bounds, 0.5, Absolute(20.), 0);
        assertEquals(40., band.size.width);
        final wider = ShimmerText.shimmerBandBounds(new Bounds(bounds.origin, size(200., 18.)), 0.5, Absolute(20.), 0);
        assertEquals(40., wider.size.width);
    }

    function testShimmerHighlightStaysBrightInBothThemes() {
        final black = Hsla.black();
        final white = Hsla.white();
        final muted = white.mixOklab(black, 0.55);
        final light = ShimmerText.shimmerHighlightColor(black, white, black, false, null);
        final dark = ShimmerText.shimmerHighlightColor(muted, black, white, true, null);
        assertTrue(light.l > black.l);
        assertTrue(dark.l > muted.l);
        assertTrue(light.a > dark.a);
        assertTrue(Math.abs(1. - Math.pow(1. - light.a, 12) - 0.75) < 0.001);
        assertTrue(Math.abs(1. - Math.pow(1. - dark.a, 12) - 0.6) < 0.001);
        assertTrue(white.l - ShimmerText.shimmerHighlightColor(white, black, white, true, null).l > 0.3);
        assertTrue(white.l - ShimmerText.shimmerHighlightColor(white, white, black, false, null).l > 0.3);
        final custom = ShimmerText.shimmerHighlightColor(black, white, black, false, muted);
        assertEquals(muted.h, custom.h);
        assertEquals(muted.s, custom.s);
        assertEquals(muted.l, custom.l);

        var animation = ShimmerText.loadingAnimation(3., false);
        assertEquals(3., animation.duration);
        assertTrue(animation.synced);
        assertFalse(animation.oneshot);
        assertNull(animation.maxFps);
        animation = ShimmerText.loadingAnimation(3., true);
        assertTrue(animation.oneshot);
        assertFalse(animation.synced);
    }

    // avatar/avatar.rs

    static function luminance(color:Hsla):Float {
        final channel = (c:Float) -> c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
        final rgb = color.toRgb();
        return 0.2126 * channel(rgb.r) + 0.7152 * channel(rgb.g) + 0.0722 * channel(rgb.b);
    }

    static function contrastRatio(a:Hsla, b:Hsla):Float {
        final la = luminance(a);
        final lb = luminance(b);
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
    }

    function testIdentityColorsStayLegibleOnEveryHue() {
        for (isDark in [false, true]) {
            for (step in 0...IdentityColor.HUES) {
                final hue = step * IdentityColor.HUE_STEP;
                final color = IdentityColor.fromHue(hue, isDark);
                final ratio = contrastRatio(color.foreground, color.background);
                assertTrue(ratio >= 4.5, 'hue $hue (dark: $isDark) has contrast $ratio, below WCAG AA');
            }
        }
    }

    function testIdentityBordersStayInsideTheSrgbGamut() {
        for (isDark in [false, true]) {
            for (step in 0...IdentityColor.HUES) {
                final hue = step * IdentityColor.HUE_STEP;
                assertTrue(IdentityColor.fromHue(hue, isDark).border.s < 1., 'border at hue $hue (dark: $isDark)');
            }
        }
    }

    function testAvatarTextInitials() {
        assertEquals('JL', @:privateAccess Avatar.extractTextInitials('Jason Lee'));
        assertEquals('FB', @:privateAccess Avatar.extractTextInitials('Foo Bar Dar'));
        assertEquals('HU', @:privateAccess Avatar.extractTextInitials('huacnlee'));
    }

    function testAvatarBuilder() {
        final avatar = Avatar.component().name('Jason Lee').placeholder(glaze.kit.Icon.component(IconName.User)).large();
        assertEquals('Jason Lee', avatar.nameValue);
        assertEquals('JL', avatar.shortName);
        assertTrue(avatar.size.equals(Large));
    }

    // avatar/avatar_group.rs

    function testAvatarGroupBuilder() {
        final group = AvatarGroup.component()
            .child(Avatar.component().name('Alice'))
            .child(Avatar.component().name('Bob'))
            .child(Avatar.component().name('Charlie'))
            .child(Avatar.component().name('David'))
            .large()
            .limit(3)
            .ellipsis();
        assertEquals(4, group.avatars.length);
        assertTrue(group.size.equals(Large));
        assertEquals(3, group.limitProp);
        assertTrue(group.ellipsisValue);
    }

    // progress/progress.rs and kit/tests/integration/components.rs

    function testStoresAnExplicitAccessibilityLabel() {
        assertNull(glaze.kit.progress.Progress.component('upload').getAccessibilityLabel());
        assertEquals('Upload progress', glaze.kit.progress.Progress.component('upload').accessibilityLabel('Upload progress').getAccessibilityLabel());
    }

}

private class Host extends Model implements Render {

    final build:() -> IntoElement;

    public function new(build:() -> IntoElement) {
        super();
        this.build = build;
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return build();
    }

}

