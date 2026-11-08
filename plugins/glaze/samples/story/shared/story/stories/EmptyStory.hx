// Ported from gpui-kit 0.8.1: crates/story/src/stories/empty_story.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package story.stories;

import glaze.AnyView;
import glaze.App;
import glaze.Context;
import glaze.Entity;
import glaze.FocusHandle;
import glaze.IntoElement;
import glaze.Model;
import glaze.Subscription;
import glaze.Window;
import glaze.kit.base.input.InputEvent;
import glaze.kit.base.input.InputState;
import glaze.kit.Icon;
import glaze.kit.IconName;
import glaze.kit.avatar.Avatar;
import glaze.kit.avatar.AvatarGroup;
import glaze.kit.button.Button;
import glaze.kit.empty.Empty;
import glaze.kit.input.Input;
import glaze.kit.link.Link;
import glaze.kit.theme.Theme;
import story.Story;

import glaze.Prelude.*;
import glaze.kit.base.Prelude.*;
import story.Lib.*;

using glaze.kit.base.StyledExt;
using glaze.kit.WindowExt;

class EmptyStory extends Model implements Story {

    final focusHandle:FocusHandle;

    var project:Null<String>;

    final search:Entity<InputState>;

    final pageSearch:Entity<InputState>;

    final subscriptions:Array<Subscription>;

