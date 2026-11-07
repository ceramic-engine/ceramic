// Ported from gpui-kit 0.8.1: crates/story/src/stories/pagination_story.rs
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
import gpui.component.Size;
import gpui.component.pagination.Pagination;

import gpui.Prelude.*;
import gpui.base.Prelude.*;
import story.Story;
import story.StoryActions.ChangeStorySize;

import story.Lib.*;

using gpui.base.StyledExt;

class PaginationStory extends Model implements Story {

    public static function title():String {
        return 'Pagination';
    }

    public static function description():String {
        return 'Pagination with page navigation, next and previous links.';
    }

    public static function newView(window:Window, cx:App):gpui.AnyView {
        return view(window, cx);
    }

    public static function view(_:Window, cx:App):Entity<PaginationStory> {
        return cx.newEntity((c:Context<PaginationStory>) -> new PaginationStory(c));
    }

    @observe var basicPage:Int = 5;

    @observe var manyPagesPage:Int = 1;

    @observe var compactPage:Int = 3;

    final focusHandle_:FocusHandle;

    @observe var size:Size = gpui.component.Size.Medium;

    function new(cx:Context<PaginationStory>) {
        super();
        focusHandle_ = cx.focusHandle();
    }

    public function focusHandle(_:App):FocusHandle {
        return focusHandle_;
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        return vFlex()
            .gap6()
            .onAction(ChangeStorySize, (action, _, _) -> size = action.value)
            .child(storyToolbar(size))
            .child(section('Default').child(new Pagination('basic-pagination')
                .currentPage(basicPage)
                .totalPages(10)
                .withSize(size)
                .onClick((page, _, _) -> basicPage = page)))
            .child(section('Visible Pages')
                .description('Control how many page links remain visible in a larger result set.')
                .child(new Pagination('many-pages-pagination')
                    .currentPage(manyPagesPage)
                    .totalPages(50)
                    .visiblePages(10)
                    .withSize(size)
                    .onClick((page, _, _) -> manyPagesPage = page)))
            .child(section('Compact Style').child(new Pagination('compact-pagination')
                .compact()
                .currentPage(compactPage)
                .totalPages(10)
                .withSize(size)
                .onClick((page, _, _) -> compactPage = page)))
            .child(section('Disabled').child(new Pagination('disabled-pagination')
                .currentPage(4)
                .totalPages(10)
                .withSize(size)
                .disabled(true)
                .onClick((_, _, _) -> {})));
    }

}
