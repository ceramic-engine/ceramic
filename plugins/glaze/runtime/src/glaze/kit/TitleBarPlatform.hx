// New code for the Haxe port of gpui-kit (no gpui-kit origin): the platform of one `TitleBar`,
// addition KIT-005 in docs/DEVIATIONS.md. See NOTICE.md.
package glaze.kit;

/**
 * The look and behaviour a `TitleBar` takes, see `TitleBar.platform`
 * (addition without upstream equivalent, KIT-005 in docs/DEVIATIONS.md).
 *
 * In its own module: its values are named like those of
 * `glaze.OperatingSystem`, and importing `glaze.kit.TitleBar` must not
 * bring them into scope.
 */
enum abstract TitleBarPlatform(Int) {

    /** Room for the traffic lights, no window controls. */
    var Mac;

    /** Minimize, maximize or restore, close buttons. */
    var Windows;

    /** The same buttons when the window is client decorated, a window menu on a right click. */
    var Linux;

    /** No window controls, no drag area. */
    var Web;

}
