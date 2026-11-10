// New code for Cityscape (not a port): the Glaze entities of the editor's
// views are released with the editor.
package cityscape.view;

/**
 * Releases the Glaze entities Cityscape creates for its views (the editor
 * view, the widget views and their kit inputs). They are created with
 * `App.newEntity`, owned by the app: dropping the reference does not
 * release them, the owner destroys them when it is disposed.
 */
class ViewEntities {

    /**
     * Destroys the model of `entity` (the app releases the entity), unless
     * it is null or already destroyed.
     */
    public static function release<T:glaze.Model>(entity:Null<glaze.Entity<T>>):Void {
        if (entity == null) {
            return;
        }
        final model:Null<glaze.Model> = (entity : T);
        if (model != null && !model.destroyed) {
            model.destroy();
        }
    }

}
