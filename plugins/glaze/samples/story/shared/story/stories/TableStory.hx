// Ported from gpui-kit 0.8.1: crates/story/src/stories/table_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.

package story.stories;

import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Model;
import glaze.Render;
import glaze.Window;
import glaze.kit.ChildElement;
import glaze.kit.Size;
import glaze.kit.table.Table;
import glaze.kit.tag.Tag;
import glaze.kit.theme.Theme;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using glaze.kit.base.StyledExt;

class TableStory extends Model implements Story {

    public static function title():String {
        return 'Table';
    }

    public static function description():String {
        return 'A basic table component for directly rendering tabular data.';
    }

    public static function newView(window:Window, cx:App):glaze.AnyView {
        return view(window, cx);
    }

    public static function view(window:Window, cx:App):Entity<TableStory> {
        return cx.newEntity((c:Context<TableStory>) -> new TableStory(window, c));
    }

    final focusHandle_:FocusHandle;

    @observe var size:Size = glaze.kit.Size.Medium;

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
            case _: Tag.component().child(status);
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
            .child(section('Default').wFull().child(Table.component()
                .withSize(size)
                .child(TableHeader.component().child(TableRow.component()
                    .child(TableHead.component().w(px(150.)).child('Invoice'))
                    .child(TableHead.component().colSpan(2).child('Status'))
                    .child(TableHead.component().textRight().child('Amount'))
                    .child(TableHead.component().textRight().child('Date'))))
                .child(TableBody.component().children([for (row in invoices) (TableRow.component()
                    .child(TableCell.component().w(px(150.)).child(row[0]))
                    .child(TableCell.component().child(statusTag(row[1])))
                    .child(TableCell.component().child(row[2]))
                    .child(TableCell.component().textRight().child(row[3]))
                    .child(TableCell.component().textRight().child(row[4])) : ChildElement)]))
                .child(TableFooter.component().child(TableRow.component()
                    .child(TableCell.component().colSpan(3).child('Total'))
                    .child(TableCell.component().colSpan(2).textRight().child('$$2,250.00'))))
                .child(TableCaption.component().child('A list of your recent invoices.'))))
            .child(section('Bordered').wFull().child(Table.component()
                .withSize(size)
                .border1()
                .borderColor(theme.border)
                .rounded(theme.radius)
                .child(TableHeader.component().child(TableRow.component()
                    .child(TableHead.component().w(px(100.)).child('Invoice'))
                    .child(TableHead.component().child('Method'))
                    .child(TableHead.component().textRight().child('Amount'))
                    .child(TableHead.component().textRight().child('Date'))))
                .child(TableBody.component().children([for (ix in 0...6) {
                    final row = invoices[ix];
                    final tableRow = TableRow.component();
                    if (ix % 2 != 0) tableRow.bg(theme.tableEven);
                    (tableRow
                        .child(TableCell.component().w(px(100.)).child(row[0]))
                        .child(TableCell.component().child(row[2]))
                        .child(TableCell.component().textRight().child(row[3]))
                        .child(TableCell.component().textRight().child(row[4])) : ChildElement);
                }]))));
    }

}
