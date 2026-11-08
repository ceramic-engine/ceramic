package;

import ceramic.Scene;
import glaze.App;
import glaze.Context;
import glaze.Glaze;
import glaze.IntoElement;
import glaze.Keystroke;
import glaze.Model;
import glaze.Render;
import glaze.Window;
import glaze.kit.base.Root;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.alert.Alert;
import glaze.kit.avatar.Avatar;
import glaze.kit.avatar.AvatarGroup;
import glaze.kit.badge.Badge;
import glaze.kit.base.Slider.SliderState;
import glaze.kit.breadcrumb.Breadcrumb;
import glaze.kit.button.Button;
import glaze.kit.button.ButtonGroup;
import glaze.kit.button.Toggle;
import glaze.kit.checkbox.Checkbox;
import glaze.kit.radio.Radio;
import glaze.kit.slider.Slider;
import glaze.kit.switch_.Switch;
import glaze.kit.toolbar.Toolbar;
import glaze.kit.descriptionlist.DescriptionList;
import glaze.kit.empty.Empty;
import glaze.kit.groupbox.GroupBox;
import glaze.kit.kbd.Kbd;
import glaze.kit.label.Label;
import glaze.kit.link.Link;
import glaze.kit.marker.Marker;
import glaze.kit.progress.Progress;
import glaze.kit.rating.Rating;
import glaze.kit.separator.Separator;
import glaze.kit.shimmer.ShimmerText;
import glaze.kit.skeleton.Skeleton;
import glaze.kit.spinner.Spinner;
import glaze.kit.statusbar.StatusBar;
import glaze.kit.tag.Tag;
import glaze.kit.theme.ColorName;
import glaze.kit.theme.Theme;
import glaze.kit.theme.ThemeMode;
import glaze.kit.VirtualList;
import glaze.kit.VirtualList.VirtualListScrollHandle;
import glaze.kit.scroll.Scrollbar;
import glaze.Action;
import glaze.Anchor;
import glaze.kit.base.Geometry.Placement;
import glaze.kit.button.DropdownButton;
import glaze.kit.dialog.DialogFooter;
import glaze.kit.dialog.DialogFooter.DialogAction;
import glaze.kit.dialog.DialogFooter.DialogClose;
import glaze.kit.hovercard.HoverCard;
import glaze.kit.menu.PopupMenu;
import glaze.kit.notification.Notification;
import glaze.kit.popover.Popover;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;

using glaze.kit.base.StyledExt;
using glaze.kit.scroll.Scrollable;
using glaze.kit.WindowExt;
using glaze.kit.menu.ContextMenu.ContextMenuExt;
using glaze.kit.menu.DropdownMenu;

/** Menu actions of the gallery (they only count in `Gallery.menuAction`). */
@:action(namespace = kit) class GalleryCopy implements Action {}

@:action(namespace = kit) class GalleryRename implements Action {}

@:action(namespace = kit) class GalleryDelete implements Action {}

/**
 * A small gallery of the gpui-kit components ported so far (waves 1 to 5).
 * Click "Toggle theme" (or press `t`) to switch between the light and the
 * dark default themes.
 */
class MainScene extends Scene {

    var ui:Glaze;

    override function create() {

        final cx = Glaze.app;

        // The image is loaded before the first frame (the web has no
        // synchronous file access); the icons are embedded in the code
        App.defaultAssetSource().preload(['ceramic.png'], _ -> {
            ui = new Glaze((window, cx) -> {
                final view = cx.newEntity((_:Context<Gallery>) -> new Gallery());
                return Root.component().child(view);
            });
            ui.size(width, height);
            add(ui);
        });

        #if sys
        // Self test: KIT_SELF_TEST=1 quits after a few seconds of rendering
        if (Sys.getEnv('KIT_SELF_TEST') != null) {
            ceramic.Timer.delay(this, 6.0, () -> {
                final out = Sys.getEnv('KIT_SELF_TEST');
                if (out != '1') sys.io.File.saveContent(out, 'kit self test done');
                Sys.exit(0);
            });
        }
        #end

        input.onKeyDown(this, key -> {
            if (key.keyCode == ceramic.KeyCode.KEY_T) Gallery.toggleTheme(cx);
        });

    }

    override function resize(width:Float, height:Float) {
        if (ui != null) ui.size(width, height);
    }

}

