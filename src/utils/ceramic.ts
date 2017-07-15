
interface Message {

    type:string;

    value?:any;

} //Message

/** Utility taking advantage of shared Ceramic component to send/receive messages. */
class CeramicProxy {

    component:any;

    send(message:Message, responseHandler?:(message:Message) => void) {

        if (this.component && this.component.ready) {
            this.component.send(message, responseHandler);
        }
        else {
            // If component is not ready, wait
            setTimeout(() => {
                this.send(message, responseHandler);
            }, 100);
        }

    } //send

}

export const ceramic = new CeramicProxy();