    function new(window:Window, cx:Context<EmptyStory>) {
        super();
        search = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx)
            .withPlaceholder('Search projects…')
            .defaultValue('Archive'));
        final subscription = cx.subscribe(search, InputEvent, (_, _, event:InputEvent, cx) -> {
            if (event.match(Change)) {
                cx.notify();
            }
        });
        pageSearch = cx.newEntity((cx:Context<InputState>) -> new InputState(window, cx).withPlaceholder('Search pages…'));

        focusHandle = cx.focusHandle();
        project = null;
        subscriptions = [subscription];
    }

    public static function view(window:Window, cx:App):Entity<EmptyStory> {
        return cx.newEntity((cx:Context<EmptyStory>) -> new EmptyStory(window, cx));
    }

    public static function title():String {
        return 'Empty';
    }

    public static function description():String {
        return 'Compose empty states with icons, avatars, actions, and custom content.';
    }

    public static function newView(window:Window, cx:App):AnyView {
        return view(window, cx);
    }

    static function openInfoDialog(title:String, text:String):(glaze.ClickEvent, Window, App) -> Void {
        return (_, window, cx) -> {
            window.openDialog(cx, (dialog, _, _) -> dialog.title(title).child(text));
        };
    }

    public function render(_:Window, cx:Context<Dynamic>):IntoElement {
        final self:Context<EmptyStory> = cast cx;
        final theme = Theme.global(cx);
        final query = search.read(cx).value().toLowerCase();
        final projects = [for (name in ['Design system', 'Website', 'Mobile app']) if (name.toLowerCase().indexOf(query) >= 0) name];

        final defaultSlot = div().wFull().minH72().flex();
        final project = this.project;
        if (project != null) {
            defaultSlot.child(vFlex()
                .wFull()
                .itemsCenter()
                .justifyCenter()
                .gap4()
                .child(hFlex()
                    .gap2()
                    .child(glaze.kit.Icon.component(IconName.Folder).size4())
                    .child(project))
                .child(Button.component('empty-reset-project')
                    .outline()
                    .label('Reset example')
                    .onClick(self.listener((this_:EmptyStory, _, _, cx) -> {
                        this_.project = null;
                        cx.notify();
                    }))));
        } else {
            defaultSlot.child(Empty.component()
                .header(EmptyHeader.component()
                    .media(EmptyMedia.component()
                        .withVariant(Icon)
                        .child(glaze.kit.Icon.component(IconName.Folder)))
                    .title(EmptyTitle.component().child('No projects yet'))
                    .description(EmptyDescription.component()
                        .child("You haven't created any projects yet. Get started by creating your first project.")))
                .content(EmptyContent.component()
                    .flexRow()
                    .flexWrap()
                    .justifyCenter()
                    .gap2()
                    .child(Button.component('empty-create-project')
                        .label('Create project')
                        .onClick(self.listener((this_:EmptyStory, _, _, cx) -> {
                            this_.project = 'Untitled project';
                            cx.notify();
                        })))
                    .child(Button.component('empty-import-project')
                        .outline()
                        .label('Import sample')
                        .onClick(self.listener((this_:EmptyStory, _, _, cx) -> {
                            this_.project = 'Starter project';
                            cx.notify();
                        }))))
                .child(glaze.kit.link.Link.component('empty-learn-more')
                    .href('https://gpui-kit.com/docs/getting-started')
                    .textSm()
                    .child('Learn more')));
        }

        final searchSlot = div().wFull().minH48().flex();
        if (projects.length == 0) {
            searchSlot.child(Empty.component()
                .header(EmptyHeader.component()
                    .title(EmptyTitle.component().child('No projects found'))
                    .description(EmptyDescription.component().child('Try a different search or clear the query to see all projects.')))
                .content(EmptyContent.component().child(Button.component('empty-clear-search')
                    .outline()
                    .label('Clear search')
                    .onClick(self.listener((this_:EmptyStory, _, window, cx) -> {
                        this_.search.update(cx, (state, cx) -> {
                            state.setValue('', window, cast cx);
                        });
                        this_.search.read(cx).focusHandle.focus(window, cx.app);
                        cx.notify();
                    })))));
        } else {
            searchSlot.child(vFlex()
                .wFull()
                .gap2()
                .children([for (project in projects) (hFlex()
                    .gap2()
                    .p3()
                    .child(glaze.kit.Icon.component(IconName.Folder).size4())
                    .child(project) : IntoElement)]));
        }

        return vFlex()
            .wFull()
            .gap4()
            .child(section('Default')
                .description('A named header, multiple actions, and an extra child below the content. Actions update this example.')
                .child(defaultSlot))
            .child(section('Outline')
                .description('Add a border through Styled; the component already supplies the dashed treatment.')
                .child(Empty.component()
                    .border1()
                    .header(EmptyHeader.component()
                        .media(EmptyMedia.component()
                            .withVariant(Icon)
                            .child(glaze.kit.Icon.component(IconName.HardDrive)))
                        .title(EmptyTitle.component().child('Cloud storage is empty'))
                        .description(EmptyDescription.component().child('Upload files to your cloud storage to access them anywhere.')))
                    .content(EmptyContent.component().child(Button.component('empty-upload')
                        .outline()
                        .small()
                        .label('Upload files…')
                        .onClick(openInfoDialog('Upload files', 'Connect your file picker to this action to choose files for upload.'))))))
            .child(section('Background')
                .description('A semantic background can blend an empty state into its surrounding surface.')
                .child(Empty.component()
                    .minH64()
                    .bg(theme.muted.opacity(0.3))
                    .header(EmptyHeader.component()
                        .media(EmptyMedia.component()
                            .withVariant(Icon)
                            .child(glaze.kit.Icon.component(IconName.Bell)))
                        .title(EmptyTitle.component().child('No notifications'))
                        .description(EmptyDescription.component().child("You're all caught up. New notifications will appear here.")))
                    .content(EmptyContent.component().child(Button.component('empty-refresh')
                        .outline()
                        .icon(glaze.kit.Icon.component(IconName.RotateCw))
                        .label('Refresh')
                        .onClick((_, window, cx) -> {
                            window.pushNotification('No new notifications', cx);
                        })))))
            .child(section('Avatar')
                .description("Default media keeps the Avatar component's own size and appearance.")
                .child(Empty.component()
                    .header(EmptyHeader.component()
                        .media(EmptyMedia.component().child(Avatar.component()
                            .name('Alex Morgan')
                            .src('https://avatars.githubusercontent.com/u/5518?v=4')))
                        .title(EmptyTitle.component().child('Alex is offline'))
                        .description(EmptyDescription.component().child("You can leave a message for Alex to read when they're back.")))
                    .content(EmptyContent.component().child(Button.component('empty-message')
                        .small()
                        .label('Leave a message…')
                        .onClick(openInfoDialog('Message Alex', 'Your message composer can open here while the empty state stays in the background.'))))))
            .child(section('Avatar group')
                .description('Compose AvatarGroup inside the same media slot; no new Empty variant is needed.')
                .child(Empty.component()
                    .header(EmptyHeader.component()
                        .media(EmptyMedia.component().child(AvatarGroup.component()
                            .child(Avatar.component().name('Alex Morgan').src('https://avatars.githubusercontent.com/u/5518?v=4'))
                            .child(Avatar.component().name('Taylor Lee').src('https://avatars.githubusercontent.com/u/28998859?v=4'))
                            .child(Avatar.component().name('Sam Chen').src('https://avatars.githubusercontent.com/u/20092316?v=4'))))
                        .title(EmptyTitle.component().child('No team members'))
                        .description(EmptyDescription.component().child('Invite your team to collaborate on this project.')))
                    .content(EmptyContent.component().child(Button.component('empty-invite')
                        .small()
                        .icon(glaze.kit.Icon.component(IconName.Plus))
                        .label('Invite members…')
                        .onClick(openInfoDialog('Invite members', 'Your invitation form can compose the existing Input and Button components here.'))))))
            .child(section('Search')
                .description('The parent owns search state. Clear the query or search for Design, Website, or Mobile to show results.')
                .vFlex()
                .gap4()
                .child(Input.component(search)
                    .prefix(glaze.kit.Icon.component(IconName.Search).size4())
                    .cleanable(true))
                .child(searchSlot))
            .child(section('Custom content')
                .description('An existing Input can live in EmptyContent, with rich supporting content beneath it.')
                .child(Empty.component()
                    .header(EmptyHeader.component()
                        .title(EmptyTitle.component().child('Looking for a project?'))
                        .description(EmptyDescription.component().child("The page you're looking for doesn't exist. Try searching for another page.")))
                    .content(EmptyContent.component()
                        .child(Input.component(pageSearch)
                            .prefix(glaze.kit.Icon.component(IconName.Search).size4())
                            .cleanable(true))
                        .child(EmptyDescription.component().child(hFlex()
                            .flexWrap()
                            .justifyCenter()
                            .gap1()
                            .child('Need help?')
                            .child(glaze.kit.link.Link.component('empty-documentation')
                                .href('https://gpui-kit.com/docs/getting-started')
                                .child('Read the documentation')))))))
            .child(section('Constrained layout')
                .description('Refine each named slot independently. Long text wraps in this compact, leading-aligned panel.')
                .child(div()
                    .wFull()
                    .maxW(rems(20.))
                    .child(Empty.component()
                        .border1()
                        .p4()
                        .itemsStart()
                        .textLeft()
                        .header(EmptyHeader.component()
                            .itemsStart()
                            .media(EmptyMedia.component()
                                .withVariant(Icon)
                                .child(glaze.kit.Icon.component(IconName.Inbox)))
                            .title(EmptyTitle.component().child('还没有共享文件'))
                            .description(EmptyDescription.component().child('将文件添加到此项目后，团队成员就能在这里查看、讨论和继续编辑。较长的说明也应该完整显示。')))
                        .content(EmptyContent.component().itemsStart().child(Button.component('empty-add-file')
                            .outline()
                            .small()
                            .label('添加文件…')
                            .onClick(openInfoDialog('添加文件', '选择要与团队共享的文件。')))))))
            .child(section('Minimal')
                .description('Media and content slots are optional.')
                .child(Empty.component().header(EmptyHeader.component()
                    .title(EmptyTitle.component().child('No recent activity'))
                    .description(EmptyDescription.component().child('New activity will appear here.')))));
    }

}