class Gallery extends Model implements Render {

    @observe var clicks:Int = 0;

    @observe var checked:Bool = true;

    @observe var switchOn:Bool = false;

    @observe var radio:Null<Int> = 0;

    @observe var bold:Bool = false;

    @observe var align:Array<Bool> = [true, false, false];

    @observe var groupSelection:Array<Int> = [1];

    @observe var menuAction:String = 'none';

    var slider:Null<glaze.Entity<SliderState>> = null;

    var range:Null<glaze.Entity<SliderState>> = null;

    final virtualHandle = new VirtualListScrollHandle();

    static final ROW_HEIGHTS = [for (ix in 0...500) new glaze.Size(200., 20. + (ix * 7) % 24)];

    public function new() {
        super();
    }

    function controls(cx:Context<Dynamic>):IntoElement {
        if (slider == null) {
            slider = cx.newEntity((_:Context<SliderState>) -> new SliderState().step(5.).defaultValue(40.));
            range = cx.newEntity((_:Context<SliderState>) -> new SliderState().defaultValue([20., 70.]));
        }
        return vFlex().gap3()
            .child(hFlex().gap2().flexWrap()
                .child(Button.component('clicks').primary().icon(IconName.Plus).label('Clicked $clicks').onClick((_, _, _) -> clicks++))
                .child(Button.component('outline').outline().label('Outline'))
                .child(Button.component('ghost').ghost().icon(IconName.Settings))
                .child(Button.component('danger').danger().label('Danger'))
                .child(Button.component('link').link().label('Link'))
                .child(Button.component('loading').label('Loading').loading(true))
                .child(Button.component('disabled').label('Disabled').disabled(true))
                .child(Button.component('caret').outline().label('Menu').dropdownCaret(true)))
            .child(hFlex().gap3()
                .child(ButtonGroup.component('group').outline()
                    .child(Button.component('g-s').label('Small').selected(groupSelection.indexOf(0) >= 0))
                    .child(Button.component('g-m').label('Medium').selected(groupSelection.indexOf(1) >= 0))
                    .child(Button.component('g-l').label('Large').selected(groupSelection.indexOf(2) >= 0))
                    .onClick((ixs, _, _) -> groupSelection = ixs.copy()))
                .child(Toggle.component('bold').icon(IconName.Bell).checked(bold).onClick((next, _, _) -> bold = next))
                .child(ToggleGroup.component('align').outline().segmented()
                    .child(Toggle.component('a-l').label('Left').checked(align[0]))
                    .child(Toggle.component('a-c').label('Center').checked(align[1]))
                    .child(Toggle.component('a-r').label('Right').checked(align[2]))
                    .onClick((next, _, _) -> align = next.copy())))
            .child(hFlex().gap4()
                .child(Checkbox.component('remember').label('Remember me').checked(checked).onClick((next, _, _) -> checked = next))
                .child(Switch.component('notify').label('Notifications').checked(switchOn).onClick((next, _, _) -> switchOn = next))
                .child(RadioGroup.horizontal('plan').selectedIndex(radio)
                    .child(Radio.labeled('Free')).child(Radio.labeled('Pro')).child(Radio.labeled('Team'))
                    .onClick((ix, _, _) -> radio = ix)))
            .child(hFlex().gap4()
                .child(div().w(px(220.)).child(Slider.component(slider)))
                .child(div().w(px(220.)).child(Slider.component(range))))
            .child(Toolbar.component('toolbar').border1()
                .child(Button.component('tb-new').icon(IconName.Plus))
                .child(Button.component('tb-search').icon(IconName.Search))
                .content(glaze.kit.separator.Separator.vertical().h4())
                .child(Toggle.component('tb-bell').icon(IconName.Bell).checked(true))
                .content(div().flex1())
                .child(Button.component('tb-publish').primary().label('Publish')));
    }

