
export function defaultValue(field:{ meta:any, name:string, type:string }):any {

    if (field.meta.editable[0].collection != null) {
        return null;
    }

    switch (field.type) {
        case 'ceramic.Text': return '';
        case 'ceramic.Color': return 0xFFFFFF;
        case 'ceramic.Texture': return null;
        case 'Int': return 0;
        case 'Float': return 0.0;
        case 'Bool': return false;
        case 'String': return '';
        default: return null;
    }

} //defaultValue
