package ceramic;

/**
 * Represents a script module for inter-script communication.
 * 
 * Script modules provide a type-safe way for scripts to access each other's
 * exported functions and variables. When a script calls methods or accesses
 * properties on a ScriptModule, the requests are dynamically resolved to the
 * owning script's scope.
 * 
 * This enables modular script architectures where scripts can interact without
 * direct references to each other.
 * 
 * @example
 * ```javascript
 * // In script A:
 * var health = 100;
 * function takeDamage(amount) {
 *     health -= amount;
 * }
 * 
 * // In script B:
 * var playerModule = module('player');
 * playerModule.takeDamage(10);
 * var currentHealth = playerModule.health;
 * ```
 */
class ScriptModule {

    /**
     * The script that owns this module.
     * All field access and method calls are delegated to this script.
     */
    public var owner(default, null):Script;

    /**
     * Creates a new module for the given script.
     * 
     * @param owner Script that exports this module
     */
    public function new(owner:Script) {

        this.owner = owner;

    }

}