    /** `overflowYScrollbar`, `overflowXScrollbar`, and a virtual list with a scrollbar. */
    function scrolling(cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        final entity:glaze.Entity<Gallery> = cast cx.entity();
        return hFlex().gap4().itemsStart()
            .child(vFlex().w(px(220.)).h(px(160.)).border1().borderColor(theme.border)
                .overflowYScrollbar()
                .children([for (ix in 0...30) (div().px2().py1().child('Row $ix') : IntoElement)]))
            .child(vFlex().gap2()
                .child(hFlex().w(px(260.)).h(px(48.)).border1().borderColor(theme.border)
                    .overflowXScrollbar()
                    .children([for (ix in 0...20) (div().flexShrink0().w(px(40.)).hFull().bg(ix % 2 == 0 ? theme.secondary : theme.muted) : IntoElement)]))
                .child(div().relative().w(px(260.)).h(px(104.)).border1().borderColor(theme.border)
                    .child(VirtualList.vVirtualList(entity, 'virtual', ROW_HEIGHTS, (_, start, end, _, cx) -> {
                        final theme = Theme.global(cx.app);
                        return [for (ix in start...end) (div().h(px(ROW_HEIGHTS[ix].height)).wFull().px2().textXs()
                            .bg(ix % 2 == 0 ? theme.secondary : theme.muted).child('Item $ix') : IntoElement)];
                    }).trackScroll(virtualHandle))
                    .child(Scrollbar.vertical(virtualHandle).mode(Always))));
    }

    static function galleryMenu(menu:PopupMenu, window:Window, cx:Context<PopupMenu>):PopupMenu {
        return menu
            .menuWithIcon('Copy', IconName.Copy, new GalleryCopy())
            .menu('Rename', new GalleryRename())
            .separator()
            .menuWithCheck('Word wrap', true, new GalleryCopy())
            .menuWithDisabled('Delete', new GalleryDelete(), true)
            .separator()
            .submenu('Share', window, cx, (menu, _, _) -> menu
                .menu('Email', new GalleryCopy())
                .menu('Copy link', new GalleryCopy()));
    }

    /** Wave 5: popover, tooltip, hover card, menus, dialogs, sheets, notifications. */
    function overlays(cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        return vFlex().gap3()
            .onAction(GalleryCopy, (_, _, _) -> menuAction = 'copy')
            .onAction(GalleryRename, (_, _, _) -> menuAction = 'rename')
            .child(hFlex().gap2().flexWrap()
                .child(Popover.component('popover').anchor(Anchor.TopLeft).arrow(true)
                    .trigger(Button.component('popover-trigger').outline().label('Popover'))
                    .child(vFlex().gap1().w(px(200.)).child('A popover').child(glaze.kit.label.Label.component('Escape or an outside click closes it').textXs())))
                .child(Button.component('tooltip').outline().label('Tooltip').tooltip('Shown after a delay'))
                .child(HoverCard.component('hover-card')
                    .trigger(Button.component('hover-trigger').link().label('@gpui-kit'))
                    .content((_, _, _) -> vFlex().w(px(200.)).gap1().child('GPUI Kit').child(glaze.kit.label.Label.component('Components for GPUI').textXs())))
                .child(Button.component('menu').outline().label('Menu').dropdownCaret(true).dropdownMenu(galleryMenu))
                .child(DropdownButton.component('split').button(Button.component('split-action').label('Save')).dropdownMenu(galleryMenu)))
            .child(hFlex().gap2().flexWrap()
                .child(Button.component('dialog').label('Dialog').onClick((_, window, cx) -> window.openDialog(cx, (dialog, _, _) -> dialog
                    .title('A dialog')
                    .child('Tab stays inside, escape closes it.')
                    .footer(DialogFooter.component()
                        .child(DialogClose.component().trigger(button -> button.label('Cancel')))
                        .child(DialogAction.component().child(Button.component('dialog-ok').primary().label('OK')))))))
                .child(Button.component('alert').label('Alert dialog').onClick((_, window, cx) -> window.openAlertDialog(cx, (alert, _, _) -> alert
                    .title('Delete project?')
                    .description('This cannot be undone.')
                    .confirm()
                    .okText('Delete')
                    .okVariant(Danger))))
                .child(Button.component('sheet').label('Sheet').onClick((_, window, cx) -> window.openSheetAt(Placement.Right, cx, (sheet, _, _) -> sheet
                    .title('Settings')
                    .child('Sheet content'))))
                .child(Button.component('notify').label('Notification').onClick((_, window, cx) -> window.pushNotification(new Notification()
                    .title('Saved')
                    .message('The file was saved.')
                    .withType(Success), cx))))
            .child(div().p3().border1().borderColor(theme.border).rounded(theme.radius).textColor(theme.mutedForeground)
                .child('Right click here for a context menu (last menu action: $menuAction)')
                .contextMenu((menu, window, cx) -> galleryMenu(menu, window, cx)));
    }

