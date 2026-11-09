package testing;

import cityscape.common.Languages;
import cityscape.common.Model.ITextModel;

// New code for Cityscape (not a port): the object literals of vscode's tests
// that implement ITokenizationSupport, as a class taking functions.

/**
 * An `ITokenizationSupport` made of functions (vscode's tests use object
 * literals). `tokenize` throws unless given.
 */
class TestTokenizationSupport implements ITokenizationSupport {

    final _getInitialState:() -> IState;

    final _tokenizeEncoded:(line:String, hasEOL:Bool, state:IState) -> EncodedTokenizationResult;

    final _tokenize:Null<(line:String, hasEOL:Bool, state:IState) -> TokenizationResult>;

    public function new(getInitialState:() -> IState, tokenizeEncoded:(line:String, hasEOL:Bool, state:IState) -> EncodedTokenizationResult, ?tokenize:(line:String, hasEOL:Bool, state:IState) -> TokenizationResult) {
        _getInitialState = getInitialState;
        _tokenizeEncoded = tokenizeEncoded;
        _tokenize = tokenize;
    }

    public function getInitialState():IState {
        return _getInitialState();
    }

    public function tokenize(line:String, hasEOL:Bool, state:IState):TokenizationResult {
        if (_tokenize == null) {
            throw 'Not implemented';
        }
        return _tokenize(line, hasEOL, state);
    }

    public function tokenizeEncoded(line:String, hasEOL:Bool, state:IState):EncodedTokenizationResult {
        return _tokenizeEncoded(line, hasEOL, state);
    }

    public function createBackgroundTokenizer(textModel:ITextModel, store:IBackgroundTokenizationStore):Null<IBackgroundTokenizer> {
        return null;
    }

}
