// Ported from gpui-kit 0.8.1: crates/story/src/stories/table_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.

package story.stories;

import gpui.App;
import gpui.Context;
import gpui.Entity;
import gpui.FocusHandle;
import gpui.IntoElement;
import gpui.Model;
import gpui.Render;
import gpui.Window;
import gpui.component.ChildElement;
import gpui.component.Size;
import gpui.component.table.Table;
import gpui.component.tag.Tag;
import gpui.component.theme.Theme;

import gpui.Prelude.*;
import gpui.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using gpui.base.StyledExt;

class TableStory extends Model implements Story {

    public static function title():String {
        return 'Table';
    }

    public static function description():String {
        return 'A basic table component for directly rendering tabular data.';
    }

    public static function newView(window:Window, cx:App):gpui.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<TableStory> {
        return cx.newEntity((c:Context<TableStory>) -> new TableStory(window, c));
    }

    final focusHandle_:FocusHandle;

    @observe var size:Size = gpui.component.Size.Medium;

    function new(_:Window, cx:Context<TableStory>) {
        super();
        focusHandle_ = cx.focusHandle();
    }

    public function focusHandle(_:App):FocusHandle {
        return focusHandle_;
    }

    static function statusTag(status:String):Tag {
        return (switch status {
            case 'Paid': Tag.success().outline().child(status);
            case 'Pending': Tag.warning().outline().child(status);
            case 'Unpaid': Tag.danger().outline().child(status);
            case _: new Tag().child(status);
        }).xsmall();
    }

    static final INVOICES:Array<Array<String>> = [
        ['INV001', 'Paid', 'Credit Card', '$$250.00', '2024-01-15'],
        ['INV002', 'Pending', 'PayPal', '$$150.00', '2024-02-01'],
        ['INV003', 'Unpaid', 'Bank Transfer', '$$350.00', '2024-02-15'],
        ['INV004', 'Paid', 'Credit Card\nMaster Card / Visa', '$$450.00', '2024-03-01'],
        ['INV005', 'Paid', 'PayPal', '$$550.00', '2024-03-15'],
        ['INV006', 'Pending', 'Bank Transfer', '$$200.00', '2024-04-01'],
        ['INV007', 'Unpaid', 'Credit Card', '$$300.00', '2024-04-15'],
    ];

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final theme = Theme.global(cx.app);
        final invoices = INVOICES;
        return vFlex()
            .sizeFull()
            .gap6()
            .onAction(ChangeStorySize, (action, _, _) -> size = action.value)
            .child(storyToolbar(size))
            .child(section('Default').wFull().child(new Table()
                .withSize(size)
                .child(new TableHeader().child(new TableRow()
                    .child(new TableHead().w(px(150.)).child('Invoice'))
                    .child(new TableHead().colSpan(2).child('Status'))
                    .child(new TableHead().textRight().child('Amount'))
                    .child(new TableHead().textRight().child('Date'))))
                .child(new TableBody().children([for (row in invoices) (new TableRow()
                    .child(new TableCell().w(px(150.)).child(row[0]))
                    .child(new TableCell().child(statusTag(row[1])))
                    .child(new TableCell().child(row[2]))
                    .child(new TableCell().textRight().child(row[3]))
                    .child(new TableCell().textRight().child(row[4])) : ChildElement)]))
                .child(new TableFooter().child(new TableRow()
                    .child(new TableCell().colSpan(3).child('Total'))
                    .child(new TableCell().colSpan(2).textRight().child('$$2,250.00'))))
                .child(new TableCaption().child('A list of your recent invoices.'))))
            .child(section('Bordered').wFull().child(new Table()
                .withSize(size)
                .border1()
                .borderColor(theme.border)
                .rounded(theme.radius)
                .child(new TableHeader().child(new TableRow()
                    .child(new TableHead().w(px(100.)).child('Invoice'))
                    .child(new TableHead().child('Method'))
                    .child(new TableHead().textRight().child('Amount'))
                    .child(new TableHead().textRight().child('Date'))))
                .child(new TableBody().children([for (ix in 0...6) {
                    final row = invoices[ix];
                    final tableRow = new TableRow();
                    if (ix % 2 != 0) tableRow.bg(theme.tableEven);
                    (tableRow
                        .child(new TableCell().w(px(100.)).child(row[0]))
                        .child(new TableCell().child(row[2]))
                        .child(new TableCell().textRight().child(row[3]))
                        .child(new TableCell().textRight().child(row[4])) : ChildElement);
                }]))));
    }

}
