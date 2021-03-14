package ceramic;

class ConvertFragmentData implements ConvertField<Dynamic,FragmentData> {

    public function new() {}

    public function basicToField(instance:Entity, field:String, assets:Assets, basic:Dynamic, done:FragmentData->Void):Void {

        done(basic);

    }

    public function fieldToBasic(instance:Entity, field:String, value:FragmentData):Dynamic {

        return value;

    }

}
