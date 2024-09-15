package ceramic;

class EntityData {

    public static function removeData(entity:Entity):Void {

        var dynData = entity.component('data');
        if (dynData != null && dynData is DynamicData) {
            entity.removeComponent('data',);
        }

    }

    public static function data(entity:Entity, ?data:Any):Dynamic {

        var dynData:DynamicData = entity.component('data');
        if (dynData == null) {
            dynData = new DynamicData(data ?? {});
            entity.component('data', dynData);
        }
        else if (data != null) {
            dynData.data = data;
        }

        return dynData.data;

    }

}