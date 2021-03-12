package ceramic;

import ceramic.Assets;
import ceramic.Shortcuts.*;
import ceramic.Fragment;

import haxe.DynamicAccess;

/** Interface to convert basic type `T` to field type `U` and vice versa. */
interface ConvertField<T,U> {

    /** Get field value from basic type. As this may require loading assets,
        A usable `Assets` instance must be provided and the result will only be
        provided asynchronously by calling `done` callback. */
    function basicToField(instance:Entity, assets:Assets, basic:T, done:U->Void):Void;

    /** Get a basic type from the field value. */
    function fieldToBasic(instance:Entity, value:U):T;

}
