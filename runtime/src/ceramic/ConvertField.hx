package ceramic;

import ceramic.Assets;
import ceramic.Shortcuts.*;
import ceramic.Fragment;

import haxe.DynamicAccess;

/** Interface to convert from/to basic type and field values with complex types. */
interface ConvertField<BasicType,FieldType> {

    /** Get field value from basic type. As this may require loading assets,
        A usable `Assets` instance must be provided and the result will only be
        provided asynchronously by calling `done` callback. */
    function basicToField(assets:Assets, basic:BasicType, done:FieldType->Void):Void;

    /** Get a basic type from the field value. */
    function fieldToBasic(value:FieldType):BasicType;

} //ConvertField
