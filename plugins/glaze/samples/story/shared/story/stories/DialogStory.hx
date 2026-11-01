// Ported from gpui-kit 0.8.1: crates/story/src/stories/dialog_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story.stories;

import gpui.Action;
import gpui.AnyView;
import gpui.App;
import gpui.Context;
import gpui.Entity;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.Model;
import gpui.Window;
import gpui.base.input.InputState;
import gpui.component.Icon;
import gpui.component.IconName;
import gpui.component.TitleBar;
import gpui.component.button.Button;
import gpui.component.dialog.Dialog;
import gpui.component.dialog.DialogDescription;
import gpui.component.dialog.DialogEntrance;
import gpui.component.dialog.DialogFooter;
import gpui.component.dialog.DialogHeader;
import gpui.component.dialog.DialogTitle;
import gpui.component.input.Input;
import gpui.component.searchablelist.SearchableVec;
import gpui.component.select.Select;
import gpui.component.select.SelectState;
import gpui.component.table.Column;
import gpui.component.table.DataTable;
import gpui.component.table.TableDelegate;
import gpui.component.table.TableState;
import gpui.component.text.TextView;
import gpui.component.theme.Theme;
import gpui.component.time.DatePicker;
import story.Include;
import story.Story;
import story.StoryActions.TestAction;

import gpui.Prelude.*;
import gpui.base.Prelude.*;
import story.Lib.*;

using gpui.base.StyledExt;
using gpui.base.Calendar.CalendarDateTools;
using gpui.component.WindowExt;

enum DialogOptionKind {
    Overlay;
    OverlayClosable;
    CloseButton;
    Keyboard;
}

/** Rust `enum ToggleDialogOption` (an action). */
@:action(namespace = dialog_story, noJson)
class ToggleDialogOption implements Action {
    public final value:DialogOptionKind;
}

@:action(namespace = dialog_story, noJson)
class SetDialogEntrance implements Action {
    public final entrance:DialogEntrance;
}

/** Rust `struct MyTable`. */
class DialogStoryTable extends TableDelegateBase {

    final columns:Array<Column>;

    public function new(_:App) {
        columns = [
            new Column('id', 'ID').withWidth(px(50.)),
            new Column('name', 'Name').withWidth(px(150.)),
            new Column('email', 'Email').withWidth(px(250.)),
            new Column('role', 'Role').withWidth(px(150.)),
            new Column('status', 'Status').withWidth(px(100.)),
        ];
    }

    public function columnsCount(_:App):Int {
        return 5;
    }

    public function rowsCount(_:App):Int {
        return 200;
    }

    public function column(colIx:Int, _:App):Column {
        return columns[colIx].clone();
    }

    public function renderTd(rowIx:Int, colIx:Int, _:Window, _:Context<TableState<Dynamic>>):IntoElement {
        return switch colIx {
            case 0: '$rowIx';
            case 1: 'User $rowIx';
            case 2: 'user-$rowIx@mail.com';
            case 3: 'User';
            case 4: 'Active';
            case _: throw 'Invalid column index';
        }
    }

}

class DialogStory extends Model implements Story {

    final focusHandle:FocusHandle;

    var selectedValue:Null<String>;

    final input1:Entity<InputState>;

    final input2:Entity<InputState>;

    final date:Entity<DatePickerState>;

    final select:Entity<SelectState<String>>;

    final table:Entity<TableState<DialogStoryTable>>;

    var dialogOverlay:Bool;

    var closeButton:Bool;

    var keyboard:Bool;

    var overlayClosable:Bool;

    var entrance:DialogEntrance;

    public static function title():String {
        return 'Dialog';
    }

    public static function description():String {
        return 'Present focused content above the current view.';
    }

    public static function newView(window:Window, cx:App):AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<DialogStory> {
        return cx.newEntity((cx:Context<DialogStory>) -> new DialogStory(window, cx));
    }

