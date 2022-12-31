package elements;

class EnumAbstractInfo {

    var enumFields:Array<String>;

    var enumValues:Array<Dynamic>;

    public function new(enumFields:Array<String>, enumValues:Array<Dynamic>) {
        this.enumFields = enumFields;
        this.enumValues = enumValues;
    }

    inline public function getEnumFields() {
        return enumFields;
    }

    inline public function getEnumFieldFromValue(value:Dynamic) {
        if (value == null)
            return null;
        var index = enumValues.indexOf(value);
        if (index < 0)
            return null;
        return enumFields[index];
    }

    public function createEnumValue(name:String):Dynamic {
        if (name == null)
            return null;
        var index = enumFields.indexOf(name);
        if (index < 0)
            return null;
        return enumValues[index];
    }

}
