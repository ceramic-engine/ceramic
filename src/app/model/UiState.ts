import { serialize, observe, Model } from 'utils';

class UiState extends Model {

/// Properties
    
    @observe @serialize sceneTab:number;

    @observe expandedAsset?:{name:string, constName:string, paths:Array<string>};

    @observe @serialize addingVisual:boolean;

} //Scene

export default UiState;