    function new(window:Window, cx:Context<DialogStory>) {
        super();
        input1 = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx).withPlaceholder('Your Name'));
        input2 = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx).withPlaceholder('Type before opening a dialog'));
        date = cx.newEntity((cx:Context<DatePickerState>) -> new DatePickerState(window, cx));
        select = cx.newEntity((cx:Context<SelectState<String>>) ->
            new SelectState(new SearchableVec(['Option 1', 'Option 2', 'Option 3']), null, window, cx));

        table = cx.newEntity((cx:Context<TableState<DialogStoryTable>>) -> new TableState(new DialogStoryTable(cx.app), window, cx));

        focusHandle = cx.focusHandle();
        selectedValue = null;
        dialogOverlay = true;
        closeButton = true;
        keyboard = true;
        overlayClosable = true;
        entrance = SlideDown;
    }

    function onActionTestAction(_:TestAction, window:Window, cx:Context<DialogStory>):Void {
        window.pushNotification('You have clicked the TestAction.', cx.app);
    }

    function renderBasicDialog(cx:Context<DialogStory>):IntoElement {
        final dialogOverlay = this.dialogOverlay;
        final overlayClosable = this.overlayClosable;
        final input1 = this.input1;
        final date = this.date;
        final select = this.select;
        final view = cx.entity();

        return section('Default')
            .description('Compose form controls and footer actions.')
            .child(new Dialog(cx.app)
                .trigger(new Button('show-dialog').outline().label('Open Dialog'))
                .overlay(dialogOverlay)
                .keyboard(keyboard)
                .closeButton(closeButton)
                .overlayClosable(overlayClosable)
                .entrance(entrance)
                .onOk((_, window, cx) -> {
                    view.update(cx, (view, cx) -> {
                        view.selectedValue = 'Hello, ${input1.read(cx).value()}, date: ${date.read(cx).date().toDisplayString()}';
                    });
                    window.pushNotification('You have pressed confirm.', cx);
                    return true;
                })
                .p0()
                .content((content, _, cx) -> content
                    .child(new DialogHeader()
                        .p4()
                        .child(new DialogTitle().child('Basic Dialog'))
                        .child(new DialogDescription().child('This is a basic dialog created using the declarative API.')))
                    .child(vFlex()
                        .px4()
                        .pb4()
                        .gap3()
                        .child('This is a dialog dialog, you can put anything here.')
                        .child(new Input(input1))
                        .child(new Select(select))
                        .child(new DatePicker(date).placeholder('Date of Birth')))
                    .child(new DialogFooter()
                        .p4()
                        .bg(Theme.global(cx).muted)
                        .justifyBetween()
                        .child(new Button('new-dialog')
                            .label('Open Other Dialog')
                            .outline()
                            .onClick((_, window, cx) -> {
                                window.openDialog(cx, (dialog, _, _) -> dialog
                                    .title('Other Dialog')
                                    .child('This is another dialog.')
                                    .minH(px(100.))
                                    .overlayClosable(overlayClosable));
                            }))
                        .child(hFlex()
                            .gap2()
                            .child(new DialogClose().child(new Button('cancel').label('Cancel').outline()))
                            .child(new DialogAction().child(new Button('confirm')
                                .primary()
                                .label('Confirm')))))));
    }

    function renderFocusReturnCheck(cx:Context<DialogStory>):IntoElement {
        final theme = Theme.global(cx);
        return hFlex().wFull().justifyCenter().child(vFlex()
            .wFull()
            .maxW96()
            .gap3()
            .p3()
            .rounded(theme.radiusLg)
            .bg(theme.muted.opacity(0.45))
            .border1()
            .borderColor(theme.border)
            .child(vFlex()
                .gap1()
                .child(div().fontMedium().child('Focus return check'))
                .child(div()
                    .textXs()
                    .textColor(theme.mutedForeground)
                    .child('Type here, then open and close any dialog.')))
            .child(hFlex()
                .wFull()
                .gap2()
                .child(div()
                    .minW0()
                    .flex1()
                    .child(new Input(input2).wFull()))
                .child(new Button('test-action')
                    .outline()
                    .label('Run Action')
                    .flexShrink0()
                    .onClick((_, window, cx) -> {
                        window.dispatchAction(new TestAction(), cx);
                    })
                    .tooltip('Verify actions still dispatch after a dialog closes.'))));
    }

    function renderDialogWithoutTitle(cx:Context<DialogStory>):IntoElement {
        final dialogOverlay = this.dialogOverlay;
        final overlayClosable = this.overlayClosable;

        return section('Without title')
            .description('Render content without a heading.')
            .child(new Button('dialog-no-title')
                .outline()
                .label('Dialog without Title')
                .onClick(cx.listener((_, _, window, cx) -> {
                    window.openDialog(cx.app, (dialog, _, _) -> dialog
                        .overlay(dialogOverlay)
                        .overlayClosable(overlayClosable)
                        .child('This is a dialog without title, you can use it when the title is not necessary.'));
                })));
    }

    function renderCustomButtons(cx:Context<DialogStory>):IntoElement {
        final dialogOverlay = this.dialogOverlay;
        final overlayClosable = this.overlayClosable;

        return section('Custom actions')
            .description('Replace the default footer actions.')
            .child(new Button('confirm-dialog1')
                .outline()
                .label('Custom Buttons')
                .onClick(cx.listener((_, _, window, cx) -> {
                    window.openDialog(cx.app, (dialog, _, cx) -> {
                        final theme = Theme.global(cx);
                        return dialog
                            .rounded(theme.radiusLg)
                            .overlay(dialogOverlay)
                            .overlayClosable(overlayClosable)
                            .child(vFlex()
                                .gap3()
                                .itemsCenter()
                                .child(div()
                                    .flex()
                                    .itemsCenter()
                                    .justifyCenter()
                                    .rounded(theme.radiusLg)
                                    .bg(theme.warning.opacity(0.2))
                                    .size12()
                                    .textColor(theme.warning)
                                    .child(new Icon(IconName.TriangleAlert).size8()))
                                .child('Update successful, we need to restart the application.'))
                            .footer(new DialogFooter()
                                .child(new DialogClose().child(new Button('cancel').label('Later').outline()))
                                .child(new DialogAction().child(new Button('ok').label('Restart Now').primary())))
                            .onOk((_, window, cx) -> {
                                window.pushNotification('You have pressed restart.', cx);
                                return true;
                            })
                            .onCancel((_, window, cx) -> {
                                window.pushNotification('You have pressed later.', cx);
                                return true;
                            });
                    });
                })));
    }

    function renderScrollableDialog(cx:Context<DialogStory>):IntoElement {
        final dialogOverlay = this.dialogOverlay;
        final overlayClosable = this.overlayClosable;

        return section('Scrollable')
            .description('Keep long content inside a fixed dialog size.')
            .child(new Button('scrollable-dialog')
                .outline()
                .label('Scrollable Dialog')
                .onClick(cx.listener((_, _, window, cx) -> {
                    window.openDialog(cx.app, (dialog, _, _) -> dialog
                        .w(px(720.))
                        .h(px(600.))
                        .overlay(dialogOverlay)
                        .overlayClosable(overlayClosable)
                        .title('Dialog with scrollbar')
                        .child(TextView.markdownAt(Include.str('README.md')))
                        .footer(new DialogFooter()
                            .gap2()
                            .child(new DialogClose().child(new Button('cancel').label('Cancel').outline()))
                            .child(new DialogAction().child(new Button('confirm').label('Confirm').primary()))));
                })));
    }

    function renderTableInDialog(cx:Context<DialogStory>):IntoElement {
        final dialogOverlay = this.dialogOverlay;
        final overlayClosable = this.overlayClosable;

        return section('Data table')
            .description('Embed a full interactive component.')
            .child(new Button('table-dialog')
                .outline()
                .label('Table Dialog')
                .onClick(cx.listener((this_:DialogStory, _, window, cx) -> {
                    final table = this_.table;
                    window.openDialog(cx.app, (dialog, _, _) -> dialog
                        .w(px(800.))
                        .h(px(600.))
                        .overlay(dialogOverlay)
                        .overlayClosable(overlayClosable)
                        .title('Dialog with Table')
                        .child(vFlex()
                            .sizeFull()
                            .gap3()
                            .child('This is a dialog contains a table component.')
                            .child(new DataTable(table))));
                })));
    }

    function renderCustomPaddings(cx:Context<DialogStory>):IntoElement {
        return section('Padding')
            .description('Control spacing around dialog content.')
            .child(new Button('custom-dialog-paddings')
                .outline()
                .label('Custom Paddings')
                .onClick(cx.listener((_, _, window, cx) -> {
                    window.openDialog(cx.app, (dialog, _, _) -> dialog.p3().title('Custom Dialog Title').child(
                        'This is a custom dialog content, we can use paddings to control the layout and spacing within the dialog.'));
                })));
    }

    function renderCustomStyle(cx:Context<DialogStory>):IntoElement {
        return section('Custom style')
            .description('Customize color, radius, and foreground.')
            .child(new Button('custom-dialog-style')
                .outline()
                .label('Custom Dialog Style')
                .onClick(cx.listener((_, _, window, cx) -> {
                    window.openDialog(cx.app, (dialog, _, cx) -> {
                        final theme = Theme.global(cx);
                        return dialog
                            .rounded(theme.radiusLg)
                            .bg(theme.cyan)
                            .textColor(theme.infoForeground)
                            .title('Custom Dialog Title')
                            .child('This is a custom dialog content.');
                    });
                })));
    }

    function renderDialogWithContent(cx:Context<DialogStory>):IntoElement {
        return section('Custom content')
            .description('Compose header, body, and footer explicitly.')
            .child(new Button('custom-width-dialog-btn')
                .outline()
                .label('Custom Width (400px)')
                .onClick(cx.listener((_, _, window, cx) -> {
                    window.openDialog(cx.app, (dialog, _, _) -> dialog.w(px(400.)).content((content, _, _) -> content
                        .child(new DialogHeader()
                            .child(new DialogTitle().child('Custom Width'))
                            .child(new DialogDescription().child('This dialog has a custom width of 400px.')))
                        .child('Content area with custom width configuration, and the footer is used flex 1 button widths.')
                        .child(new DialogFooter()
                            .justifyCenter()
                            .child(new Button('cancel')
                                .flex1()
                                .outline()
                                .label('Cancel')
                                .onClick((_, window, cx) -> {
                                    window.closeDialog(cx);
                                }))
                            .child(new Button('done')
                                .flex1()
                                .primary()
                                .label('Done')
                                .onClick((_, window, cx) -> {
                                    window.closeDialog(cx);
                                })))));
                })));
    }

    function renderTextviewDialog(cx:Context<DialogStory>):IntoElement {
        final dialogOverlay = this.dialogOverlay;
        final overlayClosable = this.overlayClosable;
        return section('Selectable text')
            .description('Embed selectable rich text.')
            .child(new Dialog(cx.app)
                .trigger(new Button('textview-dialog-btn')
                    .outline()
                    .label('TextView Dialog'))
                .overlay(dialogOverlay)
                .keyboard(keyboard)
                .closeButton(closeButton)
                .overlayClosable(overlayClosable)
                .p0()
                .content((content, _, cx) -> content
                    .child(new DialogHeader()
                        .p4()
                        .child(new DialogTitle().child('TextView Dialog')))
                    .child(vFlex().px4().pb4().gap3().child(TextView.markdown('dialog-textview',
                        'This is a dialog with a selectable TextView in it. This text should be selectable.')
                        .selectable(true)))
                    .child(new DialogFooter()
                        .p4()
                        .bg(Theme.global(cx).muted)
                        .child(new DialogClose().child(new Button('cancel').label('Cancel').outline()))
                        .child(new DialogAction().child(new Button('confirm').primary().label('Confirm'))))));
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final self:Context<DialogStory> = cast cx;
        final overlay = dialogOverlay;
        final overlayClosable = this.overlayClosable;
        final closeButton = this.closeButton;
        final keyboard = this.keyboard;
        final entrance = this.entrance;

        final column = vFlex()
            .gap6()
            .child(storyToolbarGroup().dropdownChild(new Button('dialog-options').label('Options'), (menu, window, cx) -> menu
                .menuWithCheck('Overlay', overlay, new ToggleDialogOption(Overlay))
                .menuWithCheck('Close on overlay click', overlayClosable, new ToggleDialogOption(OverlayClosable))
                .menuWithCheck('Close button', closeButton, new ToggleDialogOption(CloseButton))
                .menuWithCheck('Keyboard', keyboard, new ToggleDialogOption(Keyboard))
                .submenu('Entrance', window, cx, (menu, _, _) -> {
                    var menu = menu;
                    for (option in [
                        {label: 'Slide down', value: DialogEntrance.SlideDown},
                        {label: 'Fade', value: DialogEntrance.Fade},
                        {label: 'Fade and slide', value: DialogEntrance.FadeSlide},
                        {label: 'No animation', value: DialogEntrance.None},
                    ]) {
                        menu = menu.menuWithCheck(option.label, entrance == option.value, new SetDialogEntrance(option.value));
                    }
                    return menu;
                })))
            .child(renderBasicDialog(self))
            .child(renderCustomButtons(self))
            .child(renderScrollableDialog(self))
            .child(renderTableInDialog(self))
            .child(renderDialogWithoutTitle(self))
            .child(renderCustomPaddings(self))
            .child(renderCustomStyle(self))
            .child(renderDialogWithContent(self))
            .child(renderTextviewDialog(self));
        // Rust `cfg!(not(target_family = "wasm"))`
        if (!TitleBar.isWeb) column.child(renderFocusReturnCheck(self));

        return div()
            .id('dialog-story')
            .trackFocus(focusHandle)
            .onAction(TestAction, self.listener((this_:DialogStory, a:TestAction, w, c) -> this_.onActionTestAction(a, w, c)))
            .onAction(ToggleDialogOption, self.listener((this_:DialogStory, action:ToggleDialogOption, _, cx) -> {
                switch action.value {
                    case Overlay: this_.dialogOverlay = !this_.dialogOverlay;
                    case OverlayClosable: this_.overlayClosable = !this_.overlayClosable;
                    case CloseButton: this_.closeButton = !this_.closeButton;
                    case Keyboard: this_.keyboard = !this_.keyboard;
                }
                cx.notify();
            }))
            .onAction(SetDialogEntrance, self.listener((this_:DialogStory, action:SetDialogEntrance, _, cx) -> {
                this_.entrance = action.entrance;
                cx.notify();
            }))
            .sizeFull()
            .child(column);
    }

}
