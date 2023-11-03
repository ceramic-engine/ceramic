package ceramic;

/**
 * For now, just a way to identify a script module as a type, to resolve fields dynamically from scripts.
 * Might be extended later to link with "script converted to haxe compiled code"
 */
class ScriptModule {

    public var owner(default, null):Script;

    public function new(owner:Script) {

        this.owner = owner;

    }

}
