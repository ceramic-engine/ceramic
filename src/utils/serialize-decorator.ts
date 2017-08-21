
/** A property decorator to tell if can be serialized */
export function serialize(typeParam:any):any;
export function serialize(target:any, propertyName:string):any;
export function serialize(target:any, propertyName?:string):any {

    if (propertyName != null) {
        // Retrieve type from Typescript metadata
        const type = Reflect.getMetadata('design:type', target, propertyName);

        // Set this type as serialization type
        Reflect.defineMetadata('serialize:type', type, target, propertyName);
    }
    else {
        // Additional type param
        const typeParam = target;

        // tslint:disable-next-line:no-shadowed-variable
        return function(target:any, propertyName:string):any {

            // Retrieve type from Typescript metadata
            const type = Reflect.getMetadata('design:type', target, propertyName);

            // Set type as [type, typeParam]
            Reflect.defineMetadata('serialize:type', [type, typeParam], target, propertyName);

        };
    }

} //serialize
