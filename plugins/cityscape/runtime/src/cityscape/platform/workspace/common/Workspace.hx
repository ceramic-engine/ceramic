// Ported from vscode src/vs/platform/workspace/common/workspace.ts (the
// workspace, its folders and identifiers, the members the editor uses)
// Original code Copyright (c) Microsoft Corporation, licensed under MIT.
// Modified: translated from TypeScript to Haxe for Ceramic. See NOTICE.md.
package cityscape.platform.workspace.common;

import cityscape.base.common.Resources;
import cityscape.base.common.Uri;

/**
 * A folder of a workspace.
 */
typedef IWorkspaceFolder = {
    /** The associated URI for this workspace folder. */
    final uri:Uri;
    /** The name of this workspace folder. Defaults to the basename of its uri-path. */
    final name:String;
    /** The ordinal number of this workspace folder. */
    final index:Int;
}

/**
 * A workspace: its folders and, for a multi root workspace, the location
 * of its configuration file.
 */
typedef IWorkspace = {
    /** the unique identifier of the workspace. */
    final id:String;
    /** Folders in the workspace. */
    final folders:Array<IWorkspaceFolder>;
    /** the location of the workspace configuration */
    @:optional final configuration:Null<Uri>;
}

/**
 * The workspace of the editor (Monaco's `IWorkspaceContextService`, the
 * members the editor uses). The context's is
 * `Cityscape.workspaceContextService` (Monaco's standalone one by default,
 * `StandaloneWorkspaceContextService`).
 */
interface IWorkspaceContextService {

    /**
     * Provides access to the complete workspace object.
     */
    function getWorkspace():IWorkspace;

}

/**
 * A workspace identifier (Monaco's `IAnyWorkspaceIdentifier`): an empty
 * workspace (only `id`), a single folder (`uri`) or a multi root workspace
 * (`configPath`).
 */
typedef IAnyWorkspaceIdentifier = {
    final id:String;
    @:optional final uri:Null<Uri>;
    @:optional final configPath:Null<Uri>;
}

class WorkspaceUtils {

    public static inline final WORKSPACE_EXTENSION = 'code-workspace';

    public static function isSingleFolderWorkspaceIdentifier(obj:IAnyWorkspaceIdentifier):Bool {
        return obj.id != null && obj.uri != null;
    }

    public static function isWorkspaceIdentifier(obj:IAnyWorkspaceIdentifier):Bool {
        return obj.id != null && obj.configPath != null;
    }

    public static function isEmptyWorkspaceIdentifier(obj:IAnyWorkspaceIdentifier):Bool {
        return obj.id != null && obj.uri == null && obj.configPath == null;
    }

    public static function toWorkspaceIdentifier(workspace:IWorkspace):IAnyWorkspaceIdentifier {

        // Multi root
        if (workspace.configuration != null) {
            return {
                id: workspace.id,
                configPath: workspace.configuration
            };
        }

        // Single folder
        if (workspace.folders.length == 1) {
            return {
                id: workspace.id,
                uri: workspace.folders[0].uri
            };
        }

        // Empty workspace
        return {
            id: workspace.id
        };
    }

    /**
     * A workspace folder of a URI (its name is the basename of the URI, or
     * its authority).
     */
    public static function toWorkspaceFolder(resource:Uri):IWorkspaceFolder {
        return {uri: resource, index: 0, name: Resources.basenameOrAuthority(resource)};
    }

}
