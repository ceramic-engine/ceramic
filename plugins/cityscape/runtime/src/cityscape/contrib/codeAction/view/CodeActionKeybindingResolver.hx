// Ported from vscode src/vs/editor/contrib/codeAction/browser/codeActionKeybindingResolver.ts
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.contrib.codeAction.view;

import cityscape.base.common.HierarchicalKind;
import cityscape.base.common.Keybindings.ResolvedKeybinding;
import cityscape.common.Languages.CodeAction;
import cityscape.contrib.codeAction.common.CodeActionTypes;
import cityscape.contrib.codeAction.view.CodeAction.CodeActionCommandIds;
import cityscape.platform.keybinding.common.ResolvedKeybindingItem;

typedef ResolveCodeActionKeybinding = {
    final kind:HierarchicalKind;
    final preferred:Bool;
    final resolvedKeybinding:ResolvedKeybinding;
}

/**
 * The keybinding to show next to a code action in the menu (Monaco's
 * `CodeActionKeybindingResolver`). It takes the function giving the
 * keybindings (Monaco's `IKeybindingService.getKeybindings`), so that tests
 * can give their own.
 */
class CodeActionKeybindingResolver {

    static final codeActionCommands:Array<String> = [
        CodeActionCommandIds.refactorCommandId,
        CodeActionCommandIds.codeActionCommandId,
        CodeActionCommandIds.sourceActionCommandId,
        CodeActionCommandIds.organizeImportsCommandId,
        CodeActionCommandIds.fixAllCommandId
    ];

    final getKeybindings:() -> Array<ResolvedKeybindingItem>;

    public function new(getKeybindings:() -> Array<ResolvedKeybindingItem>) {
        this.getKeybindings = getKeybindings;
    }

    public function getResolver():(action:CodeAction) -> Null<ResolvedKeybinding> {
        // Lazy since we may not actually ever read the value
        var allCodeActionBindings:Null<Array<ResolveCodeActionKeybinding>> = null;
        final getAll = () -> {
            if (allCodeActionBindings == null) {
                allCodeActionBindings = [];
                for (item in this.getKeybindings()) {
                    if (item.command == null || codeActionCommands.indexOf(item.command) < 0 || item.resolvedKeybinding == null) {
                        continue;
                    }
                    // Special case these commands since they come built-in with VS Code and don't use 'commandArgs'
                    var commandArgs:Any = item.commandArgs;
                    if (item.command == CodeActionCommandIds.organizeImportsCommandId) {
                        commandArgs = {kind: CodeActionKind.SourceOrganizeImports.value};
                    }
                    else if (item.command == CodeActionCommandIds.fixAllCommandId) {
                        commandArgs = {kind: CodeActionKind.SourceFixAll.value};
                    }
                    final args = CodeActionCommandArgs.fromUser(commandArgs, {
                        kind: HierarchicalKind.None,
                        apply: CodeActionAutoApply.Never
                    });
                    allCodeActionBindings.push({
                        resolvedKeybinding: item.resolvedKeybinding,
                        kind: args.kind,
                        preferred: args.preferred
                    });
                }
            }
            return allCodeActionBindings;
        };

        return action -> {
            if (action.kind != null && action.kind.length > 0) {
                final binding = this.bestKeybindingForCodeAction(action, getAll());
                return binding != null ? binding.resolvedKeybinding : null;
            }
            return null;
        };
    }

    function bestKeybindingForCodeAction(action:CodeAction, candidates:Array<ResolveCodeActionKeybinding>):Null<ResolveCodeActionKeybinding> {
        if (action.kind == null || action.kind.length == 0) {
            return null;
        }
        final kind = new HierarchicalKind(action.kind);

        final filtered = candidates
            .filter(candidate -> candidate.kind.contains(kind))
            .filter(candidate -> {
                if (candidate.preferred) {
                    // If the candidate keybinding only applies to preferred actions, the this action must also be preferred
                    return action.isPreferred == true;
                }
                return true;
            });
        // reduceRight
        var currentBest:Null<ResolveCodeActionKeybinding> = null;
        var i = filtered.length - 1;
        while (i >= 0) {
            final candidate = filtered[i];
            if (currentBest == null) {
                currentBest = candidate;
            }
            else {
                // Select the more specific binding
                currentBest = currentBest.kind.contains(candidate.kind) ? candidate : currentBest;
            }
            i--;
        }
        return currentBest;
    }

}