    public static function toggleTheme(cx:App):Void {
        Theme.setMode(Theme.global(cx).isDark() ? ThemeMode.Light : ThemeMode.Dark, cx);
    }

    function section(title:String, content:IntoElement):IntoElement {
        return vFlex().gap2().child(glaze.kit.label.Label.component(title).textSm().fontSemibold()).child(content);
    }

    public function render(window:Window, cx:Context<Dynamic>):IntoElement {
        return div()
            .id('gallery')
            .sizeFull()
            .overflowYScroll()
            .child(
                vFlex()
                    .p4()
                    .gap5()
                    .child(
                        hFlex().gap3()
                            .child(glaze.kit.label.Label.component('gpui-kit gallery').textXl().fontBold())
                            .child(glaze.kit.link.Link.component('toggle').child('Toggle theme').onClick((_, _, cx) -> toggleTheme(cx)))
                            .child(Kbd.component(Keystroke.parse('t')))
                    )
                    .child(section('Buttons and controls', controls(cx)))
                    .child(section('Overlays and menus', overlays(cx)))
                    .child(section('Scrolling', scrolling(cx)))
                    .child(section('Label, Kbd, Link', hFlex().gap3()
                        .child(glaze.kit.label.Label.component('Name').secondary('(optional)'))
                        .child(glaze.kit.label.Label.component('Hello World').highlights('world'))
                        .child(Kbd.component(Keystroke.parse('cmd-shift-p')))
                        .child(glaze.kit.link.Link.component('docs').href('https://gpui-kit.com').child('gpui-kit.com'))))
                    .child(section('Badge and Tag', hFlex().gap4()
                        .child(Badge.component().count(3).child(glaze.kit.Icon.component(IconName.Bell).large()))
                        .child(Badge.component().dot().child(glaze.kit.Icon.component(IconName.Inbox).large()))
                        .child(Tag.primary().child('Primary'))
                        .child(Tag.success().outline().child('Success'))
                        .child(Tag.color(ColorName.Purple).child('Purple'))))
                    .child(section('Avatar', hFlex().gap3()
                        .child(Avatar.component().name('Jason Lee'))
                        .child(Avatar.component().src('ceramic.png'))
                        .child(AvatarGroup.component().small().limit(3).ellipsis()
                            .child(Avatar.component().name('Alice')).child(Avatar.component().name('Bob'))
                            .child(Avatar.component().name('Charlie')).child(Avatar.component().name('David')))))
                    .child(section('Progress, Spinner, Skeleton, Rating', vFlex().gap3()
                        .child(Progress.component('progress').value(60.))
                        .child(hFlex().gap3()
                            .child(glaze.kit.spinner.Spinner.component())
                            .child(Skeleton.component().w(px(160.)))
                            .child(Rating.component('rating').value(3))
                            .child(ShimmerText.component('Thinking...')))))
                    .child(section('Alert', vFlex().gap2()
                        .child(Alert.info('info', 'This port runs on Ceramic.').title('Information'))
                        .child(Alert.warning('warning', 'Waves 6 and later are not ported yet.').onClose((_, _, _) -> {}))))
                    .child(section('Separator, Breadcrumb, StatusBar', vFlex().gap3()
                        .child(Breadcrumb.component().child('Home').child('Components').child('Gallery'))
                        .child(glaze.kit.separator.Separator.horizontal().label('Or'))
                        .child(StatusBar.component().left(div().child('main')).child('Ready').right(div().child('UTF-8')))))
                    .child(section('Empty, DescriptionList, GroupBox, Marker', vFlex().gap3()
                        .child(Empty.component().border1().header(EmptyHeader.component()
                            .media(EmptyMedia.component().withVariant(EmptyMediaVariant.Icon).child(glaze.kit.Icon.component(IconName.Inbox)))
                            .title(EmptyTitle.component().child('No messages'))))
                        .child(DescriptionList.component().columns(2).item('Name', 'gpui-kit', 1).item('Version', '0.8.1', 1))
                        .child(GroupBox.component().outline().title('Group').child('Grouped content'))
                        .child(Marker.component().withVariant(MarkerVariant.Separator).content(MarkerContent.component().text('Today')))))
            );
    }

}
