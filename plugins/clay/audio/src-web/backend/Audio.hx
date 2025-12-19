package backend;

import ceramic.AudioFilterWorklet;

class Audio {

    static var _processor:Dynamic = null;

    static var _mainProcessReady:Bool = false;

    static var _busFilterWorklets:Array<{ bus:Int, filterId:Int, worklet:AudioFilterWorklet }> = [];

    static var _resolveWorkletClass:(className:String)->Class<AudioFilterWorklet> = null;

    static var _buffer:js.lib.Float32Array = null;

    static var _paramNames:Array<String> = null;

    public static function init(resolveWorkletClass:(className:String)->Class<AudioFilterWorklet>):Void {

        _resolveWorkletClass = resolveWorkletClass;

        js.Syntax.code("console.log('worklet: init')");

        // 128 params hardcoded, could be better but that will do for now
        _paramNames = [];
        for (i in 0...128) {
            _paramNames.push('param' + i);
        }
        js.Syntax.code("
    class AudioBusFilterWorkletProcessor extends AudioWorkletProcessor {
        static get parameterDescriptors() {
            const descriptors = [];
            for (let p = 0; p < 128; p++) {
                descriptors.push({
                    name: 'param' + p,
                    defaultValue: 0.0,
                    minValue: -999999.0,
                    maxValue: 999999.0,
                    automationRate: 'k-rate'
                });
            }
            return descriptors;
        }
        process(inputs, outputs, parameters) {
            return backend_Audio.process(this, inputs, outputs, parameters);
        }
    }
    registerProcessor('bus-worklet', AudioBusFilterWorkletProcessor)");

    }

    static function addBusFilterWorklet(bus:Int, filterId:Int, className:String):Void {

        destroyBusFilterWorklet(bus, filterId);

        final workletClass = _resolveWorkletClass(className);
        final worklet = Type.createInstance(workletClass, []);
        _busFilterWorklets.push({
            bus: bus,
            filterId: filterId,
            worklet: worklet
        });

        _processor.port.postMessage({
            type: 'addBusFilterWorklet',
            bus: bus,
            filterId: filterId
        });

    }

    static function destroyBusFilterWorklet(bus:Int, filterId:Int):Void {

        var i = _busFilterWorklets.length - 1;
        while (i >= 0) {
            if (_busFilterWorklets[i].bus == bus && _busFilterWorklets[i].filterId == filterId) {
                _busFilterWorklets.splice(i, 1);
            }
            i--;
        }

    }

    static function bindProcessor(processor:Dynamic):Void {

        if (_processor != processor) {
            _mainProcessReady = false;
            _processor = processor;
            _processor.port.onmessage = event -> {
                switch event?.data?.type {
                    case 'addBusFilterWorklet':
                        addBusFilterWorklet(event.data.bus, event.data.filterId, event.data.workletClass);
                    case 'destroyBusFilterWorklet':
                        destroyBusFilterWorklet(event.data.bus, event.data.filterId);
                    case 'ready':
                        _mainProcessReady = true;
                    case null | _:
                }
            };
        }

        if (!_mainProcessReady) {
            processor.port.postMessage({ type: 'ready' });
        }

    }

    static function process(processor:Dynamic, inputs:Array<Array<js.lib.Float32Array>>, outputs:Array<Array<js.lib.Float32Array>>, parameters:Dynamic):Bool {
        bindProcessor(processor);

        // Sync params
        var processorParamIndex:Int = 0;
        for (i in 0..._busFilterWorklets.length) {
            final worklet = _busFilterWorklets[i].worklet;
            for (n in 0...worklet.numParams()) {
                final processorParamName = _paramNames[processorParamIndex];
                final paramArray:js.lib.Float32Array = processorParamName != null ? Reflect.field(parameters, processorParamName) : null;
                if (paramArray != null && paramArray.length > 0) {
                    // For k-rate parameters, we use the first value
                    @:privateAccess worklet.params[n] = paramArray[0];
                } else {
                    @:privateAccess worklet.params[n] = 0.0;
                }
                processorParamIndex++;
            }
        }

        final input = inputs[0];
        final channels = input.length;
        if (channels > 0) {

            final samples = input[0].length;
            final length = channels * samples;

            // Create or resize buffer if needed
            if (_buffer == null || _buffer.length != length) {
                _buffer = new js.lib.Float32Array(length);
            }

            // Copy buffer data to process it
            for (i in 0...channels) {
                _buffer.set(input[i], i * samples);
            }

            for (i in 0..._busFilterWorklets.length) {
                final worklet = _busFilterWorklets[i].worklet;
                worklet.process(
                    _buffer, samples, channels, js.Syntax.code('sampleRate'), js.Syntax.code('currentTime')
                );
            }

            // Then copy result into output
            final output = outputs[0];
            for (i in 0...channels) {
                final offset = i * samples;
                output[i].set(_buffer.subarray(offset, offset + samples));
            }

        }

        return true;

    }

}
