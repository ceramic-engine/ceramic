require=m=>rReq(m);///////////////
(function ($global) { "use strict";
var $hxClasses = {},$estr = function() { return js_Boot.__string_rec(this,''); },$hxEnums = $hxEnums || {},$_;
function $extend(from, fields) {
	var proto = Object.create(from);
	for (var name in fields) proto[name] = fields[name];
	if( fields.toString !== Object.prototype.toString ) proto.toString = fields.toString;
	return proto;
}
var EReg = function(r,opt) {
	this.r = new RegExp(r,opt.split("u").join(""));
};
$hxClasses["EReg"] = EReg;
EReg.__name__ = true;
EReg.prototype = {
	match: function(s) {
		if(this.r.global) {
			this.r.lastIndex = 0;
		}
		this.r.m = this.r.exec(s);
		this.r.s = s;
		return this.r.m != null;
	}
	,matched: function(n) {
		if(this.r.m != null && n >= 0 && n < this.r.m.length) {
			return this.r.m[n];
		} else {
			throw haxe_Exception.thrown("EReg::matched");
		}
	}
	,split: function(s) {
		var d = "#__delim__#";
		return s.replace(this.r,d).split(d);
	}
	,__class__: EReg
};
var HxOverrides = function() { };
$hxClasses["HxOverrides"] = HxOverrides;
HxOverrides.__name__ = true;
HxOverrides.cca = function(s,index) {
	var x = s.charCodeAt(index);
	if(x != x) {
		return undefined;
	}
	return x;
};
HxOverrides.substr = function(s,pos,len) {
	if(len == null) {
		len = s.length;
	} else if(len < 0) {
		if(pos == 0) {
			len = s.length + len;
		} else {
			return "";
		}
	}
	return s.substr(pos,len);
};
HxOverrides.remove = function(a,obj) {
	var i = a.indexOf(obj);
	if(i == -1) {
		return false;
	}
	a.splice(i,1);
	return true;
};
HxOverrides.now = function() {
	return Date.now();
};
var IntIterator = function(min,max) {
	this.min = min;
	this.max = max;
};
$hxClasses["IntIterator"] = IntIterator;
IntIterator.__name__ = true;
IntIterator.prototype = {
	hasNext: function() {
		return this.min < this.max;
	}
	,next: function() {
		return this.min++;
	}
	,__class__: IntIterator
};
Math.__name__ = true;
var Reflect = function() { };
$hxClasses["Reflect"] = Reflect;
Reflect.__name__ = true;
Reflect.field = function(o,field) {
	try {
		return o[field];
	} catch( _g ) {
		return null;
	}
};
Reflect.getProperty = function(o,field) {
	var tmp;
	if(o == null) {
		return null;
	} else {
		var tmp1;
		if(o.__properties__) {
			tmp = o.__properties__["get_" + field];
			tmp1 = tmp;
		} else {
			tmp1 = false;
		}
		if(tmp1) {
			return o[tmp]();
		} else {
			return o[field];
		}
	}
};
Reflect.setProperty = function(o,field,value) {
	var tmp;
	var tmp1;
	if(o.__properties__) {
		tmp = o.__properties__["set_" + field];
		tmp1 = tmp;
	} else {
		tmp1 = false;
	}
	if(tmp1) {
		o[tmp](value);
	} else {
		o[field] = value;
	}
};
Reflect.fields = function(o) {
	var a = [];
	if(o != null) {
		var hasOwnProperty = Object.prototype.hasOwnProperty;
		for( var f in o ) {
		if(f != "__id__" && f != "hx__closures__" && hasOwnProperty.call(o,f)) {
			a.push(f);
		}
		}
	}
	return a;
};
Reflect.compare = function(a,b) {
	if(a == b) {
		return 0;
	} else if(a > b) {
		return 1;
	} else {
		return -1;
	}
};
Reflect.isObject = function(v) {
	if(v == null) {
		return false;
	}
	var t = typeof(v);
	if(!(t == "string" || t == "object" && v.__enum__ == null)) {
		if(t == "function") {
			return (v.__name__ || v.__ename__) != null;
		} else {
			return false;
		}
	} else {
		return true;
	}
};
Reflect.isEnumValue = function(v) {
	if(v != null) {
		return v.__enum__ != null;
	} else {
		return false;
	}
};
Reflect.deleteField = function(o,field) {
	if(!Object.prototype.hasOwnProperty.call(o,field)) {
		return false;
	}
	delete(o[field]);
	return true;
};
Reflect.makeVarArgs = function(f) {
	return function() {
		var a = Array.prototype.slice;
		var a1 = arguments;
		var a2 = a.call(a1);
		return f(a2);
	};
};
var Std = function() { };
$hxClasses["Std"] = Std;
Std.__name__ = true;
Std.string = function(s) {
	return js_Boot.__string_rec(s,"");
};
Std.parseInt = function(x) {
	if(x != null) {
		var _g = 0;
		var _g1 = x.length;
		while(_g < _g1) {
			var i = _g++;
			var c = x.charCodeAt(i);
			if(c <= 8 || c >= 14 && c != 32 && c != 45) {
				var nc = x.charCodeAt(i + 1);
				var v = parseInt(x,nc == 120 || nc == 88 ? 16 : 10);
				if(isNaN(v)) {
					return null;
				} else {
					return v;
				}
			}
		}
	}
	return null;
};
var StringTools = function() { };
$hxClasses["StringTools"] = StringTools;
StringTools.__name__ = true;
StringTools.startsWith = function(s,start) {
	if(s.length >= start.length) {
		return s.lastIndexOf(start,0) == 0;
	} else {
		return false;
	}
};
StringTools.endsWith = function(s,end) {
	var elen = end.length;
	var slen = s.length;
	if(slen >= elen) {
		return s.indexOf(end,slen - elen) == slen - elen;
	} else {
		return false;
	}
};
StringTools.isSpace = function(s,pos) {
	var c = HxOverrides.cca(s,pos);
	if(!(c > 8 && c < 14)) {
		return c == 32;
	} else {
		return true;
	}
};
StringTools.ltrim = function(s) {
	var l = s.length;
	var r = 0;
	while(r < l && StringTools.isSpace(s,r)) ++r;
	if(r > 0) {
		return HxOverrides.substr(s,r,l - r);
	} else {
		return s;
	}
};
StringTools.rtrim = function(s) {
	var l = s.length;
	var r = 0;
	while(r < l && StringTools.isSpace(s,l - r - 1)) ++r;
	if(r > 0) {
		return HxOverrides.substr(s,0,l - r);
	} else {
		return s;
	}
};
StringTools.trim = function(s) {
	return StringTools.ltrim(StringTools.rtrim(s));
};
StringTools.replace = function(s,sub,by) {
	return s.split(sub).join(by);
};
var Sys = function() { };
$hxClasses["Sys"] = Sys;
Sys.__name__ = true;
Sys.systemName = function() {
	var _g = process.platform;
	switch(_g) {
	case "darwin":
		return "Mac";
	case "freebsd":
		return "BSD";
	case "linux":
		return "Linux";
	case "win32":
		return "Windows";
	default:
		var other = _g;
		return other;
	}
};
var haxe_io_Output = function() { };
$hxClasses["haxe.io.Output"] = haxe_io_Output;
haxe_io_Output.__name__ = true;
var _$Sys_FileOutput = function(fd) {
	this.fd = fd;
};
$hxClasses["_Sys.FileOutput"] = _$Sys_FileOutput;
_$Sys_FileOutput.__name__ = true;
_$Sys_FileOutput.__super__ = haxe_io_Output;
_$Sys_FileOutput.prototype = $extend(haxe_io_Output.prototype,{
	writeByte: function(c) {
		js_node_Fs.writeSync(this.fd,String.fromCodePoint(c));
	}
	,writeBytes: function(s,pos,len) {
		var data = s.b;
		return js_node_Fs.writeSync(this.fd,js_node_buffer_Buffer.from(data.buffer,data.byteOffset,s.length),pos,len);
	}
	,writeString: function(s,encoding) {
		js_node_Fs.writeSync(this.fd,s);
	}
	,flush: function() {
		js_node_Fs.fsyncSync(this.fd);
	}
	,close: function() {
		js_node_Fs.closeSync(this.fd);
	}
	,__class__: _$Sys_FileOutput
});
var haxe_io_Input = function() { };
$hxClasses["haxe.io.Input"] = haxe_io_Input;
haxe_io_Input.__name__ = true;
haxe_io_Input.prototype = {
	readByte: function() {
		throw new haxe_exceptions_NotImplementedException(null,null,{ fileName : "/Users/jeremyfa/Developer/ceramic/git/haxe-binary/mac/haxe/std/haxe/io/Input.hx", lineNumber : 53, className : "haxe.io.Input", methodName : "readByte"});
	}
	,readBytes: function(s,pos,len) {
		var k = len;
		var b = s.b;
		if(pos < 0 || len < 0 || pos + len > s.length) {
			throw haxe_Exception.thrown(haxe_io_Error.OutsideBounds);
		}
		try {
			while(k > 0) {
				b[pos] = this.readByte();
				++pos;
				--k;
			}
		} catch( _g ) {
			if(!((haxe_Exception.caught(_g).unwrap()) instanceof haxe_io_Eof)) {
				throw _g;
			}
		}
		return len - k;
	}
	,readFullBytes: function(s,pos,len) {
		while(len > 0) {
			var k = this.readBytes(s,pos,len);
			if(k == 0) {
				throw haxe_Exception.thrown(haxe_io_Error.Blocked);
			}
			pos += k;
			len -= k;
		}
	}
	,readString: function(len,encoding) {
		var b = new haxe_io_Bytes(new ArrayBuffer(len));
		this.readFullBytes(b,0,len);
		return b.getString(0,len,encoding);
	}
	,__class__: haxe_io_Input
};
var _$Sys_FileInput = function(fd) {
	this.fd = fd;
};
$hxClasses["_Sys.FileInput"] = _$Sys_FileInput;
_$Sys_FileInput.__name__ = true;
_$Sys_FileInput.__super__ = haxe_io_Input;
_$Sys_FileInput.prototype = $extend(haxe_io_Input.prototype,{
	readByte: function() {
		var buf = js_node_buffer_Buffer.alloc(1);
		try {
			js_node_Fs.readSync(this.fd,buf,0,1,null);
		} catch( _g ) {
			var e = haxe_Exception.caught(_g).unwrap();
			if(e.code == "EOF") {
				throw haxe_Exception.thrown(new haxe_io_Eof());
			} else {
				throw haxe_Exception.thrown(haxe_io_Error.Custom(e));
			}
		}
		return buf[0];
	}
	,readBytes: function(s,pos,len) {
		var data = s.b;
		var buf = js_node_buffer_Buffer.from(data.buffer,data.byteOffset,s.length);
		try {
			return js_node_Fs.readSync(this.fd,buf,pos,len,null);
		} catch( _g ) {
			var e = haxe_Exception.caught(_g).unwrap();
			if(e.code == "EOF") {
				throw haxe_Exception.thrown(new haxe_io_Eof());
			} else {
				throw haxe_Exception.thrown(haxe_io_Error.Custom(e));
			}
		}
	}
	,close: function() {
		js_node_Fs.closeSync(this.fd);
	}
	,__class__: _$Sys_FileInput
});
var Type = function() { };
$hxClasses["Type"] = Type;
Type.__name__ = true;
Type.createInstance = function(cl,args) {
	var ctor = Function.prototype.bind.apply(cl,[null].concat(args));
	return new (ctor);
};
Type.enumEq = function(a,b) {
	if(a == b) {
		return true;
	}
	try {
		var e = a.__enum__;
		if(e == null || e != b.__enum__) {
			return false;
		}
		if(a._hx_index != b._hx_index) {
			return false;
		}
		var enm = $hxEnums[e];
		var params = enm.__constructs__[a._hx_index].__params__;
		var _g = 0;
		while(_g < params.length) {
			var f = params[_g];
			++_g;
			if(!Type.enumEq(a[f],b[f])) {
				return false;
			}
		}
	} catch( _g ) {
		return false;
	}
	return true;
};
Type.enumParameters = function(e) {
	var enm = $hxEnums[e.__enum__];
	var params = enm.__constructs__[e._hx_index].__params__;
	if(params != null) {
		var _g = [];
		var _g1 = 0;
		while(_g1 < params.length) {
			var p = params[_g1];
			++_g1;
			_g.push(e[p]);
		}
		return _g;
	} else {
		return [];
	}
};
var haxe_IMap = function() { };
$hxClasses["haxe.IMap"] = haxe_IMap;
haxe_IMap.__name__ = true;
haxe_IMap.__isInterface__ = true;
haxe_IMap.prototype = {
	__class__: haxe_IMap
};
var haxe_Exception = function(message,previous,native) {
	Error.call(this,message);
	this.message = message;
	this.__previousException = previous;
	this.__nativeException = native != null ? native : this;
};
$hxClasses["haxe.Exception"] = haxe_Exception;
haxe_Exception.__name__ = true;
haxe_Exception.caught = function(value) {
	if(((value) instanceof haxe_Exception)) {
		return value;
	} else if(((value) instanceof Error)) {
		return new haxe_Exception(value.message,null,value);
	} else {
		return new haxe_ValueException(value,null,value);
	}
};
haxe_Exception.thrown = function(value) {
	if(((value) instanceof haxe_Exception)) {
		return value.get_native();
	} else if(((value) instanceof Error)) {
		return value;
	} else {
		var e = new haxe_ValueException(value);
		return e;
	}
};
haxe_Exception.__super__ = Error;
haxe_Exception.prototype = $extend(Error.prototype,{
	unwrap: function() {
		return this.__nativeException;
	}
	,toString: function() {
		return this.get_message();
	}
	,get_message: function() {
		return this.message;
	}
	,get_native: function() {
		return this.__nativeException;
	}
	,__class__: haxe_Exception
	,__properties__: {get_native:"get_native",get_message:"get_message"}
});
var haxe_Log = function() { };
$hxClasses["haxe.Log"] = haxe_Log;
haxe_Log.__name__ = true;
haxe_Log.formatOutput = function(v,infos) {
	var str = Std.string(v);
	if(infos == null) {
		return str;
	}
	var pstr = infos.fileName + ":" + infos.lineNumber;
	if(infos.customParams != null) {
		var _g = 0;
		var _g1 = infos.customParams;
		while(_g < _g1.length) {
			var v = _g1[_g];
			++_g;
			str += ", " + Std.string(v);
		}
	}
	return pstr + ": " + str;
};
haxe_Log.trace = function(v,infos) {
	var str = haxe_Log.formatOutput(v,infos);
	if(typeof(console) != "undefined" && console.log != null) {
		console.log(str);
	}
};
var haxe_ValueException = function(value,previous,native) {
	haxe_Exception.call(this,String(value),previous,native);
	this.value = value;
};
$hxClasses["haxe.ValueException"] = haxe_ValueException;
haxe_ValueException.__name__ = true;
haxe_ValueException.__super__ = haxe_Exception;
haxe_ValueException.prototype = $extend(haxe_Exception.prototype,{
	unwrap: function() {
		return this.value;
	}
	,__class__: haxe_ValueException
});
var haxe_ds_BalancedTree = function() {
};
$hxClasses["haxe.ds.BalancedTree"] = haxe_ds_BalancedTree;
haxe_ds_BalancedTree.__name__ = true;
haxe_ds_BalancedTree.__interfaces__ = [haxe_IMap];
haxe_ds_BalancedTree.prototype = {
	set: function(key,value) {
		this.root = this.setLoop(key,value,this.root);
	}
	,get: function(key) {
		var node = this.root;
		while(node != null) {
			var c = this.compare(key,node.key);
			if(c == 0) {
				return node.value;
			}
			if(c < 0) {
				node = node.left;
			} else {
				node = node.right;
			}
		}
		return null;
	}
	,setLoop: function(k,v,node) {
		if(node == null) {
			return new haxe_ds_TreeNode(null,k,v,null);
		}
		var c = this.compare(k,node.key);
		if(c == 0) {
			return new haxe_ds_TreeNode(node.left,k,v,node.right,node == null ? 0 : node._height);
		} else if(c < 0) {
			var nl = this.setLoop(k,v,node.left);
			return this.balance(nl,node.key,node.value,node.right);
		} else {
			var nr = this.setLoop(k,v,node.right);
			return this.balance(node.left,node.key,node.value,nr);
		}
	}
	,balance: function(l,k,v,r) {
		var hl = l == null ? 0 : l._height;
		var hr = r == null ? 0 : r._height;
		if(hl > hr + 2) {
			var _this = l.left;
			var _this1 = l.right;
			if((_this == null ? 0 : _this._height) >= (_this1 == null ? 0 : _this1._height)) {
				return new haxe_ds_TreeNode(l.left,l.key,l.value,new haxe_ds_TreeNode(l.right,k,v,r));
			} else {
				return new haxe_ds_TreeNode(new haxe_ds_TreeNode(l.left,l.key,l.value,l.right.left),l.right.key,l.right.value,new haxe_ds_TreeNode(l.right.right,k,v,r));
			}
		} else if(hr > hl + 2) {
			var _this = r.right;
			var _this1 = r.left;
			if((_this == null ? 0 : _this._height) > (_this1 == null ? 0 : _this1._height)) {
				return new haxe_ds_TreeNode(new haxe_ds_TreeNode(l,k,v,r.left),r.key,r.value,r.right);
			} else {
				return new haxe_ds_TreeNode(new haxe_ds_TreeNode(l,k,v,r.left.left),r.left.key,r.left.value,new haxe_ds_TreeNode(r.left.right,r.key,r.value,r.right));
			}
		} else {
			return new haxe_ds_TreeNode(l,k,v,r,(hl > hr ? hl : hr) + 1);
		}
	}
	,compare: function(k1,k2) {
		return Reflect.compare(k1,k2);
	}
	,__class__: haxe_ds_BalancedTree
};
var haxe_ds_TreeNode = function(l,k,v,r,h) {
	if(h == null) {
		h = -1;
	}
	this.left = l;
	this.key = k;
	this.value = v;
	this.right = r;
	if(h == -1) {
		var tmp;
		var _this = this.left;
		var _this1 = this.right;
		if((_this == null ? 0 : _this._height) > (_this1 == null ? 0 : _this1._height)) {
			var _this = this.left;
			tmp = _this == null ? 0 : _this._height;
		} else {
			var _this = this.right;
			tmp = _this == null ? 0 : _this._height;
		}
		this._height = tmp + 1;
	} else {
		this._height = h;
	}
};
$hxClasses["haxe.ds.TreeNode"] = haxe_ds_TreeNode;
haxe_ds_TreeNode.__name__ = true;
haxe_ds_TreeNode.prototype = {
	__class__: haxe_ds_TreeNode
};
var haxe_ds_EnumValueMap = function() {
	haxe_ds_BalancedTree.call(this);
};
$hxClasses["haxe.ds.EnumValueMap"] = haxe_ds_EnumValueMap;
haxe_ds_EnumValueMap.__name__ = true;
haxe_ds_EnumValueMap.__interfaces__ = [haxe_IMap];
haxe_ds_EnumValueMap.__super__ = haxe_ds_BalancedTree;
haxe_ds_EnumValueMap.prototype = $extend(haxe_ds_BalancedTree.prototype,{
	compare: function(k1,k2) {
		var d = k1._hx_index - k2._hx_index;
		if(d != 0) {
			return d;
		}
		var p1 = Type.enumParameters(k1);
		var p2 = Type.enumParameters(k2);
		if(p1.length == 0 && p2.length == 0) {
			return 0;
		}
		return this.compareArgs(p1,p2);
	}
	,compareArgs: function(a1,a2) {
		var ld = a1.length - a2.length;
		if(ld != 0) {
			return ld;
		}
		var _g = 0;
		var _g1 = a1.length;
		while(_g < _g1) {
			var i = _g++;
			var d = this.compareArg(a1[i],a2[i]);
			if(d != 0) {
				return d;
			}
		}
		return 0;
	}
	,compareArg: function(v1,v2) {
		if(Reflect.isEnumValue(v1) && Reflect.isEnumValue(v2)) {
			return this.compare(v1,v2);
		} else if(((v1) instanceof Array) && ((v2) instanceof Array)) {
			return this.compareArgs(v1,v2);
		} else {
			return Reflect.compare(v1,v2);
		}
	}
	,__class__: haxe_ds_EnumValueMap
});
var haxe_ds_GenericCell = function(elt,next) {
	this.elt = elt;
	this.next = next;
};
$hxClasses["haxe.ds.GenericCell"] = haxe_ds_GenericCell;
haxe_ds_GenericCell.__name__ = true;
haxe_ds_GenericCell.prototype = {
	__class__: haxe_ds_GenericCell
};
var haxe_ds_GenericStack = function() {
};
$hxClasses["haxe.ds.GenericStack"] = haxe_ds_GenericStack;
haxe_ds_GenericStack.__name__ = true;
haxe_ds_GenericStack.prototype = {
	__class__: haxe_ds_GenericStack
};
var haxe_ds_IntMap = function() {
	this.h = { };
};
$hxClasses["haxe.ds.IntMap"] = haxe_ds_IntMap;
haxe_ds_IntMap.__name__ = true;
haxe_ds_IntMap.__interfaces__ = [haxe_IMap];
haxe_ds_IntMap.prototype = {
	set: function(key,value) {
		this.h[key] = value;
	}
	,get: function(key) {
		return this.h[key];
	}
	,__class__: haxe_ds_IntMap
};
var haxe_ds_ObjectMap = function() {
	this.h = { __keys__ : { }};
};
$hxClasses["haxe.ds.ObjectMap"] = haxe_ds_ObjectMap;
haxe_ds_ObjectMap.__name__ = true;
haxe_ds_ObjectMap.__interfaces__ = [haxe_IMap];
haxe_ds_ObjectMap.prototype = {
	set: function(key,value) {
		var id = key.__id__;
		if(id == null) {
			id = (key.__id__ = $global.$haxeUID++);
		}
		this.h[id] = value;
		this.h.__keys__[id] = key;
	}
	,get: function(key) {
		return this.h[key.__id__];
	}
	,__class__: haxe_ds_ObjectMap
};
var haxe_ds_StringMap = function() {
	this.h = Object.create(null);
};
$hxClasses["haxe.ds.StringMap"] = haxe_ds_StringMap;
haxe_ds_StringMap.__name__ = true;
haxe_ds_StringMap.__interfaces__ = [haxe_IMap];
haxe_ds_StringMap.prototype = {
	get: function(key) {
		return this.h[key];
	}
	,set: function(key,value) {
		this.h[key] = value;
	}
	,__class__: haxe_ds_StringMap
};
var haxe_exceptions_PosException = function(message,previous,pos) {
	haxe_Exception.call(this,message,previous);
	if(pos == null) {
		this.posInfos = { fileName : "(unknown)", lineNumber : 0, className : "(unknown)", methodName : "(unknown)"};
	} else {
		this.posInfos = pos;
	}
};
$hxClasses["haxe.exceptions.PosException"] = haxe_exceptions_PosException;
haxe_exceptions_PosException.__name__ = true;
haxe_exceptions_PosException.__super__ = haxe_Exception;
haxe_exceptions_PosException.prototype = $extend(haxe_Exception.prototype,{
	toString: function() {
		return "" + haxe_Exception.prototype.toString.call(this) + " in " + this.posInfos.className + "." + this.posInfos.methodName + " at " + this.posInfos.fileName + ":" + this.posInfos.lineNumber;
	}
	,__class__: haxe_exceptions_PosException
});
var haxe_exceptions_NotImplementedException = function(message,previous,pos) {
	if(message == null) {
		message = "Not implemented";
	}
	haxe_exceptions_PosException.call(this,message,previous,pos);
};
$hxClasses["haxe.exceptions.NotImplementedException"] = haxe_exceptions_NotImplementedException;
haxe_exceptions_NotImplementedException.__name__ = true;
haxe_exceptions_NotImplementedException.__super__ = haxe_exceptions_PosException;
haxe_exceptions_NotImplementedException.prototype = $extend(haxe_exceptions_PosException.prototype,{
	__class__: haxe_exceptions_NotImplementedException
});
var haxe_io_Bytes = function(data) {
	this.length = data.byteLength;
	this.b = new Uint8Array(data);
	this.b.bufferValue = data;
	data.hxBytes = this;
	data.bytes = this.b;
};
$hxClasses["haxe.io.Bytes"] = haxe_io_Bytes;
haxe_io_Bytes.__name__ = true;
haxe_io_Bytes.ofString = function(s,encoding) {
	if(encoding == haxe_io_Encoding.RawNative) {
		var buf = new Uint8Array(s.length << 1);
		var _g = 0;
		var _g1 = s.length;
		while(_g < _g1) {
			var i = _g++;
			var c = s.charCodeAt(i);
			buf[i << 1] = c & 255;
			buf[i << 1 | 1] = c >> 8;
		}
		return new haxe_io_Bytes(buf.buffer);
	}
	var a = [];
	var i = 0;
	while(i < s.length) {
		var c = s.charCodeAt(i++);
		if(55296 <= c && c <= 56319) {
			c = c - 55232 << 10 | s.charCodeAt(i++) & 1023;
		}
		if(c <= 127) {
			a.push(c);
		} else if(c <= 2047) {
			a.push(192 | c >> 6);
			a.push(128 | c & 63);
		} else if(c <= 65535) {
			a.push(224 | c >> 12);
			a.push(128 | c >> 6 & 63);
			a.push(128 | c & 63);
		} else {
			a.push(240 | c >> 18);
			a.push(128 | c >> 12 & 63);
			a.push(128 | c >> 6 & 63);
			a.push(128 | c & 63);
		}
	}
	return new haxe_io_Bytes(new Uint8Array(a).buffer);
};
haxe_io_Bytes.prototype = {
	getString: function(pos,len,encoding) {
		if(pos < 0 || len < 0 || pos + len > this.length) {
			throw haxe_Exception.thrown(haxe_io_Error.OutsideBounds);
		}
		if(encoding == null) {
			encoding = haxe_io_Encoding.UTF8;
		}
		var s = "";
		var b = this.b;
		var i = pos;
		var max = pos + len;
		switch(encoding._hx_index) {
		case 0:
			var debug = pos > 0;
			while(i < max) {
				var c = b[i++];
				if(c < 128) {
					if(c == 0) {
						break;
					}
					s += String.fromCodePoint(c);
				} else if(c < 224) {
					var code = (c & 63) << 6 | b[i++] & 127;
					s += String.fromCodePoint(code);
				} else if(c < 240) {
					var c2 = b[i++];
					var code1 = (c & 31) << 12 | (c2 & 127) << 6 | b[i++] & 127;
					s += String.fromCodePoint(code1);
				} else {
					var c21 = b[i++];
					var c3 = b[i++];
					var u = (c & 15) << 18 | (c21 & 127) << 12 | (c3 & 127) << 6 | b[i++] & 127;
					s += String.fromCodePoint(u);
				}
			}
			break;
		case 1:
			while(i < max) {
				var c = b[i++] | b[i++] << 8;
				s += String.fromCodePoint(c);
			}
			break;
		}
		return s;
	}
	,toString: function() {
		return this.getString(0,this.length);
	}
	,__class__: haxe_io_Bytes
};
var haxe_io_BytesBuffer = function() {
	this.pos = 0;
	this.size = 0;
};
$hxClasses["haxe.io.BytesBuffer"] = haxe_io_BytesBuffer;
haxe_io_BytesBuffer.__name__ = true;
haxe_io_BytesBuffer.prototype = {
	addByte: function(byte) {
		if(this.pos == this.size) {
			this.grow(1);
		}
		this.view.setUint8(this.pos++,byte);
	}
	,grow: function(delta) {
		var req = this.pos + delta;
		var nsize = this.size == 0 ? 16 : this.size;
		while(nsize < req) nsize = nsize * 3 >> 1;
		var nbuf = new ArrayBuffer(nsize);
		var nu8 = new Uint8Array(nbuf);
		if(this.size > 0) {
			nu8.set(this.u8);
		}
		this.size = nsize;
		this.buffer = nbuf;
		this.u8 = nu8;
		this.view = new DataView(this.buffer);
	}
	,getBytes: function() {
		if(this.size == 0) {
			return new haxe_io_Bytes(new ArrayBuffer(0));
		}
		var b = new haxe_io_Bytes(this.buffer);
		b.length = this.pos;
		return b;
	}
	,__class__: haxe_io_BytesBuffer
};
var haxe_io_BytesInput = function(b,pos,len) {
	if(pos == null) {
		pos = 0;
	}
	if(len == null) {
		len = b.length - pos;
	}
	if(pos < 0 || len < 0 || pos + len > b.length) {
		throw haxe_Exception.thrown(haxe_io_Error.OutsideBounds);
	}
	this.b = b.b;
	this.pos = pos;
	this.len = len;
	this.totlen = len;
};
$hxClasses["haxe.io.BytesInput"] = haxe_io_BytesInput;
haxe_io_BytesInput.__name__ = true;
haxe_io_BytesInput.__super__ = haxe_io_Input;
haxe_io_BytesInput.prototype = $extend(haxe_io_Input.prototype,{
	readByte: function() {
		if(this.len == 0) {
			throw haxe_Exception.thrown(new haxe_io_Eof());
		}
		this.len--;
		return this.b[this.pos++];
	}
	,readBytes: function(buf,pos,len) {
		if(pos < 0 || len < 0 || pos + len > buf.length) {
			throw haxe_Exception.thrown(haxe_io_Error.OutsideBounds);
		}
		if(this.len == 0 && len > 0) {
			throw haxe_Exception.thrown(new haxe_io_Eof());
		}
		if(this.len < len) {
			len = this.len;
		}
		var b1 = this.b;
		var b2 = buf.b;
		var _g = 0;
		var _g1 = len;
		while(_g < _g1) {
			var i = _g++;
			b2[pos + i] = b1[this.pos + i];
		}
		this.pos += len;
		this.len -= len;
		return len;
	}
	,__class__: haxe_io_BytesInput
});
var haxe_io_BytesOutput = function() {
	this.b = new haxe_io_BytesBuffer();
};
$hxClasses["haxe.io.BytesOutput"] = haxe_io_BytesOutput;
haxe_io_BytesOutput.__name__ = true;
haxe_io_BytesOutput.__super__ = haxe_io_Output;
haxe_io_BytesOutput.prototype = $extend(haxe_io_Output.prototype,{
	writeByte: function(c) {
		this.b.addByte(c);
	}
	,getBytes: function() {
		return this.b.getBytes();
	}
	,__class__: haxe_io_BytesOutput
});
var haxe_io_Encoding = $hxEnums["haxe.io.Encoding"] = { __ename__:true,__constructs__:null
	,UTF8: {_hx_name:"UTF8",_hx_index:0,__enum__:"haxe.io.Encoding",toString:$estr}
	,RawNative: {_hx_name:"RawNative",_hx_index:1,__enum__:"haxe.io.Encoding",toString:$estr}
};
haxe_io_Encoding.__constructs__ = [haxe_io_Encoding.UTF8,haxe_io_Encoding.RawNative];
var haxe_io_Eof = function() {
};
$hxClasses["haxe.io.Eof"] = haxe_io_Eof;
haxe_io_Eof.__name__ = true;
haxe_io_Eof.prototype = {
	toString: function() {
		return "Eof";
	}
	,__class__: haxe_io_Eof
};
var haxe_io_Error = $hxEnums["haxe.io.Error"] = { __ename__:true,__constructs__:null
	,Blocked: {_hx_name:"Blocked",_hx_index:0,__enum__:"haxe.io.Error",toString:$estr}
	,Overflow: {_hx_name:"Overflow",_hx_index:1,__enum__:"haxe.io.Error",toString:$estr}
	,OutsideBounds: {_hx_name:"OutsideBounds",_hx_index:2,__enum__:"haxe.io.Error",toString:$estr}
	,Custom: ($_=function(e) { return {_hx_index:3,e:e,__enum__:"haxe.io.Error",toString:$estr}; },$_._hx_name="Custom",$_.__params__ = ["e"],$_)
};
haxe_io_Error.__constructs__ = [haxe_io_Error.Blocked,haxe_io_Error.Overflow,haxe_io_Error.OutsideBounds,haxe_io_Error.Custom];
var haxe_io_Path = function(path) {
	switch(path) {
	case ".":case "..":
		this.dir = path;
		this.file = "";
		return;
	}
	var c1 = path.lastIndexOf("/");
	var c2 = path.lastIndexOf("\\");
	if(c1 < c2) {
		this.dir = HxOverrides.substr(path,0,c2);
		path = HxOverrides.substr(path,c2 + 1,null);
		this.backslash = true;
	} else if(c2 < c1) {
		this.dir = HxOverrides.substr(path,0,c1);
		path = HxOverrides.substr(path,c1 + 1,null);
	} else {
		this.dir = null;
	}
	var cp = path.lastIndexOf(".");
	if(cp != -1) {
		this.ext = HxOverrides.substr(path,cp + 1,null);
		this.file = HxOverrides.substr(path,0,cp);
	} else {
		this.ext = null;
		this.file = path;
	}
};
$hxClasses["haxe.io.Path"] = haxe_io_Path;
haxe_io_Path.__name__ = true;
haxe_io_Path.withoutExtension = function(path) {
	var s = new haxe_io_Path(path);
	s.ext = null;
	return s.toString();
};
haxe_io_Path.withoutDirectory = function(path) {
	var s = new haxe_io_Path(path);
	s.dir = null;
	return s.toString();
};
haxe_io_Path.directory = function(path) {
	var s = new haxe_io_Path(path);
	if(s.dir == null) {
		return "";
	}
	return s.dir;
};
haxe_io_Path.join = function(paths) {
	var _g = [];
	var _g1 = 0;
	var _g2 = paths;
	while(_g1 < _g2.length) {
		var v = _g2[_g1];
		++_g1;
		if(v != null && v != "") {
			_g.push(v);
		}
	}
	var paths = _g;
	if(paths.length == 0) {
		return "";
	}
	var path = paths[0];
	var _g = 1;
	var _g1 = paths.length;
	while(_g < _g1) {
		var i = _g++;
		path = haxe_io_Path.addTrailingSlash(path);
		path += paths[i];
	}
	return haxe_io_Path.normalize(path);
};
haxe_io_Path.normalize = function(path) {
	var slash = "/";
	path = path.split("\\").join(slash);
	if(path == slash) {
		return slash;
	}
	var target = [];
	var _g = 0;
	var _g1 = path.split(slash);
	while(_g < _g1.length) {
		var token = _g1[_g];
		++_g;
		if(token == ".." && target.length > 0 && target[target.length - 1] != "..") {
			target.pop();
		} else if(token == "") {
			if(target.length > 0 || HxOverrides.cca(path,0) == 47) {
				target.push(token);
			}
		} else if(token != ".") {
			target.push(token);
		}
	}
	var tmp = target.join(slash);
	var acc_b = "";
	var colon = false;
	var slashes = false;
	var _g2_offset = 0;
	var _g2_s = tmp;
	while(_g2_offset < _g2_s.length) {
		var s = _g2_s;
		var index = _g2_offset++;
		var c = s.charCodeAt(index);
		if(c >= 55296 && c <= 56319) {
			c = c - 55232 << 10 | s.charCodeAt(index + 1) & 1023;
		}
		var c1 = c;
		if(c1 >= 65536) {
			++_g2_offset;
		}
		var c2 = c1;
		switch(c2) {
		case 47:
			if(!colon) {
				slashes = true;
			} else {
				var i = c2;
				colon = false;
				if(slashes) {
					acc_b += "/";
					slashes = false;
				}
				acc_b += String.fromCodePoint(i);
			}
			break;
		case 58:
			acc_b += ":";
			colon = true;
			break;
		default:
			var i1 = c2;
			colon = false;
			if(slashes) {
				acc_b += "/";
				slashes = false;
			}
			acc_b += String.fromCodePoint(i1);
		}
	}
	return acc_b;
};
haxe_io_Path.addTrailingSlash = function(path) {
	if(path.length == 0) {
		return "/";
	}
	var c1 = path.lastIndexOf("/");
	var c2 = path.lastIndexOf("\\");
	if(c1 < c2) {
		if(c2 != path.length - 1) {
			return path + "\\";
		} else {
			return path;
		}
	} else if(c1 != path.length - 1) {
		return path + "/";
	} else {
		return path;
	}
};
haxe_io_Path.isAbsolute = function(path) {
	if(StringTools.startsWith(path,"/")) {
		return true;
	}
	if(path.charAt(1) == ":") {
		return true;
	}
	if(StringTools.startsWith(path,"\\\\")) {
		return true;
	}
	return false;
};
haxe_io_Path.prototype = {
	toString: function() {
		return (this.dir == null ? "" : this.dir + (this.backslash ? "\\" : "/")) + this.file + (this.ext == null ? "" : "." + this.ext);
	}
	,__class__: haxe_io_Path
};
var haxe_io_StringInput = function(s) {
	haxe_io_BytesInput.call(this,haxe_io_Bytes.ofString(s));
};
$hxClasses["haxe.io.StringInput"] = haxe_io_StringInput;
haxe_io_StringInput.__name__ = true;
haxe_io_StringInput.__super__ = haxe_io_BytesInput;
haxe_io_StringInput.prototype = $extend(haxe_io_BytesInput.prototype,{
	__class__: haxe_io_StringInput
});
var haxe_iterators_ArrayIterator = function(array) {
	this.current = 0;
	this.array = array;
};
$hxClasses["haxe.iterators.ArrayIterator"] = haxe_iterators_ArrayIterator;
haxe_iterators_ArrayIterator.__name__ = true;
haxe_iterators_ArrayIterator.prototype = {
	hasNext: function() {
		return this.current < this.array.length;
	}
	,next: function() {
		return this.array[this.current++];
	}
	,__class__: haxe_iterators_ArrayIterator
};
var hscript_Const = $hxEnums["hscript.Const"] = { __ename__:true,__constructs__:null
	,CInt: ($_=function(v) { return {_hx_index:0,v:v,__enum__:"hscript.Const",toString:$estr}; },$_._hx_name="CInt",$_.__params__ = ["v"],$_)
	,CFloat: ($_=function(f) { return {_hx_index:1,f:f,__enum__:"hscript.Const",toString:$estr}; },$_._hx_name="CFloat",$_.__params__ = ["f"],$_)
	,CString: ($_=function(s) { return {_hx_index:2,s:s,__enum__:"hscript.Const",toString:$estr}; },$_._hx_name="CString",$_.__params__ = ["s"],$_)
};
hscript_Const.__constructs__ = [hscript_Const.CInt,hscript_Const.CFloat,hscript_Const.CString];
var hscript_Expr = $hxEnums["hscript.Expr"] = { __ename__:true,__constructs__:null
	,EConst: ($_=function(c) { return {_hx_index:0,c:c,__enum__:"hscript.Expr",toString:$estr}; },$_._hx_name="EConst",$_.__params__ = ["c"],$_)
	,EIdent: ($_=function(v) { return {_hx_index:1,v:v,__enum__:"hscript.Expr",toString:$estr}; },$_._hx_name="EIdent",$_.__params__ = ["v"],$_)
	,EVar: ($_=function(n,t,e) { return {_hx_index:2,n:n,t:t,e:e,__enum__:"hscript.Expr",toString:$estr}; },$_._hx_name="EVar",$_.__params__ = ["n","t","e"],$_)
	,EParent: ($_=function(e) { return {_hx_index:3,e:e,__enum__:"hscript.Expr",toString:$estr}; },$_._hx_name="EParent",$_.__params__ = ["e"],$_)
	,EBlock: ($_=function(e) { return {_hx_index:4,e:e,__enum__:"hscript.Expr",toString:$estr}; },$_._hx_name="EBlock",$_.__params__ = ["e"],$_)
	,EField: ($_=function(e,f) { return {_hx_index:5,e:e,f:f,__enum__:"hscript.Expr",toString:$estr}; },$_._hx_name="EField",$_.__params__ = ["e","f"],$_)
	,EBinop: ($_=function(op,e1,e2) { return {_hx_index:6,op:op,e1:e1,e2:e2,__enum__:"hscript.Expr",toString:$estr}; },$_._hx_name="EBinop",$_.__params__ = ["op","e1","e2"],$_)
	,EUnop: ($_=function(op,prefix,e) { return {_hx_index:7,op:op,prefix:prefix,e:e,__enum__:"hscript.Expr",toString:$estr}; },$_._hx_name="EUnop",$_.__params__ = ["op","prefix","e"],$_)
	,ECall: ($_=function(e,params) { return {_hx_index:8,e:e,params:params,__enum__:"hscript.Expr",toString:$estr}; },$_._hx_name="ECall",$_.__params__ = ["e","params"],$_)
	,EIf: ($_=function(cond,e1,e2) { return {_hx_index:9,cond:cond,e1:e1,e2:e2,__enum__:"hscript.Expr",toString:$estr}; },$_._hx_name="EIf",$_.__params__ = ["cond","e1","e2"],$_)
	,EWhile: ($_=function(cond,e) { return {_hx_index:10,cond:cond,e:e,__enum__:"hscript.Expr",toString:$estr}; },$_._hx_name="EWhile",$_.__params__ = ["cond","e"],$_)
	,EFor: ($_=function(v,it,e) { return {_hx_index:11,v:v,it:it,e:e,__enum__:"hscript.Expr",toString:$estr}; },$_._hx_name="EFor",$_.__params__ = ["v","it","e"],$_)
	,EBreak: {_hx_name:"EBreak",_hx_index:12,__enum__:"hscript.Expr",toString:$estr}
	,EContinue: {_hx_name:"EContinue",_hx_index:13,__enum__:"hscript.Expr",toString:$estr}
	,EFunction: ($_=function(args,e,name,ret) { return {_hx_index:14,args:args,e:e,name:name,ret:ret,__enum__:"hscript.Expr",toString:$estr}; },$_._hx_name="EFunction",$_.__params__ = ["args","e","name","ret"],$_)
	,EReturn: ($_=function(e) { return {_hx_index:15,e:e,__enum__:"hscript.Expr",toString:$estr}; },$_._hx_name="EReturn",$_.__params__ = ["e"],$_)
	,EArray: ($_=function(e,index) { return {_hx_index:16,e:e,index:index,__enum__:"hscript.Expr",toString:$estr}; },$_._hx_name="EArray",$_.__params__ = ["e","index"],$_)
	,EArrayDecl: ($_=function(e) { return {_hx_index:17,e:e,__enum__:"hscript.Expr",toString:$estr}; },$_._hx_name="EArrayDecl",$_.__params__ = ["e"],$_)
	,ENew: ($_=function(cl,params) { return {_hx_index:18,cl:cl,params:params,__enum__:"hscript.Expr",toString:$estr}; },$_._hx_name="ENew",$_.__params__ = ["cl","params"],$_)
	,EThrow: ($_=function(e) { return {_hx_index:19,e:e,__enum__:"hscript.Expr",toString:$estr}; },$_._hx_name="EThrow",$_.__params__ = ["e"],$_)
	,ETry: ($_=function(e,v,t,ecatch) { return {_hx_index:20,e:e,v:v,t:t,ecatch:ecatch,__enum__:"hscript.Expr",toString:$estr}; },$_._hx_name="ETry",$_.__params__ = ["e","v","t","ecatch"],$_)
	,EObject: ($_=function(fl) { return {_hx_index:21,fl:fl,__enum__:"hscript.Expr",toString:$estr}; },$_._hx_name="EObject",$_.__params__ = ["fl"],$_)
	,ETernary: ($_=function(cond,e1,e2) { return {_hx_index:22,cond:cond,e1:e1,e2:e2,__enum__:"hscript.Expr",toString:$estr}; },$_._hx_name="ETernary",$_.__params__ = ["cond","e1","e2"],$_)
	,ESwitch: ($_=function(e,cases,defaultExpr) { return {_hx_index:23,e:e,cases:cases,defaultExpr:defaultExpr,__enum__:"hscript.Expr",toString:$estr}; },$_._hx_name="ESwitch",$_.__params__ = ["e","cases","defaultExpr"],$_)
	,EDoWhile: ($_=function(cond,e) { return {_hx_index:24,cond:cond,e:e,__enum__:"hscript.Expr",toString:$estr}; },$_._hx_name="EDoWhile",$_.__params__ = ["cond","e"],$_)
	,EMeta: ($_=function(name,args,e) { return {_hx_index:25,name:name,args:args,e:e,__enum__:"hscript.Expr",toString:$estr}; },$_._hx_name="EMeta",$_.__params__ = ["name","args","e"],$_)
	,ECheckType: ($_=function(e,t) { return {_hx_index:26,e:e,t:t,__enum__:"hscript.Expr",toString:$estr}; },$_._hx_name="ECheckType",$_.__params__ = ["e","t"],$_)
};
hscript_Expr.__constructs__ = [hscript_Expr.EConst,hscript_Expr.EIdent,hscript_Expr.EVar,hscript_Expr.EParent,hscript_Expr.EBlock,hscript_Expr.EField,hscript_Expr.EBinop,hscript_Expr.EUnop,hscript_Expr.ECall,hscript_Expr.EIf,hscript_Expr.EWhile,hscript_Expr.EFor,hscript_Expr.EBreak,hscript_Expr.EContinue,hscript_Expr.EFunction,hscript_Expr.EReturn,hscript_Expr.EArray,hscript_Expr.EArrayDecl,hscript_Expr.ENew,hscript_Expr.EThrow,hscript_Expr.ETry,hscript_Expr.EObject,hscript_Expr.ETernary,hscript_Expr.ESwitch,hscript_Expr.EDoWhile,hscript_Expr.EMeta,hscript_Expr.ECheckType];
var hscript_CType = $hxEnums["hscript.CType"] = { __ename__:true,__constructs__:null
	,CTPath: ($_=function(path,params) { return {_hx_index:0,path:path,params:params,__enum__:"hscript.CType",toString:$estr}; },$_._hx_name="CTPath",$_.__params__ = ["path","params"],$_)
	,CTFun: ($_=function(args,ret) { return {_hx_index:1,args:args,ret:ret,__enum__:"hscript.CType",toString:$estr}; },$_._hx_name="CTFun",$_.__params__ = ["args","ret"],$_)
	,CTAnon: ($_=function(fields) { return {_hx_index:2,fields:fields,__enum__:"hscript.CType",toString:$estr}; },$_._hx_name="CTAnon",$_.__params__ = ["fields"],$_)
	,CTParent: ($_=function(t) { return {_hx_index:3,t:t,__enum__:"hscript.CType",toString:$estr}; },$_._hx_name="CTParent",$_.__params__ = ["t"],$_)
	,CTOpt: ($_=function(t) { return {_hx_index:4,t:t,__enum__:"hscript.CType",toString:$estr}; },$_._hx_name="CTOpt",$_.__params__ = ["t"],$_)
	,CTNamed: ($_=function(n,t) { return {_hx_index:5,n:n,t:t,__enum__:"hscript.CType",toString:$estr}; },$_._hx_name="CTNamed",$_.__params__ = ["n","t"],$_)
};
hscript_CType.__constructs__ = [hscript_CType.CTPath,hscript_CType.CTFun,hscript_CType.CTAnon,hscript_CType.CTParent,hscript_CType.CTOpt,hscript_CType.CTNamed];
var hscript_Error = $hxEnums["hscript.Error"] = { __ename__:true,__constructs__:null
	,EInvalidChar: ($_=function(c) { return {_hx_index:0,c:c,__enum__:"hscript.Error",toString:$estr}; },$_._hx_name="EInvalidChar",$_.__params__ = ["c"],$_)
	,EUnexpected: ($_=function(s) { return {_hx_index:1,s:s,__enum__:"hscript.Error",toString:$estr}; },$_._hx_name="EUnexpected",$_.__params__ = ["s"],$_)
	,EUnterminatedString: {_hx_name:"EUnterminatedString",_hx_index:2,__enum__:"hscript.Error",toString:$estr}
	,EUnterminatedComment: {_hx_name:"EUnterminatedComment",_hx_index:3,__enum__:"hscript.Error",toString:$estr}
	,EInvalidPreprocessor: ($_=function(msg) { return {_hx_index:4,msg:msg,__enum__:"hscript.Error",toString:$estr}; },$_._hx_name="EInvalidPreprocessor",$_.__params__ = ["msg"],$_)
	,EUnknownVariable: ($_=function(v) { return {_hx_index:5,v:v,__enum__:"hscript.Error",toString:$estr}; },$_._hx_name="EUnknownVariable",$_.__params__ = ["v"],$_)
	,EInvalidIterator: ($_=function(v) { return {_hx_index:6,v:v,__enum__:"hscript.Error",toString:$estr}; },$_._hx_name="EInvalidIterator",$_.__params__ = ["v"],$_)
	,EInvalidOp: ($_=function(op) { return {_hx_index:7,op:op,__enum__:"hscript.Error",toString:$estr}; },$_._hx_name="EInvalidOp",$_.__params__ = ["op"],$_)
	,EInvalidAccess: ($_=function(f) { return {_hx_index:8,f:f,__enum__:"hscript.Error",toString:$estr}; },$_._hx_name="EInvalidAccess",$_.__params__ = ["f"],$_)
	,ECustom: ($_=function(msg) { return {_hx_index:9,msg:msg,__enum__:"hscript.Error",toString:$estr}; },$_._hx_name="ECustom",$_.__params__ = ["msg"],$_)
};
hscript_Error.__constructs__ = [hscript_Error.EInvalidChar,hscript_Error.EUnexpected,hscript_Error.EUnterminatedString,hscript_Error.EUnterminatedComment,hscript_Error.EInvalidPreprocessor,hscript_Error.EUnknownVariable,hscript_Error.EInvalidIterator,hscript_Error.EInvalidOp,hscript_Error.EInvalidAccess,hscript_Error.ECustom];
var hscript_ModuleDecl = $hxEnums["hscript.ModuleDecl"] = { __ename__:true,__constructs__:null
	,DPackage: ($_=function(path) { return {_hx_index:0,path:path,__enum__:"hscript.ModuleDecl",toString:$estr}; },$_._hx_name="DPackage",$_.__params__ = ["path"],$_)
	,DImport: ($_=function(path,everything) { return {_hx_index:1,path:path,everything:everything,__enum__:"hscript.ModuleDecl",toString:$estr}; },$_._hx_name="DImport",$_.__params__ = ["path","everything"],$_)
	,DClass: ($_=function(c) { return {_hx_index:2,c:c,__enum__:"hscript.ModuleDecl",toString:$estr}; },$_._hx_name="DClass",$_.__params__ = ["c"],$_)
	,DTypedef: ($_=function(c) { return {_hx_index:3,c:c,__enum__:"hscript.ModuleDecl",toString:$estr}; },$_._hx_name="DTypedef",$_.__params__ = ["c"],$_)
};
hscript_ModuleDecl.__constructs__ = [hscript_ModuleDecl.DPackage,hscript_ModuleDecl.DImport,hscript_ModuleDecl.DClass,hscript_ModuleDecl.DTypedef];
var hscript_FieldAccess = $hxEnums["hscript.FieldAccess"] = { __ename__:true,__constructs__:null
	,APublic: {_hx_name:"APublic",_hx_index:0,__enum__:"hscript.FieldAccess",toString:$estr}
	,APrivate: {_hx_name:"APrivate",_hx_index:1,__enum__:"hscript.FieldAccess",toString:$estr}
	,AInline: {_hx_name:"AInline",_hx_index:2,__enum__:"hscript.FieldAccess",toString:$estr}
	,AOverride: {_hx_name:"AOverride",_hx_index:3,__enum__:"hscript.FieldAccess",toString:$estr}
	,AStatic: {_hx_name:"AStatic",_hx_index:4,__enum__:"hscript.FieldAccess",toString:$estr}
	,AMacro: {_hx_name:"AMacro",_hx_index:5,__enum__:"hscript.FieldAccess",toString:$estr}
};
hscript_FieldAccess.__constructs__ = [hscript_FieldAccess.APublic,hscript_FieldAccess.APrivate,hscript_FieldAccess.AInline,hscript_FieldAccess.AOverride,hscript_FieldAccess.AStatic,hscript_FieldAccess.AMacro];
var hscript_FieldKind = $hxEnums["hscript.FieldKind"] = { __ename__:true,__constructs__:null
	,KFunction: ($_=function(f) { return {_hx_index:0,f:f,__enum__:"hscript.FieldKind",toString:$estr}; },$_._hx_name="KFunction",$_.__params__ = ["f"],$_)
	,KVar: ($_=function(v) { return {_hx_index:1,v:v,__enum__:"hscript.FieldKind",toString:$estr}; },$_._hx_name="KVar",$_.__params__ = ["v"],$_)
};
hscript_FieldKind.__constructs__ = [hscript_FieldKind.KFunction,hscript_FieldKind.KVar];
var hscript__$Interp_Stop = $hxEnums["hscript._Interp.Stop"] = { __ename__:true,__constructs__:null
	,SBreak: {_hx_name:"SBreak",_hx_index:0,__enum__:"hscript._Interp.Stop",toString:$estr}
	,SContinue: {_hx_name:"SContinue",_hx_index:1,__enum__:"hscript._Interp.Stop",toString:$estr}
	,SReturn: {_hx_name:"SReturn",_hx_index:2,__enum__:"hscript._Interp.Stop",toString:$estr}
};
hscript__$Interp_Stop.__constructs__ = [hscript__$Interp_Stop.SBreak,hscript__$Interp_Stop.SContinue,hscript__$Interp_Stop.SReturn];
var hscript_Interp = function() {
	var _gthis = this;
	this.variables = new haxe_ds_StringMap();
	this.locals = new haxe_ds_StringMap();
	this.declared = [];
	this.variables.h["null"] = null;
	this.variables.h["true"] = true;
	this.variables.h["false"] = false;
	var this1 = this.variables;
	var value = Reflect.makeVarArgs(function(el) {
		var inf = _gthis.posInfos();
		var v = el.shift();
		if(el.length > 0) {
			inf.customParams = el;
		}
		haxe_Log.trace(Std.string(v),inf);
	});
	this1.h["trace"] = value;
	this.initOps();
};
$hxClasses["hscript.Interp"] = hscript_Interp;
hscript_Interp.__name__ = true;
hscript_Interp.prototype = {
	posInfos: function() {
		return { fileName : "hscript", lineNumber : 0};
	}
	,initOps: function() {
		var me = this;
		this.binops = new haxe_ds_StringMap();
		this.binops.h["+"] = function(e1,e2) {
			return me.expr(e1) + me.expr(e2);
		};
		this.binops.h["-"] = function(e1,e2) {
			return me.expr(e1) - me.expr(e2);
		};
		this.binops.h["*"] = function(e1,e2) {
			return me.expr(e1) * me.expr(e2);
		};
		this.binops.h["/"] = function(e1,e2) {
			return me.expr(e1) / me.expr(e2);
		};
		this.binops.h["%"] = function(e1,e2) {
			return me.expr(e1) % me.expr(e2);
		};
		this.binops.h["&"] = function(e1,e2) {
			return me.expr(e1) & me.expr(e2);
		};
		this.binops.h["|"] = function(e1,e2) {
			return me.expr(e1) | me.expr(e2);
		};
		this.binops.h["^"] = function(e1,e2) {
			return me.expr(e1) ^ me.expr(e2);
		};
		this.binops.h["<<"] = function(e1,e2) {
			return me.expr(e1) << me.expr(e2);
		};
		this.binops.h[">>"] = function(e1,e2) {
			return me.expr(e1) >> me.expr(e2);
		};
		this.binops.h[">>>"] = function(e1,e2) {
			return me.expr(e1) >>> me.expr(e2);
		};
		this.binops.h["=="] = function(e1,e2) {
			return me.expr(e1) == me.expr(e2);
		};
		this.binops.h["!="] = function(e1,e2) {
			return me.expr(e1) != me.expr(e2);
		};
		this.binops.h[">="] = function(e1,e2) {
			return me.expr(e1) >= me.expr(e2);
		};
		this.binops.h["<="] = function(e1,e2) {
			return me.expr(e1) <= me.expr(e2);
		};
		this.binops.h[">"] = function(e1,e2) {
			return me.expr(e1) > me.expr(e2);
		};
		this.binops.h["<"] = function(e1,e2) {
			return me.expr(e1) < me.expr(e2);
		};
		this.binops.h["||"] = function(e1,e2) {
			if(me.expr(e1) != true) {
				return me.expr(e2) == true;
			} else {
				return true;
			}
		};
		this.binops.h["&&"] = function(e1,e2) {
			if(me.expr(e1) == true) {
				return me.expr(e2) == true;
			} else {
				return false;
			}
		};
		this.binops.h["="] = $bind(this,this.assign);
		this.binops.h["..."] = function(e1,e2) {
			return new IntIterator(me.expr(e1),me.expr(e2));
		};
		this.assignOp("+=",function(v1,v2) {
			return v1 + v2;
		});
		this.assignOp("-=",function(v1,v2) {
			return v1 - v2;
		});
		this.assignOp("*=",function(v1,v2) {
			return v1 * v2;
		});
		this.assignOp("/=",function(v1,v2) {
			return v1 / v2;
		});
		this.assignOp("%=",function(v1,v2) {
			return v1 % v2;
		});
		this.assignOp("&=",function(v1,v2) {
			return v1 & v2;
		});
		this.assignOp("|=",function(v1,v2) {
			return v1 | v2;
		});
		this.assignOp("^=",function(v1,v2) {
			return v1 ^ v2;
		});
		this.assignOp("<<=",function(v1,v2) {
			return v1 << v2;
		});
		this.assignOp(">>=",function(v1,v2) {
			return v1 >> v2;
		});
		this.assignOp(">>>=",function(v1,v2) {
			return v1 >>> v2;
		});
	}
	,assign: function(e1,e2) {
		var v = this.expr(e2);
		switch(e1._hx_index) {
		case 1:
			var id = e1.v;
			var l = this.locals.h[id];
			if(l == null) {
				this.variables.h[id] = v;
			} else {
				l.r = v;
			}
			break;
		case 5:
			var e = e1.e;
			var f = e1.f;
			v = this.set(this.expr(e),f,v);
			break;
		case 16:
			var e = e1.e;
			var index = e1.index;
			var arr = this.expr(e);
			var index1 = this.expr(index);
			if(js_Boot.__implements(arr,haxe_IMap)) {
				(js_Boot.__cast(arr , haxe_IMap)).set(index1,v);
			} else {
				arr[index1] = v;
			}
			break;
		default:
			var e = hscript_Error.EInvalidOp("=");
			throw haxe_Exception.thrown(e);
		}
		return v;
	}
	,assignOp: function(op,fop) {
		var me = this;
		this.binops.h[op] = function(e1,e2) {
			return me.evalAssignOp(op,fop,e1,e2);
		};
	}
	,evalAssignOp: function(op,fop,e1,e2) {
		var v;
		switch(e1._hx_index) {
		case 1:
			var id = e1.v;
			var l = this.locals.h[id];
			v = fop(this.expr(e1),this.expr(e2));
			if(l == null) {
				this.variables.h[id] = v;
			} else {
				l.r = v;
			}
			break;
		case 5:
			var e = e1.e;
			var f = e1.f;
			var obj = this.expr(e);
			v = fop(this.get(obj,f),this.expr(e2));
			v = this.set(obj,f,v);
			break;
		case 16:
			var e = e1.e;
			var index = e1.index;
			var arr = this.expr(e);
			var index1 = this.expr(index);
			if(js_Boot.__implements(arr,haxe_IMap)) {
				v = fop((js_Boot.__cast(arr , haxe_IMap)).get(index1),this.expr(e2));
				(js_Boot.__cast(arr , haxe_IMap)).set(index1,v);
			} else {
				v = fop(arr[index1],this.expr(e2));
				arr[index1] = v;
			}
			break;
		default:
			var e = hscript_Error.EInvalidOp(op);
			throw haxe_Exception.thrown(e);
		}
		return v;
	}
	,increment: function(e,prefix,delta) {
		switch(e._hx_index) {
		case 1:
			var id = e.v;
			var l = this.locals.h[id];
			var v = l == null ? this.variables.h[id] : l.r;
			if(prefix) {
				v += delta;
				if(l == null) {
					this.variables.h[id] = v;
				} else {
					l.r = v;
				}
			} else if(l == null) {
				this.variables.h[id] = v + delta;
			} else {
				l.r = v + delta;
			}
			return v;
		case 5:
			var e1 = e.e;
			var f = e.f;
			var obj = this.expr(e1);
			var v = this.get(obj,f);
			if(prefix) {
				v += delta;
				this.set(obj,f,v);
			} else {
				this.set(obj,f,v + delta);
			}
			return v;
		case 16:
			var e1 = e.e;
			var index = e.index;
			var arr = this.expr(e1);
			var index1 = this.expr(index);
			if(js_Boot.__implements(arr,haxe_IMap)) {
				var v = (js_Boot.__cast(arr , haxe_IMap)).get(index1);
				if(prefix) {
					v += delta;
					(js_Boot.__cast(arr , haxe_IMap)).set(index1,v);
				} else {
					(js_Boot.__cast(arr , haxe_IMap)).set(index1,v + delta);
				}
				return v;
			} else {
				var v = arr[index1];
				if(prefix) {
					v += delta;
					arr[index1] = v;
				} else {
					arr[index1] = v + delta;
				}
				return v;
			}
			break;
		default:
			var e = hscript_Error.EInvalidOp(delta > 0 ? "++" : "--");
			throw haxe_Exception.thrown(e);
		}
	}
	,execute: function(expr) {
		this.depth = 0;
		this.locals = new haxe_ds_StringMap();
		this.declared = [];
		return this.exprReturn(expr);
	}
	,exprReturn: function(e) {
		try {
			return this.expr(e);
		} catch( _g ) {
			var _g1 = haxe_Exception.caught(_g).unwrap();
			if(js_Boot.__instanceof(_g1,hscript__$Interp_Stop)) {
				var e = _g1;
				switch(e._hx_index) {
				case 0:
					throw haxe_Exception.thrown("Invalid break");
				case 1:
					throw haxe_Exception.thrown("Invalid continue");
				case 2:
					var v = this.returnValue;
					this.returnValue = null;
					return v;
				}
			} else {
				throw _g;
			}
		}
	}
	,duplicate: function(h) {
		var h2 = new haxe_ds_StringMap();
		var h1 = h.h;
		var k_h = h1;
		var k_keys = Object.keys(h1);
		var k_length = k_keys.length;
		var k_current = 0;
		while(k_current < k_length) {
			var k = k_keys[k_current++];
			h2.h[k] = h.h[k];
		}
		return h2;
	}
	,restore: function(old) {
		while(this.declared.length > old) {
			var d = this.declared.pop();
			this.locals.h[d.n] = d.old;
		}
	}
	,error: function(e,rethrow) {
		if(rethrow == null) {
			rethrow = false;
		}
		if(rethrow) {
			throw haxe_Exception.thrown(e);
		} else {
			throw haxe_Exception.thrown(e);
		}
	}
	,rethrow: function(e) {
		throw haxe_Exception.thrown(e);
	}
	,resolve: function(id) {
		var l = this.locals.h[id];
		if(l != null) {
			return l.r;
		}
		var v = this.variables.h[id];
		if(v == null && !Object.prototype.hasOwnProperty.call(this.variables.h,id)) {
			var e = hscript_Error.EUnknownVariable(id);
			throw haxe_Exception.thrown(e);
		}
		return v;
	}
	,expr: function(e) {
		var _gthis = this;
		switch(e._hx_index) {
		case 0:
			var c = e.c;
			switch(c._hx_index) {
			case 0:
				var v = c.v;
				return v;
			case 1:
				var f = c.f;
				return f;
			case 2:
				var s = c.s;
				return s;
			}
			break;
		case 1:
			var id = e.v;
			return this.resolve(id);
		case 2:
			var _g = e.t;
			var n = e.n;
			var e1 = e.e;
			this.declared.push({ n : n, old : this.locals.h[n]});
			var this1 = this.locals;
			var value = e1 == null ? null : this.expr(e1);
			this1.h[n] = { r : value};
			return null;
		case 3:
			var e1 = e.e;
			return this.expr(e1);
		case 4:
			var exprs = e.e;
			var old = this.declared.length;
			var v = null;
			var _g = 0;
			while(_g < exprs.length) {
				var e1 = exprs[_g];
				++_g;
				v = this.expr(e1);
			}
			this.restore(old);
			return v;
		case 5:
			var e1 = e.e;
			var f = e.f;
			return this.get(this.expr(e1),f);
		case 6:
			var op = e.op;
			var e1 = e.e1;
			var e2 = e.e2;
			var fop = this.binops.h[op];
			if(fop == null) {
				var e3 = hscript_Error.EInvalidOp(op);
				throw haxe_Exception.thrown(e3);
			}
			return fop(e1,e2);
		case 7:
			var op = e.op;
			var prefix = e.prefix;
			var e1 = e.e;
			switch(op) {
			case "!":
				return this.expr(e1) != true;
			case "++":
				return this.increment(e1,prefix,1);
			case "-":
				return -this.expr(e1);
			case "--":
				return this.increment(e1,prefix,-1);
			case "~":
				return ~this.expr(e1);
			default:
				var e1 = hscript_Error.EInvalidOp(op);
				throw haxe_Exception.thrown(e1);
			}
			break;
		case 8:
			var e1 = e.e;
			var params = e.params;
			var args = [];
			var _g = 0;
			while(_g < params.length) {
				var p = params[_g];
				++_g;
				args.push(this.expr(p));
			}
			if(e1._hx_index == 5) {
				var e2 = e1.e;
				var f = e1.f;
				var obj = this.expr(e2);
				if(obj == null) {
					var e2 = hscript_Error.EInvalidAccess(f);
					throw haxe_Exception.thrown(e2);
				}
				return this.fcall(obj,f,args);
			} else {
				return this.call(null,this.expr(e1),args);
			}
			break;
		case 9:
			var econd = e.cond;
			var e1 = e.e1;
			var e2 = e.e2;
			if(this.expr(econd) == true) {
				return this.expr(e1);
			} else if(e2 == null) {
				return null;
			} else {
				return this.expr(e2);
			}
			break;
		case 10:
			var econd = e.cond;
			var e1 = e.e;
			this.whileLoop(econd,e1);
			return null;
		case 11:
			var v = e.v;
			var it = e.it;
			var e1 = e.e;
			this.forLoop(v,it,e1);
			return null;
		case 12:
			throw haxe_Exception.thrown(hscript__$Interp_Stop.SBreak);
		case 13:
			throw haxe_Exception.thrown(hscript__$Interp_Stop.SContinue);
		case 14:
			var _g = e.ret;
			var params = e.args;
			var fexpr = e.e;
			var name = e.name;
			var capturedLocals = this.duplicate(this.locals);
			var me = this;
			var hasOpt = false;
			var minParams = 0;
			var _g = 0;
			while(_g < params.length) {
				var p = params[_g];
				++_g;
				if(p.opt) {
					hasOpt = true;
				} else {
					minParams += 1;
				}
			}
			var f = function(args) {
				if(args.length != params.length) {
					if(args.length < minParams) {
						var str = "Invalid number of parameters. Got " + args.length + ", required " + minParams;
						if(name != null) {
							str += " for function '" + name + "'";
						}
						throw haxe_Exception.thrown(str);
					}
					var args2 = [];
					var extraParams = args.length - minParams;
					var pos = 0;
					var _g = 0;
					while(_g < params.length) {
						var p = params[_g];
						++_g;
						if(p.opt) {
							if(extraParams > 0) {
								args2.push(args[pos++]);
								--extraParams;
							} else {
								args2.push(null);
							}
						} else {
							args2.push(args[pos++]);
						}
					}
					args = args2;
				}
				var old = me.locals;
				var depth = me.depth;
				me.depth++;
				me.locals = me.duplicate(capturedLocals);
				var _g = 0;
				var _g1 = params.length;
				while(_g < _g1) {
					var i = _g++;
					me.locals.h[params[i].name] = { r : args[i]};
				}
				var r = null;
				if(_gthis.inTry) {
					try {
						r = me.exprReturn(fexpr);
					} catch( _g ) {
						var e = haxe_Exception.caught(_g).unwrap();
						me.locals = old;
						me.depth = depth;
						throw haxe_Exception.thrown(e);
					}
				} else {
					r = me.exprReturn(fexpr);
				}
				me.locals = old;
				me.depth = depth;
				return r;
			};
			var f1 = Reflect.makeVarArgs(f);
			if(name != null) {
				if(this.depth == 0) {
					this.variables.h[name] = f1;
				} else {
					this.declared.push({ n : name, old : this.locals.h[name]});
					var ref = { r : f1};
					this.locals.h[name] = ref;
					capturedLocals.h[name] = ref;
				}
			}
			return f1;
		case 15:
			var e1 = e.e;
			this.returnValue = e1 == null ? null : this.expr(e1);
			throw haxe_Exception.thrown(hscript__$Interp_Stop.SReturn);
		case 16:
			var e1 = e.e;
			var index = e.index;
			var arr = this.expr(e1);
			var index1 = this.expr(index);
			if(js_Boot.__implements(arr,haxe_IMap)) {
				return (js_Boot.__cast(arr , haxe_IMap)).get(index1);
			} else {
				return arr[index1];
			}
			break;
		case 17:
			var arr = e.e;
			var tmp;
			if(arr.length > 0) {
				var _g = arr[0];
				if(_g._hx_index == 6) {
					var _g1 = _g.e1;
					var _g1 = _g.e2;
					tmp = _g.op == "=>";
				} else {
					tmp = false;
				}
			} else {
				tmp = false;
			}
			if(tmp) {
				var isAllString = true;
				var isAllInt = true;
				var isAllObject = true;
				var isAllEnum = true;
				var keys = [];
				var values = [];
				var _g = 0;
				while(_g < arr.length) {
					var e1 = arr[_g];
					++_g;
					if(e1._hx_index == 6) {
						if(e1.op == "=>") {
							var eKey = e1.e1;
							var eValue = e1.e2;
							var key = this.expr(eKey);
							var value = this.expr(eValue);
							isAllString = isAllString && typeof(key) == "string";
							isAllInt = isAllInt && (typeof(key) == "number" && ((key | 0) === key));
							isAllObject = isAllObject && Reflect.isObject(key);
							isAllEnum = isAllEnum && Reflect.isEnumValue(key);
							keys.push(key);
							values.push(value);
						} else {
							throw haxe_Exception.thrown("=> expected");
						}
					} else {
						throw haxe_Exception.thrown("=> expected");
					}
				}
				var map;
				if(isAllInt) {
					map = new haxe_ds_IntMap();
				} else if(isAllString) {
					map = new haxe_ds_StringMap();
				} else if(isAllEnum) {
					map = new haxe_ds_EnumValueMap();
				} else if(isAllObject) {
					map = new haxe_ds_ObjectMap();
				} else {
					throw haxe_Exception.thrown("Inconsistent key types");
				}
				var _g = 0;
				var _g1 = keys.length;
				while(_g < _g1) {
					var n = _g++;
					(js_Boot.__cast(map , haxe_IMap)).set(keys[n],values[n]);
				}
				return map;
			} else {
				var a = [];
				var _g = 0;
				while(_g < arr.length) {
					var e1 = arr[_g];
					++_g;
					a.push(this.expr(e1));
				}
				return a;
			}
			break;
		case 18:
			var cl = e.cl;
			var params1 = e.params;
			var a = [];
			var _g = 0;
			while(_g < params1.length) {
				var e1 = params1[_g];
				++_g;
				a.push(this.expr(e1));
			}
			return this.cnew(cl,a);
		case 19:
			var e1 = e.e;
			throw haxe_Exception.thrown(this.expr(e1));
		case 20:
			var _g = e.t;
			var e1 = e.e;
			var n = e.v;
			var ecatch = e.ecatch;
			var old = this.declared.length;
			var oldTry = this.inTry;
			try {
				this.inTry = true;
				var v = this.expr(e1);
				this.restore(old);
				this.inTry = oldTry;
				return v;
			} catch( _g ) {
				var _g1 = haxe_Exception.caught(_g).unwrap();
				if(js_Boot.__instanceof(_g1,hscript__$Interp_Stop)) {
					var err = _g1;
					this.inTry = oldTry;
					throw haxe_Exception.thrown(err);
				} else {
					var err = _g1;
					this.restore(old);
					this.inTry = oldTry;
					this.declared.push({ n : n, old : this.locals.h[n]});
					this.locals.h[n] = { r : err};
					var v = this.expr(ecatch);
					this.restore(old);
					return v;
				}
			}
			break;
		case 21:
			var fl = e.fl;
			var o = { };
			var _g = 0;
			while(_g < fl.length) {
				var f = fl[_g];
				++_g;
				this.set(o,f.name,this.expr(f.e));
			}
			return o;
		case 22:
			var econd = e.cond;
			var e1 = e.e1;
			var e2 = e.e2;
			if(this.expr(econd) == true) {
				return this.expr(e1);
			} else {
				return this.expr(e2);
			}
			break;
		case 23:
			var e1 = e.e;
			var cases = e.cases;
			var def = e.defaultExpr;
			var val = this.expr(e1);
			var match = false;
			var _g = 0;
			while(_g < cases.length) {
				var c = cases[_g];
				++_g;
				var _g1 = 0;
				var _g2 = c.values;
				while(_g1 < _g2.length) {
					var v = _g2[_g1];
					++_g1;
					if(this.expr(v) == val) {
						match = true;
						break;
					}
				}
				if(match) {
					val = this.expr(c.expr);
					break;
				}
			}
			if(!match) {
				val = def == null ? null : this.expr(def);
			}
			return val;
		case 24:
			var econd = e.cond;
			var e1 = e.e;
			this.doWhileLoop(econd,e1);
			return null;
		case 25:
			var _g = e.name;
			var _g = e.args;
			var e1 = e.e;
			return this.expr(e1);
		case 26:
			var _g = e.t;
			var e1 = e.e;
			return this.expr(e1);
		}
	}
	,doWhileLoop: function(econd,e) {
		var old = this.declared.length;
		_hx_loop1: while(true) {
			try {
				this.expr(e);
			} catch( _g ) {
				var _g1 = haxe_Exception.caught(_g).unwrap();
				if(js_Boot.__instanceof(_g1,hscript__$Interp_Stop)) {
					var err = _g1;
					switch(err._hx_index) {
					case 0:
						break _hx_loop1;
					case 1:
						break;
					case 2:
						throw haxe_Exception.thrown(err);
					}
				} else {
					throw _g;
				}
			}
			if(!(this.expr(econd) == true)) {
				break;
			}
		}
		this.restore(old);
	}
	,whileLoop: function(econd,e) {
		var old = this.declared.length;
		_hx_loop1: while(this.expr(econd) == true) try {
			this.expr(e);
		} catch( _g ) {
			var _g1 = haxe_Exception.caught(_g).unwrap();
			if(js_Boot.__instanceof(_g1,hscript__$Interp_Stop)) {
				var err = _g1;
				switch(err._hx_index) {
				case 0:
					break _hx_loop1;
				case 1:
					break;
				case 2:
					throw haxe_Exception.thrown(err);
				}
			} else {
				throw _g;
			}
		}
		this.restore(old);
	}
	,makeIterator: function(v) {
		try {
			v = $getIterator(v);
		} catch( _g ) {
		}
		if(v.hasNext == null || v.next == null) {
			var e = hscript_Error.EInvalidIterator(v);
			throw haxe_Exception.thrown(e);
		}
		return v;
	}
	,forLoop: function(n,it,e) {
		var old = this.declared.length;
		this.declared.push({ n : n, old : this.locals.h[n]});
		var it1 = this.makeIterator(this.expr(it));
		_hx_loop1: while(it1.hasNext()) {
			var this1 = this.locals;
			var value = { r : it1.next()};
			this1.h[n] = value;
			try {
				this.expr(e);
			} catch( _g ) {
				var _g1 = haxe_Exception.caught(_g).unwrap();
				if(js_Boot.__instanceof(_g1,hscript__$Interp_Stop)) {
					var err = _g1;
					switch(err._hx_index) {
					case 0:
						break _hx_loop1;
					case 1:
						break;
					case 2:
						throw haxe_Exception.thrown(err);
					}
				} else {
					throw _g;
				}
			}
		}
		this.restore(old);
	}
	,isMap: function(o) {
		return js_Boot.__implements(o,haxe_IMap);
	}
	,getMapValue: function(map,key) {
		return (js_Boot.__cast(map , haxe_IMap)).get(key);
	}
	,setMapValue: function(map,key,value) {
		(js_Boot.__cast(map , haxe_IMap)).set(key,value);
	}
	,get: function(o,f) {
		if(o == null) {
			var e = hscript_Error.EInvalidAccess(f);
			throw haxe_Exception.thrown(e);
		}
		return Reflect.getProperty(o,f);
	}
	,set: function(o,f,v) {
		if(o == null) {
			var e = hscript_Error.EInvalidAccess(f);
			throw haxe_Exception.thrown(e);
		}
		Reflect.setProperty(o,f,v);
		return v;
	}
	,fcall: function(o,f,args) {
		return this.call(o,this.get(o,f),args);
	}
	,call: function(o,f,args) {
		return f.apply(o,args);
	}
	,cnew: function(cl,args) {
		var c = $hxClasses[cl];
		if(c == null) {
			c = this.resolve(cl);
		}
		return Type.createInstance(c,args);
	}
	,__class__: hscript_Interp
};
var hscript_Token = $hxEnums["hscript.Token"] = { __ename__:true,__constructs__:null
	,TEof: {_hx_name:"TEof",_hx_index:0,__enum__:"hscript.Token",toString:$estr}
	,TConst: ($_=function(c) { return {_hx_index:1,c:c,__enum__:"hscript.Token",toString:$estr}; },$_._hx_name="TConst",$_.__params__ = ["c"],$_)
	,TId: ($_=function(s) { return {_hx_index:2,s:s,__enum__:"hscript.Token",toString:$estr}; },$_._hx_name="TId",$_.__params__ = ["s"],$_)
	,TOp: ($_=function(s) { return {_hx_index:3,s:s,__enum__:"hscript.Token",toString:$estr}; },$_._hx_name="TOp",$_.__params__ = ["s"],$_)
	,TPOpen: {_hx_name:"TPOpen",_hx_index:4,__enum__:"hscript.Token",toString:$estr}
	,TPClose: {_hx_name:"TPClose",_hx_index:5,__enum__:"hscript.Token",toString:$estr}
	,TBrOpen: {_hx_name:"TBrOpen",_hx_index:6,__enum__:"hscript.Token",toString:$estr}
	,TBrClose: {_hx_name:"TBrClose",_hx_index:7,__enum__:"hscript.Token",toString:$estr}
	,TDot: {_hx_name:"TDot",_hx_index:8,__enum__:"hscript.Token",toString:$estr}
	,TComma: {_hx_name:"TComma",_hx_index:9,__enum__:"hscript.Token",toString:$estr}
	,TSemicolon: {_hx_name:"TSemicolon",_hx_index:10,__enum__:"hscript.Token",toString:$estr}
	,TBkOpen: {_hx_name:"TBkOpen",_hx_index:11,__enum__:"hscript.Token",toString:$estr}
	,TBkClose: {_hx_name:"TBkClose",_hx_index:12,__enum__:"hscript.Token",toString:$estr}
	,TQuestion: {_hx_name:"TQuestion",_hx_index:13,__enum__:"hscript.Token",toString:$estr}
	,TDoubleDot: {_hx_name:"TDoubleDot",_hx_index:14,__enum__:"hscript.Token",toString:$estr}
	,TMeta: ($_=function(s) { return {_hx_index:15,s:s,__enum__:"hscript.Token",toString:$estr}; },$_._hx_name="TMeta",$_.__params__ = ["s"],$_)
	,TPrepro: ($_=function(s) { return {_hx_index:16,s:s,__enum__:"hscript.Token",toString:$estr}; },$_._hx_name="TPrepro",$_.__params__ = ["s"],$_)
};
hscript_Token.__constructs__ = [hscript_Token.TEof,hscript_Token.TConst,hscript_Token.TId,hscript_Token.TOp,hscript_Token.TPOpen,hscript_Token.TPClose,hscript_Token.TBrOpen,hscript_Token.TBrClose,hscript_Token.TDot,hscript_Token.TComma,hscript_Token.TSemicolon,hscript_Token.TBkOpen,hscript_Token.TBkClose,hscript_Token.TQuestion,hscript_Token.TDoubleDot,hscript_Token.TMeta,hscript_Token.TPrepro];
var hscript_Parser = function() {
	this.uid = 0;
	this.preprocesorValues = new haxe_ds_StringMap();
	this.line = 1;
	this.opChars = "+*/-=!><&|^%~";
	this.identChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_";
	var priorities = [["%"],["*","/"],["+","-"],["<<",">>",">>>"],["|","&","^"],["==","!=",">","<",">=","<="],["..."],["&&"],["||"],["=","+=","-=","*=","/=","%=","<<=",">>=",">>>=","|=","&=","^=","=>"]];
	this.opPriority = new haxe_ds_StringMap();
	this.opRightAssoc = new haxe_ds_StringMap();
	this.unops = new haxe_ds_StringMap();
	var _g = 0;
	var _g1 = priorities.length;
	while(_g < _g1) {
		var i = _g++;
		var _g2 = 0;
		var _g3 = priorities[i];
		while(_g2 < _g3.length) {
			var x = _g3[_g2];
			++_g2;
			this.opPriority.h[x] = i;
			if(i == 9) {
				this.opRightAssoc.h[x] = true;
			}
		}
	}
	var x = "!";
	this.unops.h[x] = x == "++" || x == "--";
	var x = "++";
	this.unops.h[x] = x == "++" || x == "--";
	var x = "--";
	this.unops.h[x] = x == "++" || x == "--";
	var x = "-";
	this.unops.h[x] = x == "++" || x == "--";
	var x = "~";
	this.unops.h[x] = x == "++" || x == "--";
};
$hxClasses["hscript.Parser"] = hscript_Parser;
hscript_Parser.__name__ = true;
hscript_Parser.prototype = {
	error: function(err,pmin,pmax) {
		throw haxe_Exception.thrown(err);
	}
	,invalidChar: function(c) {
		throw haxe_Exception.thrown(hscript_Error.EInvalidChar(c));
	}
	,initParser: function(origin) {
		this.preprocStack = [];
		this.tokens = new haxe_ds_GenericStack();
		this.char = -1;
		this.ops = [];
		this.idents = [];
		this.uid = 0;
		var _g = 0;
		var _g1 = this.opChars.length;
		while(_g < _g1) {
			var i = _g++;
			this.ops[HxOverrides.cca(this.opChars,i)] = true;
		}
		var _g = 0;
		var _g1 = this.identChars.length;
		while(_g < _g1) {
			var i = _g++;
			this.idents[HxOverrides.cca(this.identChars,i)] = true;
		}
	}
	,parseString: function(s,origin) {
		if(origin == null) {
			origin = "hscript";
		}
		return this.parse(new haxe_io_StringInput(s),origin);
	}
	,parse: function(s,origin) {
		if(origin == null) {
			origin = "hscript";
		}
		this.initParser(origin);
		this.input = s;
		var a = [];
		while(true) {
			var tk = this.token();
			if(tk == hscript_Token.TEof) {
				break;
			}
			var _this = this.tokens;
			_this.head = new haxe_ds_GenericCell(tk,_this.head);
			this.parseFullExpr(a);
		}
		if(a.length == 1) {
			return a[0];
		} else {
			return hscript_Expr.EBlock(a);
		}
	}
	,unexpected: function(tk) {
		throw haxe_Exception.thrown(hscript_Error.EUnexpected(this.tokenString(tk)));
	}
	,push: function(tk) {
		var _this = this.tokens;
		_this.head = new haxe_ds_GenericCell(tk,_this.head);
	}
	,ensure: function(tk) {
		var t = this.token();
		if(t != tk) {
			this.unexpected(t);
		}
	}
	,ensureToken: function(tk) {
		var t = this.token();
		if(!Type.enumEq(t,tk)) {
			this.unexpected(t);
		}
	}
	,maybe: function(tk) {
		var t = this.token();
		if(Type.enumEq(t,tk)) {
			return true;
		}
		var _this = this.tokens;
		_this.head = new haxe_ds_GenericCell(t,_this.head);
		return false;
	}
	,getIdent: function() {
		var tk = this.token();
		if(tk == null) {
			this.unexpected(tk);
			return null;
		} else if(tk._hx_index == 2) {
			var id = tk.s;
			return id;
		} else {
			this.unexpected(tk);
			return null;
		}
	}
	,expr: function(e) {
		return e;
	}
	,pmin: function(e) {
		return 0;
	}
	,pmax: function(e) {
		return 0;
	}
	,mk: function(e,pmin,pmax) {
		return e;
	}
	,isBlock: function(e) {
		switch(e._hx_index) {
		case 2:
			var _g = e.n;
			var t = e.t;
			var e1 = e.e;
			if(e1 != null) {
				return this.isBlock(e1);
			} else if(t != null) {
				if(t == null) {
					return false;
				} else if(t._hx_index == 2) {
					var _g = t.fields;
					return true;
				} else {
					return false;
				}
			} else {
				return false;
			}
			break;
		case 4:
			var _g = e.e;
			return true;
		case 6:
			var _g = e.op;
			var _g = e.e1;
			var e1 = e.e2;
			return this.isBlock(e1);
		case 7:
			var _g = e.op;
			var prefix = e.prefix;
			var e1 = e.e;
			if(!prefix) {
				return this.isBlock(e1);
			} else {
				return false;
			}
			break;
		case 9:
			var _g = e.cond;
			var e1 = e.e1;
			var e2 = e.e2;
			if(e2 != null) {
				return this.isBlock(e2);
			} else {
				return this.isBlock(e1);
			}
			break;
		case 10:
			var _g = e.cond;
			var e1 = e.e;
			return this.isBlock(e1);
		case 11:
			var _g = e.v;
			var _g = e.it;
			var e1 = e.e;
			return this.isBlock(e1);
		case 14:
			var _g = e.args;
			var _g = e.name;
			var _g = e.ret;
			var e1 = e.e;
			return this.isBlock(e1);
		case 15:
			var e1 = e.e;
			if(e1 != null) {
				return this.isBlock(e1);
			} else {
				return false;
			}
			break;
		case 20:
			var _g = e.e;
			var _g = e.v;
			var _g = e.t;
			var e1 = e.ecatch;
			return this.isBlock(e1);
		case 21:
			var _g = e.fl;
			return true;
		case 23:
			var _g = e.e;
			var _g = e.cases;
			var _g = e.defaultExpr;
			return true;
		case 24:
			var _g = e.cond;
			var e1 = e.e;
			return this.isBlock(e1);
		case 25:
			var _g = e.name;
			var _g = e.args;
			var e1 = e.e;
			return this.isBlock(e1);
		default:
			return false;
		}
	}
	,parseFullExpr: function(exprs) {
		var e = this.parseExpr();
		exprs.push(e);
		var tk = this.token();
		while(true) {
			var tmp;
			if(tk == hscript_Token.TComma) {
				if(e._hx_index == 2) {
					var _g = e.n;
					var _g1 = e.t;
					var _g2 = e.e;
					tmp = true;
				} else {
					tmp = false;
				}
			} else {
				tmp = false;
			}
			if(!tmp) {
				break;
			}
			e = this.parseStructure("var");
			exprs.push(e);
			tk = this.token();
		}
		if(tk != hscript_Token.TSemicolon && tk != hscript_Token.TEof) {
			if(this.isBlock(e)) {
				var _this = this.tokens;
				_this.head = new haxe_ds_GenericCell(tk,_this.head);
			} else {
				this.unexpected(tk);
			}
		}
	}
	,parseObject: function(p1) {
		var fl = [];
		_hx_loop1: while(true) {
			var tk = this.token();
			var id = null;
			if(tk == null) {
				this.unexpected(tk);
			} else {
				switch(tk._hx_index) {
				case 1:
					var c = tk.c;
					if(!this.allowJSON) {
						this.unexpected(tk);
					}
					if(c._hx_index == 2) {
						var s = c.s;
						id = s;
					} else {
						this.unexpected(tk);
					}
					break;
				case 2:
					var i = tk.s;
					id = i;
					break;
				case 7:
					break _hx_loop1;
				default:
					this.unexpected(tk);
				}
			}
			var t = this.token();
			if(t != hscript_Token.TDoubleDot) {
				this.unexpected(t);
			}
			fl.push({ name : id, e : this.parseExpr()});
			tk = this.token();
			if(tk == null) {
				this.unexpected(tk);
			} else {
				switch(tk._hx_index) {
				case 7:
					break _hx_loop1;
				case 9:
					break;
				default:
					this.unexpected(tk);
				}
			}
		}
		return this.parseExprNext(hscript_Expr.EObject(fl));
	}
	,parseExpr: function() {
		var tk = this.token();
		if(tk == null) {
			return this.unexpected(tk);
		} else {
			switch(tk._hx_index) {
			case 1:
				var c = tk.c;
				return this.parseExprNext(hscript_Expr.EConst(c));
			case 2:
				var id = tk.s;
				var e = this.parseStructure(id);
				if(e == null) {
					e = hscript_Expr.EIdent(id);
				}
				return this.parseExprNext(e);
			case 3:
				var op = tk.s;
				if(Object.prototype.hasOwnProperty.call(this.unops.h,op)) {
					var start = 0;
					var e = this.parseExpr();
					if(op == "-") {
						if(e._hx_index == 0) {
							var _g = e.c;
							switch(_g._hx_index) {
							case 0:
								var i = _g.v;
								return hscript_Expr.EConst(hscript_Const.CInt(-i));
							case 1:
								var f = _g.f;
								return hscript_Expr.EConst(hscript_Const.CFloat(-f));
							default:
							}
						}
					}
					return this.makeUnop(op,e);
				}
				return this.unexpected(tk);
			case 4:
				var e = this.parseExpr();
				tk = this.token();
				if(tk != null) {
					switch(tk._hx_index) {
					case 5:
						return this.parseExprNext(hscript_Expr.EParent(e));
					case 9:
						if(e._hx_index == 1) {
							var v = e.v;
							return this.parseLambda([{ name : v}],0);
						}
						break;
					case 14:
						var t = this.parseType();
						tk = this.token();
						if(tk != null) {
							switch(tk._hx_index) {
							case 5:
								return this.parseExprNext(hscript_Expr.ECheckType(e,t));
							case 9:
								if(e._hx_index == 1) {
									var v = e.v;
									return this.parseLambda([{ name : v, t : t}],0);
								}
								break;
							default:
							}
						}
						break;
					default:
					}
				}
				return this.unexpected(tk);
			case 6:
				tk = this.token();
				if(tk == null) {
					var _this = this.tokens;
					_this.head = new haxe_ds_GenericCell(tk,_this.head);
				} else {
					switch(tk._hx_index) {
					case 1:
						var c = tk.c;
						if(this.allowJSON) {
							if(c._hx_index == 2) {
								var _g = c.s;
								var tk2 = this.token();
								var _this = this.tokens;
								_this.head = new haxe_ds_GenericCell(tk2,_this.head);
								var _this = this.tokens;
								_this.head = new haxe_ds_GenericCell(tk,_this.head);
								if(tk2 != null) {
									if(tk2._hx_index == 14) {
										return this.parseExprNext(this.parseObject(0));
									}
								}
							} else {
								var _this = this.tokens;
								_this.head = new haxe_ds_GenericCell(tk,_this.head);
							}
						} else {
							var _this = this.tokens;
							_this.head = new haxe_ds_GenericCell(tk,_this.head);
						}
						break;
					case 2:
						var _g = tk.s;
						var tk2 = this.token();
						var _this = this.tokens;
						_this.head = new haxe_ds_GenericCell(tk2,_this.head);
						var _this = this.tokens;
						_this.head = new haxe_ds_GenericCell(tk,_this.head);
						if(tk2 != null) {
							if(tk2._hx_index == 14) {
								return this.parseExprNext(this.parseObject(0));
							}
						}
						break;
					case 7:
						return this.parseExprNext(hscript_Expr.EObject([]));
					default:
						var _this = this.tokens;
						_this.head = new haxe_ds_GenericCell(tk,_this.head);
					}
				}
				var a = [];
				while(true) {
					this.parseFullExpr(a);
					tk = this.token();
					if(tk == hscript_Token.TBrClose) {
						break;
					}
					var _this = this.tokens;
					_this.head = new haxe_ds_GenericCell(tk,_this.head);
				}
				return hscript_Expr.EBlock(a);
			case 11:
				var a = [];
				tk = this.token();
				while(tk != hscript_Token.TBkClose) {
					var _this = this.tokens;
					_this.head = new haxe_ds_GenericCell(tk,_this.head);
					a.push(this.parseExpr());
					tk = this.token();
					if(tk == hscript_Token.TComma) {
						tk = this.token();
					}
				}
				if(a.length == 1) {
					var _g = a[0];
					switch(_g._hx_index) {
					case 10:
						var _g1 = _g.cond;
						var _g1 = _g.e;
						var tmp = "__a_" + this.uid++;
						var e = hscript_Expr.EBlock([hscript_Expr.EVar(tmp,null,hscript_Expr.EArrayDecl([])),this.mapCompr(tmp,a[0]),hscript_Expr.EIdent(tmp)]);
						return this.parseExprNext(e);
					case 11:
						var _g1 = _g.v;
						var _g1 = _g.it;
						var _g1 = _g.e;
						var tmp = "__a_" + this.uid++;
						var e = hscript_Expr.EBlock([hscript_Expr.EVar(tmp,null,hscript_Expr.EArrayDecl([])),this.mapCompr(tmp,a[0]),hscript_Expr.EIdent(tmp)]);
						return this.parseExprNext(e);
					case 24:
						var _g1 = _g.cond;
						var _g1 = _g.e;
						var tmp = "__a_" + this.uid++;
						var e = hscript_Expr.EBlock([hscript_Expr.EVar(tmp,null,hscript_Expr.EArrayDecl([])),this.mapCompr(tmp,a[0]),hscript_Expr.EIdent(tmp)]);
						return this.parseExprNext(e);
					default:
					}
				}
				return this.parseExprNext(hscript_Expr.EArrayDecl(a));
			case 15:
				var id = tk.s;
				if(this.allowMetadata) {
					var args = this.parseMetaArgs();
					return hscript_Expr.EMeta(id,args,this.parseExpr());
				} else {
					return this.unexpected(tk);
				}
				break;
			default:
				return this.unexpected(tk);
			}
		}
	}
	,parseLambda: function(args,pmin) {
		_hx_loop1: while(true) {
			var id = this.getIdent();
			var t = this.maybe(hscript_Token.TDoubleDot) ? this.parseType() : null;
			args.push({ name : id, t : t});
			var tk = this.token();
			if(tk == null) {
				this.unexpected(tk);
			} else {
				switch(tk._hx_index) {
				case 5:
					break _hx_loop1;
				case 9:
					break;
				default:
					this.unexpected(tk);
				}
			}
		}
		var t = this.token();
		if(!Type.enumEq(t,hscript_Token.TOp("->"))) {
			this.unexpected(t);
		}
		var eret = this.parseExpr();
		return hscript_Expr.EFunction(args,hscript_Expr.EReturn(eret));
	}
	,parseMetaArgs: function() {
		var tk = this.token();
		if(tk != hscript_Token.TPOpen) {
			var _this = this.tokens;
			_this.head = new haxe_ds_GenericCell(tk,_this.head);
			return null;
		}
		var args = [];
		tk = this.token();
		if(tk != hscript_Token.TPClose) {
			var _this = this.tokens;
			_this.head = new haxe_ds_GenericCell(tk,_this.head);
			_hx_loop1: while(true) {
				args.push(this.parseExpr());
				var _g = this.token();
				if(_g == null) {
					var tk = _g;
					this.unexpected(tk);
				} else {
					switch(_g._hx_index) {
					case 5:
						break _hx_loop1;
					case 9:
						break;
					default:
						var tk1 = _g;
						this.unexpected(tk1);
					}
				}
			}
		}
		return args;
	}
	,mapCompr: function(tmp,e) {
		var edef;
		switch(e._hx_index) {
		case 3:
			var e2 = e.e;
			edef = hscript_Expr.EParent(this.mapCompr(tmp,e2));
			break;
		case 4:
			var _g = e.e;
			if(_g.length == 1) {
				var e1 = _g[0];
				edef = hscript_Expr.EBlock([this.mapCompr(tmp,e1)]);
			} else {
				edef = hscript_Expr.ECall(hscript_Expr.EField(hscript_Expr.EIdent(tmp),"push"),[e]);
			}
			break;
		case 9:
			var cond = e.cond;
			var e1 = e.e1;
			var e2 = e.e2;
			edef = e2 == null ? hscript_Expr.EIf(cond,this.mapCompr(tmp,e1),null) : hscript_Expr.ECall(hscript_Expr.EField(hscript_Expr.EIdent(tmp),"push"),[e]);
			break;
		case 10:
			var cond = e.cond;
			var e2 = e.e;
			edef = hscript_Expr.EWhile(cond,this.mapCompr(tmp,e2));
			break;
		case 11:
			var v = e.v;
			var it = e.it;
			var e2 = e.e;
			edef = hscript_Expr.EFor(v,it,this.mapCompr(tmp,e2));
			break;
		case 24:
			var cond = e.cond;
			var e2 = e.e;
			edef = hscript_Expr.EDoWhile(cond,this.mapCompr(tmp,e2));
			break;
		default:
			edef = hscript_Expr.ECall(hscript_Expr.EField(hscript_Expr.EIdent(tmp),"push"),[e]);
		}
		return edef;
	}
	,makeUnop: function(op,e) {
		switch(e._hx_index) {
		case 6:
			var bop = e.op;
			var e1 = e.e1;
			var e2 = e.e2;
			return hscript_Expr.EBinop(bop,this.makeUnop(op,e1),e2);
		case 22:
			var e1 = e.cond;
			var e2 = e.e1;
			var e3 = e.e2;
			return hscript_Expr.ETernary(this.makeUnop(op,e1),e2,e3);
		default:
			return hscript_Expr.EUnop(op,true,e);
		}
	}
	,makeBinop: function(op,e1,e) {
		switch(e._hx_index) {
		case 6:
			var op2 = e.op;
			var e2 = e.e1;
			var e3 = e.e2;
			if(this.opPriority.h[op] <= this.opPriority.h[op2] && !Object.prototype.hasOwnProperty.call(this.opRightAssoc.h,op)) {
				return hscript_Expr.EBinop(op2,this.makeBinop(op,e1,e2),e3);
			} else {
				return hscript_Expr.EBinop(op,e1,e);
			}
			break;
		case 22:
			var e2 = e.cond;
			var e3 = e.e1;
			var e4 = e.e2;
			if(Object.prototype.hasOwnProperty.call(this.opRightAssoc.h,op)) {
				return hscript_Expr.EBinop(op,e1,e);
			} else {
				return hscript_Expr.ETernary(this.makeBinop(op,e1,e2),e3,e4);
			}
			break;
		default:
			return hscript_Expr.EBinop(op,e1,e);
		}
	}
	,parseStructure: function(id) {
		switch(id) {
		case "break":
			return hscript_Expr.EBreak;
		case "continue":
			return hscript_Expr.EContinue;
		case "do":
			var e = this.parseExpr();
			var tk = this.token();
			if(tk == null) {
				this.unexpected(tk);
			} else if(tk._hx_index == 2) {
				if(tk.s != "while") {
					this.unexpected(tk);
				}
			} else {
				this.unexpected(tk);
			}
			var econd = this.parseExpr();
			return hscript_Expr.EDoWhile(econd,e);
		case "else":
			return this.unexpected(hscript_Token.TId(id));
		case "for":
			var t = this.token();
			if(t != hscript_Token.TPOpen) {
				this.unexpected(t);
			}
			var vname = this.getIdent();
			var t = this.token();
			if(!Type.enumEq(t,hscript_Token.TId("in"))) {
				this.unexpected(t);
			}
			var eiter = this.parseExpr();
			var t = this.token();
			if(t != hscript_Token.TPClose) {
				this.unexpected(t);
			}
			var e = this.parseExpr();
			return hscript_Expr.EFor(vname,eiter,e);
		case "function":
			var tk = this.token();
			var name = null;
			if(tk == null) {
				var _this = this.tokens;
				_this.head = new haxe_ds_GenericCell(tk,_this.head);
			} else if(tk._hx_index == 2) {
				var id = tk.s;
				name = id;
			} else {
				var _this = this.tokens;
				_this.head = new haxe_ds_GenericCell(tk,_this.head);
			}
			var inf = this.parseFunctionDecl();
			return hscript_Expr.EFunction(inf.args,inf.body,name,inf.ret);
		case "if":
			var t = this.token();
			if(t != hscript_Token.TPOpen) {
				this.unexpected(t);
			}
			var cond = this.parseExpr();
			var t = this.token();
			if(t != hscript_Token.TPClose) {
				this.unexpected(t);
			}
			var e1 = this.parseExpr();
			var e2 = null;
			var semic = false;
			var tk = this.token();
			if(tk == hscript_Token.TSemicolon) {
				semic = true;
				tk = this.token();
			}
			if(Type.enumEq(tk,hscript_Token.TId("else"))) {
				e2 = this.parseExpr();
			} else {
				var _this = this.tokens;
				_this.head = new haxe_ds_GenericCell(tk,_this.head);
				if(semic) {
					var _this = this.tokens;
					_this.head = new haxe_ds_GenericCell(hscript_Token.TSemicolon,_this.head);
				}
			}
			return hscript_Expr.EIf(cond,e1,e2);
		case "inline":
			if(!this.maybe(hscript_Token.TId("function"))) {
				this.unexpected(hscript_Token.TId("inline"));
			}
			return this.parseStructure("function");
		case "new":
			var a = [];
			a.push(this.getIdent());
			var next = true;
			while(next) {
				var tk = this.token();
				if(tk == null) {
					this.unexpected(tk);
				} else {
					switch(tk._hx_index) {
					case 4:
						next = false;
						break;
					case 8:
						a.push(this.getIdent());
						break;
					default:
						this.unexpected(tk);
					}
				}
			}
			var args = this.parseExprList(hscript_Token.TPClose);
			return hscript_Expr.ENew(a.join("."),args);
		case "return":
			var tk = this.token();
			var _this = this.tokens;
			_this.head = new haxe_ds_GenericCell(tk,_this.head);
			var e = tk == hscript_Token.TSemicolon ? null : this.parseExpr();
			return hscript_Expr.EReturn(e);
		case "switch":
			var e = this.parseExpr();
			var def = null;
			var cases = [];
			var t = this.token();
			if(t != hscript_Token.TBrOpen) {
				this.unexpected(t);
			}
			_hx_loop2: while(true) {
				var tk = this.token();
				if(tk == null) {
					this.unexpected(tk);
				} else {
					switch(tk._hx_index) {
					case 2:
						switch(tk.s) {
						case "case":
							var c = { values : [], expr : null};
							cases.push(c);
							_hx_loop3: while(true) {
								var e1 = this.parseExpr();
								c.values.push(e1);
								tk = this.token();
								if(tk == null) {
									this.unexpected(tk);
								} else {
									switch(tk._hx_index) {
									case 9:
										break;
									case 14:
										break _hx_loop3;
									default:
										this.unexpected(tk);
									}
								}
							}
							var exprs = [];
							_hx_loop4: while(true) {
								tk = this.token();
								var _this = this.tokens;
								_this.head = new haxe_ds_GenericCell(tk,_this.head);
								if(tk == null) {
									this.parseFullExpr(exprs);
								} else {
									switch(tk._hx_index) {
									case 2:
										switch(tk.s) {
										case "case":case "default":
											break _hx_loop4;
										default:
											this.parseFullExpr(exprs);
										}
										break;
									case 7:
										break _hx_loop4;
									default:
										this.parseFullExpr(exprs);
									}
								}
							}
							c.expr = exprs.length == 1 ? exprs[0] : exprs.length == 0 ? hscript_Expr.EBlock([]) : hscript_Expr.EBlock(exprs);
							break;
						case "default":
							if(def != null) {
								this.unexpected(tk);
							}
							var t = this.token();
							if(t != hscript_Token.TDoubleDot) {
								this.unexpected(t);
							}
							var exprs1 = [];
							_hx_loop5: while(true) {
								tk = this.token();
								var _this1 = this.tokens;
								_this1.head = new haxe_ds_GenericCell(tk,_this1.head);
								if(tk == null) {
									this.parseFullExpr(exprs1);
								} else {
									switch(tk._hx_index) {
									case 2:
										switch(tk.s) {
										case "case":case "default":
											break _hx_loop5;
										default:
											this.parseFullExpr(exprs1);
										}
										break;
									case 7:
										break _hx_loop5;
									default:
										this.parseFullExpr(exprs1);
									}
								}
							}
							def = exprs1.length == 1 ? exprs1[0] : exprs1.length == 0 ? hscript_Expr.EBlock([]) : hscript_Expr.EBlock(exprs1);
							break;
						default:
							this.unexpected(tk);
						}
						break;
					case 7:
						break _hx_loop2;
					default:
						this.unexpected(tk);
					}
				}
			}
			return hscript_Expr.ESwitch(e,cases,def);
		case "throw":
			var e = this.parseExpr();
			return hscript_Expr.EThrow(e);
		case "try":
			var e = this.parseExpr();
			var t = this.token();
			if(!Type.enumEq(t,hscript_Token.TId("catch"))) {
				this.unexpected(t);
			}
			var t = this.token();
			if(t != hscript_Token.TPOpen) {
				this.unexpected(t);
			}
			var vname = this.getIdent();
			var t = this.token();
			if(t != hscript_Token.TDoubleDot) {
				this.unexpected(t);
			}
			var t = null;
			if(this.allowTypes) {
				t = this.parseType();
			} else {
				var t1 = this.token();
				if(!Type.enumEq(t1,hscript_Token.TId("Dynamic"))) {
					this.unexpected(t1);
				}
			}
			var t1 = this.token();
			if(t1 != hscript_Token.TPClose) {
				this.unexpected(t1);
			}
			var ec = this.parseExpr();
			return hscript_Expr.ETry(e,vname,t,ec);
		case "var":
			var ident = this.getIdent();
			var tk = this.token();
			var t = null;
			if(tk == hscript_Token.TDoubleDot && this.allowTypes) {
				t = this.parseType();
				tk = this.token();
			}
			var e = null;
			if(Type.enumEq(tk,hscript_Token.TOp("="))) {
				e = this.parseExpr();
			} else {
				var _this = this.tokens;
				_this.head = new haxe_ds_GenericCell(tk,_this.head);
			}
			return hscript_Expr.EVar(ident,t,e);
		case "while":
			var econd = this.parseExpr();
			var e = this.parseExpr();
			return hscript_Expr.EWhile(econd,e);
		default:
			return null;
		}
	}
	,parseExprNext: function(e1) {
		var tk = this.token();
		if(tk == null) {
			var _this = this.tokens;
			_this.head = new haxe_ds_GenericCell(tk,_this.head);
			return e1;
		} else {
			switch(tk._hx_index) {
			case 3:
				var op = tk.s;
				if(op == "->") {
					switch(e1._hx_index) {
					case 1:
						var i = e1.v;
						var eret = this.parseExpr();
						return hscript_Expr.EFunction([{ name : i}],hscript_Expr.EReturn(eret));
					case 3:
						var _hx_tmp = e1.e;
						if(_hx_tmp._hx_index == 1) {
							var i = _hx_tmp.v;
							var eret = this.parseExpr();
							return hscript_Expr.EFunction([{ name : i}],hscript_Expr.EReturn(eret));
						}
						break;
					case 26:
						var _hx_tmp = e1.e;
						if(_hx_tmp._hx_index == 1) {
							var i = _hx_tmp.v;
							var t = e1.t;
							var eret = this.parseExpr();
							return hscript_Expr.EFunction([{ name : i, t : t}],hscript_Expr.EReturn(eret));
						}
						break;
					default:
					}
					this.unexpected(tk);
				}
				if(this.unops.h[op]) {
					var tmp;
					if(!this.isBlock(e1)) {
						if(e1._hx_index == 3) {
							var _g = e1.e;
							tmp = true;
						} else {
							tmp = false;
						}
					} else {
						tmp = true;
					}
					if(tmp) {
						var _this = this.tokens;
						_this.head = new haxe_ds_GenericCell(tk,_this.head);
						return e1;
					}
					return this.parseExprNext(hscript_Expr.EUnop(op,false,e1));
				}
				return this.makeBinop(op,e1,this.parseExpr());
			case 4:
				return this.parseExprNext(hscript_Expr.ECall(e1,this.parseExprList(hscript_Token.TPClose)));
			case 8:
				var field = this.getIdent();
				return this.parseExprNext(hscript_Expr.EField(e1,field));
			case 11:
				var e2 = this.parseExpr();
				var t = this.token();
				if(t != hscript_Token.TBkClose) {
					this.unexpected(t);
				}
				return this.parseExprNext(hscript_Expr.EArray(e1,e2));
			case 13:
				var e2 = this.parseExpr();
				var t = this.token();
				if(t != hscript_Token.TDoubleDot) {
					this.unexpected(t);
				}
				var e3 = this.parseExpr();
				return hscript_Expr.ETernary(e1,e2,e3);
			default:
				var _this = this.tokens;
				_this.head = new haxe_ds_GenericCell(tk,_this.head);
				return e1;
			}
		}
	}
	,parseFunctionArgs: function() {
		var args = [];
		var tk = this.token();
		if(tk != hscript_Token.TPClose) {
			var done = false;
			while(!done) {
				var name = null;
				var opt = false;
				if(tk != null) {
					if(tk._hx_index == 13) {
						opt = true;
						tk = this.token();
					}
				}
				if(tk == null) {
					this.unexpected(tk);
				} else if(tk._hx_index == 2) {
					var id = tk.s;
					name = id;
				} else {
					this.unexpected(tk);
				}
				var arg = { name : name};
				args.push(arg);
				if(opt) {
					arg.opt = true;
				}
				if(this.allowTypes) {
					if(this.maybe(hscript_Token.TDoubleDot)) {
						arg.t = this.parseType();
					}
					if(this.maybe(hscript_Token.TOp("="))) {
						arg.value = this.parseExpr();
					}
				}
				tk = this.token();
				if(tk == null) {
					this.unexpected(tk);
				} else {
					switch(tk._hx_index) {
					case 5:
						done = true;
						break;
					case 9:
						tk = this.token();
						break;
					default:
						this.unexpected(tk);
					}
				}
			}
		}
		return args;
	}
	,parseFunctionDecl: function() {
		var t = this.token();
		if(t != hscript_Token.TPOpen) {
			this.unexpected(t);
		}
		var args = this.parseFunctionArgs();
		var ret = null;
		if(this.allowTypes) {
			var tk = this.token();
			if(tk != hscript_Token.TDoubleDot) {
				var _this = this.tokens;
				_this.head = new haxe_ds_GenericCell(tk,_this.head);
			} else {
				ret = this.parseType();
			}
		}
		return { args : args, ret : ret, body : this.parseExpr()};
	}
	,parsePath: function() {
		var path = [this.getIdent()];
		while(true) {
			var t = this.token();
			if(t != hscript_Token.TDot) {
				var _this = this.tokens;
				_this.head = new haxe_ds_GenericCell(t,_this.head);
				break;
			}
			path.push(this.getIdent());
		}
		return path;
	}
	,parseType: function() {
		var _gthis = this;
		var t = this.token();
		if(t == null) {
			return this.unexpected(t);
		} else {
			switch(t._hx_index) {
			case 2:
				var v = t.s;
				var _this = this.tokens;
				_this.head = new haxe_ds_GenericCell(t,_this.head);
				var path = this.parsePath();
				var params = null;
				t = this.token();
				if(t == null) {
					var _this = this.tokens;
					_this.head = new haxe_ds_GenericCell(t,_this.head);
				} else if(t._hx_index == 3) {
					var op = t.s;
					if(op == "<") {
						params = [];
						_hx_loop1: while(true) {
							params.push(this.parseType());
							t = this.token();
							if(t != null) {
								switch(t._hx_index) {
								case 3:
									var op = t.s;
									if(op == ">") {
										break _hx_loop1;
									}
									if(HxOverrides.cca(op,0) == 62) {
										var _this = this.tokens;
										_this.head = new haxe_ds_GenericCell(hscript_Token.TOp(HxOverrides.substr(op,1,null)),_this.head);
										break _hx_loop1;
									}
									break;
								case 9:
									continue;
								default:
								}
							}
							this.unexpected(t);
						}
					} else {
						var _this = this.tokens;
						_this.head = new haxe_ds_GenericCell(t,_this.head);
					}
				} else {
					var _this = this.tokens;
					_this.head = new haxe_ds_GenericCell(t,_this.head);
				}
				return this.parseTypeNext(hscript_CType.CTPath(path,params));
			case 4:
				var a = this.token();
				var b = this.token();
				var _this = this.tokens;
				_this.head = new haxe_ds_GenericCell(b,_this.head);
				var _this = this.tokens;
				_this.head = new haxe_ds_GenericCell(a,_this.head);
				var withReturn = function(args) {
					var _g = _gthis.token();
					if(_g == null) {
						var t = _g;
						_gthis.unexpected(t);
					} else if(_g._hx_index == 3) {
						if(_g.s != "->") {
							var t = _g;
							_gthis.unexpected(t);
						}
					} else {
						var t = _g;
						_gthis.unexpected(t);
					}
					return hscript_CType.CTFun(args,_gthis.parseType());
				};
				if(a == null) {
					var t1 = this.parseType();
					var _g = this.token();
					if(_g == null) {
						var t2 = _g;
						return this.unexpected(t2);
					} else {
						switch(_g._hx_index) {
						case 5:
							return this.parseTypeNext(hscript_CType.CTParent(t1));
						case 9:
							var args = [t1];
							while(true) {
								args.push(this.parseType());
								if(!this.maybe(hscript_Token.TComma)) {
									break;
								}
							}
							var t1 = this.token();
							if(t1 != hscript_Token.TPClose) {
								this.unexpected(t1);
							}
							return withReturn(args);
						default:
							var t1 = _g;
							return this.unexpected(t1);
						}
					}
				} else {
					switch(a._hx_index) {
					case 2:
						var _g = a.s;
						if(b == null) {
							var t1 = this.parseType();
							var _g = this.token();
							if(_g == null) {
								var t2 = _g;
								return this.unexpected(t2);
							} else {
								switch(_g._hx_index) {
								case 5:
									return this.parseTypeNext(hscript_CType.CTParent(t1));
								case 9:
									var args = [t1];
									while(true) {
										args.push(this.parseType());
										if(!this.maybe(hscript_Token.TComma)) {
											break;
										}
									}
									var t1 = this.token();
									if(t1 != hscript_Token.TPClose) {
										this.unexpected(t1);
									}
									return withReturn(args);
								default:
									var t1 = _g;
									return this.unexpected(t1);
								}
							}
						} else if(b._hx_index == 14) {
							var _g = [];
							var _g1 = 0;
							var _g2 = this.parseFunctionArgs();
							while(_g1 < _g2.length) {
								var arg = _g2[_g1];
								++_g1;
								var _g3 = arg.value;
								if(_g3 != null) {
									var v = _g3;
									throw haxe_Exception.thrown(hscript_Error.ECustom("Default values not allowed in function types"));
								}
								_g.push(hscript_CType.CTNamed(arg.name,arg.opt ? hscript_CType.CTOpt(arg.t) : arg.t));
							}
							var args = _g;
							return withReturn(args);
						} else {
							var t1 = this.parseType();
							var _g = this.token();
							if(_g == null) {
								var t2 = _g;
								return this.unexpected(t2);
							} else {
								switch(_g._hx_index) {
								case 5:
									return this.parseTypeNext(hscript_CType.CTParent(t1));
								case 9:
									var args = [t1];
									while(true) {
										args.push(this.parseType());
										if(!this.maybe(hscript_Token.TComma)) {
											break;
										}
									}
									var t1 = this.token();
									if(t1 != hscript_Token.TPClose) {
										this.unexpected(t1);
									}
									return withReturn(args);
								default:
									var t1 = _g;
									return this.unexpected(t1);
								}
							}
						}
						break;
					case 5:
						var _g = [];
						var _g1 = 0;
						var _g2 = this.parseFunctionArgs();
						while(_g1 < _g2.length) {
							var arg = _g2[_g1];
							++_g1;
							var _g3 = arg.value;
							if(_g3 != null) {
								var v = _g3;
								throw haxe_Exception.thrown(hscript_Error.ECustom("Default values not allowed in function types"));
							}
							_g.push(hscript_CType.CTNamed(arg.name,arg.opt ? hscript_CType.CTOpt(arg.t) : arg.t));
						}
						var args = _g;
						return withReturn(args);
					default:
						var t1 = this.parseType();
						var _g = this.token();
						if(_g == null) {
							var t2 = _g;
							return this.unexpected(t2);
						} else {
							switch(_g._hx_index) {
							case 5:
								return this.parseTypeNext(hscript_CType.CTParent(t1));
							case 9:
								var args = [t1];
								while(true) {
									args.push(this.parseType());
									if(!this.maybe(hscript_Token.TComma)) {
										break;
									}
								}
								var t1 = this.token();
								if(t1 != hscript_Token.TPClose) {
									this.unexpected(t1);
								}
								return withReturn(args);
							default:
								var t1 = _g;
								return this.unexpected(t1);
							}
						}
					}
				}
				break;
			case 6:
				var fields = [];
				var meta = null;
				_hx_loop8: while(true) {
					t = this.token();
					if(t == null) {
						this.unexpected(t);
					} else {
						switch(t._hx_index) {
						case 2:
							var _g = t.s;
							if(_g == "var") {
								var name = this.getIdent();
								var t1 = this.token();
								if(t1 != hscript_Token.TDoubleDot) {
									this.unexpected(t1);
								}
								fields.push({ name : name, t : this.parseType(), meta : meta});
								meta = null;
								var t2 = this.token();
								if(t2 != hscript_Token.TSemicolon) {
									this.unexpected(t2);
								}
							} else {
								var name1 = _g;
								var t3 = this.token();
								if(t3 != hscript_Token.TDoubleDot) {
									this.unexpected(t3);
								}
								fields.push({ name : name1, t : this.parseType(), meta : meta});
								t = this.token();
								if(t == null) {
									this.unexpected(t);
								} else {
									switch(t._hx_index) {
									case 7:
										break _hx_loop8;
									case 9:
										break;
									default:
										this.unexpected(t);
									}
								}
							}
							break;
						case 7:
							break _hx_loop8;
						case 15:
							var name2 = t.s;
							if(meta == null) {
								meta = [];
							}
							meta.push({ name : name2, params : this.parseMetaArgs()});
							break;
						default:
							this.unexpected(t);
						}
					}
				}
				return this.parseTypeNext(hscript_CType.CTAnon(fields));
			default:
				return this.unexpected(t);
			}
		}
	}
	,parseTypeNext: function(t) {
		var tk = this.token();
		if(tk == null) {
			var _this = this.tokens;
			_this.head = new haxe_ds_GenericCell(tk,_this.head);
			return t;
		} else if(tk._hx_index == 3) {
			var op = tk.s;
			if(op != "->") {
				var _this = this.tokens;
				_this.head = new haxe_ds_GenericCell(tk,_this.head);
				return t;
			}
		} else {
			var _this = this.tokens;
			_this.head = new haxe_ds_GenericCell(tk,_this.head);
			return t;
		}
		var t2 = this.parseType();
		if(t2._hx_index == 1) {
			var _g = t2.ret;
			var args = t2.args;
			args.unshift(t);
			return t2;
		} else {
			return hscript_CType.CTFun([t],t2);
		}
	}
	,parseExprList: function(etk) {
		var args = [];
		var tk = this.token();
		if(tk == etk) {
			return args;
		}
		var _this = this.tokens;
		_this.head = new haxe_ds_GenericCell(tk,_this.head);
		while(true) {
			args.push(this.parseExpr());
			tk = this.token();
			if(tk == null) {
				if(tk == etk) {
					break;
				}
				this.unexpected(tk);
			} else if(tk._hx_index != 9) {
				if(tk == etk) {
					break;
				}
				this.unexpected(tk);
			}
		}
		return args;
	}
	,parseModule: function(content,origin) {
		if(origin == null) {
			origin = "hscript";
		}
		this.initParser(origin);
		this.input = new haxe_io_StringInput(content);
		this.allowTypes = true;
		this.allowMetadata = true;
		var decls = [];
		while(true) {
			var tk = this.token();
			if(tk == hscript_Token.TEof) {
				break;
			}
			var _this = this.tokens;
			_this.head = new haxe_ds_GenericCell(tk,_this.head);
			decls.push(this.parseModuleDecl());
		}
		return decls;
	}
	,parseMetadata: function() {
		var meta = [];
		while(true) {
			var tk = this.token();
			if(tk == null) {
				var _this = this.tokens;
				_this.head = new haxe_ds_GenericCell(tk,_this.head);
				break;
			} else if(tk._hx_index == 15) {
				var name = tk.s;
				meta.push({ name : name, params : this.parseMetaArgs()});
			} else {
				var _this1 = this.tokens;
				_this1.head = new haxe_ds_GenericCell(tk,_this1.head);
				break;
			}
		}
		return meta;
	}
	,parseParams: function() {
		if(this.maybe(hscript_Token.TOp("<"))) {
			throw haxe_Exception.thrown(hscript_Error.EInvalidOp("Unsupported class type parameters"));
		}
		return { };
	}
	,parseModuleDecl: function() {
		var meta = this.parseMetadata();
		var ident = this.getIdent();
		var isPrivate = false;
		var isExtern = false;
		_hx_loop1: while(true) {
			switch(ident) {
			case "extern":
				isExtern = true;
				break;
			case "private":
				isPrivate = true;
				break;
			default:
				break _hx_loop1;
			}
			ident = this.getIdent();
		}
		switch(ident) {
		case "class":
			var name = this.getIdent();
			var params = this.parseParams();
			var extend = null;
			var implement = [];
			_hx_loop2: while(true) {
				var t = this.token();
				if(t == null) {
					var _this = this.tokens;
					_this.head = new haxe_ds_GenericCell(t,_this.head);
					break;
				} else if(t._hx_index == 2) {
					switch(t.s) {
					case "extends":
						extend = this.parseType();
						break;
					case "implements":
						implement.push(this.parseType());
						break;
					default:
						var _this1 = this.tokens;
						_this1.head = new haxe_ds_GenericCell(t,_this1.head);
						break _hx_loop2;
					}
				} else {
					var _this2 = this.tokens;
					_this2.head = new haxe_ds_GenericCell(t,_this2.head);
					break;
				}
			}
			var fields = [];
			var t = this.token();
			if(t != hscript_Token.TBrOpen) {
				this.unexpected(t);
			}
			while(!this.maybe(hscript_Token.TBrClose)) fields.push(this.parseField());
			return hscript_ModuleDecl.DClass({ name : name, meta : meta, params : params, extend : extend, implement : implement, fields : fields, isPrivate : isPrivate, isExtern : isExtern});
		case "import":
			var path = [this.getIdent()];
			var star = false;
			while(true) {
				var t = this.token();
				if(t != hscript_Token.TDot) {
					var _this = this.tokens;
					_this.head = new haxe_ds_GenericCell(t,_this.head);
					break;
				}
				t = this.token();
				if(t == null) {
					this.unexpected(t);
				} else {
					switch(t._hx_index) {
					case 2:
						var id = t.s;
						path.push(id);
						break;
					case 3:
						if(t.s == "*") {
							star = true;
						} else {
							this.unexpected(t);
						}
						break;
					default:
						this.unexpected(t);
					}
				}
			}
			var t = this.token();
			if(t != hscript_Token.TSemicolon) {
				this.unexpected(t);
			}
			return hscript_ModuleDecl.DImport(path,star);
		case "package":
			var path = this.parsePath();
			var t = this.token();
			if(t != hscript_Token.TSemicolon) {
				this.unexpected(t);
			}
			return hscript_ModuleDecl.DPackage(path);
		case "typedef":
			var name = this.getIdent();
			var params = this.parseParams();
			var t = this.token();
			if(!Type.enumEq(t,hscript_Token.TOp("="))) {
				this.unexpected(t);
			}
			var t = this.parseType();
			return hscript_ModuleDecl.DTypedef({ name : name, meta : meta, params : params, isPrivate : isPrivate, t : t});
		default:
			this.unexpected(hscript_Token.TId(ident));
		}
		return null;
	}
	,parseField: function() {
		var meta = this.parseMetadata();
		var access = [];
		while(true) {
			var id = this.getIdent();
			switch(id) {
			case "function":
				var name = this.getIdent();
				var inf = this.parseFunctionDecl();
				return { name : name, meta : meta, access : access, kind : hscript_FieldKind.KFunction({ args : inf.args, expr : inf.body, ret : inf.ret})};
			case "inline":
				access.push(hscript_FieldAccess.AInline);
				break;
			case "macro":
				access.push(hscript_FieldAccess.AMacro);
				break;
			case "override":
				access.push(hscript_FieldAccess.AOverride);
				break;
			case "private":
				access.push(hscript_FieldAccess.APrivate);
				break;
			case "public":
				access.push(hscript_FieldAccess.APublic);
				break;
			case "static":
				access.push(hscript_FieldAccess.AStatic);
				break;
			case "var":
				var name1 = this.getIdent();
				var get = null;
				var set = null;
				if(this.maybe(hscript_Token.TPOpen)) {
					get = this.getIdent();
					var t = this.token();
					if(t != hscript_Token.TComma) {
						this.unexpected(t);
					}
					set = this.getIdent();
					var t1 = this.token();
					if(t1 != hscript_Token.TPClose) {
						this.unexpected(t1);
					}
				}
				var type = this.maybe(hscript_Token.TDoubleDot) ? this.parseType() : null;
				var expr = this.maybe(hscript_Token.TOp("=")) ? this.parseExpr() : null;
				if(expr != null) {
					if(this.isBlock(expr)) {
						this.maybe(hscript_Token.TSemicolon);
					} else {
						var t2 = this.token();
						if(t2 != hscript_Token.TSemicolon) {
							this.unexpected(t2);
						}
					}
				} else {
					var tmp;
					if(type != null) {
						if(type == null) {
							tmp = false;
						} else if(type._hx_index == 2) {
							var _g = type.fields;
							tmp = true;
						} else {
							tmp = false;
						}
					} else {
						tmp = false;
					}
					if(tmp) {
						this.maybe(hscript_Token.TSemicolon);
					} else {
						var t3 = this.token();
						if(t3 != hscript_Token.TSemicolon) {
							this.unexpected(t3);
						}
					}
				}
				return { name : name1, meta : meta, access : access, kind : hscript_FieldKind.KVar({ get : get, set : set, type : type, expr : expr})};
			default:
				this.unexpected(hscript_Token.TId(id));
			}
		}
	}
	,incPos: function() {
	}
	,readChar: function() {
		try {
			return this.input.readByte();
		} catch( _g ) {
			return 0;
		}
	}
	,readString: function(until) {
		var c = 0;
		var b = new haxe_io_BytesOutput();
		var esc = false;
		var old = this.line;
		var s = this.input;
		while(true) {
			try {
				c = s.readByte();
			} catch( _g ) {
				this.line = old;
				throw haxe_Exception.thrown(hscript_Error.EUnterminatedString);
			}
			if(esc) {
				esc = false;
				switch(c) {
				case 34:case 39:case 92:
					b.writeByte(c);
					break;
				case 47:
					if(this.allowJSON) {
						b.writeByte(c);
					} else {
						this.invalidChar(c);
					}
					break;
				case 110:
					b.writeByte(10);
					break;
				case 114:
					b.writeByte(13);
					break;
				case 116:
					b.writeByte(9);
					break;
				case 117:
					if(!this.allowJSON) {
						this.invalidChar(c);
					}
					var code = null;
					try {
						code = s.readString(4);
					} catch( _g1 ) {
						this.line = old;
						throw haxe_Exception.thrown(hscript_Error.EUnterminatedString);
					}
					var k = 0;
					k <<= 4;
					var char = HxOverrides.cca(code,0);
					if(char == null) {
						this.invalidChar(char);
					} else {
						switch(char) {
						case 48:case 49:case 50:case 51:case 52:case 53:case 54:case 55:case 56:case 57:
							k += char - 48;
							break;
						case 65:case 66:case 67:case 68:case 69:case 70:
							k += char - 55;
							break;
						case 97:case 98:case 99:case 100:case 101:case 102:
							k += char - 87;
							break;
						default:
							this.invalidChar(char);
						}
					}
					k <<= 4;
					var char1 = HxOverrides.cca(code,1);
					if(char1 == null) {
						this.invalidChar(char1);
					} else {
						switch(char1) {
						case 48:case 49:case 50:case 51:case 52:case 53:case 54:case 55:case 56:case 57:
							k += char1 - 48;
							break;
						case 65:case 66:case 67:case 68:case 69:case 70:
							k += char1 - 55;
							break;
						case 97:case 98:case 99:case 100:case 101:case 102:
							k += char1 - 87;
							break;
						default:
							this.invalidChar(char1);
						}
					}
					k <<= 4;
					var char2 = HxOverrides.cca(code,2);
					if(char2 == null) {
						this.invalidChar(char2);
					} else {
						switch(char2) {
						case 48:case 49:case 50:case 51:case 52:case 53:case 54:case 55:case 56:case 57:
							k += char2 - 48;
							break;
						case 65:case 66:case 67:case 68:case 69:case 70:
							k += char2 - 55;
							break;
						case 97:case 98:case 99:case 100:case 101:case 102:
							k += char2 - 87;
							break;
						default:
							this.invalidChar(char2);
						}
					}
					k <<= 4;
					var char3 = HxOverrides.cca(code,3);
					if(char3 == null) {
						this.invalidChar(char3);
					} else {
						switch(char3) {
						case 48:case 49:case 50:case 51:case 52:case 53:case 54:case 55:case 56:case 57:
							k += char3 - 48;
							break;
						case 65:case 66:case 67:case 68:case 69:case 70:
							k += char3 - 55;
							break;
						case 97:case 98:case 99:case 100:case 101:case 102:
							k += char3 - 87;
							break;
						default:
							this.invalidChar(char3);
						}
					}
					if(k <= 127) {
						b.writeByte(k);
					} else if(k <= 2047) {
						b.writeByte(192 | k >> 6);
						b.writeByte(128 | k & 63);
					} else {
						b.writeByte(224 | k >> 12);
						b.writeByte(128 | k >> 6 & 63);
						b.writeByte(128 | k & 63);
					}
					break;
				default:
					this.invalidChar(c);
				}
			} else if(c == 92) {
				esc = true;
			} else if(c == until) {
				break;
			} else {
				if(c == 10) {
					this.line++;
				}
				b.writeByte(c);
			}
		}
		return b.getBytes().toString();
	}
	,token: function() {
		if(this.tokens.head != null) {
			var _this = this.tokens;
			var k = _this.head;
			if(k == null) {
				return null;
			} else {
				_this.head = k.next;
				return k.elt;
			}
		}
		var char;
		if(this.char < 0) {
			char = this.readChar();
		} else {
			char = this.char;
			this.char = -1;
		}
		while(true) {
			switch(char) {
			case 0:
				return hscript_Token.TEof;
			case 10:
				this.line++;
				break;
			case 9:case 13:case 32:
				break;
			case 35:
				char = this.readChar();
				if(this.idents[char]) {
					var id = String.fromCodePoint(char);
					while(true) {
						char = this.readChar();
						if(!this.idents[char]) {
							this.char = char;
							return this.preprocess(id);
						}
						id += String.fromCodePoint(char);
					}
				}
				this.invalidChar(char);
				break;
			case 34:case 39:
				return hscript_Token.TConst(hscript_Const.CString(this.readString(char)));
			case 40:
				return hscript_Token.TPOpen;
			case 41:
				return hscript_Token.TPClose;
			case 44:
				return hscript_Token.TComma;
			case 46:
				char = this.readChar();
				switch(char) {
				case 46:
					char = this.readChar();
					if(char != 46) {
						this.invalidChar(char);
					}
					return hscript_Token.TOp("...");
				case 48:case 49:case 50:case 51:case 52:case 53:case 54:case 55:case 56:case 57:
					var n = char - 48;
					var exp = 1;
					while(true) {
						char = this.readChar();
						exp *= 10;
						switch(char) {
						case 48:case 49:case 50:case 51:case 52:case 53:case 54:case 55:case 56:case 57:
							n = n * 10 + (char - 48);
							break;
						default:
							this.char = char;
							return hscript_Token.TConst(hscript_Const.CFloat(n / exp));
						}
					}
					break;
				default:
					this.char = char;
					return hscript_Token.TDot;
				}
				break;
			case 48:case 49:case 50:case 51:case 52:case 53:case 54:case 55:case 56:case 57:
				var n1 = (char - 48) * 1.0;
				var exp1 = 0.;
				while(true) {
					char = this.readChar();
					exp1 *= 10;
					switch(char) {
					case 46:
						if(exp1 > 0) {
							if(exp1 == 10 && this.readChar() == 46) {
								var _this = this.tokens;
								_this.head = new haxe_ds_GenericCell(hscript_Token.TOp("..."),_this.head);
								var i = n1 | 0;
								return hscript_Token.TConst(i == n1 ? hscript_Const.CInt(i) : hscript_Const.CFloat(n1));
							}
							this.invalidChar(char);
						}
						exp1 = 1.;
						break;
					case 48:case 49:case 50:case 51:case 52:case 53:case 54:case 55:case 56:case 57:
						n1 = n1 * 10 + (char - 48);
						break;
					case 69:case 101:
						var tk = this.token();
						var pow = null;
						if(tk == null) {
							var _this1 = this.tokens;
							_this1.head = new haxe_ds_GenericCell(tk,_this1.head);
						} else {
							switch(tk._hx_index) {
							case 1:
								var _g = tk.c;
								if(_g._hx_index == 0) {
									var e = _g.v;
									pow = e;
								} else {
									var _this2 = this.tokens;
									_this2.head = new haxe_ds_GenericCell(tk,_this2.head);
								}
								break;
							case 3:
								if(tk.s == "-") {
									tk = this.token();
									if(tk == null) {
										var _this3 = this.tokens;
										_this3.head = new haxe_ds_GenericCell(tk,_this3.head);
									} else if(tk._hx_index == 1) {
										var _g1 = tk.c;
										if(_g1._hx_index == 0) {
											var e1 = _g1.v;
											pow = -e1;
										} else {
											var _this4 = this.tokens;
											_this4.head = new haxe_ds_GenericCell(tk,_this4.head);
										}
									} else {
										var _this5 = this.tokens;
										_this5.head = new haxe_ds_GenericCell(tk,_this5.head);
									}
								} else {
									var _this6 = this.tokens;
									_this6.head = new haxe_ds_GenericCell(tk,_this6.head);
								}
								break;
							default:
								var _this7 = this.tokens;
								_this7.head = new haxe_ds_GenericCell(tk,_this7.head);
							}
						}
						if(pow == null) {
							this.invalidChar(char);
						}
						return hscript_Token.TConst(hscript_Const.CFloat(Math.pow(10,pow) / exp1 * n1 * 10));
					case 120:
						if(n1 > 0 || exp1 > 0) {
							this.invalidChar(char);
						}
						var n2 = 0;
						while(true) {
							char = this.readChar();
							switch(char) {
							case 48:case 49:case 50:case 51:case 52:case 53:case 54:case 55:case 56:case 57:
								n2 = (n2 << 4) + char - 48;
								break;
							case 65:case 66:case 67:case 68:case 69:case 70:
								n2 = (n2 << 4) + (char - 55);
								break;
							case 97:case 98:case 99:case 100:case 101:case 102:
								n2 = (n2 << 4) + (char - 87);
								break;
							default:
								this.char = char;
								return hscript_Token.TConst(hscript_Const.CInt(n2));
							}
						}
						break;
					default:
						this.char = char;
						var i1 = n1 | 0;
						return hscript_Token.TConst(exp1 > 0 ? hscript_Const.CFloat(n1 * 10 / exp1) : i1 == n1 ? hscript_Const.CInt(i1) : hscript_Const.CFloat(n1));
					}
				}
				break;
			case 58:
				return hscript_Token.TDoubleDot;
			case 59:
				return hscript_Token.TSemicolon;
			case 61:
				char = this.readChar();
				if(char == 61) {
					return hscript_Token.TOp("==");
				} else if(char == 62) {
					return hscript_Token.TOp("=>");
				}
				this.char = char;
				return hscript_Token.TOp("=");
			case 63:
				return hscript_Token.TQuestion;
			case 64:
				char = this.readChar();
				if(this.idents[char] || char == 58) {
					var id1 = String.fromCodePoint(char);
					while(true) {
						char = this.readChar();
						if(!this.idents[char]) {
							this.char = char;
							return hscript_Token.TMeta(id1);
						}
						id1 += String.fromCodePoint(char);
					}
				}
				this.invalidChar(char);
				break;
			case 91:
				return hscript_Token.TBkOpen;
			case 93:
				return hscript_Token.TBkClose;
			case 123:
				return hscript_Token.TBrOpen;
			case 125:
				return hscript_Token.TBrClose;
			default:
				if(this.ops[char]) {
					var op = String.fromCodePoint(char);
					var prev = -1;
					while(true) {
						char = this.readChar();
						if(!this.ops[char] || prev == 61) {
							if(HxOverrides.cca(op,0) == 47) {
								return this.tokenComment(op,char);
							}
							this.char = char;
							return hscript_Token.TOp(op);
						}
						prev = char;
						op += String.fromCodePoint(char);
					}
				}
				if(this.idents[char]) {
					var id2 = String.fromCodePoint(char);
					while(true) {
						char = this.readChar();
						if(!this.idents[char]) {
							this.char = char;
							return hscript_Token.TId(id2);
						}
						id2 += String.fromCodePoint(char);
					}
				}
				this.invalidChar(char);
			}
			char = this.readChar();
		}
	}
	,preprocValue: function(id) {
		return this.preprocesorValues.h[id];
	}
	,parsePreproCond: function() {
		var tk = this.token();
		if(tk == null) {
			return this.unexpected(tk);
		} else {
			switch(tk._hx_index) {
			case 2:
				var id = tk.s;
				return hscript_Expr.EIdent(id);
			case 3:
				if(tk.s == "!") {
					return hscript_Expr.EUnop("!",true,this.parsePreproCond());
				} else {
					return this.unexpected(tk);
				}
				break;
			case 4:
				var _this = this.tokens;
				_this.head = new haxe_ds_GenericCell(hscript_Token.TPOpen,_this.head);
				return this.parseExpr();
			default:
				return this.unexpected(tk);
			}
		}
	}
	,evalPreproCond: function(e) {
		switch(e._hx_index) {
		case 1:
			var id = e.v;
			return this.preprocValue(id) != null;
		case 3:
			var e1 = e.e;
			return this.evalPreproCond(e1);
		case 6:
			var _g = e.e1;
			var _g1 = e.e2;
			switch(e.op) {
			case "&&":
				var e1 = _g;
				var e2 = _g1;
				if(this.evalPreproCond(e1)) {
					return this.evalPreproCond(e2);
				} else {
					return false;
				}
				break;
			case "||":
				var e1 = _g;
				var e2 = _g1;
				if(!this.evalPreproCond(e1)) {
					return this.evalPreproCond(e2);
				} else {
					return true;
				}
				break;
			default:
				throw haxe_Exception.thrown(hscript_Error.EInvalidPreprocessor("Can't eval " + $hxEnums[e.__enum__].__constructs__[e._hx_index]._hx_name));
			}
			break;
		case 7:
			var _g = e.prefix;
			if(e.op == "!") {
				var e1 = e.e;
				return !this.evalPreproCond(e1);
			} else {
				throw haxe_Exception.thrown(hscript_Error.EInvalidPreprocessor("Can't eval " + $hxEnums[e.__enum__].__constructs__[e._hx_index]._hx_name));
			}
			break;
		default:
			throw haxe_Exception.thrown(hscript_Error.EInvalidPreprocessor("Can't eval " + $hxEnums[e.__enum__].__constructs__[e._hx_index]._hx_name));
		}
	}
	,preprocess: function(id) {
		switch(id) {
		case "else":case "elseif":
			if(this.preprocStack.length > 0) {
				if(this.preprocStack[this.preprocStack.length - 1].r) {
					this.preprocStack[this.preprocStack.length - 1].r = false;
					this.skipTokens();
					return this.token();
				} else if(id == "else") {
					this.preprocStack.pop();
					this.preprocStack.push({ r : true});
					return this.token();
				} else {
					this.preprocStack.pop();
					return this.preprocess("if");
				}
			} else {
				return hscript_Token.TPrepro(id);
			}
			break;
		case "end":
			if(this.preprocStack.length > 0) {
				this.preprocStack.pop();
				return this.token();
			} else {
				return hscript_Token.TPrepro(id);
			}
			break;
		case "if":
			var e = this.parsePreproCond();
			if(this.evalPreproCond(e)) {
				this.preprocStack.push({ r : true});
				return this.token();
			}
			this.preprocStack.push({ r : false});
			this.skipTokens();
			return this.token();
		default:
			return hscript_Token.TPrepro(id);
		}
	}
	,skipTokens: function() {
		var spos = this.preprocStack.length - 1;
		var obj = this.preprocStack[spos];
		var pos = 0;
		while(true) {
			var tk = this.token();
			if(tk == hscript_Token.TEof) {
				throw haxe_Exception.thrown(hscript_Error.EInvalidPreprocessor("Unclosed"));
			}
			if(this.preprocStack[spos] != obj) {
				var _this = this.tokens;
				_this.head = new haxe_ds_GenericCell(tk,_this.head);
				break;
			}
		}
	}
	,tokenComment: function(op,char) {
		var c = HxOverrides.cca(op,1);
		var s = this.input;
		if(c == 47) {
			try {
				while(char != 13 && char != 10) char = s.readByte();
				this.char = char;
			} catch( _g ) {
			}
			return this.token();
		}
		if(c == 42) {
			var old = this.line;
			if(op == "/**/") {
				this.char = char;
				return this.token();
			}
			try {
				while(true) {
					while(char != 42) {
						if(char == 10) {
							this.line++;
						}
						char = s.readByte();
					}
					char = s.readByte();
					if(char == 47) {
						break;
					}
				}
			} catch( _g ) {
				this.line = old;
				throw haxe_Exception.thrown(hscript_Error.EUnterminatedComment);
			}
			return this.token();
		}
		this.char = char;
		return hscript_Token.TOp(op);
	}
	,constString: function(c) {
		switch(c._hx_index) {
		case 0:
			var v = c.v;
			if(v == null) {
				return "null";
			} else {
				return "" + v;
			}
			break;
		case 1:
			var f = c.f;
			if(f == null) {
				return "null";
			} else {
				return "" + f;
			}
			break;
		case 2:
			var s = c.s;
			return s;
		}
	}
	,tokenString: function(t) {
		switch(t._hx_index) {
		case 0:
			return "<eof>";
		case 1:
			var c = t.c;
			return this.constString(c);
		case 2:
			var s = t.s;
			return s;
		case 3:
			var s = t.s;
			return s;
		case 4:
			return "(";
		case 5:
			return ")";
		case 6:
			return "{";
		case 7:
			return "}";
		case 8:
			return ".";
		case 9:
			return ",";
		case 10:
			return ";";
		case 11:
			return "[";
		case 12:
			return "]";
		case 13:
			return "?";
		case 14:
			return ":";
		case 15:
			var id = t.s;
			return "@" + id;
		case 16:
			var id = t.s;
			return "#" + id;
		}
	}
	,__class__: hscript_Parser
};
var hscript_Tools = function() { };
$hxClasses["hscript.Tools"] = hscript_Tools;
hscript_Tools.__name__ = true;
hscript_Tools.iter = function(e,f) {
	switch(e._hx_index) {
	case 0:
		var _g = e.c;
		break;
	case 1:
		var _g = e.v;
		break;
	case 2:
		var _g = e.n;
		var _g = e.t;
		var e1 = e.e;
		if(e1 != null) {
			f(e1);
		}
		break;
	case 3:
		var e1 = e.e;
		f(e1);
		break;
	case 4:
		var el = e.e;
		var _g = 0;
		while(_g < el.length) {
			var e1 = el[_g];
			++_g;
			f(e1);
		}
		break;
	case 5:
		var _g = e.f;
		var e1 = e.e;
		f(e1);
		break;
	case 6:
		var _g = e.op;
		var e1 = e.e1;
		var e2 = e.e2;
		f(e1);
		f(e2);
		break;
	case 7:
		var _g = e.op;
		var _g = e.prefix;
		var e1 = e.e;
		f(e1);
		break;
	case 8:
		var e1 = e.e;
		var args = e.params;
		f(e1);
		var _g = 0;
		while(_g < args.length) {
			var a = args[_g];
			++_g;
			f(a);
		}
		break;
	case 9:
		var c = e.cond;
		var e1 = e.e1;
		var e2 = e.e2;
		f(c);
		f(e1);
		if(e2 != null) {
			f(e2);
		}
		break;
	case 10:
		var c = e.cond;
		var e1 = e.e;
		f(c);
		f(e1);
		break;
	case 11:
		var _g = e.v;
		var it = e.it;
		var e1 = e.e;
		f(it);
		f(e1);
		break;
	case 12:case 13:
		break;
	case 14:
		var _g = e.args;
		var _g = e.name;
		var _g = e.ret;
		var e1 = e.e;
		f(e1);
		break;
	case 15:
		var e1 = e.e;
		if(e1 != null) {
			f(e1);
		}
		break;
	case 16:
		var e1 = e.e;
		var i = e.index;
		f(e1);
		f(i);
		break;
	case 17:
		var el = e.e;
		var _g = 0;
		while(_g < el.length) {
			var e1 = el[_g];
			++_g;
			f(e1);
		}
		break;
	case 18:
		var _g = e.cl;
		var el = e.params;
		var _g = 0;
		while(_g < el.length) {
			var e1 = el[_g];
			++_g;
			f(e1);
		}
		break;
	case 19:
		var e1 = e.e;
		f(e1);
		break;
	case 20:
		var _g = e.v;
		var _g = e.t;
		var e1 = e.e;
		var c = e.ecatch;
		f(e1);
		f(c);
		break;
	case 21:
		var fl = e.fl;
		var _g = 0;
		while(_g < fl.length) {
			var fi = fl[_g];
			++_g;
			f(fi.e);
		}
		break;
	case 22:
		var c = e.cond;
		var e1 = e.e1;
		var e2 = e.e2;
		f(c);
		f(e1);
		f(e2);
		break;
	case 23:
		var e1 = e.e;
		var cases = e.cases;
		var def = e.defaultExpr;
		f(e1);
		var _g = 0;
		while(_g < cases.length) {
			var c = cases[_g];
			++_g;
			var _g1 = 0;
			var _g2 = c.values;
			while(_g1 < _g2.length) {
				var v = _g2[_g1];
				++_g1;
				f(v);
			}
			f(c.expr);
		}
		if(def != null) {
			f(def);
		}
		break;
	case 24:
		var c = e.cond;
		var e1 = e.e;
		f(c);
		f(e1);
		break;
	case 25:
		var name = e.name;
		var args = e.args;
		var e1 = e.e;
		if(args != null) {
			var _g = 0;
			while(_g < args.length) {
				var a = args[_g];
				++_g;
				f(a);
			}
		}
		f(e1);
		break;
	case 26:
		var _g = e.t;
		var e1 = e.e;
		f(e1);
		break;
	}
};
hscript_Tools.map = function(e,f) {
	var edef;
	switch(e._hx_index) {
	case 0:
		var _g = e.c;
		edef = e;
		break;
	case 1:
		var _g = e.v;
		edef = e;
		break;
	case 2:
		var n = e.n;
		var t = e.t;
		var e1 = e.e;
		edef = hscript_Expr.EVar(n,t,e1 != null ? f(e1) : null);
		break;
	case 3:
		var e1 = e.e;
		edef = hscript_Expr.EParent(f(e1));
		break;
	case 4:
		var el = e.e;
		var _g = [];
		var _g1 = 0;
		while(_g1 < el.length) {
			var e1 = el[_g1];
			++_g1;
			_g.push(f(e1));
		}
		edef = hscript_Expr.EBlock(_g);
		break;
	case 5:
		var e1 = e.e;
		var fi = e.f;
		edef = hscript_Expr.EField(f(e1),fi);
		break;
	case 6:
		var op = e.op;
		var e1 = e.e1;
		var e2 = e.e2;
		edef = hscript_Expr.EBinop(op,f(e1),f(e2));
		break;
	case 7:
		var op = e.op;
		var pre = e.prefix;
		var e1 = e.e;
		edef = hscript_Expr.EUnop(op,pre,f(e1));
		break;
	case 8:
		var e1 = e.e;
		var args = e.params;
		var edef1 = f(e1);
		var _g = [];
		var _g1 = 0;
		while(_g1 < args.length) {
			var a = args[_g1];
			++_g1;
			_g.push(f(a));
		}
		edef = hscript_Expr.ECall(edef1,_g);
		break;
	case 9:
		var c = e.cond;
		var e1 = e.e1;
		var e2 = e.e2;
		edef = hscript_Expr.EIf(f(c),f(e1),e2 != null ? f(e2) : null);
		break;
	case 10:
		var c = e.cond;
		var e1 = e.e;
		edef = hscript_Expr.EWhile(f(c),f(e1));
		break;
	case 11:
		var v = e.v;
		var it = e.it;
		var e1 = e.e;
		edef = hscript_Expr.EFor(v,f(it),f(e1));
		break;
	case 12:case 13:
		edef = e;
		break;
	case 14:
		var args = e.args;
		var e1 = e.e;
		var name = e.name;
		var t = e.ret;
		edef = hscript_Expr.EFunction(args,f(e1),name,t);
		break;
	case 15:
		var e1 = e.e;
		edef = hscript_Expr.EReturn(e1 != null ? f(e1) : null);
		break;
	case 16:
		var e1 = e.e;
		var i = e.index;
		edef = hscript_Expr.EArray(f(e1),f(i));
		break;
	case 17:
		var el = e.e;
		var _g = [];
		var _g1 = 0;
		while(_g1 < el.length) {
			var e1 = el[_g1];
			++_g1;
			_g.push(f(e1));
		}
		edef = hscript_Expr.EArrayDecl(_g);
		break;
	case 18:
		var cl = e.cl;
		var el = e.params;
		var _g = [];
		var _g1 = 0;
		while(_g1 < el.length) {
			var e1 = el[_g1];
			++_g1;
			_g.push(f(e1));
		}
		edef = hscript_Expr.ENew(cl,_g);
		break;
	case 19:
		var e1 = e.e;
		edef = hscript_Expr.EThrow(f(e1));
		break;
	case 20:
		var e1 = e.e;
		var v = e.v;
		var t = e.t;
		var c = e.ecatch;
		edef = hscript_Expr.ETry(f(e1),v,t,f(c));
		break;
	case 21:
		var fl = e.fl;
		var _g = [];
		var _g1 = 0;
		while(_g1 < fl.length) {
			var fi = fl[_g1];
			++_g1;
			_g.push({ name : fi.name, e : f(fi.e)});
		}
		edef = hscript_Expr.EObject(_g);
		break;
	case 22:
		var c = e.cond;
		var e1 = e.e1;
		var e2 = e.e2;
		edef = hscript_Expr.ETernary(f(c),f(e1),f(e2));
		break;
	case 23:
		var e1 = e.e;
		var cases = e.cases;
		var def = e.defaultExpr;
		var edef1 = f(e1);
		var _g = [];
		var _g1 = 0;
		while(_g1 < cases.length) {
			var c = cases[_g1];
			++_g1;
			var _g2 = [];
			var _g3 = 0;
			var _g4 = c.values;
			while(_g3 < _g4.length) {
				var v = _g4[_g3];
				++_g3;
				_g2.push(f(v));
			}
			_g.push({ values : _g2, expr : f(c.expr)});
		}
		edef = hscript_Expr.ESwitch(edef1,_g,def == null ? null : f(def));
		break;
	case 24:
		var c = e.cond;
		var e1 = e.e;
		edef = hscript_Expr.EDoWhile(f(c),f(e1));
		break;
	case 25:
		var name = e.name;
		var args = e.args;
		var e1 = e.e;
		var edef1;
		if(args == null) {
			edef1 = null;
		} else {
			var _g = [];
			var _g1 = 0;
			while(_g1 < args.length) {
				var a = args[_g1];
				++_g1;
				_g.push(f(a));
			}
			edef1 = _g;
		}
		edef = hscript_Expr.EMeta(name,edef1,f(e1));
		break;
	case 26:
		var e1 = e.e;
		var t = e.t;
		edef = hscript_Expr.ECheckType(f(e1),t);
		break;
	}
	return edef;
};
hscript_Tools.expr = function(e) {
	return e;
};
hscript_Tools.mk = function(e,p) {
	return e;
};
var js_Boot = function() { };
$hxClasses["js.Boot"] = js_Boot;
js_Boot.__name__ = true;
js_Boot.getClass = function(o) {
	if(o == null) {
		return null;
	} else if(((o) instanceof Array)) {
		return Array;
	} else {
		var cl = o.__class__;
		if(cl != null) {
			return cl;
		}
		var name = js_Boot.__nativeClassName(o);
		if(name != null) {
			return js_Boot.__resolveNativeClass(name);
		}
		return null;
	}
};
js_Boot.__string_rec = function(o,s) {
	if(o == null) {
		return "null";
	}
	if(s.length >= 5) {
		return "<...>";
	}
	var t = typeof(o);
	if(t == "function" && (o.__name__ || o.__ename__)) {
		t = "object";
	}
	switch(t) {
	case "function":
		return "<function>";
	case "object":
		if(o.__enum__) {
			var e = $hxEnums[o.__enum__];
			var con = e.__constructs__[o._hx_index];
			var n = con._hx_name;
			if(con.__params__) {
				s = s + "\t";
				return n + "(" + ((function($this) {
					var $r;
					var _g = [];
					{
						var _g1 = 0;
						var _g2 = con.__params__;
						while(true) {
							if(!(_g1 < _g2.length)) {
								break;
							}
							var p = _g2[_g1];
							_g1 = _g1 + 1;
							_g.push(js_Boot.__string_rec(o[p],s));
						}
					}
					$r = _g;
					return $r;
				}(this))).join(",") + ")";
			} else {
				return n;
			}
		}
		if(((o) instanceof Array)) {
			var str = "[";
			s += "\t";
			var _g = 0;
			var _g1 = o.length;
			while(_g < _g1) {
				var i = _g++;
				str += (i > 0 ? "," : "") + js_Boot.__string_rec(o[i],s);
			}
			str += "]";
			return str;
		}
		var tostr;
		try {
			tostr = o.toString;
		} catch( _g ) {
			return "???";
		}
		if(tostr != null && tostr != Object.toString && typeof(tostr) == "function") {
			var s2 = o.toString();
			if(s2 != "[object Object]") {
				return s2;
			}
		}
		var str = "{\n";
		s += "\t";
		var hasp = o.hasOwnProperty != null;
		var k = null;
		for( k in o ) {
		if(hasp && !o.hasOwnProperty(k)) {
			continue;
		}
		if(k == "prototype" || k == "__class__" || k == "__super__" || k == "__interfaces__" || k == "__properties__") {
			continue;
		}
		if(str.length != 2) {
			str += ", \n";
		}
		str += s + k + " : " + js_Boot.__string_rec(o[k],s);
		}
		s = s.substring(1);
		str += "\n" + s + "}";
		return str;
	case "string":
		return o;
	default:
		return String(o);
	}
};
js_Boot.__interfLoop = function(cc,cl) {
	if(cc == null) {
		return false;
	}
	if(cc == cl) {
		return true;
	}
	var intf = cc.__interfaces__;
	if(intf != null) {
		var _g = 0;
		var _g1 = intf.length;
		while(_g < _g1) {
			var i = _g++;
			var i1 = intf[i];
			if(i1 == cl || js_Boot.__interfLoop(i1,cl)) {
				return true;
			}
		}
	}
	return js_Boot.__interfLoop(cc.__super__,cl);
};
js_Boot.__instanceof = function(o,cl) {
	if(cl == null) {
		return false;
	}
	switch(cl) {
	case Array:
		return ((o) instanceof Array);
	case Bool:
		return typeof(o) == "boolean";
	case Dynamic:
		return o != null;
	case Float:
		return typeof(o) == "number";
	case Int:
		if(typeof(o) == "number") {
			return ((o | 0) === o);
		} else {
			return false;
		}
		break;
	case String:
		return typeof(o) == "string";
	default:
		if(o != null) {
			if(typeof(cl) == "function") {
				if(js_Boot.__downcastCheck(o,cl)) {
					return true;
				}
			} else if(typeof(cl) == "object" && js_Boot.__isNativeObj(cl)) {
				if(((o) instanceof cl)) {
					return true;
				}
			}
		} else {
			return false;
		}
		if(cl == Class ? o.__name__ != null : false) {
			return true;
		}
		if(cl == Enum ? o.__ename__ != null : false) {
			return true;
		}
		return o.__enum__ != null ? $hxEnums[o.__enum__] == cl : false;
	}
};
js_Boot.__downcastCheck = function(o,cl) {
	if(!((o) instanceof cl)) {
		if(cl.__isInterface__) {
			return js_Boot.__interfLoop(js_Boot.getClass(o),cl);
		} else {
			return false;
		}
	} else {
		return true;
	}
};
js_Boot.__implements = function(o,iface) {
	return js_Boot.__interfLoop(js_Boot.getClass(o),iface);
};
js_Boot.__cast = function(o,t) {
	if(o == null || js_Boot.__instanceof(o,t)) {
		return o;
	} else {
		throw haxe_Exception.thrown("Cannot cast " + Std.string(o) + " to " + Std.string(t));
	}
};
js_Boot.__nativeClassName = function(o) {
	var name = js_Boot.__toStr.call(o).slice(8,-1);
	if(name == "Object" || name == "Function" || name == "Math" || name == "JSON") {
		return null;
	}
	return name;
};
js_Boot.__isNativeObj = function(o) {
	return js_Boot.__nativeClassName(o) != null;
};
js_Boot.__resolveNativeClass = function(name) {
	return $global[name];
};
var js_node_ChildProcess = require("child_process");
var js_node_Fs = require("fs");
var js_node_Http = require("http");
var js_node_KeyValue = {};
js_node_KeyValue.__properties__ = {get_value:"get_value",get_key:"get_key"};
js_node_KeyValue.get_key = function(this1) {
	return this1[0];
};
js_node_KeyValue.get_value = function(this1) {
	return this1[1];
};
var js_node_Os = require("os");
var js_node_Path = require("path");
var js_node_buffer_Buffer = require("buffer").Buffer;
var js_node_stream_WritableNewOptionsAdapter = {};
js_node_stream_WritableNewOptionsAdapter.from = function(options) {
	if(!Object.prototype.hasOwnProperty.call(options,"final")) {
		Object.defineProperty(options,"final",{ get : function() {
			return options.final_;
		}});
	}
	return options;
};
var js_node_url_URLSearchParamsEntry = {};
js_node_url_URLSearchParamsEntry.__properties__ = {get_value:"get_value",get_name:"get_name"};
js_node_url_URLSearchParamsEntry._new = function(name,value) {
	var this1 = [name,value];
	return this1;
};
js_node_url_URLSearchParamsEntry.get_name = function(this1) {
	return this1[0];
};
js_node_url_URLSearchParamsEntry.get_value = function(this1) {
	return this1[1];
};
var npm_Colors = require("colors/safe");
var npm_Future = require("fibers/future");
var npm_Glob = require("glob");
var npm_WebSocket = require("ws");
var npm_WebSocketServer = require("ws").Server;
var npm_Yaml = require("yamljs");
var sys_FileSystem = function() { };
$hxClasses["sys.FileSystem"] = sys_FileSystem;
sys_FileSystem.__name__ = true;
sys_FileSystem.exists = function(path) {
	try {
		js_node_Fs.accessSync(path);
		return true;
	} catch( _g ) {
		return false;
	}
};
sys_FileSystem.isDirectory = function(path) {
	try {
		return js_node_Fs.statSync(path).isDirectory();
	} catch( _g ) {
		return false;
	}
};
sys_FileSystem.createDirectory = function(path) {
	try {
		js_node_Fs.mkdirSync(path);
	} catch( _g ) {
		var e = haxe_Exception.caught(_g).unwrap();
		if(e.code == "ENOENT") {
			sys_FileSystem.createDirectory(js_node_Path.dirname(path));
			js_node_Fs.mkdirSync(path);
		} else {
			var stat;
			try {
				stat = js_node_Fs.statSync(path);
			} catch( _g1 ) {
				throw e;
			}
			if(!stat.isDirectory()) {
				throw e;
			}
		}
	}
};
sys_FileSystem.deleteDirectory = function(path) {
	if(sys_FileSystem.exists(path)) {
		var _g = 0;
		var _g1 = js_node_Fs.readdirSync(path);
		while(_g < _g1.length) {
			var file = _g1[_g];
			++_g;
			var curPath = path + "/" + file;
			if(sys_FileSystem.isDirectory(curPath)) {
				sys_FileSystem.deleteDirectory(curPath);
			} else {
				js_node_Fs.unlinkSync(curPath);
			}
		}
		js_node_Fs.rmdirSync(path);
	}
};
var sys_io_File = function() { };
$hxClasses["sys.io.File"] = sys_io_File;
sys_io_File.__name__ = true;
sys_io_File.copy = function(srcPath,dstPath) {
	var src = js_node_Fs.openSync(srcPath,"r");
	var stat = js_node_Fs.fstatSync(src);
	var dst = js_node_Fs.openSync(dstPath,"w",stat.mode);
	var bytesRead;
	var pos = 0;
	while(true) {
		bytesRead = js_node_Fs.readSync(src,sys_io_File.copyBuf,0,65536,pos);
		if(!(bytesRead > 0)) {
			break;
		}
		js_node_Fs.writeSync(dst,sys_io_File.copyBuf,0,bytesRead);
		pos += bytesRead;
	}
	js_node_Fs.closeSync(src);
	js_node_Fs.closeSync(dst);
};
var sys_io_FileInput = function(fd) {
	this.fd = fd;
	this.pos = 0;
};
$hxClasses["sys.io.FileInput"] = sys_io_FileInput;
sys_io_FileInput.__name__ = true;
sys_io_FileInput.__super__ = haxe_io_Input;
sys_io_FileInput.prototype = $extend(haxe_io_Input.prototype,{
	readByte: function() {
		var buf = js_node_buffer_Buffer.alloc(1);
		var bytesRead;
		try {
			bytesRead = js_node_Fs.readSync(this.fd,buf,0,1,this.pos);
		} catch( _g ) {
			var e = haxe_Exception.caught(_g).unwrap();
			if(e.code == "EOF") {
				throw haxe_Exception.thrown(new haxe_io_Eof());
			} else {
				throw haxe_Exception.thrown(haxe_io_Error.Custom(e));
			}
		}
		if(bytesRead == 0) {
			throw haxe_Exception.thrown(new haxe_io_Eof());
		}
		this.pos++;
		return buf[0];
	}
	,readBytes: function(s,pos,len) {
		var data = s.b;
		var buf = js_node_buffer_Buffer.from(data.buffer,data.byteOffset,s.length);
		var bytesRead;
		try {
			bytesRead = js_node_Fs.readSync(this.fd,buf,pos,len,this.pos);
		} catch( _g ) {
			var e = haxe_Exception.caught(_g).unwrap();
			if(e.code == "EOF") {
				throw haxe_Exception.thrown(new haxe_io_Eof());
			} else {
				throw haxe_Exception.thrown(haxe_io_Error.Custom(e));
			}
		}
		if(bytesRead == 0) {
			throw haxe_Exception.thrown(new haxe_io_Eof());
		}
		this.pos += bytesRead;
		return bytesRead;
	}
	,close: function() {
		js_node_Fs.closeSync(this.fd);
	}
	,seek: function(p,pos) {
		switch(pos._hx_index) {
		case 0:
			this.pos = p;
			break;
		case 1:
			this.pos += p;
			break;
		case 2:
			this.pos = js_node_Fs.fstatSync(this.fd).size + p;
			break;
		}
	}
	,tell: function() {
		return this.pos;
	}
	,eof: function() {
		return this.pos >= js_node_Fs.fstatSync(this.fd).size;
	}
	,__class__: sys_io_FileInput
});
var sys_io_FileOutput = function(fd) {
	this.fd = fd;
	this.pos = 0;
};
$hxClasses["sys.io.FileOutput"] = sys_io_FileOutput;
sys_io_FileOutput.__name__ = true;
sys_io_FileOutput.__super__ = haxe_io_Output;
sys_io_FileOutput.prototype = $extend(haxe_io_Output.prototype,{
	writeByte: function(b) {
		var buf = js_node_buffer_Buffer.alloc(1);
		buf[0] = b;
		js_node_Fs.writeSync(this.fd,buf,0,1,this.pos);
		this.pos++;
	}
	,writeBytes: function(s,pos,len) {
		var data = s.b;
		var buf = js_node_buffer_Buffer.from(data.buffer,data.byteOffset,s.length);
		var wrote = js_node_Fs.writeSync(this.fd,buf,pos,len,this.pos);
		this.pos += wrote;
		return wrote;
	}
	,close: function() {
		js_node_Fs.closeSync(this.fd);
	}
	,seek: function(p,pos) {
		switch(pos._hx_index) {
		case 0:
			this.pos = p;
			break;
		case 1:
			this.pos += p;
			break;
		case 2:
			this.pos = js_node_Fs.fstatSync(this.fd).size + p;
			break;
		}
	}
	,tell: function() {
		return this.pos;
	}
	,__class__: sys_io_FileOutput
});
var sys_io_FileSeek = $hxEnums["sys.io.FileSeek"] = { __ename__:true,__constructs__:null
	,SeekBegin: {_hx_name:"SeekBegin",_hx_index:0,__enum__:"sys.io.FileSeek",toString:$estr}
	,SeekCur: {_hx_name:"SeekCur",_hx_index:1,__enum__:"sys.io.FileSeek",toString:$estr}
	,SeekEnd: {_hx_name:"SeekEnd",_hx_index:2,__enum__:"sys.io.FileSeek",toString:$estr}
};
sys_io_FileSeek.__constructs__ = [sys_io_FileSeek.SeekBegin,sys_io_FileSeek.SeekCur,sys_io_FileSeek.SeekEnd];
var tools_Asset = function(name,rootDirectory) {
	this.name = name;
	this.rootDirectory = rootDirectory;
	this.absolutePath = haxe_io_Path.join([rootDirectory,name]);
};
$hxClasses["tools.Asset"] = tools_Asset;
tools_Asset.__name__ = true;
tools_Asset.prototype = {
	__class__: tools_Asset
};
var tools_BuildConfig = $hxEnums["tools.BuildConfig"] = { __ename__:true,__constructs__:null
	,Build: ($_=function(displayName) { return {_hx_index:0,displayName:displayName,__enum__:"tools.BuildConfig",toString:$estr}; },$_._hx_name="Build",$_.__params__ = ["displayName"],$_)
	,Run: ($_=function(displayName) { return {_hx_index:1,displayName:displayName,__enum__:"tools.BuildConfig",toString:$estr}; },$_._hx_name="Run",$_.__params__ = ["displayName"],$_)
	,Clean: ($_=function(displayName) { return {_hx_index:2,displayName:displayName,__enum__:"tools.BuildConfig",toString:$estr}; },$_._hx_name="Clean",$_.__params__ = ["displayName"],$_)
};
tools_BuildConfig.__constructs__ = [tools_BuildConfig.Build,tools_BuildConfig.Run,tools_BuildConfig.Clean];
var tools_BuildTarget = function(name,displayName,configs) {
	this.name = name;
	this.displayName = displayName;
	this.configs = configs;
};
$hxClasses["tools.BuildTarget"] = tools_BuildTarget;
tools_BuildTarget.__name__ = true;
tools_BuildTarget.prototype = {
	__class__: tools_BuildTarget
};
var tools_BuildTargetExtensions = function() { };
$hxClasses["tools.BuildTargetExtensions"] = tools_BuildTargetExtensions;
tools_BuildTargetExtensions.__name__ = true;
tools_BuildTargetExtensions.outPath = function(target,group,cwd,debug,variant) {
	if(cwd == null) {
		cwd = tools_Helpers.context.cwd;
	}
	if(debug == null) {
		debug = tools_Helpers.context.debug;
	}
	if(variant == null) {
		variant = tools_Helpers.context.variant;
	}
	return tools_BuildTargetExtensions.outPathWithName(group,target.name,cwd,debug,variant);
};
tools_BuildTargetExtensions.outPathWithName = function(group,targetName,cwd,debug,variant) {
	if(cwd == null) {
		cwd = tools_Helpers.context.cwd;
	}
	if(debug == null) {
		debug = tools_Helpers.context.debug;
	}
	if(variant == null) {
		variant = tools_Helpers.context.variant;
	}
	return haxe_io_Path.join([cwd,"out",group,targetName + (variant != "standard" ? "-" + variant : "") + (debug ? "-debug" : "")]);
};
var tools_Colors = function() { };
$hxClasses["tools.Colors"] = tools_Colors;
tools_Colors.__name__ = true;
tools_Colors.black = function(str) {
	if(!tools_Helpers.context.colors) {
		return str;
	} else if(tools_Helpers.isElectronProxy()) {
		return "[|color:black|]" + str + "[|/color:black|]";
	} else {
		return npm_Colors.black(str);
	}
};
tools_Colors.red = function(str) {
	if(!tools_Helpers.context.colors) {
		return str;
	} else if(tools_Helpers.isElectronProxy()) {
		return "[|color:red|]" + str + "[|/color:red|]";
	} else {
		return npm_Colors.red(str);
	}
};
tools_Colors.green = function(str) {
	if(!tools_Helpers.context.colors) {
		return str;
	} else if(tools_Helpers.isElectronProxy()) {
		return "[|color:green|]" + str + "[|/color:green|]";
	} else {
		return npm_Colors.green(str);
	}
};
tools_Colors.yellow = function(str) {
	if(!tools_Helpers.context.colors) {
		return str;
	} else if(tools_Helpers.isElectronProxy()) {
		return "[|color:yellow|]" + str + "[|/color:yellow|]";
	} else {
		return npm_Colors.yellow(str);
	}
};
tools_Colors.blue = function(str) {
	if(!tools_Helpers.context.colors) {
		return str;
	} else if(tools_Helpers.isElectronProxy()) {
		return "[|color:blue|]" + str + "[|/color:blue|]";
	} else {
		return npm_Colors.blue(str);
	}
};
tools_Colors.magenta = function(str) {
	if(!tools_Helpers.context.colors) {
		return str;
	} else if(tools_Helpers.isElectronProxy()) {
		return "[|color:magenta|]" + str + "[|/color:magenta|]";
	} else {
		return npm_Colors.magenta(str);
	}
};
tools_Colors.cyan = function(str) {
	if(!tools_Helpers.context.colors) {
		return str;
	} else if(tools_Helpers.isElectronProxy()) {
		return "[|color:cyan|]" + str + "[|/color:cyan|]";
	} else {
		return npm_Colors.cyan(str);
	}
};
tools_Colors.white = function(str) {
	if(!tools_Helpers.context.colors) {
		return str;
	} else if(tools_Helpers.isElectronProxy()) {
		return "[|color:white|]" + str + "[|/color:white|]";
	} else {
		return npm_Colors.white(str);
	}
};
tools_Colors.gray = function(str) {
	if(!tools_Helpers.context.colors) {
		return str;
	} else if(tools_Helpers.isElectronProxy()) {
		return "[|color:gray|]" + str + "[|/color:gray|]";
	} else {
		return npm_Colors.gray(str);
	}
};
tools_Colors.grey = function(str) {
	if(!tools_Helpers.context.colors) {
		return str;
	} else if(tools_Helpers.isElectronProxy()) {
		return "[|color:grey|]" + str + "[|/color:grey|]";
	} else {
		return npm_Colors.grey(str);
	}
};
tools_Colors.bgBlack = function(str) {
	if(!tools_Helpers.context.colors) {
		return str;
	} else if(tools_Helpers.isElectronProxy()) {
		return "[|color:bgBlack|]" + str + "[|/color:bgBlack|]";
	} else {
		return npm_Colors.bgBlack(str);
	}
};
tools_Colors.bgRed = function(str) {
	if(!tools_Helpers.context.colors) {
		return str;
	} else if(tools_Helpers.isElectronProxy()) {
		return "[|color:bgRed|]" + str + "[|/color:bgRed|]";
	} else {
		return npm_Colors.bgRed(str);
	}
};
tools_Colors.bgGreen = function(str) {
	if(!tools_Helpers.context.colors) {
		return str;
	} else if(tools_Helpers.isElectronProxy()) {
		return "[|color:bgGreen|]" + str + "[|/color:bgGreen|]";
	} else {
		return npm_Colors.bgGreen(str);
	}
};
tools_Colors.bgYellow = function(str) {
	if(!tools_Helpers.context.colors) {
		return str;
	} else if(tools_Helpers.isElectronProxy()) {
		return "[|color:bgYellow|]" + str + "[|/color:bgYellow|]";
	} else {
		return npm_Colors.bgYellow(str);
	}
};
tools_Colors.bgBlue = function(str) {
	if(!tools_Helpers.context.colors) {
		return str;
	} else if(tools_Helpers.isElectronProxy()) {
		return "[|color:bgBlue|]" + str + "[|/color:bgBlue|]";
	} else {
		return npm_Colors.bgBlue(str);
	}
};
tools_Colors.bgMagenta = function(str) {
	if(!tools_Helpers.context.colors) {
		return str;
	} else if(tools_Helpers.isElectronProxy()) {
		return "[|color:bgMagenta|]" + str + "[|/color:bgMagenta|]";
	} else {
		return npm_Colors.bgMagenta(str);
	}
};
tools_Colors.bgCyan = function(str) {
	if(!tools_Helpers.context.colors) {
		return str;
	} else if(tools_Helpers.isElectronProxy()) {
		return "[|color:bgCyan|]" + str + "[|/color:bgCyan|]";
	} else {
		return npm_Colors.bgCyan(str);
	}
};
tools_Colors.bgWhite = function(str) {
	if(!tools_Helpers.context.colors) {
		return str;
	} else if(tools_Helpers.isElectronProxy()) {
		return "[|color:bgWhite|]" + str + "[|/color:bgWhite|]";
	} else {
		return npm_Colors.bgWhite(str);
	}
};
tools_Colors.reset = function(str) {
	if(!tools_Helpers.context.colors) {
		return str;
	} else if(tools_Helpers.isElectronProxy()) {
		return "[|color:reset|]" + str + "[|/color:reset|]";
	} else {
		return npm_Colors.reset(str);
	}
};
tools_Colors.bold = function(str) {
	if(!tools_Helpers.context.colors) {
		return str;
	} else if(tools_Helpers.isElectronProxy()) {
		return "[|color:bold|]" + str + "[|/color:bold|]";
	} else {
		return npm_Colors.bold(str);
	}
};
tools_Colors.dim = function(str) {
	if(!tools_Helpers.context.colors) {
		return str;
	} else if(tools_Helpers.isElectronProxy()) {
		return "[|color:dim|]" + str + "[|/color:bladimck|]";
	} else {
		return npm_Colors.dim(str);
	}
};
tools_Colors.italic = function(str) {
	if(!tools_Helpers.context.colors) {
		return str;
	} else if(tools_Helpers.isElectronProxy()) {
		return "[|color:italic|]" + str + "[|/color:italic|]";
	} else {
		return npm_Colors.italic(str);
	}
};
tools_Colors.underline = function(str) {
	if(!tools_Helpers.context.colors) {
		return str;
	} else if(tools_Helpers.isElectronProxy()) {
		return "[|color:underline|]" + str + "[|/color:underline|]";
	} else {
		return npm_Colors.underline(str);
	}
};
tools_Colors.inverse = function(str) {
	if(!tools_Helpers.context.colors) {
		return str;
	} else if(tools_Helpers.isElectronProxy()) {
		return "[|color:inverse|]" + str + "[|/color:inverse|]";
	} else {
		return npm_Colors.inverse(str);
	}
};
tools_Colors.hidden = function(str) {
	if(!tools_Helpers.context.colors) {
		return str;
	} else if(tools_Helpers.isElectronProxy()) {
		return "[|color:hidden|]" + str + "[|/color:hidden|]";
	} else {
		return npm_Colors.hidden(str);
	}
};
tools_Colors.strikethrough = function(str) {
	if(!tools_Helpers.context.colors) {
		return str;
	} else if(tools_Helpers.isElectronProxy()) {
		return "[|color:strikethrough|]" + str + "[|/color:strikethrough|]";
	} else {
		return npm_Colors.strikethrough(str);
	}
};
tools_Colors.rainbow = function(str) {
	if(!tools_Helpers.context.colors) {
		return str;
	} else if(tools_Helpers.isElectronProxy()) {
		return "[|color:rainbow|]" + str + "[|/color:rainbow|]";
	} else {
		return npm_Colors.rainbow(str);
	}
};
tools_Colors.zebra = function(str) {
	if(!tools_Helpers.context.colors) {
		return str;
	} else if(tools_Helpers.isElectronProxy()) {
		return "[|color:zebra|]" + str + "[|/color:zebra|]";
	} else {
		return npm_Colors.zebra(str);
	}
};
tools_Colors.america = function(str) {
	if(!tools_Helpers.context.colors) {
		return str;
	} else if(tools_Helpers.isElectronProxy()) {
		return "[|color:america|]" + str + "[|/color:america|]";
	} else {
		return npm_Colors.america(str);
	}
};
tools_Colors.trap = function(str) {
	if(!tools_Helpers.context.colors) {
		return str;
	} else if(tools_Helpers.isElectronProxy()) {
		return "[|color:trap|]" + str + "[|/color:trap|]";
	} else {
		return npm_Colors.trap(str);
	}
};
tools_Colors.random = function(str) {
	if(!tools_Helpers.context.colors) {
		return str;
	} else if(tools_Helpers.isElectronProxy()) {
		return "[|color:random|]" + str + "[|/color:random|]";
	} else {
		return npm_Colors.random(str);
	}
};
var tools_Files = function() { };
$hxClasses["tools.Files"] = tools_Files;
tools_Files.__name__ = true;
tools_Files.haveSameLastModified = function(filePath1,filePath2) {
	var file1Exists = sys_FileSystem.exists(filePath1);
	var file2Exists = sys_FileSystem.exists(filePath2);
	if(file1Exists != file2Exists) {
		return false;
	}
	if(!file1Exists && !file2Exists) {
		return false;
	}
	var time1 = js_node_Fs.statSync(filePath1).mtime.getTime();
	var time2 = js_node_Fs.statSync(filePath2).mtime.getTime();
	return Math.abs(time1 - time2) < 1000;
};
tools_Files.setToSameLastModified = function(srcFilePath,dstFilePath) {
	var file1Exists = sys_FileSystem.exists(srcFilePath);
	var file2Exists = sys_FileSystem.exists(dstFilePath);
	if(!file1Exists || !file2Exists) {
		return;
	}
	var utime = Math.round(js_node_Fs.statSync(srcFilePath).mtime.getTime() / 1000.0);
	js_node_Fs.utimesSync(dstFilePath,utime,utime);
};
tools_Files.getLastModified = function(filePath) {
	if(!sys_FileSystem.exists(filePath)) {
		return -1;
	}
	return Math.round(js_node_Fs.statSync(filePath).mtime.getTime() / 1000.0);
};
tools_Files.touch = function(filePath) {
	if(!sys_FileSystem.exists(filePath)) {
		if(!sys_FileSystem.exists(haxe_io_Path.directory(filePath))) {
			sys_FileSystem.createDirectory(haxe_io_Path.directory(filePath));
		}
		js_node_Fs.writeFileSync(filePath,"");
	}
	var utime = new Date().getTime() / 1000.0;
	js_node_Fs.utimesSync(filePath,utime,utime);
};
tools_Files.getFlatDirectory = function(dir,excludeSystemFiles,subCall) {
	if(subCall == null) {
		subCall = false;
	}
	if(excludeSystemFiles == null) {
		excludeSystemFiles = true;
	}
	var result = [];
	var _g = 0;
	var _g1 = js_node_Fs.readdirSync(dir);
	while(_g < _g1.length) {
		var name = _g1[_g];
		++_g;
		if(excludeSystemFiles && name == ".DS_Store") {
			continue;
		}
		var path = haxe_io_Path.join([dir,name]);
		if(sys_FileSystem.isDirectory(path)) {
			result = result.concat(tools_Files.getFlatDirectory(path,excludeSystemFiles,true));
		} else {
			result.push(path);
		}
	}
	if(!subCall) {
		var prevResult = result;
		result = [];
		var prefix = haxe_io_Path.normalize(dir);
		if(!StringTools.endsWith(prefix,"/")) {
			prefix += "/";
		}
		var _g = 0;
		while(_g < prevResult.length) {
			var item = prevResult[_g];
			++_g;
			result.push(HxOverrides.substr(item,prefix.length,null));
		}
	}
	return result;
};
tools_Files.removeEmptyDirectories = function(dir,excludeSystemFiles) {
	if(excludeSystemFiles == null) {
		excludeSystemFiles = true;
	}
	var _g = 0;
	var _g1 = js_node_Fs.readdirSync(dir);
	while(_g < _g1.length) {
		var name = _g1[_g];
		++_g;
		if(name == ".DS_Store") {
			continue;
		}
		var path = haxe_io_Path.join([dir,name]);
		if(sys_FileSystem.isDirectory(path)) {
			tools_Files.removeEmptyDirectories(path,excludeSystemFiles);
			if(tools_Files.isEmptyDirectory(path,excludeSystemFiles)) {
				tools_Files.deleteRecursive(path);
			}
		}
	}
};
tools_Files.isEmptyDirectory = function(dir,excludeSystemFiles) {
	if(excludeSystemFiles == null) {
		excludeSystemFiles = true;
	}
	var _g = 0;
	var _g1 = js_node_Fs.readdirSync(dir);
	while(_g < _g1.length) {
		var name = _g1[_g];
		++_g;
		if(name == ".DS_Store") {
			continue;
		}
		return false;
	}
	return true;
};
tools_Files.deleteAnyFileNamed = function(toDeleteName,inDirectory) {
	if(sys_FileSystem.isDirectory(inDirectory)) {
		var _g = 0;
		var _g1 = js_node_Fs.readdirSync(inDirectory);
		while(_g < _g1.length) {
			var name = _g1[_g];
			++_g;
			var path = haxe_io_Path.join([inDirectory,name]);
			if(name == toDeleteName) {
				if(sys_FileSystem.isDirectory(path)) {
					tools_Files.deleteRecursive(path);
				} else {
					js_node_Fs.unlinkSync(path);
				}
			} else if(sys_FileSystem.isDirectory(path)) {
				tools_Files.deleteAnyFileNamed(toDeleteName,path);
			}
		}
	} else {
		throw haxe_Exception.thrown("" + inDirectory + " is not a directory!");
	}
};
tools_Files.zipDirectory = function(srcDirectory,dstZip) {
	var os = Sys.systemName();
	if(os == "Mac" || os == "Linux") {
		tools_Helpers.command("zip",["-9","-r","-q","-y",dstZip,haxe_io_Path.withoutDirectory(srcDirectory)],{ cwd : haxe_io_Path.directory(srcDirectory)});
	} else {
		throw haxe_Exception.thrown("Zip not supported on " + os);
	}
};
tools_Files.deleteRecursive = function(toDelete) {
	if(!sys_FileSystem.exists(toDelete)) {
		return;
	}
	var os = Sys.systemName();
	if(os == "Mac" || os == "Linux") {
		tools_Helpers.command("rm",["-rf",toDelete]);
		return;
	}
	if(sys_FileSystem.isDirectory(toDelete)) {
		var _g = 0;
		var _g1 = js_node_Fs.readdirSync(toDelete);
		while(_g < _g1.length) {
			var name = _g1[_g];
			++_g;
			var path = haxe_io_Path.join([toDelete,name]);
			if(sys_FileSystem.isDirectory(path)) {
				tools_Files.deleteRecursive(path);
			} else {
				js_node_Fs.unlinkSync(path);
			}
		}
		if(sys_FileSystem.exists(toDelete)) {
			var _g = 0;
			var _g1 = js_node_Fs.readdirSync(toDelete);
			while(_g < _g1.length) {
				var file = _g1[_g];
				++_g;
				var curPath = toDelete + "/" + file;
				if(sys_FileSystem.isDirectory(curPath)) {
					if(sys_FileSystem.exists(curPath)) {
						var _g2 = 0;
						var _g3 = js_node_Fs.readdirSync(curPath);
						while(_g2 < _g3.length) {
							var file1 = _g3[_g2];
							++_g2;
							var curPath1 = curPath + "/" + file1;
							if(sys_FileSystem.isDirectory(curPath1)) {
								sys_FileSystem.deleteDirectory(curPath1);
							} else {
								js_node_Fs.unlinkSync(curPath1);
							}
						}
						js_node_Fs.rmdirSync(curPath);
					}
				} else {
					js_node_Fs.unlinkSync(curPath);
				}
			}
			js_node_Fs.rmdirSync(toDelete);
		}
	} else {
		js_node_Fs.unlinkSync(toDelete);
	}
};
tools_Files.getRelativePath = function(absolutePath,relativeTo) {
	var isWindows = Sys.systemName() == "Windows";
	var fromParts = HxOverrides.substr(haxe_io_Path.normalize(relativeTo),isWindows ? 3 : 1,null).split("/");
	var toParts = HxOverrides.substr(haxe_io_Path.normalize(absolutePath),isWindows ? 3 : 1,null).split("/");
	var length = Math.min(fromParts.length,toParts.length);
	var samePartsLength = length;
	var _g = 0;
	var _g1 = length;
	while(_g < _g1) {
		var i = _g++;
		if(fromParts[i] != toParts[i]) {
			samePartsLength = i;
			break;
		}
	}
	var outputParts = [];
	var _g = samePartsLength;
	var _g1 = fromParts.length;
	while(_g < _g1) {
		var i = _g++;
		outputParts.push("..");
	}
	outputParts = outputParts.concat(toParts.slice(samePartsLength));
	var result = outputParts.join("/");
	if(StringTools.endsWith(absolutePath,"/") && !StringTools.endsWith(result,"/")) {
		result += "/";
	}
	if(!StringTools.startsWith(result,".")) {
		result = "./" + result;
	}
	return result;
};
tools_Files.copyIfNeeded = function(srcFile,dstFile,createDirectory) {
	if(createDirectory == null) {
		createDirectory = true;
	}
	if(createDirectory && !sys_FileSystem.exists(haxe_io_Path.directory(dstFile))) {
		sys_FileSystem.createDirectory(haxe_io_Path.directory(dstFile));
	}
	if(sys_FileSystem.exists(srcFile) && !tools_Files.haveSameLastModified(srcFile,dstFile)) {
		sys_io_File.copy(srcFile,dstFile);
		tools_Files.setToSameLastModified(srcFile,dstFile);
	}
};
tools_Files.copyDirectory = function(srcDir,dstDir,removeExisting) {
	if(removeExisting == null) {
		removeExisting = false;
	}
	if(sys_FileSystem.exists(dstDir) && (removeExisting || !sys_FileSystem.isDirectory(dstDir))) {
		tools_Files.deleteRecursive(dstDir);
	}
	if(!sys_FileSystem.exists(dstDir)) {
		sys_FileSystem.createDirectory(dstDir);
	}
	var _g = 0;
	var _g1 = js_node_Fs.readdirSync(srcDir);
	while(_g < _g1.length) {
		var name = _g1[_g];
		++_g;
		if(name == ".DS_Store") {
			continue;
		}
		var srcPath = haxe_io_Path.join([srcDir,name]);
		var dstPath = haxe_io_Path.join([dstDir,name]);
		if(sys_FileSystem.isDirectory(srcPath)) {
			tools_Files.copyDirectory(srcPath,dstPath,removeExisting);
		} else {
			sys_io_File.copy(srcPath,dstPath);
		}
	}
};
tools_Files.getDirectoryLastModifiedList = function(dir,fileSuffix,output) {
	if(output == null) {
		output = { };
	}
	if(!sys_FileSystem.exists(dir)) {
		return output;
	}
	var _g = 0;
	var _g1 = js_node_Fs.readdirSync(dir);
	while(_g < _g1.length) {
		var name = _g1[_g];
		++_g;
		var filePath = haxe_io_Path.join([dir,name]);
		if(sys_FileSystem.isDirectory(filePath)) {
			tools_Files.getDirectoryLastModifiedList(filePath,fileSuffix,output);
		} else if(fileSuffix == null || StringTools.endsWith(filePath,fileSuffix)) {
			output[filePath] = tools_Files.getLastModified(filePath);
		}
	}
	return output;
};
tools_Files.hasDirectoryChanged = function(lastModifiedListBefore,lastModifiedListAfter) {
	var _g = 0;
	var _g1 = Reflect.fields(lastModifiedListBefore);
	while(_g < _g1.length) {
		var key = _g1[_g];
		++_g;
		if(!Object.prototype.hasOwnProperty.call(lastModifiedListAfter,key)) {
			return true;
		}
		if(Math.abs(lastModifiedListAfter[key] - lastModifiedListBefore[key]) >= 1.0) {
			return true;
		}
	}
	var _g = 0;
	var _g1 = Reflect.fields(lastModifiedListAfter);
	while(_g < _g1.length) {
		var key = _g1[_g];
		++_g;
		if(!Object.prototype.hasOwnProperty.call(lastModifiedListAfter,key)) {
			return true;
		}
	}
	return false;
};
var tools_Helpers = function() { };
$hxClasses["tools.Helpers"] = tools_Helpers;
tools_Helpers.__name__ = true;
tools_Helpers.extractDefines = function(cwd,args) {
	var target = null;
	if(tools_Helpers.context.backend != null) {
		var availableTargets = tools_Helpers.context.backend.getBuildTargets();
		var targetName = tools_Helpers.getTargetName(args,availableTargets);
		if(targetName != null) {
			var _g = 0;
			while(_g < availableTargets.length) {
				var aTarget = availableTargets[_g];
				++_g;
				if(aTarget.name == targetName) {
					target = aTarget;
					break;
				}
			}
		}
		var this1 = tools_Helpers.context.defines;
		var value = StringTools.replace(tools_Helpers.context.backend.name.toLowerCase()," ","_");
		this1.h["backend"] = value;
		var this1 = tools_Helpers.context.defines;
		var key = StringTools.replace(tools_Helpers.context.backend.name.toLowerCase()," ","_");
		this1.h[key] = "backend";
	}
	tools_Helpers.context.defines.h["ceramic"] = tools_Helpers.context.ceramicVersion;
	var this1 = tools_Helpers.context.defines;
	var value = haxe_io_Path.join([cwd,"assets"]);
	this1.h["assets_path"] = value;
	var this1 = tools_Helpers.context.defines;
	var value = haxe_io_Path.join([tools_Helpers.context.ceramicToolsPath,"assets"]);
	this1.h["ceramic_assets_path"] = value;
	tools_Helpers.context.defines.h["ceramic_root_path"] = tools_Helpers.context.ceramicRootPath;
	tools_Helpers.context.defines.h["HXCPP_STACK_LINE"] = "";
	tools_Helpers.context.defines.h["HXCPP_STACK_TRACE"] = "";
	if(tools_Helpers.context.variant != null) {
		tools_Helpers.context.defines.h["variant"] = tools_Helpers.context.variant;
		if(!Object.prototype.hasOwnProperty.call(tools_Helpers.context.defines.h,tools_Helpers.context.variant)) {
			tools_Helpers.context.defines.h[tools_Helpers.context.variant] = "variant";
		}
	}
	var pluginsAssetPaths = [];
	var h = tools_Helpers.context.plugins.h;
	var plugin_h = h;
	var plugin_keys = Object.keys(h);
	var plugin_length = plugin_keys.length;
	var plugin_current = 0;
	while(plugin_current < plugin_length) {
		var plugin = plugin_h[plugin_keys[plugin_current++]];
		var path_ = haxe_io_Path.join([plugin.path,"assets"]);
		if(sys_FileSystem.exists(path_) && sys_FileSystem.isDirectory(path_)) {
			pluginsAssetPaths.push(path_);
		}
	}
	var this1 = tools_Helpers.context.defines;
	var value = JSON.stringify(JSON.stringify(pluginsAssetPaths));
	this1.h["ceramic_plugins_assets_paths"] = value;
	tools_Helpers.context.defines.h["HXCPP_CHECK_POINTER"] = "";
	tools_Helpers.context.defines.h["safeMode"] = "";
	tools_Helpers.context.defines.h["absolute-path"] = "";
	if(target != null && tools_Helpers.context.backend != null) {
		var extraDefines = tools_Helpers.context.backend.getTargetDefines(cwd,args,target,tools_Helpers.context.variant);
		var h = extraDefines.h;
		var key_h = h;
		var key_keys = Object.keys(h);
		var key_length = key_keys.length;
		var key_current = 0;
		while(key_current < key_length) {
			var key = key_keys[key_current++];
			if(!Object.prototype.hasOwnProperty.call(tools_Helpers.context.defines.h,key)) {
				tools_Helpers.context.defines.h[key] = extraDefines.h[key];
			}
		}
	}
};
tools_Helpers.setVariant = function(variant) {
	var prevVariant = tools_Helpers.context.variant;
	if(prevVariant != variant) {
		if(tools_Helpers.context.defines.h[prevVariant] == "variant") {
			var _this = tools_Helpers.context.defines;
			if(Object.prototype.hasOwnProperty.call(_this.h,prevVariant)) {
				delete(_this.h[prevVariant]);
			}
		}
	}
	tools_Helpers.context.variant = variant;
	tools_Helpers.context.defines.h["variant"] = tools_Helpers.context.variant;
	if(!Object.prototype.hasOwnProperty.call(tools_Helpers.context.defines.h,tools_Helpers.context.variant)) {
		tools_Helpers.context.defines.h[tools_Helpers.context.variant] = "variant";
	}
};
tools_Helpers.computePlugins = function() {
	tools_Helpers.context.plugins = new haxe_ds_StringMap();
	tools_Helpers.context.unbuiltPlugins = new haxe_ds_StringMap();
	var plugins_h = Object.create(null);
	var files = js_node_Fs.readdirSync(tools_Helpers.context.defaultPluginsPath);
	var _g = 0;
	while(_g < files.length) {
		var file = files[_g];
		++_g;
		var pluginProjectPath = haxe_io_Path.join([tools_Helpers.context.defaultPluginsPath,file,"ceramic.yml"]);
		var pluginsDir = tools_Helpers.context.defaultPluginsPath;
		if(sys_FileSystem.exists(pluginProjectPath)) {
			try {
				var str = StringTools.replace(StringTools.replace(js_node_Fs.readFileSync(pluginProjectPath,{ encoding : "utf8"}),"{plugin:cwd}",haxe_io_Path.join([pluginsDir,file])),"{cwd}",tools_Helpers.context.cwd);
				var info = npm_Yaml.parse(str);
				if(info != null && info.plugin != null && info.plugin.name != null) {
					plugins_h[("" + info.plugin.name).toLowerCase()] = { name : info.plugin.name, path : haxe_io_Path.join([pluginsDir,file]), runtime : info.plugin.runtime};
				} else {
					tools_Helpers.warning("Invalid plugin: " + pluginProjectPath);
				}
			} catch( _g1 ) {
				tools_Helpers.error("Failed to parse plugin config: " + pluginProjectPath);
			}
		}
	}
	if(sys_FileSystem.exists(haxe_io_Path.join([tools_Helpers.context.cwd,"ceramic.yml"]))) {
		if(sys_FileSystem.exists(tools_Helpers.context.projectPluginsPath) && sys_FileSystem.isDirectory(tools_Helpers.context.projectPluginsPath)) {
			var files = js_node_Fs.readdirSync(tools_Helpers.context.projectPluginsPath);
			var _g = 0;
			while(_g < files.length) {
				var file = files[_g];
				++_g;
				var pluginProjectPath = haxe_io_Path.join([tools_Helpers.context.projectPluginsPath,file,"ceramic.yml"]);
				var pluginsDir = tools_Helpers.context.projectPluginsPath;
				if(sys_FileSystem.exists(pluginProjectPath)) {
					try {
						var str = StringTools.replace(StringTools.replace(js_node_Fs.readFileSync(pluginProjectPath,{ encoding : "utf8"}),"{plugin:cwd}",haxe_io_Path.join([pluginsDir,file])),"{cwd}",tools_Helpers.context.cwd);
						var info = npm_Yaml.parse(str);
						if(info != null && info.plugin != null && info.plugin.name != null) {
							plugins_h[("" + info.plugin.name).toLowerCase()] = { name : info.plugin.name, path : haxe_io_Path.join([pluginsDir,file]), runtime : info.plugin.runtime};
						} else {
							tools_Helpers.warning("Invalid plugin: " + pluginProjectPath);
						}
					} catch( _g1 ) {
						tools_Helpers.error("Failed to parse plugin config: " + pluginProjectPath);
					}
				}
			}
		}
	}
	var h = plugins_h;
	var key_h = h;
	var key_keys = Object.keys(h);
	var key_length = key_keys.length;
	var key_current = 0;
	while(key_current < key_length) {
		var key = key_keys[key_current++];
		var info = plugins_h[key];
		var name = info.name;
		var path = info.path;
		var runtime = info.runtime;
		try {
			if(!haxe_io_Path.isAbsolute(path)) {
				path = haxe_io_Path.normalize(haxe_io_Path.join([tools_Helpers.context.dotCeramicPath,"..",path]));
			}
			var pluginIndexPath = haxe_io_Path.join([path,"index.js"]);
			if(sys_FileSystem.exists(pluginIndexPath)) {
				var plugin = require(pluginIndexPath);
				plugin.path = haxe_io_Path.directory(require.resolve(pluginIndexPath));
				plugin.name = name;
				plugin.runtime = runtime;
				tools_Helpers.context.plugins.h[name] = plugin;
			} else {
				tools_Helpers.context.unbuiltPlugins.h[name] = { path : path, name : name, runtime : runtime};
			}
		} catch( _g ) {
			var e = haxe_Exception.caught(_g).unwrap();
			console.error(e);
			tools_Helpers.error("Error when loading plugin: " + path);
		}
	}
};
tools_Helpers.runCeramic = function(cwd,args,mute) {
	if(mute == null) {
		mute = false;
	}
	if(args == null) {
		args = [];
	}
	var actualArgs = [].concat(args);
	if(!tools_Helpers.context.colors && actualArgs.indexOf("--no-colors") == -1) {
		actualArgs.push("--no-colors");
	}
	if(Sys.systemName() == "Windows") {
		return tools_Helpers.command(haxe_io_Path.join([tools_Helpers.context.ceramicToolsPath,"ceramic.cmd"]),actualArgs,{ cwd : cwd, mute : mute});
	} else {
		return tools_Helpers.command(haxe_io_Path.join([tools_Helpers.context.ceramicToolsPath,"node_modules/.bin/node"]),[haxe_io_Path.join([tools_Helpers.context.ceramicToolsPath,"ceramic"])].concat(actualArgs),{ cwd : cwd, mute : mute});
	}
};
tools_Helpers.print = function(message) {
	if(tools_Helpers.context.muted) {
		return;
	}
	var message1 = "" + message;
	if(tools_Helpers.context.printSplitLines) {
		var parts = message1.split("\n");
		var _g = 0;
		while(_g < parts.length) {
			var part = parts[_g];
			++_g;
			tools_Sync.run(function(done) {
				global.setTimeout(done,0);
			});
			tools_Helpers.stdoutWrite(part + "\n");
		}
	} else {
		tools_Helpers.stdoutWrite(message1 + "\n");
	}
};
tools_Helpers.success = function(message) {
	if(tools_Helpers.context.muted) {
		return;
	}
	if(tools_Helpers.context.colors) {
		tools_Helpers.stdoutWrite("" + tools_Colors.green(message) + "\n");
	} else {
		tools_Helpers.stdoutWrite("" + message + "\n");
	}
};
tools_Helpers.error = function(message) {
	if(tools_Helpers.context.muted) {
		return;
	}
	if(tools_Helpers.context.colors) {
		tools_Helpers.stderrWrite("" + tools_Colors.red(message) + "\n");
	} else {
		tools_Helpers.stderrWrite("" + message + "\n");
	}
};
tools_Helpers.warning = function(message) {
	if(tools_Helpers.context.muted) {
		return;
	}
	if(tools_Helpers.context.colors) {
		tools_Helpers.stderrWrite("" + tools_Colors.yellow(message) + "\n");
	} else {
		tools_Helpers.stderrWrite("" + message + "\n");
	}
};
tools_Helpers.stdoutWrite = function(input) {
	if(tools_Helpers.isElectronProxy()) {
		var parts = ("" + input).split("\n");
		var i = 0;
		while(i < parts.length) {
			var part = parts[i];
			part = StringTools.replace(part,"\r","");
			process.stdout.write(new js_node_buffer_Buffer(part).toString("base64") + (i + 1 < parts.length ? "\n" : ""),"ascii");
			++i;
		}
	} else {
		process.stdout.write(input);
	}
};
tools_Helpers.stderrWrite = function(input) {
	if(tools_Helpers.isElectronProxy()) {
		var parts = ("" + input).split("\n");
		var i = 0;
		while(i < parts.length) {
			var part = parts[i];
			part = StringTools.replace(part,"\r","");
			process.stderr.write(new js_node_buffer_Buffer(part).toString("base64") + (i + 1 < parts.length ? "\n" : ""),"ascii");
			++i;
		}
	} else {
		process.stderr.write(input);
	}
};
tools_Helpers.fail = function(message) {
	tools_Helpers.error(message);
	process.exit(1);
};
tools_Helpers.runningHaxeServerPort = function() {
	var homedir = require('os').homedir();
	var infoPath = haxe_io_Path.join([homedir,".ceramic-haxe-server"]);
	var mtime = tools_Files.getLastModified(infoPath);
	var currentTime = new Date().getTime() / 1000;
	var timeGap = Math.abs(currentTime - mtime);
	if(timeGap < 2.0) {
		return Std.parseInt(StringTools.trim(js_node_Fs.readFileSync(infoPath,{ encoding : "utf8"})));
	} else {
		return -1;
	}
};
tools_Helpers.haxe = function(args,options) {
	var haxe = Sys.systemName() == "Windows" ? "haxe.cmd" : "haxe";
	return tools_Helpers.command(haxe_io_Path.join([tools_Helpers.context.ceramicToolsPath,haxe]),args,options);
};
tools_Helpers.haxeWithChecksAndLogs = function(args,options) {
	var haxe = Sys.systemName() == "Windows" ? "haxe.cmd" : "haxe";
	return tools_Helpers.commandWithChecksAndLogs(haxe_io_Path.join([tools_Helpers.context.ceramicToolsPath,haxe]),args,options);
};
tools_Helpers.haxelib = function(args,options) {
	var haxelib = Sys.systemName() == "Windows" ? "haxelib.cmd" : "haxelib";
	return tools_Helpers.command(haxe_io_Path.join([tools_Helpers.context.ceramicToolsPath,haxelib]),args,options);
};
tools_Helpers.haxelibGlobal = function(args,options) {
	return tools_Helpers.command("haxelib",args,options);
};
tools_Helpers.commandExists = function(name) {
	return require("command-exists").sync(name);
};
tools_Helpers.checkProjectHaxelibSetup = function(cwd,args) {
	var haxelibRepoPath = haxe_io_Path.join([cwd,".haxelib"]);
	if(!sys_FileSystem.exists(haxelibRepoPath)) {
		sys_FileSystem.createDirectory(haxelibRepoPath);
	}
	var hxcppPath = haxe_io_Path.join([haxelibRepoPath,"hxcpp","4,1,15"]);
	if(!sys_FileSystem.exists(hxcppPath)) {
		tools_Helpers.haxelib(["install","hxcpp","4.1.15","--always"],{ cwd : cwd});
	}
	var androidClangToolchainPath = haxe_io_Path.join([hxcppPath,"toolchain/android-toolchain-clang.xml"]);
	var androidClangToolchain = js_node_Fs.readFileSync(androidClangToolchainPath,{ encoding : "utf8"});
	var indexOfOptimFlag = androidClangToolchain.indexOf("<flag value=\"-O2\" unless=\"debug\"/>");
	var indexOfStaticLibcpp = androidClangToolchain.indexOf("=\"-static-libstdc++\" />");
	var indexOfLibAtomic = androidClangToolchain.indexOf("name=\"-latomic\"");
	var indexOfPlatform16 = androidClangToolchain.indexOf("<set name=\"PLATFORM_NUMBER\" value=\"16\" />");
	if(indexOfOptimFlag == -1 || indexOfStaticLibcpp != -1 || indexOfLibAtomic == -1 || indexOfPlatform16 != -1) {
		tools_Helpers.print("Patch hxcpp android-clang toolchain");
		if(indexOfOptimFlag == -1) {
			androidClangToolchain = StringTools.replace(androidClangToolchain,"<flag value=\"-fpic\"/>","<flag value=\"-fpic\"/>\n  <flag value=\"-O2\" unless=\"debug\"/>");
		}
		if(indexOfStaticLibcpp != -1) {
			androidClangToolchain = StringTools.replace(androidClangToolchain,"=\"-static-libstdc++\" />","=\"-static-libstdc++\" if=\"HXCPP_LIBCPP_STATIC\" />");
		}
		if(indexOfLibAtomic == -1) {
			androidClangToolchain = StringTools.replace(androidClangToolchain,"</linker>","  <lib name=\"-latomic\" if=\"HXCPP_LIB_ATOMIC\" />\n</linker>");
		}
		if(indexOfPlatform16 != -1) {
			androidClangToolchain = StringTools.replace(androidClangToolchain,"<set name=\"PLATFORM_NUMBER\" value=\"16\" />","<set name=\"PLATFORM_NUMBER\" value=\"21\" />");
		}
	}
	js_node_Fs.writeFileSync(androidClangToolchainPath,androidClangToolchain);
	if(!sys_FileSystem.exists(haxe_io_Path.join([haxelibRepoPath,"hxnodejs","12,1,0"]))) {
		tools_Helpers.haxelib(["install","hxnodejs","12.1.0","--always"],{ cwd : cwd});
	}
	if(!sys_FileSystem.exists(haxe_io_Path.join([haxelibRepoPath,"hxnodejs-ws","5,2,3"]))) {
		tools_Helpers.haxelib(["install","hxnodejs-ws","5.2.3","--always"],{ cwd : cwd});
	}
	if(!sys_FileSystem.exists(haxe_io_Path.join([haxelibRepoPath,"hscript","2,4,0"]))) {
		tools_Helpers.haxelib(["install","hscript","2.4.0","--always"],{ cwd : cwd});
	}
	if(!sys_FileSystem.exists(haxe_io_Path.join([haxelibRepoPath,"bind","0,4,10"]))) {
		tools_Helpers.haxelib(["install","bind","0.4.10","--always"],{ cwd : cwd});
	}
	if(!sys_FileSystem.exists(haxe_io_Path.join([haxelibRepoPath,"format","3,4,2"]))) {
		tools_Helpers.haxelib(["install","format","3.4.2","--always"],{ cwd : cwd});
	}
	if(!sys_FileSystem.exists(haxe_io_Path.join([haxelibRepoPath,"hxnodejs","10,0,0"]))) {
		tools_Helpers.haxelib(["install","hxnodejs","10.0.0","--always"],{ cwd : cwd});
	}
	if(!sys_FileSystem.exists(haxe_io_Path.join([haxelibRepoPath,"akifox-asynchttp"]))) {
		tools_Helpers.haxelib(["dev","akifox-asynchttp",haxe_io_Path.join([tools_Helpers.context.ceramicGitDepsPath,"akifox-asynchttp"]),"--always"],{ cwd : cwd});
	}
	if(!sys_FileSystem.exists(haxe_io_Path.join([haxelibRepoPath,"tracker"]))) {
		tools_Helpers.haxelib(["dev","tracker",haxe_io_Path.join([tools_Helpers.context.ceramicGitDepsPath,"tracker"]),"--always"],{ cwd : cwd});
	}
	if(!sys_FileSystem.exists(haxe_io_Path.join([haxelibRepoPath,"arcade"]))) {
		tools_Helpers.haxelib(["dev","arcade",haxe_io_Path.join([tools_Helpers.context.ceramicGitDepsPath,"arcade"]),"--always"],{ cwd : cwd});
	}
	if(!sys_FileSystem.exists(haxe_io_Path.join([haxelibRepoPath,"nape"]))) {
		tools_Helpers.haxelib(["dev","nape",haxe_io_Path.join([tools_Helpers.context.ceramicGitDepsPath,"nape"]),"--always"],{ cwd : cwd});
	}
	if(!sys_FileSystem.exists(haxe_io_Path.join([haxelibRepoPath,"differ"]))) {
		tools_Helpers.haxelib(["dev","differ",haxe_io_Path.join([tools_Helpers.context.ceramicGitDepsPath,"differ"]),"--always"],{ cwd : cwd});
	}
	if(!sys_FileSystem.exists(haxe_io_Path.join([haxelibRepoPath,"hsluv"]))) {
		tools_Helpers.haxelib(["dev","hsluv",haxe_io_Path.join([tools_Helpers.context.ceramicGitDepsPath,"hsluv","haxe"]),"--always"],{ cwd : cwd});
	}
	if(!sys_FileSystem.exists(haxe_io_Path.join([haxelibRepoPath,"spine-hx"]))) {
		tools_Helpers.haxelib(["dev","spine-hx",haxe_io_Path.join([tools_Helpers.context.ceramicGitDepsPath,"spine-hx"]),"--always"],{ cwd : cwd});
	}
	if(!sys_FileSystem.exists(haxe_io_Path.join([haxelibRepoPath,"polyline"]))) {
		tools_Helpers.haxelib(["dev","polyline",haxe_io_Path.join([tools_Helpers.context.ceramicGitDepsPath,"polyline"]),"--always"],{ cwd : cwd});
	}
	if(!sys_FileSystem.exists(haxe_io_Path.join([haxelibRepoPath,"earcut"]))) {
		tools_Helpers.haxelib(["dev","earcut",haxe_io_Path.join([tools_Helpers.context.ceramicGitDepsPath,"earcut"]),"--always"],{ cwd : cwd});
	}
	if(!sys_FileSystem.exists(haxe_io_Path.join([haxelibRepoPath,"poly2tri"]))) {
		tools_Helpers.haxelib(["dev","poly2tri",haxe_io_Path.join([tools_Helpers.context.ceramicGitDepsPath,"poly2tri"]),"--always"],{ cwd : cwd});
	}
	if(!sys_FileSystem.exists(haxe_io_Path.join([haxelibRepoPath,"generate"]))) {
		tools_Helpers.haxelib(["dev","generate",haxe_io_Path.join([tools_Helpers.context.ceramicGitDepsPath,"generate"]),"--always"],{ cwd : cwd});
	}
	if(!sys_FileSystem.exists(haxe_io_Path.join([haxelibRepoPath,"format-tiled"]))) {
		tools_Helpers.haxelib(["dev","format-tiled",haxe_io_Path.join([tools_Helpers.context.ceramicGitDepsPath,"format-tiled"]),"--always"],{ cwd : cwd});
	}
	if(!sys_FileSystem.exists(haxe_io_Path.join([haxelibRepoPath,"imgui-hx"]))) {
		tools_Helpers.haxelib(["dev","imgui-hx",haxe_io_Path.join([tools_Helpers.context.ceramicGitDepsPath,"imgui-hx"]),"--always"],{ cwd : cwd});
	}
};
tools_Helpers.commandWithChecksAndLogs = function(name,args,options) {
	if(options == null) {
		options = { cwd : null, logCwd : null};
	}
	if(options.cwd == null) {
		options.cwd = tools_Helpers.context.cwd;
	}
	if(options.logCwd == null) {
		options.logCwd = options.cwd;
	}
	var status = 0;
	var cwd = options.cwd;
	var logCwd = options.logCwd;
	tools_Sync.run(function(done) {
		var proc = null;
		if(args == null) {
			proc = js_node_ChildProcess.spawn(name,{ cwd : cwd});
		} else {
			proc = js_node_ChildProcess.spawn(name,args,{ cwd : cwd});
		}
		var out = require("stream-splitter")("\n");
		proc.stdout.on("data",function(data) {
			out.write(data);
		});
		proc.on("exit",function(code) {
			status = code;
			if(done != null) {
				var _done = done;
				done = null;
				_done();
			}
		});
		proc.on("close",function(code) {
			status = code;
			if(done != null) {
				var _done = done;
				done = null;
				_done();
			}
		});
		out.encoding = "utf8";
		out.on("token",function(token) {
			token = tools_Helpers.formatLineOutput(logCwd,token);
			tools_Helpers.stdoutWrite(token + "\n");
		});
		out.on("done",function() {
		});
		out.on("error",function(err) {
		});
		var err = require("stream-splitter")("\n");
		proc.stderr.on("data",function(data) {
			err.write(data);
		});
		err.encoding = "utf8";
		err.on("token",function(token) {
			token = tools_Helpers.formatLineOutput(logCwd,token);
			tools_Helpers.stderrWrite(token + "\n");
		});
		err.on("error",function(err) {
		});
	});
	return status;
};
tools_Helpers.command = function(name,args,options) {
	if(options == null) {
		options = { cwd : null, mute : false, detached : false};
	}
	if(tools_Helpers.context.muted) {
		options.mute = true;
	}
	if(options.cwd == null) {
		options.cwd = tools_Helpers.context.cwd;
	}
	var result = { stdout : "", stderr : "", status : 0};
	if(Sys.systemName() == "Windows") {
		if(name == "npm" || name == "node" || name == "ceramic" || name == "haxe" || name == "haxelib" || name == "neko") {
			name += ".cmd";
		}
	}
	var spawnOptions = { cwd : options.cwd};
	if(options.detached) {
		spawnOptions.detached = true;
		spawnOptions.stdio = ["ignore","ignore","ignore"];
		var proc = null;
		if(args == null) {
			proc = js_node_ChildProcess.spawn(name,spawnOptions);
		} else {
			proc = js_node_ChildProcess.spawn(name,args,spawnOptions);
		}
		proc.unref();
	} else {
		tools_Sync.run(function(done) {
			var proc = null;
			if(args == null) {
				proc = js_node_ChildProcess.spawn(name,spawnOptions);
			} else {
				proc = js_node_ChildProcess.spawn(name,args,spawnOptions);
			}
			proc.stdout.on("data",function(input) {
				result.stdout += input.toString();
				if(!options.mute) {
					tools_Helpers.stdoutWrite(input.toString());
				}
			});
			proc.stderr.on("data",function(input) {
				result.stderr += input.toString();
				if(!options.mute) {
					tools_Helpers.stderrWrite(input.toString());
				}
			});
			proc.on("error",function(err) {
				tools_Helpers.error(err + " (" + options.cwd + ")");
				tools_Helpers.fail("Failed to run command: " + name + (args != null && args.length > 0 ? " " + args.join(" ") : ""));
			});
			proc.on("close",function(code) {
				result.status = code;
				done();
			});
		});
	}
	return result;
};
tools_Helpers.runTask = function(taskCommand,args,addContextArgs,allowMissingTask) {
	if(allowMissingTask == null) {
		allowMissingTask = false;
	}
	if(addContextArgs == null) {
		addContextArgs = true;
	}
	var task = tools_Helpers.context.tasks.h[taskCommand];
	if(task == null) {
		var err = "Cannot run task because `ceramic " + taskCommand + "` command doesn't exist.";
		if(allowMissingTask) {
			tools_Helpers.warning(err);
		} else {
			tools_Helpers.fail(err);
		}
		return false;
	}
	var taskArgs = [];
	if(args != null) {
		taskArgs = [].concat(args);
	}
	taskArgs.push("--cwd");
	taskArgs.push(tools_Helpers.context.cwd);
	if(tools_Helpers.context.debug) {
		taskArgs.push("--debug");
	}
	if(tools_Helpers.context.variant != "standard") {
		taskArgs.push("--variant");
		taskArgs.push(tools_Helpers.context.variant);
	}
	task.run(tools_Helpers.context.cwd,taskArgs);
	return true;
};
tools_Helpers.extractArgValue = function(args,name,remove) {
	if(remove == null) {
		remove = false;
	}
	var index = args.indexOf("--" + name);
	if(index == -1) {
		return null;
	}
	if(index + 1 >= args.length) {
		tools_Helpers.fail("A value is required after --" + name + " argument.");
	}
	var value = args[index + 1];
	if(remove) {
		args.splice(index,2);
	}
	return value;
};
tools_Helpers.extractArgFlag = function(args,name,remove) {
	if(remove == null) {
		remove = false;
	}
	var index = args.indexOf("--" + name);
	if(index == -1) {
		return false;
	}
	if(remove) {
		args.splice(index,1);
	}
	return true;
};
tools_Helpers.getRelativePath = function(absolutePath,relativeTo) {
	return tools_Files.getRelativePath(absolutePath,relativeTo);
};
tools_Helpers.getTargetName = function(args,availableTargets) {
	var targetArgIndex = 1;
	if(args.length > 1) {
		if(Object.prototype.hasOwnProperty.call(tools_Helpers.context.tasks.h,args[0] + " " + args[1])) {
			++targetArgIndex;
		}
	}
	var targetArg = args[targetArgIndex];
	var targetName = null;
	if(targetArg != null && !StringTools.startsWith(targetArg,"--")) {
		targetName = targetArg;
	}
	if(targetName == "default") {
		return targetName;
	}
	var _g = 0;
	while(_g < availableTargets.length) {
		var target = availableTargets[_g];
		++_g;
		if(targetName == target.name) {
			return targetName;
		}
	}
	targetName = null;
	var os = Sys.systemName();
	if(os == "Mac") {
		targetName = "mac";
	} else {
		var tmp = os == "Windows";
	}
	var _g = 0;
	while(_g < availableTargets.length) {
		var target = availableTargets[_g];
		++_g;
		if(targetName == target.name) {
			return targetName;
		}
	}
	return null;
};
tools_Helpers.isErrorOutput = function(input) {
	input = StringTools.replace(input,"\r","");
	if(input.indexOf(": Warning :") != -1) {
		return false;
	}
	var result = tools_Helpers.RE_HAXE_ERROR.match(input);
	return result;
};
tools_Helpers.formatLineOutput = function(cwd,input) {
	if(!tools_Helpers.context.colors) {
		input = require("strip-ansi")(input);
	}
	input = StringTools.rtrim(StringTools.replace(input,"\r",""));
	if(tools_Helpers.RE_HAXE_ERROR.match(input)) {
		var relativePath = tools_Helpers.RE_HAXE_ERROR.matched(1);
		var lineNumber = tools_Helpers.RE_HAXE_ERROR.matched(2);
		var absolutePath = haxe_io_Path.isAbsolute(relativePath) ? relativePath : haxe_io_Path.normalize(haxe_io_Path.join([cwd,relativePath]));
		if(tools_Helpers.context.vscode) {
			var charsBefore = "characters " + tools_Helpers.RE_HAXE_ERROR.matched(4) + "-" + tools_Helpers.RE_HAXE_ERROR.matched(5);
			var charsAfter = "characters " + Std.parseInt(tools_Helpers.RE_HAXE_ERROR.matched(4)) + "-" + Std.parseInt(tools_Helpers.RE_HAXE_ERROR.matched(5));
			input = StringTools.replace(input,charsBefore,charsAfter);
		}
		input = StringTools.replace(input,relativePath,absolutePath);
		if(tools_Helpers.context.colors) {
			if(input.indexOf(": Warning :") != -1) {
				input = tools_Colors.gray("" + absolutePath + ":" + lineNumber + ": ") + tools_Colors.yellow(HxOverrides.substr(StringTools.replace(input,": Warning :",":"),("" + absolutePath + ":" + lineNumber + ":").length + 1,null));
			} else {
				input = tools_Colors.gray("" + absolutePath + ":" + lineNumber + ": ") + tools_Colors.red(HxOverrides.substr(input,("" + absolutePath + ":" + lineNumber + ":").length + 1,null));
			}
		} else {
			input = "" + absolutePath + ":" + lineNumber + ": " + HxOverrides.substr(input,("" + absolutePath + ":" + lineNumber + ":").length + 1,null);
		}
	} else if(tools_Helpers.RE_STACK_FILE_LINE.match(input)) {
		var symbol = tools_Helpers.RE_STACK_FILE_LINE.matched(1);
		var relativePath = tools_Helpers.RE_STACK_FILE_LINE.matched(2);
		var lineNumber = tools_Helpers.RE_STACK_FILE_LINE.matched(3);
		var absolutePath = haxe_io_Path.isAbsolute(relativePath) ? relativePath : haxe_io_Path.normalize(haxe_io_Path.join([cwd,relativePath]));
		if(tools_Helpers.context.colors) {
			input = StringTools.replace(input,tools_Helpers.RE_STACK_FILE_LINE.matched(0),tools_Colors.red("" + symbol + " ") + tools_Colors.gray("" + absolutePath + ":" + lineNumber));
		} else {
			input = StringTools.replace(input,tools_Helpers.RE_STACK_FILE_LINE.matched(0),"" + symbol + " " + absolutePath + ":" + lineNumber);
		}
	} else if(tools_Helpers.RE_STACK_FILE_LINE_BIS.match(input)) {
		var symbol = tools_Helpers.RE_STACK_FILE_LINE_BIS.matched(1);
		var relativePath = tools_Helpers.RE_STACK_FILE_LINE_BIS.matched(2);
		var lineNumber = tools_Helpers.RE_STACK_FILE_LINE_BIS.matched(3);
		var absolutePath = haxe_io_Path.isAbsolute(relativePath) ? relativePath : haxe_io_Path.normalize(haxe_io_Path.join([cwd,relativePath]));
		if(tools_Helpers.context.colors) {
			input = StringTools.replace(input,tools_Helpers.RE_STACK_FILE_LINE_BIS.matched(0),tools_Colors.red("" + symbol + " ") + tools_Colors.gray("" + absolutePath + ":" + lineNumber));
		} else {
			input = StringTools.replace(input,tools_Helpers.RE_STACK_FILE_LINE_BIS.matched(0),"" + symbol + " " + absolutePath + ":" + lineNumber);
		}
	} else if(tools_Helpers.RE_TRACE_FILE_LINE.match(input)) {
		var relativePath = tools_Helpers.RE_TRACE_FILE_LINE.matched(1);
		var lineNumber = tools_Helpers.RE_TRACE_FILE_LINE.matched(2);
		var absolutePath = haxe_io_Path.isAbsolute(relativePath) ? relativePath : haxe_io_Path.normalize(haxe_io_Path.join([cwd,relativePath]));
		input = StringTools.replace(input,tools_Helpers.RE_TRACE_FILE_LINE.matched(0),"");
		if(tools_Helpers.context.colors) {
			if(StringTools.startsWith(input,"[info] ")) {
				input = tools_Colors.cyan(HxOverrides.substr(input,7,null));
			} else if(StringTools.startsWith(input,"[debug] ")) {
				input = tools_Colors.magenta(HxOverrides.substr(input,8,null));
			} else if(StringTools.startsWith(input,"[warning] ")) {
				input = tools_Colors.yellow(HxOverrides.substr(input,10,null));
			} else if(StringTools.startsWith(input,"[error] ")) {
				input = tools_Colors.red(HxOverrides.substr(input,8,null));
			} else if(StringTools.startsWith(input,"[success] ")) {
				input = tools_Colors.green(HxOverrides.substr(input,10,null));
			} else if(StringTools.startsWith(input,"characters ")) {
				input = tools_Colors.red(input);
			}
			input += tools_Colors.gray(" " + absolutePath + ":" + lineNumber);
		} else {
			input += " " + absolutePath + ":" + lineNumber;
		}
	} else if(tools_Helpers.RE_JS_FILE_LINE.match(input)) {
		var identifier = tools_Helpers.RE_JS_FILE_LINE.matched(1);
		var absolutePathWithLine = tools_Helpers.RE_JS_FILE_LINE.matched(2);
		if(tools_Helpers.context.colors) {
			input = tools_Colors.red(identifier + " ") + tools_Colors.gray(absolutePathWithLine);
		} else {
			input = identifier + " " + absolutePathWithLine;
		}
	} else if(tools_Helpers.context.colors && StringTools.startsWith(input,"Error : ")) {
		input = tools_Colors.red(input);
	} else if(StringTools.startsWith(input,"[error] ")) {
		if(tools_Helpers.context.colors) {
			input = input.substring("[error] ".length);
			input = tools_Colors.red(input);
		}
	} else if(StringTools.startsWith(input,"[warning] ")) {
		if(tools_Helpers.context.colors) {
			input = input.substring("[warning] ".length);
			input = tools_Colors.yellow(input);
		}
	} else if(StringTools.startsWith(input,"[success] ")) {
		if(tools_Helpers.context.colors) {
			input = input.substring("[success] ".length);
			input = tools_Colors.green(input);
		}
	} else if(StringTools.startsWith(input,"[info] ")) {
		if(tools_Helpers.context.colors) {
			input = input.substring("[info] ".length);
			input = tools_Colors.cyan(input);
		}
	} else if(StringTools.startsWith(input,"[debug] ")) {
		if(tools_Helpers.context.colors) {
			input = input.substring("[debug] ".length);
			input = tools_Colors.magenta(input);
		}
	} else if(input == "[debug]" || input == "[info]" || input == "[success]" || input == "[warning]" || input == "[error]") {
		input = "";
	} else if(tools_Helpers.context.colors && StringTools.startsWith(input,"Called from hxcpp::")) {
		input = tools_Colors.red(input);
	}
	return input;
};
tools_Helpers.loadProject = function(cwd,args) {
	var projectPath = haxe_io_Path.join([cwd,"ceramic.yml"]);
	if(!sys_FileSystem.exists(projectPath)) {
		return null;
	}
	var kind = tools_Helpers.getProjectKind(cwd,args);
	if(kind == null) {
		return null;
	}
	switch(kind._hx_index) {
	case 0:
		var project = new tools_Project();
		project.loadAppFile(projectPath);
		return project;
	case 1:
		var _g = kind.kinds;
		var project = new tools_Project();
		project.loadPluginFile(projectPath);
		return project;
	}
};
tools_Helpers.getProjectKind = function(cwd,args) {
	return new tools_Project().getKind(haxe_io_Path.join([cwd,"ceramic.yml"]));
};
tools_Helpers.loadIdeInfo = function(cwd,args) {
	var ceramicYamlPath = haxe_io_Path.join([cwd,"ceramic.yml"]);
	if(!sys_FileSystem.exists(ceramicYamlPath)) {
		tools_Helpers.fail("Cannot load IDE info because ceramic.yml does not exist (" + ceramicYamlPath + ")");
	}
	try {
		var yml = js_node_Fs.readFileSync(ceramicYamlPath,{ encoding : "utf8"});
		yml = StringTools.replace(yml,"{plugin:cwd}",cwd);
		yml = StringTools.replace(yml,"{cwd}",cwd);
		var data = npm_Yaml.parse(yml);
		if(data == null) {
			tools_Helpers.fail("Invalid IDE data at path: " + ceramicYamlPath);
		}
		if(data.ide == null) {
			return { };
		} else {
			return data.ide;
		}
	} catch( _g ) {
		var e = haxe_Exception.caught(_g).unwrap();
		tools_Helpers.fail("Failed to load yaml data at path: " + ceramicYamlPath + " ; " + Std.string(e));
		return null;
	}
};
tools_Helpers.ensureCeramicProject = function(cwd,args,kind) {
	switch(kind._hx_index) {
	case 0:
		var project = new tools_Project();
		project.loadAppFile(haxe_io_Path.join([cwd,"ceramic.yml"]));
		return project;
	case 1:
		var _g = kind.kinds;
		var project = new tools_Project();
		project.loadPluginFile(haxe_io_Path.join([cwd,"ceramic.yml"]));
		return project;
	}
};
tools_Helpers.runHooks = function(cwd,args,hooks,when) {
	if(hooks == null) {
		return;
	}
	var _g = 0;
	while(_g < hooks.length) {
		var hook = hooks[_g];
		++_g;
		if(hook.when == when) {
			tools_Helpers.print("Run " + when + " hooks");
			break;
		}
	}
	var _g = 0;
	while(_g < hooks.length) {
		var hook = hooks[_g];
		++_g;
		if(hook.when == when) {
			var cmd = hook.command;
			var res;
			if(cmd == "ceramic") {
				res = tools_Helpers.runCeramic(cwd,hook.args != null ? hook.args : []);
			} else {
				res = tools_Helpers.command(hook.command,hook.args != null ? hook.args : [],{ cwd : cwd});
			}
			if(res.status != 0) {
				if(StringTools.trim(res.stderr).length > 0) {
					tools_Helpers.warning(res.stderr);
				}
				tools_Helpers.fail("Error when running hook: " + hook.command + (hook.args != null ? " " + hook.args.join(" ") : ""));
			}
		}
	}
};
tools_Helpers.isElectron = function() {
	return process.versions["electron"] != null;
};
tools_Helpers.isElectronProxy = function() {
	return global.isElectronProxy != null;
};
tools_Helpers.stripHxcppLineMarkers = function(cppContent) {
	var cppLines = cppContent.split("\n");
	var _g = 0;
	var _g1 = cppLines.length;
	while(_g < _g1) {
		var i = _g++;
		var line = cppLines[i];
		if(tools_Helpers.RE_HXCPP_LINE_MARKER.match(StringTools.ltrim(line))) {
			var len = tools_Helpers.RE_HXCPP_LINE_MARKER.matched(0).length;
			var space = "";
			var _g2 = 0;
			var _g3 = len;
			while(_g2 < _g3) {
				var n = _g2++;
				space += " ";
			}
			cppLines[i] = StringTools.replace(line,tools_Helpers.RE_HXCPP_LINE_MARKER.matched(0),space);
		}
	}
	return cppLines.join("\n");
};
tools_Helpers.toAssetConstName = function(input) {
	var res_b = "";
	var len = input.length;
	var i = 0;
	var canAddSpace = false;
	while(i < len) {
		var c = input.charAt(i);
		if(c == "/") {
			res_b += "__";
			canAddSpace = false;
		} else if(c == ".") {
			res_b += "_";
			canAddSpace = false;
		} else if(tools_Helpers.isAsciiChar(c)) {
			var uc = c.toUpperCase();
			var isUpperCase = c == uc;
			if(canAddSpace && isUpperCase) {
				res_b += "_";
				canAddSpace = false;
			}
			res_b += uc == null ? "null" : "" + uc;
			canAddSpace = !isUpperCase;
		} else {
			res_b += "_";
			canAddSpace = false;
		}
		++i;
	}
	var str = res_b;
	if(StringTools.endsWith(str,"_")) {
		str = HxOverrides.substr(str,0,str.length - 1);
	}
	return str;
};
tools_Helpers.isAsciiChar = function(c) {
	var code = HxOverrides.cca(c,0);
	if(!(code >= 48 && code <= 57 || code >= 65 && code <= 90)) {
		if(code >= 97) {
			return code <= 122;
		} else {
			return false;
		}
	} else {
		return true;
	}
};
tools_Helpers.compareSemVerAscending = function(a,b) {
	var partsA = a.split(".");
	var partsB = b.split(".");
	var i = 0;
	while(i < partsA.length && i < partsB.length) {
		var partA = Std.parseInt(partsA[i]);
		var partB = Std.parseInt(partsB[i]);
		if(partA > partB) {
			return 1;
		} else if(partA < partB) {
			return -1;
		}
		++i;
	}
	if(partsA.length > partsB.length) {
		return 1;
	} else if(partsA.length < partsB.length) {
		return -1;
	}
	return 0;
};
tools_Helpers.getWindowsDrives = function() {
	var result = [];
	var hasC = false;
	if(Sys.systemName() == "Windows") {
		var out = tools_Helpers.command("wmic",["logicaldisk","get","name"],{ mute : true}).stdout;
		var _g = 0;
		var _g1 = new EReg("[\r\n]+","").split(out);
		while(_g < _g1.length) {
			var line = _g1[_g];
			++_g;
			line = StringTools.trim(line);
			if(line.length >= 2 && line.charAt(1) == ":") {
				var letter = line.charAt(0).toUpperCase();
				if(letter == "C") {
					hasC = true;
				} else {
					result.push(letter);
				}
			}
		}
	}
	if(hasC) {
		result.unshift("C");
	}
	return result;
};
var tools_Hxml = function() { };
$hxClasses["tools.Hxml"] = tools_Hxml;
tools_Hxml.__name__ = true;
tools_Hxml.parse = function(rawHxml) {
	var args = [];
	var i = 0;
	var len = rawHxml.length;
	var currentArg = "";
	var prevArg = null;
	var numberOfParens = 0;
	var c;
	var m0;
	while(i < len) {
		c = rawHxml.charAt(i);
		if(c == "(") {
			if(prevArg == "--macro") {
				++numberOfParens;
			}
			currentArg += c;
			++i;
		} else if(numberOfParens > 0 && c == ")") {
			--numberOfParens;
			currentArg += c;
			++i;
		} else if(c == "\"" || c == "'") {
			if(tools_Hxml.RE_BEGINS_WITH_STRING.match(HxOverrides.substr(rawHxml,i,null))) {
				m0 = tools_Hxml.RE_BEGINS_WITH_STRING.matched(0);
				currentArg += m0;
				i += m0.length;
			} else {
				currentArg += c;
				++i;
			}
		} else if(StringTools.trim(c) == "") {
			if(numberOfParens == 0) {
				if(currentArg.length > 0) {
					prevArg = currentArg;
					currentArg = "";
					args.push(prevArg);
				}
			} else {
				currentArg += c;
			}
			++i;
		} else {
			currentArg += c;
			++i;
		}
	}
	if(currentArg.length > 0) {
		args.push(currentArg);
	}
	return args;
};
tools_Hxml.formatAndChangeRelativeDir = function(hxmlData,originalDir,targetDir) {
	var updatedData = [];
	var i = 0;
	while(i < hxmlData.length) {
		var item = hxmlData[i];
		if(StringTools.startsWith(item,"-") || StringTools.endsWith(item,".hxml")) {
			if(updatedData.length > 0) {
				updatedData.push("\n");
			}
		}
		if(StringTools.endsWith(item,".hxml")) {
			var path = hxmlData[i];
			if(!haxe_io_Path.isAbsolute(path)) {
				path = haxe_io_Path.normalize(haxe_io_Path.join([originalDir,path]));
				if(StringTools.startsWith(path,targetDir + "/")) {
					path = HxOverrides.substr(path,targetDir.length + 1,null);
				}
			}
			updatedData.push(path);
		} else {
			updatedData.push(item);
		}
		if(item == "-cp" || item == "-cpp" || item == "-js" || item == "-swf") {
			++i;
			var path1 = hxmlData[i];
			if(!haxe_io_Path.isAbsolute(path1)) {
				path1 = haxe_io_Path.normalize(haxe_io_Path.join([originalDir,path1]));
				if(item != "-cp" && StringTools.startsWith(path1,targetDir + "/")) {
					path1 = HxOverrides.substr(path1,targetDir.length + 1,null);
				}
			}
			updatedData.push(path1);
		}
		++i;
	}
	return updatedData;
};
tools_Hxml.disableDeadCodeElimination = function(hxml) {
	var result = [];
	var _g = 0;
	var _g1 = hxml.length;
	while(_g < _g1) {
		var i = _g++;
		var item = hxml[i];
		if(!StringTools.startsWith(item,"-dce ")) {
			result.push(item);
		}
	}
	result.push("-dce no");
	return result;
};
var tools_Images = function() { };
$hxClasses["tools.Images"] = tools_Images;
tools_Images.__name__ = true;
tools_Images.getRaw = function(srcPath) {
	var pixels = null;
	var width;
	var height;
	var channels;
	tools_Sync.run(function(done) {
		var input = srcPath;
		var options = null;
		(options != null ? require("sharp")(input,options) : require("sharp")(input)).raw().toBuffer(function(err,data,info) {
			if(err != null) {
				throw haxe_Exception.thrown(err);
			}
			pixels = data;
			width = info.width;
			height = info.height;
			channels = info.channels;
			done();
		});
	});
	return { pixels : pixels, width : width, height : height, channels : channels};
};
tools_Images.saveRaw = function(dstPath,data) {
	tools_Sync.run(function(done) {
		var input = data.pixels;
		var options = { raw : { width : data.width, height : data.height, channels : data.channels}};
		(options != null ? require("sharp")(input,options) : require("sharp")(input)).png().toFile(dstPath,function(err,info) {
			if(err != null) {
				throw haxe_Exception.thrown(err);
			}
			done();
		});
	});
};
tools_Images.premultiplyAlpha = function(pixels) {
	var count = pixels.length;
	var index = 0;
	while(index < count) {
		var r = pixels[index];
		var g = pixels[index + 1];
		var b = pixels[index + 2];
		var a = pixels[index + 3] / 255.0;
		pixels[index] = r * a | 0;
		pixels[index + 1] = g * a | 0;
		pixels[index + 2] = b * a | 0;
		index += 4;
	}
};
tools_Images.resize = function(srcPath,dstPath,targetWidth,targetHeight,padTop,padRight,padBottom,padLeft) {
	if(padLeft == null) {
		padLeft = 0;
	}
	if(padBottom == null) {
		padBottom = 0;
	}
	if(padRight == null) {
		padRight = 0;
	}
	if(padTop == null) {
		padTop = 0;
	}
	tools_Sync.run(function(done) {
		var dirname = haxe_io_Path.directory(dstPath);
		if(!sys_FileSystem.exists(dirname)) {
			sys_FileSystem.createDirectory(dirname);
		}
		if(padTop == 0 && padRight == 0 && padBottom == 0 && padLeft == 0) {
			var input = srcPath;
			var options = null;
			(options != null ? require("sharp")(input,options) : require("sharp")(input)).resize(Math.round(targetWidth),Math.round(targetHeight)).toFile(dstPath,function(err,info) {
				if(err != null) {
					throw haxe_Exception.thrown(err);
				}
				done();
			});
		} else {
			var input = srcPath;
			var options = null;
			var tmp = options != null ? require("sharp")(input,options) : require("sharp")(input);
			var tmp1 = Math.round(padTop);
			var tmp2 = Math.round(padTop);
			var tmp3 = Math.round(padBottom);
			var tmp4 = Math.round(padLeft);
			tmp.resize(Math.round(targetWidth),Math.round(targetHeight)).extend({ top : tmp1, right : tmp2, bottom : tmp3, left : tmp4, background : { r : 0, g : 0, b : 0, alpha : 0}}).toFile(dstPath,function(err,info) {
				if(err != null) {
					throw haxe_Exception.thrown(err);
				}
				done();
			});
		}
	});
};
tools_Images.createIco = function(srcPath,dstPath,targetWidth,targetHeight) {
	if(targetHeight == null) {
		targetHeight = 256;
	}
	if(targetWidth == null) {
		targetWidth = 256;
	}
	tools_Sync.run(function(done) {
		var dirname = haxe_io_Path.directory(dstPath);
		if(!sys_FileSystem.exists(dirname)) {
			sys_FileSystem.createDirectory(dirname);
		}
		var input = srcPath;
		var options = null;
		(options != null ? require("sharp")(input,options) : require("sharp")(input)).resize(Math.round(targetWidth),Math.round(targetHeight)).toBuffer(function(err,data,info) {
			if(err != null) {
				throw haxe_Exception.thrown(err);
			}
			var input = [data];
			var options = { resize : true, sizes : [16,24,32,48,64,128,256]};
			(options != null ? require("to-ico")(input,options) : require("to-ico")(input)).then(function(buffer) {
				js_node_Fs.writeFileSync(dstPath,buffer);
				done();
			},function(err) {
				throw haxe_Exception.thrown(err);
			});
		});
	});
};
tools_Images.prototype = {
	metadata: function(path) {
		var width = 0;
		var height = 0;
		tools_Sync.run(function(done) {
			var input = path;
			var options = null;
			(options != null ? require("sharp")(input,options) : require("sharp")(input)).metadata(function(err,meta) {
				if(err != null) {
					throw haxe_Exception.thrown(err);
				}
				width = meta.width;
				height = meta.height;
			});
		});
		return { width : Math.round(width), height : Math.round(height)};
	}
	,__class__: tools_Images
};
var tools_Module = function() { };
$hxClasses["tools.Module"] = tools_Module;
tools_Module.__name__ = true;
tools_Module.patchHxml = function(cwd,project,hxml,moduleName) {
	var prevHxml = hxml.split("\n");
	var newHxml = [];
	var srcPath = haxe_io_Path.normalize(haxe_io_Path.join([cwd,"src"]));
	var didInsertCpSrc = false;
	var _g = 0;
	while(_g < prevHxml.length) {
		var line = prevHxml[_g];
		++_g;
		line = StringTools.trim(line);
		if(StringTools.startsWith(line,"-cp ")) {
			var path = haxe_io_Path.normalize(StringTools.ltrim(line.substring(4)));
			if(StringTools.startsWith(path,srcPath + "/") || path == srcPath) {
				if(!didInsertCpSrc) {
					if(moduleName == null || moduleName == "") {
						newHxml.push("-cp " + srcPath);
					} else {
						var modulePath = tools_Module.resolvePath(cwd,project,moduleName);
						var dependencies = tools_Module.resolveDependencies(project,moduleName);
						var dependants = tools_Module.resolveDependants(project,moduleName);
						newHxml.push("-cp " + modulePath);
						var _g1 = 0;
						while(_g1 < dependencies.length) {
							var dep = dependencies[_g1];
							++_g1;
							var depPath = tools_Module.resolvePath(cwd,project,dep);
							newHxml.push("-cp " + depPath);
						}
					}
					didInsertCpSrc = true;
				}
				continue;
			}
		}
		newHxml.push(line);
	}
	return newHxml.join("\n");
};
tools_Module.resolvePath = function(cwd,project,moduleName) {
	if(project.app.modules == null) {
		tools_Helpers.fail("ceramic.yml need a modules: key");
	}
	var info = Reflect.field(project.app.modules,moduleName);
	if(info == null) {
		tools_Helpers.fail("Missing module info for: " + moduleName + " in ceramic.yml");
	}
	if(info.pack == null) {
		tools_Helpers.fail("Missing pack in module info for: " + moduleName + " in ceramic.yml");
	}
	var pack = info.pack;
	var path = haxe_io_Path.join([cwd,"src",StringTools.replace(pack,".","/")]);
	return path;
};
tools_Module.resolvePack = function(cwd,project,moduleName) {
	if(project.app.modules == null) {
		tools_Helpers.fail("ceramic.yml need a modules: key");
	}
	var info = Reflect.field(project.app.modules,moduleName);
	if(info == null) {
		tools_Helpers.fail("Missing module info for: " + moduleName + " in ceramic.yml");
	}
	if(info.pack == null) {
		tools_Helpers.fail("Missing pack in module info for: " + moduleName + " in ceramic.yml");
	}
	var pack = info.pack;
	return pack;
};
tools_Module.resolveDependencies = function(project,moduleName) {
	if(project.app.modules == null) {
		tools_Helpers.fail("ceramic.yml need a modules: key");
	}
	var info = Reflect.field(project.app.modules,moduleName);
	if(info == null) {
		tools_Helpers.fail("Missing module info for: " + moduleName + " in ceramic.yml");
	}
	var uses = info.uses;
	if(uses == null) {
		return [];
	}
	return uses;
};
tools_Module.resolveDependants = function(project,moduleName) {
	return [];
};
var tools_PluginKind = $hxEnums["tools.PluginKind"] = { __ename__:true,__constructs__:null
	,Runtime: {_hx_name:"Runtime",_hx_index:0,__enum__:"tools.PluginKind",toString:$estr}
	,Tools: {_hx_name:"Tools",_hx_index:1,__enum__:"tools.PluginKind",toString:$estr}
	,Editor: {_hx_name:"Editor",_hx_index:2,__enum__:"tools.PluginKind",toString:$estr}
};
tools_PluginKind.__constructs__ = [tools_PluginKind.Runtime,tools_PluginKind.Tools,tools_PluginKind.Editor];
var tools_ProjectKind = $hxEnums["tools.ProjectKind"] = { __ename__:true,__constructs__:null
	,App: {_hx_name:"App",_hx_index:0,__enum__:"tools.ProjectKind",toString:$estr}
	,Plugin: ($_=function(kinds) { return {_hx_index:1,kinds:kinds,__enum__:"tools.ProjectKind",toString:$estr}; },$_._hx_name="Plugin",$_.__params__ = ["kinds"],$_)
};
tools_ProjectKind.__constructs__ = [tools_ProjectKind.App,tools_ProjectKind.Plugin];
var tools_Project = function() {
};
$hxClasses["tools.Project"] = tools_Project;
tools_Project.__name__ = true;
tools_Project.prototype = {
	getKind: function(path) {
		if(this.app != null) {
			return tools_ProjectKind.App;
		}
		if(this.plugin != null) {
			return tools_ProjectKind.Plugin([]);
		}
		if(!sys_FileSystem.exists(path)) {
			tools_Helpers.fail("There is no app project file at path: " + path);
		}
		if(sys_FileSystem.isDirectory(path)) {
			tools_Helpers.fail("A directory is not a valid ceramic project path at: " + path);
		}
		var data = null;
		try {
			data = StringTools.replace(StringTools.replace(js_node_Fs.readFileSync(path,{ encoding : "utf8"}),"{plugin:cwd}",tools_Helpers.context.cwd),"{cwd}",tools_Helpers.context.cwd);
		} catch( _g ) {
			var e = haxe_Exception.caught(_g).unwrap();
			tools_Helpers.fail("Unable to read project at path " + path + ": " + Std.string(e));
		}
		try {
			var parsed = npm_Yaml.parse(data);
			if(parsed.app == null) {
				if(parsed.plugin != null) {
					return tools_ProjectKind.Plugin([]);
				} else {
					return null;
				}
			} else {
				return tools_ProjectKind.App;
			}
		} catch( _g ) {
			var e = haxe_Exception.caught(_g).unwrap();
			tools_Helpers.fail("Error when parsing project YAML: " + Std.string(e));
		}
		tools_Helpers.fail("Unable to retrieve project kind.");
		return null;
	}
	,loadAppFile: function(path) {
		if(!sys_FileSystem.exists(path)) {
			tools_Helpers.fail("There is no app project file at path: " + path);
		}
		if(sys_FileSystem.isDirectory(path)) {
			tools_Helpers.fail("A directory is not a valid app project path at: " + path);
		}
		var data = null;
		try {
			data = StringTools.replace(StringTools.replace(js_node_Fs.readFileSync(path,{ encoding : "utf8"}),"{plugin:cwd}",tools_Helpers.context.cwd),"{cwd}",tools_Helpers.context.cwd);
		} catch( _g ) {
			var e = haxe_Exception.caught(_g).unwrap();
			tools_Helpers.fail("Unable to read project at path " + path + ": " + Std.string(e));
		}
		this.app = tools_ProjectLoader.loadAppConfig(data,tools_Helpers.context.defines,tools_Helpers.context.plugins,tools_Helpers.context.unbuiltPlugins);
		var tmp = haxe_io_Path.isAbsolute(path) ? path : haxe_io_Path.normalize(haxe_io_Path.join([tools_Helpers.context.cwd,path]));
		this.app.path = tmp;
		if(tools_Helpers.context.plugins != null) {
			var h = tools_Helpers.context.plugins.h;
			var plugin_h = h;
			var plugin_keys = Object.keys(h);
			var plugin_length = plugin_keys.length;
			var plugin_current = 0;
			while(plugin_current < plugin_length) {
				var plugin = plugin_h[plugin_keys[plugin_current++]];
				if(plugin.extendProject != null) {
					var prevPlugin = tools_Helpers.context.plugin;
					tools_Helpers.context.plugin = plugin;
					plugin.extendProject(this);
					tools_Helpers.context.plugin = prevPlugin;
				}
			}
		}
		this.app.editable.push("ceramic.Entity");
		this.app.editable.push("ceramic.Visual");
		this.app.editable.push("ceramic.Layer");
		this.app.editable.push("ceramic.Fragment");
		this.app.editable.push("ceramic.Quad");
		this.app.editable.push("ceramic.Text");
		this.app.editable.push("ceramic.Mesh");
		this.app.editable.push("ceramic.Shape");
		this.app.editable.push("ceramic.Ngon");
		this.app.editable.push("ceramic.Arc");
		this.app.editable.push("ceramic.Line");
		this.app.editable.push("ceramic.Particles");
		if(this.app.hxml == null) {
			this.app.hxml = "";
		}
		var appInfo = { };
		if(Reflect.field(this.app,"package") != null) {
			appInfo["package"] = Reflect.field(appInfo,"package");
		}
		if(this.app.name != null) {
			appInfo.name = this.app.name;
		}
		if(this.app.displayName != null) {
			appInfo.displayName = this.app.displayName;
		}
		if(this.app.author != null) {
			appInfo.author = this.app.author;
		}
		if(this.app.version != null) {
			appInfo.version = this.app.version;
		}
		if(this.app.collections != null) {
			appInfo.collections = this.app.collections;
		}
		if(this.app.editable != null) {
			appInfo.editable = this.app.editable;
		}
		var fh = this.app;
		fh.hxml = Std.string(fh.hxml) + ("\n" + "-D app_info=" + JSON.stringify(JSON.stringify(appInfo)));
		var fh = this.app;
		fh.hxml = Std.string(fh.hxml) + ("\n" + "--macro ceramic.macros.MacroCache.init()");
		var fh = this.app;
		fh.hxml = Std.string(fh.hxml) + ("\n" + "-D tracker_ceramic");
		var fh = this.app;
		fh.hxml = Std.string(fh.hxml) + ("\n" + "-D tracker_no_default_backend");
		var fh = this.app;
		fh.hxml = Std.string(fh.hxml) + ("\n" + "-D tracker_custom_entity=ceramic.Entity");
		var fh = this.app;
		fh.hxml = Std.string(fh.hxml) + ("\n" + "-D tracker_custom_component=ceramic.Component");
		var fh = this.app;
		fh.hxml = Std.string(fh.hxml) + ("\n" + "-D tracker_custom_array_pool=ceramic.ArrayPool");
		var fh = this.app;
		fh.hxml = Std.string(fh.hxml) + ("\n" + "-D tracker_custom_backend=ceramic.TrackerBackend");
		var fh = this.app;
		fh.hxml = Std.string(fh.hxml) + ("\n" + "-D tracker_custom_reusable_array=ceramic.ReusableArray");
		if(Object.prototype.hasOwnProperty.call(tools_Helpers.context.defines.h,"android")) {
			if(Object.prototype.hasOwnProperty.call(tools_Helpers.context.defines.h,"ceramic_android_use_gcc")) {
				var fh = this.app;
				fh.hxml = Std.string(fh.hxml) + ("\n" + "-D HXCPP_ANDROID_PLATFORM=21 -D PLATFORM=android-21");
			}
			var fh = this.app;
			fh.hxml = Std.string(fh.hxml) + ("\n" + "-D NO_PRECOMPILED_HEADERS");
		}
	}
	,loadPluginFile: function(path) {
		if(!sys_FileSystem.exists(path)) {
			tools_Helpers.fail("There is no plugin project file at path: " + path);
		}
		if(sys_FileSystem.isDirectory(path)) {
			tools_Helpers.fail("A directory is not a valid plugin project path at: " + path);
		}
		var data = null;
		try {
			data = StringTools.replace(StringTools.replace(js_node_Fs.readFileSync(path,{ encoding : "utf8"}),"{plugin:cwd}",haxe_io_Path.directory(path)),"{cwd}",tools_Helpers.context.cwd);
		} catch( _g ) {
			var e = haxe_Exception.caught(_g).unwrap();
			tools_Helpers.fail("Unable to read project at path " + path + ": " + Std.string(e));
		}
		this.plugin = tools_ProjectLoader.loadPluginConfig(data,tools_Helpers.context.defines);
		var tmp = haxe_io_Path.isAbsolute(path) ? path : haxe_io_Path.normalize(haxe_io_Path.join([tools_Helpers.context.cwd,path]));
		this.plugin.path = tmp;
	}
	,__class__: tools_Project
};
var tools_ProjectLoader = function() { };
$hxClasses["tools.ProjectLoader"] = tools_ProjectLoader;
tools_ProjectLoader.__name__ = true;
tools_ProjectLoader.loadAppConfig = function(input,defines,plugins,unbuiltPlugins) {
	var app = null;
	try {
		var parsed = npm_Yaml.parse(input);
		if(parsed.app == null) {
			if(parsed.plugin != null) {
				tools_Helpers.fail("This project is not a ceramic app project. Is it a plugin project?");
			} else {
				tools_Helpers.fail("This project is not a ceramic app project.");
			}
		}
		app = parsed.app;
	} catch( _g ) {
		var e = haxe_Exception.caught(_g).unwrap();
		tools_Helpers.fail("Error when parsing project YAML: " + Std.string(e));
	}
	try {
		if(app.defines != null) {
			if(((app.defines) instanceof Array)) {
				var appDefinesList = app.defines;
				app.defines = { };
				var _g = 0;
				while(_g < appDefinesList.length) {
					var item = appDefinesList[_g];
					++_g;
					if(typeof(item) == "string" || typeof(item) == "boolean" || typeof(item) == "number" || typeof(item) == "number" && ((item | 0) === item)) {
						app.defines[item] = true;
					} else {
						var _g1 = 0;
						var _g2 = Reflect.fields(item);
						while(_g1 < _g2.length) {
							var key = _g2[_g1];
							++_g1;
							app.defines[key] = Reflect.field(item,key);
						}
					}
				}
			}
			var _g = 0;
			var _g1 = Reflect.fields(app.defines);
			while(_g < _g1.length) {
				var key = _g1[_g];
				++_g;
				if(!Object.prototype.hasOwnProperty.call(defines.h,key)) {
					var val = Reflect.field(app.defines,key);
					defines.h[key] = val == true ? "" : "" + (val == null ? "null" : "" + val);
				}
			}
		} else {
			app.defines = { };
		}
		if(app.plugins != null && ((app.plugins) instanceof Array)) {
			var pluginList = app.plugins;
			var _g = 0;
			while(_g < pluginList.length) {
				var pluginName = pluginList[_g];
				++_g;
				var key = "plugin_" + pluginName;
				if(!Object.prototype.hasOwnProperty.call(defines.h,key)) {
					defines.h[key] = "";
				}
			}
		}
		var pluginI = 0;
		if(plugins != null) {
			var h = plugins.h;
			var plugin_h = h;
			var plugin_keys = Object.keys(h);
			var plugin_length = plugin_keys.length;
			var plugin_current = 0;
			while(plugin_current < plugin_length) {
				var plugin = plugin_h[plugin_keys[plugin_current++]];
				if(plugin.runtime != null) {
					app["if true || plugin_runtime_" + pluginI++] = JSON.parse(JSON.stringify(plugin.runtime));
				}
			}
		}
		if(unbuiltPlugins != null) {
			var h = unbuiltPlugins.h;
			var plugin_h = h;
			var plugin_keys = Object.keys(h);
			var plugin_length = plugin_keys.length;
			var plugin_current = 0;
			while(plugin_current < plugin_length) {
				var plugin = plugin_h[plugin_keys[plugin_current++]];
				if(plugin.runtime != null) {
					app["if true || plugin_runtime_" + pluginI++] = JSON.parse(JSON.stringify(plugin.runtime));
				}
			}
		}
		tools_ProjectLoader.evaluateConditionals(app,defines,true);
		if(app.libs == null) {
			app.libs = [];
		}
		if(app.paths == null) {
			app.paths = [];
		}
		if(app.editable == null) {
			app.editable = [];
		}
		var _g = 0;
		var _g1 = tools_Project.runtimeLibraries;
		while(_g < _g1.length) {
			var item = _g1[_g];
			++_g;
			if(typeof(item) == "string") {
				app.libs.push(item);
			} else {
				var libName = null;
				var libVersion = null;
				var _g2 = 0;
				var _g3 = Reflect.fields(item);
				while(_g2 < _g3.length) {
					var key = _g3[_g2];
					++_g2;
					libName = key;
					libVersion = Reflect.field(item,key);
					break;
				}
				if(libVersion != null && StringTools.startsWith(libVersion,"git:")) {
					app.libs.push(libName);
				} else {
					app.libs.push(item);
				}
			}
		}
		if(app.paths == null) {
			app.paths = [];
		}
		if(app.hooks == null) {
			app.hooks = [];
		}
		var genPath = haxe_io_Path.join([tools_Helpers.context.cwd,"gen"]);
		if(sys_FileSystem.exists(genPath) && sys_FileSystem.isDirectory(genPath)) {
			var paths = app.paths;
			paths.push("gen");
		}
		if(app.icon == null) {
			app.icon = "resources/AppIcon.png";
		}
		if(app.iconFlat == null) {
			app.iconFlat = "resources/AppIcon-flat.png";
		}
		if(app.screen == null) {
			app.screen = { };
		}
		if(app.screen.width == null) {
			app.screen.width = 320;
			app.screen.height = 568;
		}
		if(app.screen.orientation == null) {
			if(app.screen.width > app.screen.height) {
				app.screen.orientation = "landscape";
			} else {
				app.screen.orientation = "portrait";
			}
		}
		app.lowercaseName = app.name.toLowerCase();
		if(Object.prototype.hasOwnProperty.call(app,"package")) {
			app.packagePath = StringTools.replace("" + Std.string(Reflect.field(app,"package")),".","/");
		}
		if(app.defines != null) {
			var _g = 0;
			var _g1 = Reflect.fields(app.defines);
			while(_g < _g1.length) {
				var key = _g1[_g];
				++_g;
				if(!Object.prototype.hasOwnProperty.call(defines.h,key)) {
					var val = Reflect.field(app.defines,key);
					defines.h[key] = val == true ? "" : "" + (val == null ? "null" : "" + val);
				}
			}
		}
		app.defines = { };
		var h = defines.h;
		var key_h = h;
		var key_keys = Object.keys(h);
		var key_length = key_keys.length;
		var key_current = 0;
		while(key_current < key_length) {
			var key = key_keys[key_current++];
			var val = defines.h[key];
			app.defines[key] = val == null || StringTools.trim(val) == "" ? true : StringTools.trim(val);
		}
	} catch( _g ) {
		var e = haxe_Exception.caught(_g).unwrap();
		tools_Helpers.fail("Error when processing app project content: " + Std.string(e));
	}
	return app;
};
tools_ProjectLoader.loadPluginConfig = function(input,defines) {
	var plugin = null;
	try {
		var parsed = npm_Yaml.parse(input);
		if(parsed.plugin == null) {
			if(parsed.app != null) {
				tools_Helpers.fail("This project is not a ceramic plugin project. Is it an app project?");
			} else {
				tools_Helpers.fail("This project is not a ceramic plugin project.");
			}
		}
		plugin = parsed.plugin;
	} catch( _g ) {
		var e = haxe_Exception.caught(_g).unwrap();
		tools_Helpers.fail("Error when parsing project YAML: " + Std.string(e));
	}
	if(plugin.runtime != null) {
		Reflect.deleteField(plugin,"runtime");
	}
	try {
		if(plugin.defines != null) {
			if(((plugin.defines) instanceof Array)) {
				var pluginDefinesList = plugin.defines;
				plugin.defines = { };
				var _g = 0;
				while(_g < pluginDefinesList.length) {
					var item = pluginDefinesList[_g];
					++_g;
					if(typeof(item) == "string" || typeof(item) == "boolean" || typeof(item) == "number" || typeof(item) == "number" && ((item | 0) === item)) {
						plugin.defines[item] = true;
					} else {
						var _g1 = 0;
						var _g2 = Reflect.fields(item);
						while(_g1 < _g2.length) {
							var key = _g2[_g1];
							++_g1;
							plugin.defines[key] = Reflect.field(item,key);
						}
					}
				}
			}
			var _g = 0;
			var _g1 = Reflect.fields(plugin.defines);
			while(_g < _g1.length) {
				var key = _g1[_g];
				++_g;
				if(!Object.prototype.hasOwnProperty.call(defines.h,key)) {
					var val = Reflect.field(plugin.defines,key);
					defines.h[key] = val == true ? "" : "" + (val == null ? "null" : "" + val);
				}
			}
		}
		tools_ProjectLoader.evaluateConditionals(plugin,defines,true);
		if(plugin.libs == null) {
			plugin.libs = [];
		}
		if(plugin.paths == null) {
			plugin.paths = [];
		}
		plugin.lowercaseName = plugin.name.toLowerCase();
		if(plugin.defines != null) {
			var _g = 0;
			var _g1 = Reflect.fields(plugin.defines);
			while(_g < _g1.length) {
				var key = _g1[_g];
				++_g;
				if(!Object.prototype.hasOwnProperty.call(defines.h,key)) {
					var val = Reflect.field(plugin.defines,key);
					defines.h[key] = val == true ? "" : "" + (val == null ? "null" : "" + val);
				}
			}
		} else {
			plugin.defines = { };
		}
		var h = defines.h;
		var key_h = h;
		var key_keys = Object.keys(h);
		var key_length = key_keys.length;
		var key_current = 0;
		while(key_current < key_length) {
			var key = key_keys[key_current++];
			var val = defines.h[key];
			plugin.defines[key] = val == null || StringTools.trim(val) == "" ? true : StringTools.trim(val);
		}
	} catch( _g ) {
		var e = haxe_Exception.caught(_g).unwrap();
		tools_Helpers.fail("Error when processing plugin project content: " + Std.string(e));
	}
	return plugin;
};
tools_ProjectLoader.evaluateConditionals = function(data,defines,isRoot) {
	var _g = 0;
	var _g1 = Reflect.fields(data);
	while(_g < _g1.length) {
		var key = _g1[_g];
		++_g;
		if(StringTools.startsWith(key,"if ")) {
			var parser = new hscript_Parser();
			var condition = parser.parseString("(" + key.substring(3) + ");");
			var identifiers = tools_ProjectLoader.extractIdentifiers(key.substring(3));
			var interp = new hscript_Interp();
			var h = defines.h;
			var defKey_h = h;
			var defKey_keys = Object.keys(h);
			var defKey_length = defKey_keys.length;
			var defKey_current = 0;
			while(defKey_current < defKey_length) {
				var defKey = defKey_keys[defKey_current++];
				var val = defines.h[defKey];
				var this1 = interp.variables;
				var value = val == null || StringTools.trim(val) == "";
				this1.h[defKey] = value ? true : val;
			}
			var _g2 = 0;
			while(_g2 < identifiers.length) {
				var identifier = identifiers[_g2];
				++_g2;
				if(!Object.prototype.hasOwnProperty.call(interp.variables.h,identifier)) {
					interp.variables.h[identifier] = false;
				}
			}
			var result = false;
			try {
				result = interp.execute(condition);
			} catch( _g3 ) {
				var e = haxe_Exception.caught(_g3).unwrap();
				tools_Helpers.warning("Error when evaluating expression '" + key.substring(3) + "': " + Std.string(e));
			}
			if(result) {
				tools_ProjectLoader.mergeConfigs(data,Reflect.field(data,key),defines,isRoot);
			}
			Reflect.deleteField(data,key);
		}
	}
};
tools_ProjectLoader.mergeConfigs = function(data,extra,defines,isRoot) {
	tools_ProjectLoader.evaluateConditionals(extra,defines,false);
	var _g = 0;
	var _g1 = Reflect.fields(extra);
	while(_g < _g1.length) {
		var key = _g1[_g];
		++_g;
		var modifier = null;
		if(StringTools.startsWith(key,"+")) {
			modifier = "+";
			key = key.substring(1);
		} else if(StringTools.startsWith(key,"-")) {
			modifier = "-";
			key = key.substring(1);
		}
		var origKey = isRoot || modifier == null ? key : modifier + key;
		var orig = Reflect.field(data,origKey);
		var value = Reflect.field(extra,(modifier != null ? modifier : "") + key);
		if(key == "defines") {
			if(((value) instanceof Array)) {
				var valueList = value;
				value = { };
				var _g2 = 0;
				while(_g2 < valueList.length) {
					var item = valueList[_g2];
					++_g2;
					if(typeof(item) == "string" || typeof(item) == "boolean" || typeof(item) == "number" || typeof(item) == "number" && ((item | 0) === item)) {
						value[item] = true;
					} else {
						var _g3 = 0;
						var _g4 = Reflect.fields(item);
						while(_g3 < _g4.length) {
							var key1 = _g4[_g3];
							++_g3;
							value[key1] = Reflect.field(item,key1);
						}
					}
				}
			}
		}
		if(orig != null && modifier == "+") {
			if(((orig) instanceof Array) && ((value) instanceof Array)) {
				var list = value;
				var origList = orig;
				var _g5 = 0;
				while(_g5 < list.length) {
					var entry = list[_g5];
					++_g5;
					origList.push(entry);
				}
			} else if(typeof(orig) == "string" && typeof(value) == "string") {
				var str = value;
				var origStr = orig;
				origStr = StringTools.rtrim(origStr) + "\n" + StringTools.ltrim(str);
				orig = origStr;
				data[origKey] = orig;
			} else if(typeof(orig) != "string" && typeof(orig) != "boolean" && !(typeof(orig) == "number" && ((orig | 0) === orig)) && typeof(orig) != "number") {
				var _g6 = 0;
				var _g7 = Reflect.fields(value);
				while(_g6 < _g7.length) {
					var subKey = _g7[_g6];
					++_g6;
					var subValue = Reflect.field(value,subKey);
					orig[subKey] = subValue;
				}
			}
		} else if(orig != null && modifier == "-") {
			if(((orig) instanceof Array) && ((value) instanceof Array)) {
				var list1 = value;
				var origList1 = orig;
				var _g8 = 0;
				while(_g8 < list1.length) {
					var entry1 = list1[_g8];
					++_g8;
					HxOverrides.remove(origList1,entry1);
				}
			} else if(typeof(orig) == "string" && typeof(value) == "string") {
				var str1 = value;
				var origStr1 = orig;
				origStr1 = StringTools.replace(origStr1,str1,"");
				orig = origStr1;
				data[origKey] = orig;
			} else if(typeof(orig) != "string" && typeof(orig) != "boolean" && !(typeof(orig) == "number" && ((orig | 0) === orig)) && typeof(orig) != "number") {
				if(((value) instanceof Array)) {
					var list2 = value;
					var _g9 = 0;
					while(_g9 < list2.length) {
						var entry2 = list2[_g9];
						++_g9;
						Reflect.deleteField(orig,entry2);
					}
				} else {
					var _g10 = 0;
					var _g11 = Reflect.fields(value);
					while(_g10 < _g11.length) {
						var subKey1 = _g11[_g10];
						++_g10;
						Reflect.deleteField(orig,subKey1);
					}
				}
			}
		} else {
			data[origKey] = value;
		}
	}
};
tools_ProjectLoader.extractIdentifiers = function(input) {
	var identifiers_h = Object.create(null);
	var i = 0;
	var len = input.length;
	var cleaned = "";
	while(i < len) {
		var c = input.charAt(i);
		if(tools_ProjectLoader.RE_ALNUM_CHAR.match(c)) {
			cleaned += c;
		} else if(!StringTools.endsWith(cleaned," ")) {
			cleaned += " ";
		}
		++i;
	}
	var _g = 0;
	var _g1 = cleaned.split(" ");
	while(_g < _g1.length) {
		var part = _g1[_g];
		++_g;
		if(tools_ProjectLoader.RE_IDENTIFIER.match(part)) {
			identifiers_h[part] = true;
		}
	}
	var result = [];
	var h = identifiers_h;
	var key_h = h;
	var key_keys = Object.keys(h);
	var key_length = key_keys.length;
	var key_current = 0;
	while(key_current < key_length) {
		var key = key_keys[key_current++];
		result.push(key);
	}
	return result;
};
var tools_Sync = function() { };
$hxClasses["tools.Sync"] = tools_Sync;
tools_Sync.__name__ = true;
tools_Sync.run = function(fn,simplify) {
	if(simplify == null) {
		simplify = false;
	}
	var future = new npm_Future();
	var sent = false;
	var payload = null;
	var resultError = null;
	var callback = function() {
		var args = Array.prototype.slice.call(arguments);
		if(!sent) {
			if(simplify) {
				payload = args[0];
				if(((payload) instanceof tools__$Sync_InternalError)) {
					resultError = payload.err;
				}
			} else {
				payload = args;
			}
			future.return();
		}
	};
	global.setImmediate(function() {
		fn(callback);
	});
	future.wait();
	sent = true;
	if(resultError != null) {
		throw haxe_Exception.thrown(resultError);
	}
	return payload;
};
var tools__$Sync_InternalError = function(err) {
	this.err = err;
};
$hxClasses["tools._Sync.InternalError"] = tools__$Sync_InternalError;
tools__$Sync_InternalError.__name__ = true;
tools__$Sync_InternalError.prototype = {
	__class__: tools__$Sync_InternalError
};
var tools_Task = function() {
	this.hidden = false;
	this.plugin = null;
	this.backend = null;
	this.backend = tools_Helpers.context.backend;
	this.plugin = tools_Helpers.context.plugin;
};
$hxClasses["tools.Task"] = tools_Task;
tools_Task.__name__ = true;
tools_Task.prototype = {
	help: function(cwd) {
		return null;
	}
	,info: function(cwd) {
		return null;
	}
	,run: function(cwd,args) {
		tools_Helpers.fail("This task has no implementation.");
	}
	,__class__: tools_Task
};
var tools_Tools = function() { };
$hxClasses["tools.Tools"] = tools_Tools;
tools_Tools.__name__ = true;
tools_Tools.main = function() {
	var $module = module;
	$module.exports = tools_Tools.runInFiber;
};
tools_Tools.runInFiber = function(cwd,args,ceramicPath) {
	require("fibers")(function() {
		tools_Tools.run(cwd,args,ceramicPath);
	}).run();
};
tools_Tools.run = function(cwd,args,ceramicPath) {
	tools_Helpers.context = { project : null, colors : true, debug : args.indexOf("--debug") != -1, defines : new haxe_ds_StringMap(), ceramicToolsPath : ceramicPath, ceramicRootPath : haxe_io_Path.normalize(haxe_io_Path.join([ceramicPath,".."])), ceramicRuntimePath : haxe_io_Path.normalize(haxe_io_Path.join([ceramicPath,"../runtime"])), ceramicRunnerPath : haxe_io_Path.normalize(haxe_io_Path.join([ceramicPath,"../runner"])), ceramicGitDepsPath : haxe_io_Path.normalize(haxe_io_Path.join([ceramicPath,"../git"])), defaultPluginsPath : haxe_io_Path.normalize(haxe_io_Path.join([ceramicPath,"../plugins"])), projectPluginsPath : haxe_io_Path.normalize(haxe_io_Path.join([cwd,"plugins"])), homeDir : "" + Std.string(require("os").homedir()), isLocalDotCeramic : false, dotCeramicPath : "" + haxe_io_Path.join([require("os").homedir(),".ceramic"]), variant : "standard", vscode : false, muted : false, plugins : new haxe_ds_StringMap(), unbuiltPlugins : new haxe_ds_StringMap(), backend : null, cwd : cwd, args : args, tasks : new haxe_ds_StringMap(), plugin : null, rootTask : null, isEmbeddedInElectron : false, ceramicVersion : null, assetsChanged : false, iconsChanged : false, printSplitLines : args.indexOf("--print-split-lines") != -1};
	var electronPackageFile = haxe_io_Path.join([tools_Helpers.context.ceramicToolsPath,"../../package.json"]);
	if(sys_FileSystem.exists(electronPackageFile)) {
		if(JSON.parse(js_node_Fs.readFileSync(electronPackageFile,{ encoding : "utf8"})).name == "ceramic") {
			tools_Helpers.context.isEmbeddedInElectron = true;
			var tmp = haxe_io_Path.join([tools_Helpers.context.ceramicToolsPath,"../../vendor/ceramic-runtime"]);
			tools_Helpers.context.ceramicRuntimePath = haxe_io_Path.normalize(tmp);
			var tmp = haxe_io_Path.join([tools_Helpers.context.ceramicToolsPath,"../../vendor/ceramic-plugins"]);
			tools_Helpers.context.defaultPluginsPath = haxe_io_Path.normalize(tmp);
		}
	}
	var version = require(haxe_io_Path.join([tools_Helpers.context.ceramicToolsPath,"package.json"])).version;
	var versionPath = haxe_io_Path.join([__dirname,"version"]);
	if(sys_FileSystem.exists(versionPath)) {
		version = js_node_Fs.readFileSync(versionPath,{ encoding : "utf8"});
	}
	if(tools_Helpers.commandExists("git")) {
		var hash = StringTools.trim(tools_Helpers.command("git",["rev-parse","--short","HEAD"],{ cwd : tools_Helpers.context.ceramicToolsPath, mute : true}).stdout);
		if(hash != null && hash != "") {
			version += "-" + hash;
		}
	}
	tools_Helpers.context.ceramicVersion = version;
	var localDotCeramic = haxe_io_Path.join([tools_Helpers.context.cwd,".ceramic"]);
	if(sys_FileSystem.exists(localDotCeramic) && sys_FileSystem.isDirectory(localDotCeramic)) {
		tools_Helpers.context.dotCeramicPath = localDotCeramic;
		tools_Helpers.context.isLocalDotCeramic = true;
	}
	if(!sys_FileSystem.exists(tools_Helpers.context.dotCeramicPath)) {
		sys_FileSystem.createDirectory(tools_Helpers.context.dotCeramicPath);
	}
	tools_Helpers.computePlugins();
	var this1 = tools_Helpers.context.tasks;
	var value = new tools_tasks_Version();
	this1.h["version"] = value;
	var this1 = tools_Helpers.context.tasks;
	var value = new tools_tasks_Help();
	this1.h["help"] = value;
	var this1 = tools_Helpers.context.tasks;
	var value = new tools_tasks_Server();
	this1.h["server"] = value;
	var this1 = tools_Helpers.context.tasks;
	var value = new tools_tasks_Query();
	this1.h["query"] = value;
	var this1 = tools_Helpers.context.tasks;
	var value = new tools_tasks_Init();
	this1.h["init"] = value;
	var this1 = tools_Helpers.context.tasks;
	var value = new tools_tasks_Vscode();
	this1.h["vscode"] = value;
	var this1 = tools_Helpers.context.tasks;
	var value = new tools_tasks_Link();
	this1.h["link"] = value;
	var this1 = tools_Helpers.context.tasks;
	var value = new tools_tasks_Unlink();
	this1.h["unlink"] = value;
	var this1 = tools_Helpers.context.tasks;
	var value = new tools_tasks_Path();
	this1.h["path"] = value;
	var this1 = tools_Helpers.context.tasks;
	var value = new tools_tasks_Info();
	this1.h["info"] = value;
	var this1 = tools_Helpers.context.tasks;
	var value = new tools_tasks_Libs();
	this1.h["libs"] = value;
	var this1 = tools_Helpers.context.tasks;
	var value = new tools_tasks_Hxml();
	this1.h["hxml"] = value;
	var this1 = tools_Helpers.context.tasks;
	var value = new tools_tasks_Module();
	this1.h["module"] = value;
	var this1 = tools_Helpers.context.tasks;
	var value = new tools_tasks_Font();
	this1.h["font"] = value;
	var this1 = tools_Helpers.context.tasks;
	var value = new tools_tasks_ZipTools();
	this1.h["tools zip"] = value;
	var this1 = tools_Helpers.context.tasks;
	var value = new tools_tasks_HaxeServer();
	this1.h["haxe server"] = value;
	var this1 = tools_Helpers.context.tasks;
	var value = new tools_tasks_plugin_PluginHxml();
	this1.h["plugin hxml"] = value;
	var this1 = tools_Helpers.context.tasks;
	var value = new tools_tasks_plugin_BuildPlugin();
	this1.h["plugin build"] = value;
	var this1 = tools_Helpers.context.tasks;
	var value = new tools_tasks_plugin_ListPlugins();
	this1.h["plugin list"] = value;
	var this1 = tools_Helpers.context.tasks;
	var value = new tools_tasks_IdeInfo();
	this1.h["ide info"] = value;
	var this1 = tools_Helpers.context.tasks;
	var value = new tools_tasks_haxelib_ExportLibrary();
	this1.h["lib export"] = value;
	var this1 = tools_Helpers.context.tasks;
	var value = new tools_tasks_images_ExportImages();
	this1.h["images export"] = value;
	if(tools_Helpers.context.plugins != null) {
		var h = tools_Helpers.context.plugins.h;
		var key_h = h;
		var key_keys = Object.keys(h);
		var key_length = key_keys.length;
		var key_current = 0;
		while(key_current < key_length) {
			var key = key_keys[key_current++];
			var plugin = tools_Helpers.context.plugins.h[key];
			var prevPlugin = tools_Helpers.context.plugin;
			tools_Helpers.context.plugin = plugin;
			plugin.init(tools_Helpers.context);
			tools_Helpers.context.plugin = prevPlugin;
		}
	}
	var index = args.indexOf("--no-colors");
	if(index != -1) {
		tools_Helpers.context.colors = false;
		args.splice(index,1);
	}
	index = args.indexOf("--cwd");
	if(index != -1) {
		if(index + 1 >= args.length) {
			tools_Helpers.fail("A value is required after --cwd argument.");
		}
		var newCwd = args[index + 1];
		if(!haxe_io_Path.isAbsolute(newCwd)) {
			newCwd = haxe_io_Path.normalize(haxe_io_Path.join([cwd,newCwd]));
		}
		if(!sys_FileSystem.exists(newCwd)) {
			tools_Helpers.fail("Provided cwd path doesn't exist.");
		}
		if(!sys_FileSystem.isDirectory(newCwd)) {
			tools_Helpers.fail("Provided cwd path exists but is not a directory.");
		}
		cwd = newCwd;
		tools_Helpers.context.cwd = cwd;
		args.splice(index,2);
	}
	index = args.indexOf("--variant");
	if(index != -1) {
		if(index + 1 >= args.length) {
			tools_Helpers.fail("A value is required after --variant argument.");
		}
		var variant = args[index + 1];
		tools_Helpers.context.variant = variant;
		tools_Helpers.context.defines.h["variant"] = variant;
		if(!Object.prototype.hasOwnProperty.call(tools_Helpers.context.defines.h,variant)) {
			tools_Helpers.context.defines.h[variant] = "";
		}
		args.splice(index,2);
	}
	if(args.indexOf("--debug") != -1) {
		tools_Helpers.context.debug = true;
		if(!Object.prototype.hasOwnProperty.call(tools_Helpers.context.defines.h,"debug")) {
			tools_Helpers.context.defines.h["debug"] = "";
		}
	}
	index = args.indexOf("--vscode-editor");
	if(index != -1) {
		tools_Helpers.context.vscode = true;
		args.splice(index,1);
	}
	tools_Helpers.context.project = tools_Helpers.loadProject(cwd,args);
	tools_Helpers.context.args = args;
	if(args.length < 1) {
		tools_Helpers.fail("Invalid arguments.");
	} else {
		var taskName = args[0];
		if(args.length >= 3 && Object.prototype.hasOwnProperty.call(tools_Helpers.context.tasks.h,taskName + " " + args[1] + " " + args[2])) {
			taskName = taskName + " " + args[1] + " " + args[2];
		} else if(args.length >= 2 && Object.prototype.hasOwnProperty.call(tools_Helpers.context.tasks.h,taskName + " " + args[1])) {
			taskName = taskName + " " + args[1];
		}
		if(Object.prototype.hasOwnProperty.call(tools_Helpers.context.tasks.h,taskName)) {
			var task = tools_Helpers.context.tasks.h[taskName];
			tools_Helpers.context.backend = task.backend;
			tools_Helpers.context.plugin = task.plugin;
			tools_Helpers.extractDefines(cwd,args);
			tools_Helpers.context.rootTask = task;
			task.run(cwd,args);
			process.exit(0);
		} else {
			tools_Helpers.fail("Unknown command: " + taskName);
		}
	}
};
var tools_ToolsPlugin = function() {
};
$hxClasses["tools.ToolsPlugin"] = tools_ToolsPlugin;
tools_ToolsPlugin.__name__ = true;
tools_ToolsPlugin.main = function() {
	var $module = module;
	$module.exports = new tools_ToolsPlugin();
};
tools_ToolsPlugin.prototype = {
	init: function(context) {
		tools_Helpers.context = context;
		var tasks = context.tasks;
		var value = new tools_tasks_imgui_SetupJS();
		tasks.h["imgui setup js"] = value;
	}
	,extendProject: function(project) {
	}
	,__class__: tools_ToolsPlugin
};
var tools_spec_BackendTools = function() { };
$hxClasses["tools.spec.BackendTools"] = tools_spec_BackendTools;
tools_spec_BackendTools.__name__ = true;
tools_spec_BackendTools.__isInterface__ = true;
tools_spec_BackendTools.prototype = {
	__class__: tools_spec_BackendTools
};
var tools_tasks_Font = function() {
	tools_Task.call(this);
};
$hxClasses["tools.tasks.Font"] = tools_tasks_Font;
tools_tasks_Font.__name__ = true;
tools_tasks_Font.__super__ = tools_Task;
tools_tasks_Font.prototype = $extend(tools_Task.prototype,{
	help: function(cwd) {
		return [["--font <path to font>","The ttf/otf font file to convert"],["--out <output directory>","The output directory"],["--msdf","If used, export with multichannel distance field"],["--size <font size>","The font size to export (default: 42)"],["--factor <factor>","A precision factor (advanced usage, default: 4)"],["--charset","Characters to use as charset"],["--charset-file","A text file containing characters to use as charset"],["--offset-x","Move every character by this X offset"],["--offset-y","Move every character by this Y offset"]];
	}
	,info: function(cwd) {
		return "Utility to convert ttf/otf font to bitmap font compatible with ceramic";
	}
	,run: function(cwd,args) {
		var fontPath = tools_Helpers.extractArgValue(args,"font");
		var outputPath = tools_Helpers.extractArgValue(args,"out");
		var charset = tools_Helpers.extractArgValue(args,"charset");
		var charsetFile = tools_Helpers.extractArgValue(args,"charset-file");
		var msdf = tools_Helpers.extractArgFlag(args,"msdf");
		var size = tools_Helpers.extractArgValue(args,"size") != null ? parseFloat(tools_Helpers.extractArgValue(args,"size")) : 42;
		var offsetX = tools_Helpers.extractArgValue(args,"offset-x") != null ? parseFloat(tools_Helpers.extractArgValue(args,"offset-x")) : 0;
		var offsetY = tools_Helpers.extractArgValue(args,"offset-y") != null ? parseFloat(tools_Helpers.extractArgValue(args,"offset-y")) : 0;
		if(fontPath == null) {
			tools_Helpers.fail("--font argument is required");
		}
		if(outputPath == null) {
			outputPath = cwd;
		}
		if(charset == null) {
			charset = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~¡¢£¤¥¦§¨©ª«¬­®¯°±²³´µ¶·¸¹º»¼½¾¿ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖ×ØÙÚÛÜÝÞßàáâãäåæçèéêëìíîïðñòóôõö÷øùúûüýþÿœŒ€£";
		}
		if(!haxe_io_Path.isAbsolute(fontPath)) {
			fontPath = haxe_io_Path.normalize(haxe_io_Path.join([cwd,fontPath]));
		}
		if(!haxe_io_Path.isAbsolute(outputPath)) {
			outputPath = haxe_io_Path.normalize(haxe_io_Path.join([cwd,outputPath]));
		}
		var tmpDir = haxe_io_Path.join([cwd,".tmp"]);
		if(sys_FileSystem.exists(tmpDir)) {
			tools_Files.deleteRecursive(tmpDir);
		}
		sys_FileSystem.createDirectory(tmpDir);
		var ttfName = haxe_io_Path.withoutDirectory(fontPath);
		var rawName = haxe_io_Path.withoutExtension(ttfName);
		var tmpFontPath = haxe_io_Path.join([tmpDir,ttfName]);
		sys_io_File.copy(fontPath,tmpFontPath);
		var charsetPath = haxe_io_Path.join([tmpDir,"charset.txt"]);
		if(charsetFile != null) {
			if(!haxe_io_Path.isAbsolute(charsetFile)) {
				charsetFile = haxe_io_Path.join([cwd,charsetFile]);
			}
			charsetPath = charsetFile;
		} else {
			js_node_Fs.writeFileSync(charsetPath,charset);
		}
		var factor = 0.25;
		var rawFactor = tools_Helpers.extractArgValue(args,"factor");
		if(rawFactor != null) {
			factor = 1.0 / parseFloat(rawFactor);
		}
		if(msdf) {
			tools_Helpers.command("node",[haxe_io_Path.join([tools_Helpers.context.ceramicToolsPath,"node_modules/.bin/msdf-bmfont"]),tmpFontPath,"-f","json","-s","" + Math.round(size / factor),"-i",charsetPath,"-t","msdf","-p","2","-d","2","--factor","" + Math.round(1.0 / factor),"--smart-size"],{ cwd : tmpDir});
		} else {
			tools_Helpers.command(haxe_io_Path.join([tools_Helpers.context.ceramicToolsPath,"npx"]),["msdf-bmfont",tmpFontPath,"-f","json","-s","" + size,"-i",charsetPath,"-t","msdf","-v","-p","2","--factor","1","--smart-size"],{ cwd : tmpDir});
			factor = 1;
		}
		var jsonPath = haxe_io_Path.join([tmpDir,rawName + ".json"]);
		var json = JSON.parse(js_node_Fs.readFileSync(jsonPath,{ encoding : "utf8"}));
		var fnt = "";
		fnt += "info";
		fnt += " face=" + JSON.stringify(rawName);
		fnt += " size=" + Math.round(parseFloat(json.info.size) * factor);
		fnt += " bold=" + json.info.bold;
		fnt += " italic=" + json.info.italic;
		fnt += " unicode=" + json.info.unicode;
		fnt += " stretchH=" + json.info.stretchH;
		fnt += " smooth=" + json.info.smooth;
		fnt += " aa=" + json.info.aa;
		if(!msdf) {
			var padding = json.info.padding;
			var spacing = json.info.spacing;
			var result = new Array(padding.length);
			var _g = 0;
			var _g1 = padding.length;
			while(_g < _g1) {
				var i = _g++;
				result[i] = "" + parseFloat(padding[i]) * factor;
			}
			padding = result;
			var result = new Array(spacing.length);
			var _g = 0;
			var _g1 = spacing.length;
			while(_g < _g1) {
				var i = _g++;
				result[i] = "" + parseFloat(spacing[i]) * factor;
			}
			spacing = result;
			fnt += " padding=" + padding.join(",");
			fnt += " spacing=" + spacing.join(",");
		} else {
			fnt += " padding=" + json.info.padding.join(",");
			fnt += " spacing=" + json.info.spacing.join(",");
		}
		fnt += " charset=\"\"";
		fnt += "\n";
		fnt += "common";
		fnt += " lineHeight=" + Math.round(parseFloat(json.common.lineHeight) * factor);
		fnt += " base=" + Math.round(parseFloat(json.common.base) * factor);
		fnt += " scaleW=" + json.common.scaleW;
		fnt += " scaleH=" + json.common.scaleH;
		fnt += " pages=" + json.common.pages;
		fnt += " packed=" + json.common.packed;
		fnt += " alphaChnl=" + json.common.alphaChnl;
		fnt += " redChnl=" + json.common.redChnl;
		fnt += " greenChnl=" + json.common.greenChnl;
		fnt += " blueChnl=" + json.common.blueChnl;
		fnt += "\n";
		if(msdf) {
			fnt += "distanceField";
			fnt += " fieldType=" + json.distanceField.fieldType;
			fnt += " distanceRange=" + json.distanceField.distanceRange;
			fnt += "\n";
		}
		var base = parseFloat(json.common.base);
		var pngFiles = [];
		var i = 0;
		var _g = 0;
		var _g1 = json.pages;
		while(_g < _g1.length) {
			var page = _g1[_g];
			++_g;
			pngFiles.push(page);
			var chars = json.chars;
			fnt += "page id=" + i + " file=" + JSON.stringify(page) + "\n";
			fnt += "chars count=" + chars.length;
			fnt += "\n";
			var _g2 = 0;
			while(_g2 < chars.length) {
				var char = chars[_g2];
				++_g2;
				fnt += "char";
				fnt += " id=" + Std.string(char.id);
				fnt += " index=" + Std.string(char.index);
				fnt += " char=" + JSON.stringify(char.char);
				if(msdf) {
					fnt += " width=" + Std.string(char.width);
					fnt += " height=" + Std.string(char.height);
				} else {
					fnt += " width=" + parseFloat(char.width) * factor;
					fnt += " height=" + parseFloat(char.height) * factor;
				}
				fnt += " xoffset=" + (parseFloat(char.xoffset) * factor + offsetX);
				fnt += " yoffset=" + (parseFloat(char.yoffset) * factor + offsetY);
				fnt += " xadvance=" + parseFloat(char.xadvance) * factor;
				fnt += " chnl=" + Std.string(char.chnl);
				fnt += " x=" + Std.string(char.x);
				fnt += " y=" + Std.string(char.y);
				fnt += " page=" + Std.string(char.page);
				fnt += "\n";
			}
			++i;
		}
		var kernings = json.kernings;
		if(kernings != null && kernings.length > 0) {
			fnt += "kernings count=" + kernings.length + "\n";
			var _g = 0;
			while(_g < kernings.length) {
				var kerning = kernings[_g];
				++_g;
				fnt += "kerning";
				fnt += " first=" + Std.string(kerning.first);
				fnt += " second=" + Std.string(kerning.second);
				fnt += " amount=" + parseFloat(kerning.amount) * factor;
				fnt += "\n";
			}
		}
		if(!msdf) {
			var _g = 0;
			while(_g < pngFiles.length) {
				var pngFile = pngFiles[_g];
				++_g;
				var pngRawName = haxe_io_Path.withoutExtension(pngFile);
				var svgPath = [haxe_io_Path.join([tmpDir,pngRawName + ".svg"])];
				var pngPath = [haxe_io_Path.join([tmpDir,pngRawName + ".png"])];
				var flatPngPath = [haxe_io_Path.join([tmpDir,pngRawName + "-flat.png"])];
				tools_Sync.run((function(flatPngPath,pngPath,svgPath) {
					return function(done) {
						var input = pngPath[0];
						var options = null;
						(options != null ? require("sharp")(input,options) : require("sharp")(input)).raw().toBuffer((function(flatPngPath,svgPath) {
							return function(err,data,info) {
								if(err != null) {
									throw haxe_Exception.thrown(err);
								}
								var width = info.width;
								var height = info.height;
								var offsetX = 2;
								var offsetY = 0;
								var input = svgPath[0];
								var options = null;
								(options != null ? require("sharp")(input,options) : require("sharp")(input)).extract({ left : offsetX, top : offsetY, width : width, height : height}).resize(Math.round(width * factor),Math.round(height * factor)).toFile(flatPngPath[0],(function() {
									return function(err,info) {
										if(err != null) {
											throw haxe_Exception.thrown(err);
										}
										done();
									};
								})());
							};
						})(flatPngPath,svgPath));
					};
				})(flatPngPath,pngPath,svgPath));
				tools_Sync.run((function(flatPngPath) {
					return function(done) {
						var input = flatPngPath[0];
						var options = null;
						(options != null ? require("sharp")(input,options) : require("sharp")(input)).raw().toBuffer((function(flatPngPath) {
							return function(err,data,info) {
								var pixels = data;
								var len = pixels.length;
								var i = 0;
								while(i < len) {
									pixels[i] = 255;
									pixels[i + 1] = 255;
									pixels[i + 2] = 255;
									i += 4;
								}
								var input = pixels;
								var options = { raw : { width : info.width, height : info.height, channels : info.channels}};
								(options != null ? require("sharp")(input,options) : require("sharp")(input)).png().toFile(flatPngPath[0],(function() {
									return function(err,info) {
										if(err != null) {
											throw haxe_Exception.thrown(err);
										}
										done();
									};
								})());
							};
						})(flatPngPath));
					};
				})(flatPngPath));
				js_node_Fs.unlinkSync(pngPath[0]);
				js_node_Fs.renameSync(flatPngPath[0],pngPath[0]);
			}
		}
		var fntPath = haxe_io_Path.join([outputPath,rawName + ".fnt"]);
		js_node_Fs.writeFileSync(fntPath,fnt);
		var _g = 0;
		while(_g < pngFiles.length) {
			var pngFile = pngFiles[_g];
			++_g;
			var pngPath1 = haxe_io_Path.join([tmpDir,pngFile]);
			sys_io_File.copy(pngPath1,haxe_io_Path.join([outputPath,haxe_io_Path.withoutDirectory(pngPath1)]));
		}
		tools_Files.deleteRecursive(tmpDir);
	}
	,__class__: tools_tasks_Font
});
var tools_tasks_HaxeServer = function() {
	tools_Task.call(this);
};
$hxClasses["tools.tasks.HaxeServer"] = tools_tasks_HaxeServer;
tools_tasks_HaxeServer.__name__ = true;
tools_tasks_HaxeServer.__super__ = tools_Task;
tools_tasks_HaxeServer.prototype = $extend(tools_Task.prototype,{
	info: function(cwd) {
		return "Run a haxe compilation server to build projects faster.";
	}
	,run: function(cwd,args) {
		var port = 7000;
		var customPort = tools_Helpers.extractArgValue(args,"port");
		var verbose = tools_Helpers.extractArgFlag(args,"verbose");
		if(customPort != null && StringTools.trim(customPort) != "") {
			port = Std.parseInt(customPort);
		}
		tools_Sync.run(function(done) {
			require("detect-port")(port,function(err,_port) {
				if(err) {
					tools_Helpers.fail(err);
				}
				if(port != _port) {
					port = _port;
				}
				done();
			});
		});
		tools_Helpers.print("Start Haxe compilation server on port " + port);
		tools_Helpers.haxe(["--version"]);
		var homedir = require('os').homedir();
		global.setTimeout(function() {
			js_node_Fs.writeFileSync(haxe_io_Path.join([homedir,".ceramic-haxe-server"]),"" + port);
		},100);
		global.setInterval(function() {
			tools_Files.touch(haxe_io_Path.join([homedir,".ceramic-haxe-server"]));
		},1000);
		var haxeArgs = ["--wait","" + port];
		if(verbose) {
			haxeArgs.unshift("-v");
		}
		tools_Helpers.haxe(haxeArgs);
	}
	,__class__: tools_tasks_HaxeServer
});
var tools_tasks_Help = function() {
	tools_Task.call(this);
};
$hxClasses["tools.tasks.Help"] = tools_tasks_Help;
tools_tasks_Help.__name__ = true;
tools_tasks_Help.__super__ = tools_Task;
tools_tasks_Help.prototype = $extend(tools_Task.prototype,{
	info: function(cwd) {
		return "Display help/manual.";
	}
	,run: function(cwd,args) {
		var b = function(str) {
			if(tools_Helpers.context.colors) {
				return tools_Colors.bold(str);
			} else {
				return str;
			}
		};
		var r = function(str) {
			if(tools_Helpers.context.colors) {
				return tools_Colors.reset(str);
			} else {
				return str;
			}
		};
		var i = function(str) {
			if(tools_Helpers.context.colors) {
				return tools_Colors.italic(str);
			} else {
				return str;
			}
		};
		var g = function(str) {
			if(tools_Helpers.context.colors) {
				return tools_Colors.gray(str);
			} else {
				return str;
			}
		};
		var u = function(str) {
			if(tools_Helpers.context.colors) {
				return tools_Colors.underline(str);
			} else {
				return "<" + str + ">";
			}
		};
		var bg = function(str) {
			if(tools_Helpers.context.colors) {
				return tools_Colors.bold(tools_Colors.green(str));
			} else {
				return str;
			}
		};
		var green = function(str) {
			if(tools_Helpers.context.colors) {
				return tools_Colors.green(str);
			} else {
				return str;
			}
		};
		var len = function(str,n) {
			var res = str;
			while(res.length < n) res += " ";
			return res;
		};
		var noltlen = function(str,n) {
			var lenOffset = 0;
			var _g = 0;
			var _g1 = str.length;
			while(_g < _g1) {
				var i = _g++;
				var code = HxOverrides.cca(str,i);
				if(code == 60 || code == 62) {
					--lenOffset;
				}
			}
			var res = str;
			while(res.length + lenOffset < n) res += " ";
			return res;
		};
		var ltu = function(str) {
			var result = "";
			var ltText = null;
			var _g = 0;
			var _g1 = str.length;
			while(_g < _g1) {
				var i = _g++;
				var c = str.charAt(i);
				if(ltText != null) {
					if(c == ">") {
						result += u(ltText);
						ltText = null;
					} else {
						ltText += c;
					}
				} else if(c == "<") {
					ltText = "";
				} else {
					result += c;
				}
			}
			return result;
		};
		var nolt = function(text) {
			return StringTools.replace(StringTools.replace(text,"<",""),">","");
		};
		var lines = [];
		var tab = "  ";
		var commandName = null;
		var _g = 0;
		var _g1 = args.length;
		while(_g < _g1) {
			var i1 = _g++;
			if(i1 < args.length - 1) {
				if(args[i1] == "help") {
					commandName = args[i1 + 1];
				} else if(commandName != null) {
					commandName += " " + args[i1 + 1];
				}
			}
		}
		if(commandName != null) {
			var task = tools_Helpers.context.tasks.h[commandName];
			if(task == null) {
				tools_Helpers.fail("Unknown command: " + commandName);
			}
			var info = task.info(cwd);
			lines.push("");
			lines.push(tab + b("COMMAND"));
			lines.push(tab + "ceramic " + commandName + "    " + g(info));
			var helpData = task.help(cwd);
			if(helpData != null && helpData.length > 0) {
				lines.push("");
				lines.push(tab + b("OPTIONS"));
				var item0Len = 0;
				var _g = 0;
				while(_g < helpData.length) {
					var item = helpData[_g];
					++_g;
					var noLtText = nolt(item[0]);
					if(noLtText.length > item0Len) {
						item0Len = noLtText.length;
					}
				}
				var _g = 0;
				while(_g < helpData.length) {
					var item = helpData[_g];
					++_g;
					lines.push(tab + ltu(noltlen(item[0],item0Len)) + "    " + g(item[1]));
				}
			}
			tools_Helpers.print(lines.join("\n") + "\n");
			return;
		}
		var toolsPath = tools_Helpers.context.ceramicToolsPath;
		var version = "v" + tools_Helpers.context.ceramicVersion;
		if(tools_Helpers.context.isEmbeddedInElectron) {
			version += " *";
		}
		lines.push("                                              \n                                                         " + bg("_|") + "            \n    " + bg("_|_|_|") + "    " + bg("_|_|") + "    " + bg("_|") + "  " + bg("_|_|") + "   " + bg("_|_|_|") + "  " + bg("_|_|_|") + "  " + bg("_|_|") + "          " + bg("_|_|_|") + "  \n  " + bg("_|") + "        " + bg("_|_|_|_|") + "  " + bg("_|_|") + "     " + bg("_|") + "    " + bg("_|") + "  " + bg("_|") + "    " + bg("_|") + "    " + bg("_|") + "  " + bg("_|") + "  " + bg("_|") + "        \n  " + bg("_|") + "        " + bg("_|") + "        " + bg("_|") + "       " + bg("_|") + "    " + bg("_|") + "  " + bg("_|") + "    " + bg("_|") + "    " + bg("_|") + "  " + bg("_|") + "  " + bg("_|") + "        \n    " + bg("_|_|_|") + "    " + bg("_|_|_|") + "  " + bg("_|") + "         " + bg("_|_|_|") + "  " + bg("_|") + "    " + bg("_|") + "    " + bg("_|") + "  " + bg("_|") + "    " + bg("_|_|_|"));
		var logo = lines[lines.length - 1];
		var logoLines = StringTools.replace(logo,"\r","").split("\n");
		logoLines[1] += " " + green(version);
		lines[lines.length - 1] = logoLines.join("\n");
		lines.push("\n");
		lines.push(tab + b("USAGE"));
		lines.push(tab + r("ceramic ") + u("command") + " " + g("[") + "--arg" + g(",") + " --arg value" + g(", …]"));
		lines.push("");
		lines.push(tab + b("COMMANDS"));
		var allTasks_h = Object.create(null);
		var h = tools_Helpers.context.tasks.h;
		var key_h = h;
		var key_keys = Object.keys(h);
		var key_length = key_keys.length;
		var key_current = 0;
		while(key_current < key_length) {
			var key = key_keys[key_current++];
			allTasks_h[key] = tools_Helpers.context.tasks.h[key];
		}
		var maxTaskLen = 0;
		var h = allTasks_h;
		var key_h = h;
		var key_keys = Object.keys(h);
		var key_length = key_keys.length;
		var key_current = 0;
		while(key_current < key_length) {
			var key = key_keys[key_current++];
			maxTaskLen = Math.max(maxTaskLen,key.length);
		}
		var i1 = 0;
		var h = allTasks_h;
		var key_h = h;
		var key_keys = Object.keys(h);
		var key_length = key_keys.length;
		var key_current = 0;
		while(key_current < key_length) {
			var key = key_keys[key_current++];
			var task = allTasks_h[key];
			var prevBackend = tools_Helpers.context.backend;
			tools_Helpers.context.backend = task.backend;
			var prevPlugin = tools_Helpers.context.plugin;
			tools_Helpers.context.plugin = task.plugin;
			if(i1 == 0) {
				lines.push(tab + r(len(key,maxTaskLen)) + "    " + g(task.info(cwd)));
			} else {
				lines.push(tab + len(key,maxTaskLen) + "    " + g(task.info(cwd)));
			}
			tools_Helpers.context.backend = prevBackend;
			tools_Helpers.context.plugin = prevPlugin;
			++i1;
		}
		lines.push("");
		lines.push(tab + b("HELP"));
		lines.push(tab + "ceramic help " + u("command"));
		tools_Helpers.print(lines.join("\n") + "\n");
	}
	,__class__: tools_tasks_Help
});
var tools_tasks_Hxml = function() {
	tools_Task.call(this);
};
$hxClasses["tools.tasks.Hxml"] = tools_tasks_Hxml;
tools_tasks_Hxml.__name__ = true;
tools_tasks_Hxml.__super__ = tools_Task;
tools_tasks_Hxml.prototype = $extend(tools_Task.prototype,{
	info: function(cwd) {
		if(tools_Helpers.context.backend == null) {
			return "Print hxml data (uses --from-hxml param).";
		} else {
			return "Print hxml data using " + tools_Helpers.context.backend.name + " backend and the given target.";
		}
	}
	,run: function(cwd,args) {
		var rawHxml;
		var hxmlOriginalCwd;
		var fromHxml = tools_Helpers.extractArgValue(args,"from-hxml");
		if(fromHxml != null) {
			if(!haxe_io_Path.isAbsolute(fromHxml)) {
				fromHxml = haxe_io_Path.join([cwd,fromHxml]);
			}
			rawHxml = js_node_Fs.readFileSync(fromHxml,{ encoding : "utf8"});
			hxmlOriginalCwd = haxe_io_Path.directory(fromHxml);
		} else {
			tools_Helpers.ensureCeramicProject(cwd,args,tools_ProjectKind.App);
			var availableTargets = tools_Helpers.context.backend.getBuildTargets();
			var targetName = tools_Helpers.getTargetName(args,availableTargets);
			if(targetName == null) {
				tools_Helpers.fail("You must specify a target to get hxml from.");
			}
			var target = null;
			var _g = 0;
			while(_g < availableTargets.length) {
				var aTarget = availableTargets[_g];
				++_g;
				if(aTarget.name == targetName) {
					target = aTarget;
					break;
				}
			}
			if(target == null) {
				tools_Helpers.fail("Unknown target: " + targetName);
			}
			if(!Object.prototype.hasOwnProperty.call(tools_Helpers.context.defines.h,target.name)) {
				tools_Helpers.context.defines.h[target.name] = "";
			}
			if(tools_Helpers.extractArgFlag(args,"setup",true)) {
				tools_Helpers.context.backend.runSetup(cwd,["setup",target.name,"--update-project"],target,tools_Helpers.context.variant,true);
			}
			rawHxml = tools_Helpers.context.backend.getHxml(cwd,args,target,tools_Helpers.context.variant);
			hxmlOriginalCwd = tools_Helpers.context.backend.getHxmlCwd(cwd,args,target,tools_Helpers.context.variant);
			if(rawHxml == null) {
				tools_Helpers.fail("Failed to get hxml for " + target.name + ". Did you run setup on this target?");
			}
			rawHxml += "\n" + "-D completion -D display -D no_inline";
			var pathFilters = [];
			var ceramicSrcContentPath = haxe_io_Path.join([tools_Helpers.context.ceramicRuntimePath,"src/ceramic"]);
			var _g = 0;
			var _g1 = js_node_Fs.readdirSync(ceramicSrcContentPath);
			while(_g < _g1.length) {
				var name = _g1[_g];
				++_g;
				if(!sys_FileSystem.isDirectory(haxe_io_Path.join([ceramicSrcContentPath,name]))) {
					if(StringTools.endsWith(name,".hx")) {
						var className = HxOverrides.substr(name,0,name.length - 3);
						if(className != "Assets") {
							pathFilters.push("ceramic." + className);
						}
					}
				}
			}
			var h = tools_Helpers.context.plugins.h;
			var plugin_h = h;
			var plugin_keys = Object.keys(h);
			var plugin_length = plugin_keys.length;
			var plugin_current = 0;
			while(plugin_current < plugin_length) {
				var plugin = plugin_h[plugin_keys[plugin_current++]];
				if(plugin.extendCompletionHxml != null) {
					var prevBackend = tools_Helpers.context.backend;
					tools_Helpers.context.backend = plugin.backend;
					plugin.extendCompletionHxml(rawHxml);
					tools_Helpers.context.backend = prevBackend;
				}
			}
		}
		var hxmlData = tools_Hxml.parse(rawHxml);
		var hxmlTargetCwd = cwd;
		var output = tools_Helpers.extractArgValue(args,"output");
		if(output != null) {
			if(!haxe_io_Path.isAbsolute(output)) {
				output = haxe_io_Path.join([cwd,output]);
			}
			var outputDir = haxe_io_Path.directory(output);
			if(!sys_FileSystem.exists(outputDir)) {
				sys_FileSystem.createDirectory(outputDir);
			}
			if(haxe_io_Path.normalize(outputDir) != haxe_io_Path.normalize(hxmlTargetCwd)) {
				hxmlTargetCwd = outputDir;
			}
		}
		var finalHxml = StringTools.trim(StringTools.replace(tools_Hxml.formatAndChangeRelativeDir(hxmlData,hxmlOriginalCwd,hxmlOriginalCwd).join(" ")," \n ","\n"));
		finalHxml = "--cwd " + hxmlOriginalCwd + "\n" + finalHxml;
		if(output != null) {
			var prevHxml = null;
			if(sys_FileSystem.exists(output)) {
				prevHxml = js_node_Fs.readFileSync(output,{ encoding : "utf8"});
			}
			if(finalHxml != prevHxml) {
				js_node_Fs.writeFileSync(output,StringTools.rtrim(finalHxml) + "\n");
			}
		} else {
			tools_Helpers.print(StringTools.rtrim(finalHxml));
		}
	}
	,__class__: tools_tasks_Hxml
});
var tools_tasks_IdeInfo = function() {
	tools_Task.call(this);
};
$hxClasses["tools.tasks.IdeInfo"] = tools_tasks_IdeInfo;
tools_tasks_IdeInfo.__name__ = true;
tools_tasks_IdeInfo.__super__ = tools_Task;
tools_tasks_IdeInfo.prototype = $extend(tools_Task.prototype,{
	info: function(cwd) {
		return "Print project information for IDE.";
	}
	,run: function(cwd,args) {
		var ide = tools_Helpers.loadIdeInfo(cwd,args);
		var targets = [];
		var variants = [];
		if(tools_Helpers.context.project != null && tools_Helpers.context.project.app != null) {
			variants.push({ name : "Release", args : [], group : "build", role : "build-preset"});
			variants.push({ name : "Debug", args : ["--debug"], group : "build", role : "build-preset", select : { args : ["--debug"]}});
			var defaultBackendName = "clay";
			var h = tools_Helpers.context.plugins.h;
			var plugin_h = h;
			var plugin_keys = Object.keys(h);
			var plugin_length = plugin_keys.length;
			var plugin_current = 0;
			while(plugin_current < plugin_length) {
				var plugin = plugin_h[plugin_keys[plugin_current++]];
				if(plugin.name != null && plugin.name.toLowerCase() == defaultBackendName.toLowerCase()) {
					if(plugin.extendIdeInfo != null) {
						plugin.extendIdeInfo(targets,variants);
					}
				}
			}
			var h = tools_Helpers.context.plugins.h;
			var plugin_h = h;
			var plugin_keys = Object.keys(h);
			var plugin_length = plugin_keys.length;
			var plugin_current = 0;
			while(plugin_current < plugin_length) {
				var plugin = plugin_h[plugin_keys[plugin_current++]];
				if(plugin.name == null || plugin.name.toLowerCase() != defaultBackendName.toLowerCase()) {
					if(plugin.extendIdeInfo != null) {
						plugin.extendIdeInfo(targets,variants);
					}
				}
			}
		} else if(tools_Helpers.context.project != null && tools_Helpers.context.project.plugin != null) {
			targets.push({ name : "Tools Plugin", command : "ceramic", args : ["plugin","build","--tools"], select : { command : "ceramic", args : ["plugin","hxml","--tools","--debug","--completion","--output","completion.hxml"]}});
		}
		try {
			if(ide != null) {
				var projectTargets = ide.targets;
				var projectVariants = ide.variants;
				if(projectTargets != null) {
					var _g = 0;
					while(_g < projectTargets.length) {
						var item = projectTargets[_g];
						++_g;
						if(item == null || typeof(item) == "boolean" || ((item) instanceof Array) || typeof(item) == "number" && ((item | 0) === item) || typeof(item) == "number") {
							tools_Helpers.fail("Invalid target item: " + Std.string(item));
						}
						if(item.name == null || typeof(item.name) != "string" || StringTools.trim("" + item.name) == "") {
							tools_Helpers.fail("Invalid target name in ceramic.yml: " + item.name);
						}
						var itemName = StringTools.trim("" + item.name);
						if(item.command == null || typeof(item.command) != "string" || StringTools.trim("" + item.command) == "") {
							tools_Helpers.fail("Invalid target command in ceramic.yml: " + item.command);
						}
						var itemCommand = StringTools.trim("" + item.command);
						if(item.cwd != null && (typeof(item.cwd) != "string" || StringTools.trim("" + item.cwd) == "")) {
							tools_Helpers.fail("Invalid target cwd in ceramic.yml: " + item.cwd);
						}
						var itemCwd = StringTools.trim("" + item.cwd);
						if(item.args != null && !((item.args) instanceof Array)) {
							tools_Helpers.fail("Invalid target args in ceramic.yml: " + Std.string(item.args));
						}
						var itemArgs = [];
						if(item.args != null) {
							var rawItemArgs = item.args;
							if(rawItemArgs.length > 0) {
								var _g1 = 0;
								while(_g1 < rawItemArgs.length) {
									var rawArg = rawItemArgs[_g1];
									++_g1;
									itemArgs.push("" + Std.string(rawArg));
								}
							}
						}
						if(item.groups != null && !((item.groups) instanceof Array)) {
							tools_Helpers.fail("Invalid target groups in ceramic.yml: " + Std.string(item.groups));
						}
						var itemGroups = [];
						if(item.groups != null) {
							var rawItemGroups = item.groups;
							if(rawItemGroups.length > 0) {
								var _g2 = 0;
								while(_g2 < rawItemGroups.length) {
									var rawGroup = rawItemGroups[_g2];
									++_g2;
									var group = StringTools.trim("" + Std.string(rawGroup));
									if(group != "") {
										if(itemGroups.indexOf(group) == -1) {
											itemGroups.push(group);
										}
									}
								}
							}
						}
						if(Object.prototype.hasOwnProperty.call(item,"group") && typeof(Reflect.field(item,"group")) == "string") {
							var group1 = StringTools.trim("" + Std.string(Reflect.field(item,"group")));
							if(group1 != "") {
								if(itemGroups.indexOf(group1) == -1) {
									itemGroups.push(group1);
								}
							}
						}
						var itemSelect = null;
						if(item.select != null) {
							var tmp;
							if(!(typeof(item.select) == "boolean" || ((item.select) instanceof Array))) {
								var v = item.select;
								tmp = typeof(v) == "number" && ((v | 0) === v);
							} else {
								tmp = true;
							}
							if(tmp || typeof(item.select) == "number") {
								tools_Helpers.fail("Invalid target item select: " + Std.string(item.select));
							}
							var selectCommand = StringTools.trim("" + item.select.command);
							if(item.select.args != null && !((item.select.args) instanceof Array)) {
								tools_Helpers.fail("Invalid target select args in ceramic.yml: " + Std.string(item.select.args));
							}
							var selectArgs = [];
							if(item.select.args != null) {
								var rawSelectArgs = item.select.args;
								if(rawSelectArgs.length > 0) {
									var _g3 = 0;
									while(_g3 < rawSelectArgs.length) {
										var rawArg1 = rawSelectArgs[_g3];
										++_g3;
										selectArgs.push("" + Std.string(rawArg1));
									}
								}
							}
							itemSelect = { command : selectCommand, args : selectArgs};
						}
						targets.push({ name : itemName, command : itemCommand, args : itemArgs, cwd : itemCwd, groups : itemGroups, select : itemSelect});
					}
				}
				if(projectVariants != null) {
					var _g = 0;
					while(_g < projectVariants.length) {
						var item = projectVariants[_g];
						++_g;
						if(item == null || typeof(item) == "boolean" || ((item) instanceof Array) || typeof(item) == "number" && ((item | 0) === item) || typeof(item) == "number") {
							tools_Helpers.fail("Invalid variant item: " + Std.string(item));
						}
						if(item.name == null || typeof(item.name) != "string" || StringTools.trim("" + item.name) == "") {
							tools_Helpers.fail("Invalid variant name in ceramic.yml: " + item.name);
						}
						var itemName = StringTools.trim("" + item.name);
						if(item.args != null && !((item.args) instanceof Array)) {
							tools_Helpers.fail("Invalid variant args in ceramic.yml: " + Std.string(item.args));
						}
						var itemArgs = [];
						if(item.args != null) {
							var rawItemArgs = item.args;
							if(rawItemArgs.length > 0) {
								var _g1 = 0;
								while(_g1 < rawItemArgs.length) {
									var rawArg = rawItemArgs[_g1];
									++_g1;
									itemArgs.push("" + Std.string(rawArg));
								}
							}
						}
						var itemGroup = null;
						if(item.group != null && typeof(item.group) == "string") {
							var group = StringTools.trim("" + item.group);
							if(group != "") {
								itemGroup = group;
							}
						}
						var itemSelect = null;
						if(item.select != null) {
							var tmp;
							if(!(typeof(item.select) == "boolean" || ((item.select) instanceof Array))) {
								var v = item.select;
								tmp = typeof(v) == "number" && ((v | 0) === v);
							} else {
								tmp = true;
							}
							if(tmp || typeof(item.select) == "number") {
								tools_Helpers.fail("Invalid variant item select: " + Std.string(item.select));
							}
							if(item.select.args != null && !((item.select.args) instanceof Array)) {
								tools_Helpers.fail("Invalid variant select args in ceramic.yml: " + Std.string(item.select.args));
							}
							var selectArgs = [];
							if(item.select.args != null) {
								var rawSelectArgs = item.select.args;
								if(rawSelectArgs.length > 0) {
									var _g2 = 0;
									while(_g2 < rawSelectArgs.length) {
										var rawArg1 = rawSelectArgs[_g2];
										++_g2;
										selectArgs.push("" + Std.string(rawArg1));
									}
								}
							}
							itemSelect = { args : selectArgs};
						}
						variants.push({ name : itemName, args : itemArgs, group : itemGroup, select : itemSelect});
					}
				}
			}
		} catch( _g ) {
			var e = haxe_Exception.caught(_g).unwrap();
			tools_Helpers.fail("Invalid target list in ceramic.yml: " + Std.string(e));
		}
		tools_Helpers.print(JSON.stringify({ ide : { targets : targets, variants : variants}},null,"    "));
	}
	,__class__: tools_tasks_IdeInfo
});
var tools_tasks_Info = function() {
	tools_Task.call(this);
};
$hxClasses["tools.tasks.Info"] = tools_tasks_Info;
tools_tasks_Info.__name__ = true;
tools_tasks_Info.__super__ = tools_Task;
tools_tasks_Info.prototype = $extend(tools_Task.prototype,{
	info: function(cwd) {
		return "Print project information depending on the current settings and defines.";
	}
	,run: function(cwd,args) {
		var project = tools_Helpers.ensureCeramicProject(cwd,args,tools_ProjectKind.App);
		tools_Helpers.print(JSON.stringify(project.app,null,"    "));
	}
	,__class__: tools_tasks_Info
});
var tools_tasks_Init = function() {
	tools_Task.call(this);
};
$hxClasses["tools.tasks.Init"] = tools_tasks_Init;
tools_tasks_Init.__name__ = true;
tools_tasks_Init.__super__ = tools_Task;
tools_tasks_Init.prototype = $extend(tools_Task.prototype,{
	info: function(cwd) {
		return "Initialize a new ceramic project.";
	}
	,run: function(cwd,args) {
		var projectPath = cwd;
		var force = tools_Helpers.extractArgFlag(args,"force");
		var index = args.indexOf("--name");
		if(index == -1) {
			tools_Helpers.fail("Project name (--name MyProject) is required.");
		}
		if(index + 1 >= args.length) {
			tools_Helpers.fail("A value is required after --name argument.");
		}
		var projectName = args[args.indexOf("--name") + 1];
		projectPath = haxe_io_Path.join([projectPath,projectName]);
		index = args.indexOf("--path");
		var newProjectPath = projectPath;
		if(index != -1) {
			if(index + 1 >= args.length) {
				tools_Helpers.fail("A value is required after --path argument.");
			}
			newProjectPath = args[args.indexOf("--path") + 1];
		}
		if(!haxe_io_Path.isAbsolute(newProjectPath)) {
			newProjectPath = haxe_io_Path.normalize(haxe_io_Path.join([cwd,newProjectPath]));
		}
		projectPath = newProjectPath;
		if(!force && sys_FileSystem.exists(haxe_io_Path.join([projectPath,"ceramic.yml"]))) {
			tools_Helpers.fail("A project already exist at target path: " + projectPath + ". Use --force to replace files.");
		}
		if(!sys_FileSystem.exists(projectPath)) {
			try {
				sys_FileSystem.createDirectory(projectPath);
			} catch( _g ) {
				var e = haxe_Exception.caught(_g).unwrap();
				tools_Helpers.fail("Error when creating project directory: " + Std.string(e));
			}
		}
		if(!sys_FileSystem.isDirectory(projectPath)) {
			tools_Helpers.fail("Project path is not a directory at: " + projectPath);
		}
		var tplProjectPath = haxe_io_Path.join([tools_Helpers.context.ceramicToolsPath,"tpl/project/empty"]);
		tools_Files.copyDirectory(tplProjectPath,projectPath);
		var content = StringTools.ltrim("\napp:\n    package: mycompany." + projectName + "\n    name: " + projectName + "\n    displayName: " + projectName + "\n    author: My Company\n    version: '1.0'\n\n    libs: []\n");
		js_node_Fs.writeFileSync(haxe_io_Path.join([projectPath,"ceramic.yml"]),content);
		var backends = [];
		while(true) {
			var aBackend = tools_Helpers.extractArgValue(args,"backend",true);
			if(aBackend == null || StringTools.trim(aBackend) == "") {
				break;
			}
			backends.push(aBackend);
		}
		if(backends.length == 0) {
			backends.push("clay");
		}
		var generatedTplPath = haxe_io_Path.join([tools_Helpers.context.ceramicToolsPath,"tpl","generated"]);
		var generatedFiles = tools_Files.getFlatDirectory(generatedTplPath);
		var projectGenPath = haxe_io_Path.join([projectPath,"gen"]);
		var _g = 0;
		while(_g < generatedFiles.length) {
			var file = generatedFiles[_g];
			++_g;
			var sourceFile = haxe_io_Path.join([generatedTplPath,file]);
			var destFile = haxe_io_Path.join([projectGenPath,file]);
			if(!sys_FileSystem.exists(destFile)) {
				tools_Files.copyIfNeeded(sourceFile,destFile);
			}
		}
		tools_Helpers.success("Project created at path: " + projectPath);
		var _g = 0;
		while(_g < backends.length) {
			var backendName = backends[_g];
			++_g;
			tools_Helpers.runCeramic(projectPath,[backendName,"setup","default"].concat(force ? ["--force"] : []));
		}
		var ide = tools_Helpers.extractArgValue(args,"ide");
		if(ide == null) {
			ide = "vscode";
		}
		if(ide == "vscode") {
			var task = new tools_tasks_Vscode();
			var taskArgs = [args[1]].concat(force ? ["--force"] : []);
			var _g = 0;
			while(_g < backends.length) {
				var backendName = backends[_g];
				++_g;
				taskArgs.push("--backend");
				taskArgs.push(backendName);
			}
			task.run(projectPath,taskArgs);
		}
	}
	,__class__: tools_tasks_Init
});
var tools_tasks_Libs = function() {
	tools_Task.call(this);
};
$hxClasses["tools.tasks.Libs"] = tools_tasks_Libs;
tools_tasks_Libs.__name__ = true;
tools_tasks_Libs.__super__ = tools_Task;
tools_tasks_Libs.prototype = $extend(tools_Task.prototype,{
	info: function(cwd) {
		if(tools_Helpers.context.backend != null) {
			return "Install required haxe libs when using " + tools_Helpers.context.backend.name + " backend on current project.";
		} else {
			return "Install required haxe libs on current project.";
		}
	}
	,run: function(cwd,args) {
		tools_Helpers.ensureCeramicProject(cwd,args,tools_ProjectKind.App);
		tools_Helpers.checkProjectHaxelibSetup(cwd,args);
		var g = function(str) {
			if(tools_Helpers.context.colors) {
				return tools_Colors.gray(str);
			} else {
				return str;
			}
		};
		if(tools_Helpers.context.backend != null) {
			var availableTargets = this.backend.getBuildTargets();
			var targetName = tools_Helpers.getTargetName(args,availableTargets);
			if(targetName == null) {
				tools_Helpers.fail("You must specify a target.");
			}
			var target = null;
			var _g = 0;
			while(_g < availableTargets.length) {
				var aTarget = availableTargets[_g];
				++_g;
				if(aTarget.name == targetName) {
					target = aTarget;
					break;
				}
			}
			if(target == null) {
				tools_Helpers.fail("Unknown target: " + targetName);
			}
		}
		var project = new tools_Project();
		var projectPath = haxe_io_Path.join([cwd,"ceramic.yml"]);
		project.loadAppFile(projectPath);
		var libs_h = Object.create(null);
		var appLibs = project.app.libs;
		var _g = 0;
		while(_g < appLibs.length) {
			var lib = appLibs[_g];
			++_g;
			var libName = null;
			var libVersion = null;
			if(typeof(lib) == "string") {
				libName = lib;
			} else {
				var _g1 = 0;
				var _g2 = Reflect.fields(lib);
				while(_g1 < _g2.length) {
					var k = _g2[_g1];
					++_g1;
					libName = k;
					libVersion = Reflect.field(lib,k);
					break;
				}
			}
			libs_h[libName] = libVersion;
		}
		var extractPath = function(rawPathData) {
			var parts = StringTools.trim(rawPathData).split("\r").join("").split("\n");
			var _g = 0;
			while(_g < parts.length) {
				var part = parts[_g];
				++_g;
				if(!StringTools.startsWith(part,"-")) {
					return StringTools.trim(part);
				}
			}
			return null;
		};
		var h = libs_h;
		var libName_h = h;
		var libName_keys = Object.keys(h);
		var libName_length = libName_keys.length;
		var libName_current = 0;
		while(libName_current < libName_length) {
			var libName = libName_keys[libName_current++];
			var libVersion = libs_h[libName];
			var isGit = false;
			var isPath = false;
			if(libVersion != null) {
				if(StringTools.startsWith(libVersion,"git:")) {
					isGit = true;
				} else if(StringTools.startsWith(libVersion,"path:")) {
					isPath = true;
				}
			}
			var query = libName;
			if(libVersion != null && !isPath && !isGit) {
				query += ":" + libVersion;
			}
			var res = tools_Helpers.haxelib(["path",query],{ mute : true, cwd : cwd});
			var path = extractPath("" + res.stdout);
			if(sys_FileSystem.exists(path) && sys_FileSystem.isDirectory(path)) {
				if(libVersion != null) {
					tools_Helpers.success("Use " + libName + " " + libVersion + " " + g(path));
				} else {
					tools_Helpers.success("Use " + libName + " " + g(path));
				}
			} else {
				if(isPath) {
					var devArg = [libName,libVersion.substring("path:".length)];
					res = tools_Helpers.haxelib(["dev"].concat(devArg),{ cwd : cwd});
				} else if(isGit) {
					var gitArgs = [libName,StringTools.replace(libVersion.substring("git:".length),"#"," ")];
					res = tools_Helpers.haxelib(["git"].concat(gitArgs),{ cwd : cwd});
				} else {
					var installArgs = [libName];
					if(libVersion != null) {
						installArgs.push(libVersion);
					}
					res = tools_Helpers.haxelib(["install"].concat(installArgs),{ cwd : cwd});
				}
				query = libName;
				if(libVersion != null && !isGit && !isPath) {
					query += ":" + libVersion;
				}
				res = tools_Helpers.haxelib(["path",query],{ mute : true, cwd : cwd});
				path = extractPath("" + res.stdout);
				if(sys_FileSystem.exists(path) && sys_FileSystem.isDirectory(path)) {
					if(libVersion != null) {
						tools_Helpers.success("Installed " + libName + " " + libVersion + " " + g(path));
					} else {
						tools_Helpers.success("Installed " + libName + " " + g(path));
					}
				} else if(libVersion != null) {
					tools_Helpers.fail("Failed to install " + libName + " " + libVersion);
				} else {
					tools_Helpers.fail("Failed to install " + libName);
				}
			}
		}
	}
	,__class__: tools_tasks_Libs
});
var tools_tasks_Link = function() {
	tools_Task.call(this);
};
$hxClasses["tools.tasks.Link"] = tools_tasks_Link;
tools_tasks_Link.__name__ = true;
tools_tasks_Link.__super__ = tools_Task;
tools_tasks_Link.prototype = $extend(tools_Task.prototype,{
	info: function(cwd) {
		return "Make this ceramic command global.";
	}
	,run: function(cwd,args) {
		if(Sys.systemName() == "Mac" || Sys.systemName() == "Linux") {
			tools_Helpers.command("rm",["ceramic"],{ cwd : "/usr/local/bin", mute : true});
			if(tools_Helpers.isElectron()) {
				tools_Helpers.command("ln",["-s",haxe_io_Path.join([tools_Helpers.context.ceramicToolsPath,"ceramic-electron"]),"ceramic"],{ cwd : "/usr/local/bin"});
			} else {
				var script = "#!/bin/bash\n" + haxe_io_Path.join([tools_Helpers.context.ceramicToolsPath,"node_modules/.bin/node"]) + " " + haxe_io_Path.join([tools_Helpers.context.ceramicToolsPath,"ceramic"]) + " \"$@\"";
				js_node_Fs.writeFileSync("/usr/local/bin/ceramic",script);
				tools_Helpers.command("chmod",["+x","ceramic"],{ cwd : "/usr/local/bin", mute : true});
			}
		} else if(Sys.systemName() == "Windows") {
			var haxePath = process.env["HAXEPATH"];
			if(haxePath == null || !sys_FileSystem.exists(haxePath)) {
				tools_Helpers.fail("Haxe must be installed on this machine in order to link ceramic command.");
			}
			js_node_Fs.writeFileSync(haxe_io_Path.join([haxePath,"ceramic.cmd"]),"@echo off\r\n" + haxe_io_Path.join([tools_Helpers.context.ceramicToolsPath,tools_Helpers.isElectron() ? "ceramic-electron" : "ceramic"]) + " %*");
		}
	}
	,__class__: tools_tasks_Link
});
var tools_tasks_Module = function() {
	tools_Task.call(this);
};
$hxClasses["tools.tasks.Module"] = tools_tasks_Module;
tools_tasks_Module.__name__ = true;
tools_tasks_Module.__super__ = tools_Task;
tools_tasks_Module.prototype = $extend(tools_Task.prototype,{
	info: function(cwd) {
		return "Target a specific module.";
	}
	,run: function(cwd,args) {
		var project = tools_Helpers.ensureCeramicProject(cwd,args,tools_ProjectKind.App);
		var moduleName = tools_Helpers.extractArgValue(args,"name");
		var vscodeDir = haxe_io_Path.join([cwd,".vscode"]);
		js_node_Fs.writeFileSync(haxe_io_Path.join([cwd,".module"]),moduleName != null ? moduleName : "");
		if(sys_FileSystem.exists(haxe_io_Path.join([cwd,"completion.hxml"]))) {
			var hxml = js_node_Fs.readFileSync(haxe_io_Path.join([cwd,"completion.hxml"]),{ encoding : "utf8"});
			hxml = tools_Module.patchHxml(cwd,project,hxml,moduleName);
			js_node_Fs.writeFileSync(haxe_io_Path.join([cwd,"completion.hxml"]),hxml);
		}
		if(sys_FileSystem.exists(haxe_io_Path.join([vscodeDir,"settings.json"]))) {
			try {
				var vscodeSettings = JSON.parse(js_node_Fs.readFileSync(haxe_io_Path.join([vscodeDir,"settings.json"]),{ encoding : "utf8"}));
				if(moduleName != null && moduleName != "") {
					vscodeSettings["haxe.configurations"] = [["completion.hxml","-D","module_" + moduleName]];
				} else {
					vscodeSettings["haxe.configurations"] = [["completion.hxml"]];
				}
				js_node_Fs.writeFileSync(haxe_io_Path.join([vscodeDir,"settings.json"]),JSON.stringify(vscodeSettings,null,"    "));
			} catch( _g ) {
				var e = haxe_Exception.caught(_g).unwrap();
				tools_Helpers.warning("Error when saving .vscode/settings.json: " + Std.string(e));
			}
		}
	}
	,__class__: tools_tasks_Module
});
var tools_tasks_Path = function() {
	tools_Task.call(this);
};
$hxClasses["tools.tasks.Path"] = tools_tasks_Path;
tools_tasks_Path.__name__ = true;
tools_tasks_Path.__super__ = tools_Task;
tools_tasks_Path.prototype = $extend(tools_Task.prototype,{
	info: function(cwd) {
		return "Print ceramic path on this machine.";
	}
	,run: function(cwd,args) {
		tools_Helpers.print(tools_Helpers.context.ceramicToolsPath);
	}
	,__class__: tools_tasks_Path
});
var tools_tasks_Query = function() {
	tools_Task.call(this);
};
$hxClasses["tools.tasks.Query"] = tools_tasks_Query;
tools_tasks_Query.__name__ = true;
tools_tasks_Query.__super__ = tools_Task;
tools_tasks_Query.prototype = $extend(tools_Task.prototype,{
	info: function(cwd) {
		return "Query an active ceramic server";
	}
	,run: function(cwd,args) {
		var port = tools_Helpers.extractArgValue(args,"port",true);
		if(port == null) {
			tools_Helpers.fail("Missing --port argument");
		}
		var cmdArgs = [].concat(args.slice(1));
		var customCwd = tools_Helpers.extractArgValue(cmdArgs,"cwd");
		if(customCwd == null) {
			cmdArgs = ["--cwd",tools_Helpers.context.cwd].concat(cmdArgs);
		}
		tools_Sync.run(function(done) {
			var ws = new npm_WebSocket("ws://127.0.0.1:" + port);
			ws.on("error",console.error);
			ws.on("open",function() {
				haxe_Log.trace("WS OPEN",{ fileName : "/Users/jeremyfa/Developer/ceramic/tools/src/tools/tasks/Query.hx", lineNumber : 34, className : "tools.tasks.Query", methodName : "run"});
				ws.send(JSON.stringify({ query : "command", args : cmdArgs}),console.error);
			});
			ws.on("message",function(data) {
				haxe_Log.trace("WS MESSAGE: " + data,{ fileName : "/Users/jeremyfa/Developer/ceramic/tools/src/tools/tasks/Query.hx", lineNumber : 42, className : "tools.tasks.Query", methodName : "run"});
			});
		});
	}
	,__class__: tools_tasks_Query
});
var tools_tasks_Server = function() {
	this.nextQueryId = 1;
	tools_Task.call(this);
};
$hxClasses["tools.tasks.Server"] = tools_tasks_Server;
tools_tasks_Server.__name__ = true;
tools_tasks_Server.__super__ = tools_Task;
tools_tasks_Server.prototype = $extend(tools_Task.prototype,{
	info: function(cwd) {
		return "Create a ceramic server to run consecutive commands with a single output";
	}
	,run: function(cwd,args) {
		var _gthis = this;
		var port = tools_Helpers.extractArgValue(args,"port");
		if(port == null) {
			tools_Helpers.fail("Missing --port argument");
		}
		this.server = js_node_Http.createServer(function(req,res) {
			if(req.method == "POST") {
				var body = "";
				req.on("data",function(data) {
					body += Std.string(data);
				});
				req.on("end",function() {
					try {
						var json = JSON.parse(body);
						if(json.query == "command" && ((json.args) instanceof Array)) {
							var queryId = _gthis.handleCommand(json.args);
							res.writeHead(200,{ "Content-Type" : "text/plain"});
							res.end("" + queryId + "\n");
							return;
						} else {
							res.writeHead(404,{ "Content-Type" : "text/plain"});
							res.end("-3\n");
							return;
						}
					} catch( _g ) {
						res.writeHead(404,{ "Content-Type" : "text/plain"});
						res.end("-2\n");
						return;
					}
				});
				return;
			}
			res.writeHead(404,{ "Content-Type" : "text/plain"});
			res.end("-1\n");
		});
		this.wss = new npm_WebSocketServer({ server : this.server});
		this.wss.on("error",function(err) {
		});
		this.wss.on("connection",function(ws) {
			ws.on("error",function(err) {
			});
			ws.on("message",function(message) {
				haxe_Log.trace("RECEIVE MESSAGE: " + message,{ fileName : "/Users/jeremyfa/Developer/ceramic/tools/src/tools/tasks/Server.hx", lineNumber : 81, className : "tools.tasks.Server", methodName : "run"});
			});
		});
		tools_Sync.run(function(done) {
			_gthis.server.listen(port);
		});
	}
	,handleCommand: function(args) {
		var queryId = this.nextQueryId++;
		haxe_Log.trace("HANDLE CERAMIC CMD ARGS: " + JSON.stringify(args),{ fileName : "/Users/jeremyfa/Developer/ceramic/tools/src/tools/tasks/Server.hx", lineNumber : 97, className : "tools.tasks.Server", methodName : "handleCommand"});
		return queryId;
	}
	,__class__: tools_tasks_Server
});
var tools_tasks_Unlink = function() {
	tools_Task.call(this);
};
$hxClasses["tools.tasks.Unlink"] = tools_tasks_Unlink;
tools_tasks_Unlink.__name__ = true;
tools_tasks_Unlink.__super__ = tools_Task;
tools_tasks_Unlink.prototype = $extend(tools_Task.prototype,{
	info: function(cwd) {
		return "Remove global ceramic command.";
	}
	,run: function(cwd,args) {
		if(Sys.systemName() == "Mac") {
			tools_Helpers.command("rm",["ceramic"],{ cwd : "/usr/local/bin"});
		} else if(Sys.systemName() == "Windows") {
			var haxePath = process.env["HAXEPATH"];
			if(haxePath == null || !sys_FileSystem.exists(haxe_io_Path.join([haxePath,"ceramic.cmd"]))) {
				tools_Helpers.fail("There is nothing to unlink.");
			}
			js_node_Fs.unlinkSync(haxe_io_Path.join([haxePath,"ceramic.cmd"]));
		}
	}
	,__class__: tools_tasks_Unlink
});
var tools_tasks_Version = function() {
	tools_Task.call(this);
};
$hxClasses["tools.tasks.Version"] = tools_tasks_Version;
tools_tasks_Version.__name__ = true;
tools_tasks_Version.__super__ = tools_Task;
tools_tasks_Version.prototype = $extend(tools_Task.prototype,{
	info: function(cwd) {
		return "Print ceramic tools version.";
	}
	,run: function(cwd,args) {
		if(tools_Helpers.extractArgFlag(args,"base")) {
			var baseVersion = tools_Helpers.context.ceramicVersion.split("-")[0];
			tools_Helpers.print("" + baseVersion);
			return;
		}
		if(tools_Helpers.extractArgFlag(args,"short")) {
			tools_Helpers.print("" + tools_Helpers.context.ceramicVersion);
			return;
		}
		var checkTag = tools_Helpers.extractArgValue(args,"check-tag");
		if(checkTag != null) {
			var expectedTag = "v" + tools_Helpers.context.ceramicVersion.split("-")[0];
			var sanitizedTag = checkTag;
			var _this_r = new RegExp("[a-zA-Z_-]+$","".split("u").join(""));
			sanitizedTag = sanitizedTag.replace(_this_r,"");
			if(sanitizedTag != expectedTag) {
				tools_Helpers.fail("Tag " + checkTag + " doesn't match current version: " + tools_Helpers.context.ceramicVersion);
			} else {
				tools_Helpers.success("Tag " + checkTag + " is matching current version");
			}
		}
		var toolsPath = tools_Helpers.context.ceramicToolsPath;
		var homedir = js_node_Os.homedir();
		var hash = null;
		var date = null;
		if(tools_Helpers.commandExists("git")) {
			hash = StringTools.trim(tools_Helpers.command("git",["rev-parse","--short","HEAD"],{ cwd : toolsPath, mute : true}).stdout);
			if(hash != null && hash != "") {
				date = StringTools.trim(tools_Helpers.command("git",["show","-s","--format=%ci",hash],{ cwd : toolsPath, mute : true}).stdout);
			}
		}
		if(StringTools.startsWith(toolsPath,homedir)) {
			toolsPath = haxe_io_Path.join(["~",toolsPath.substring(homedir.length)]);
		}
		if(tools_Helpers.context.isEmbeddedInElectron && StringTools.endsWith(toolsPath,"/Contents/Resources/app/node_modules/ceramic-tools")) {
			toolsPath = toolsPath.substring(0,toolsPath.length - "/Contents/Resources/app/node_modules/ceramic-tools".length);
		}
		tools_Helpers.print(tools_Helpers.context.ceramicVersion + " (" + toolsPath + ")" + (date != null ? " " + date : ""));
	}
	,__class__: tools_tasks_Version
});
var tools_tasks_Vscode = function() {
	tools_Task.call(this);
};
$hxClasses["tools.tasks.Vscode"] = tools_tasks_Vscode;
tools_tasks_Vscode.__name__ = true;
tools_tasks_Vscode.__super__ = tools_Task;
tools_tasks_Vscode.prototype = $extend(tools_Task.prototype,{
	info: function(cwd) {
		return "Generate project files for Visual Studio Code.";
	}
	,run: function(cwd,args) {
		var project = tools_Helpers.ensureCeramicProject(cwd,args,tools_ProjectKind.App);
		var force = tools_Helpers.extractArgFlag(args,"force");
		var updateTasks = tools_Helpers.extractArgFlag(args,"update-tasks");
		var settingsOnly = tools_Helpers.extractArgFlag(args,"settings-only");
		var vscodeProjectRoot = tools_Helpers.extractArgValue(args,"vscode-project-root");
		var vscodeDir = vscodeProjectRoot != null ? vscodeProjectRoot : haxe_io_Path.join([cwd,".vscode"]);
		if(!haxe_io_Path.isAbsolute(vscodeDir)) {
			vscodeDir = haxe_io_Path.join([cwd,vscodeDir]);
		}
		var backends = [];
		while(true) {
			var aBackend = tools_Helpers.extractArgValue(args,"backend",true);
			if(aBackend == null || StringTools.trim(aBackend) == "") {
				break;
			}
			backends.push(aBackend);
		}
		if(!force && !settingsOnly && !updateTasks) {
			if(sys_FileSystem.exists(haxe_io_Path.join([vscodeDir,"tasks.json"])) || sys_FileSystem.exists(haxe_io_Path.join([vscodeDir,"settings.json"]))) {
				tools_Helpers.fail("Some Visual Studio Code project files already exist.\nUse --force to generate them again.");
			}
		}
		if(!sys_FileSystem.exists(vscodeDir)) {
			sys_FileSystem.createDirectory(vscodeDir);
		}
		if(!settingsOnly) {
			var vscodeTasks = { "version" : "2.0.0", "tasks" : [{ "type" : "ceramic", "args" : "active configuration", "problemMatcher" : ["$haxe-absolute","$haxe","$haxe-error","$haxe-trace"], "group" : { "kind" : "build", "isDefault" : true}, "label" : "ceramic: active configuration"}]};
			js_node_Fs.writeFileSync(haxe_io_Path.join([vscodeDir,"tasks.json"]),JSON.stringify(vscodeTasks,null,"    "));
		}
		var vscodeSettings = { "window.title" : "${activeEditorShort} — " + Std.string(project.app.name), "haxe.configurations" : [["completion.hxml"]], "search.exclude" : { "**/.git" : true, "**/node_modules" : true, "**/tmp" : true, "**/out" : true}};
		var settingsExist = false;
		if(sys_FileSystem.exists(haxe_io_Path.join([vscodeDir,"settings.json"]))) {
			try {
				var existingVscodeSettings = JSON.parse(js_node_Fs.readFileSync(haxe_io_Path.join([vscodeDir,"settings.json"]),{ encoding : "utf8"}));
				existingVscodeSettings["haxe.configurations"] = Reflect.field(vscodeSettings,"haxe.configurations");
				vscodeSettings = existingVscodeSettings;
				settingsExist = true;
			} catch( _g ) {
			}
		}
		if(!settingsOnly || settingsExist) {
			js_node_Fs.writeFileSync(haxe_io_Path.join([vscodeDir,"settings.json"]),JSON.stringify(vscodeSettings,null,"    "));
		}
		var vscodeLaunch = { "version" : "0.2.0", "configurations" : [{ "name" : "Debug Web", "type" : "chrome", "request" : "attach", "port" : 9223, "webRoot" : "${workspaceFolder}/project/web", "sourceMaps" : true, "disableNetworkCache" : true, "smartStep" : true}]};
		if(!settingsOnly) {
			js_node_Fs.writeFileSync(haxe_io_Path.join([vscodeDir,"launch.json"]),JSON.stringify(vscodeLaunch,null,"    "));
		}
	}
	,__class__: tools_tasks_Vscode
});
var tools_tasks_ZipTools = function() {
	tools_Task.call(this);
};
$hxClasses["tools.tasks.ZipTools"] = tools_tasks_ZipTools;
tools_tasks_ZipTools.__name__ = true;
tools_tasks_ZipTools.__super__ = tools_Task;
tools_tasks_ZipTools.prototype = $extend(tools_Task.prototype,{
	info: function(cwd) {
		return "Package these ceramic tools as a redistribuable zip file.";
	}
	,run: function(cwd,args) {
		var os = Sys.systemName();
		if(os == "Mac") {
			var tmpDirContainerPath = haxe_io_Path.join([cwd,"ceramic.zip.tmp"]);
			var tmpDirPath = haxe_io_Path.join([tmpDirContainerPath,"ceramic"]);
			tools_Helpers.print("Copy ceramic directory to " + tmpDirPath);
			if(sys_FileSystem.exists(tmpDirContainerPath)) {
				tools_Files.deleteRecursive(tmpDirContainerPath);
			}
			sys_FileSystem.createDirectory(tmpDirPath);
			tools_Helpers.command("cp",["-a","-f",tools_Helpers.context.ceramicRootPath + "/.",tmpDirPath + "/"]);
			tools_Helpers.print("Remove files not needed on " + os);
			tools_Files.deleteAnyFileNamed(".git",tmpDirPath);
			tools_Files.deleteAnyFileNamed(".DS_Store",tmpDirPath);
			tools_Files.deleteRecursive(haxe_io_Path.join([tmpDirPath,"git/linc_openal/lib/openal-soft/lib/Windows"]));
			tools_Files.deleteRecursive(haxe_io_Path.join([tmpDirPath,"git/linc_openal/lib/openal-soft/lib/Windows64"]));
			tools_Files.deleteRecursive(haxe_io_Path.join([tmpDirPath,"git/linc_openal/lib/openal-soft/lib/Linux"]));
			tools_Files.deleteRecursive(haxe_io_Path.join([tmpDirPath,"git/linc_openal/lib/openal-soft/lib/Linux64"]));
			tools_Files.deleteRecursive(haxe_io_Path.join([tmpDirPath,"git/linc_openal/lib/openal-android/lib"]));
			tools_Files.deleteRecursive(haxe_io_Path.join([tmpDirPath,"git/linc_openal/lib/openal-android/obj"]));
			tools_Files.deleteRecursive(haxe_io_Path.join([tmpDirPath,"git/spine-hx/spine-runtimes"]));
			tools_Files.deleteRecursive(haxe_io_Path.join([tmpDirPath,"git/spine-hx/node_modules"]));
			tools_Files.deleteRecursive(haxe_io_Path.join([tmpDirPath,"git/haxe-binary/linux"]));
			tools_Files.deleteRecursive(haxe_io_Path.join([tmpDirPath,"git/haxe-binary/windows"]));
			tools_Helpers.print("Zip contents");
			var zipPath = haxe_io_Path.join([cwd,"ceramic.zip"]);
			if(sys_FileSystem.exists(zipPath)) {
				js_node_Fs.unlinkSync(zipPath);
			}
			tools_Files.zipDirectory(tmpDirPath,zipPath);
			tools_Helpers.print("Remove temporary directory");
			tools_Files.deleteRecursive(tmpDirContainerPath);
		} else if(os == "Windows") {
			tools_Helpers.fail("Not supported on windows yet");
		} else if(os == "Linux") {
			tools_Helpers.fail("Not supported on linux yet");
		}
	}
	,__class__: tools_tasks_ZipTools
});
var tools_tasks_haxelib_ExportLibrary = function() {
	tools_Task.call(this);
};
$hxClasses["tools.tasks.haxelib.ExportLibrary"] = tools_tasks_haxelib_ExportLibrary;
tools_tasks_haxelib_ExportLibrary.__name__ = true;
tools_tasks_haxelib_ExportLibrary.__super__ = tools_Task;
tools_tasks_haxelib_ExportLibrary.prototype = $extend(tools_Task.prototype,{
	info: function(cwd) {
		return "Export haxelib-compatible libraries from ceramic source-code.";
	}
	,run: function(cwd,args) {
		var exportRuntime = tools_Helpers.extractArgFlag(args,"runtime",true);
		var force = tools_Helpers.extractArgFlag(args,"force");
		var outputPath = tools_Helpers.extractArgValue(args,"output-path");
		if(outputPath == null) {
			tools_Helpers.fail("Missing argument: --output-path");
		}
		if(!haxe_io_Path.isAbsolute(outputPath)) {
			outputPath = haxe_io_Path.normalize(haxe_io_Path.join([cwd,outputPath]));
		}
		if(exportRuntime) {
			var libPath = haxe_io_Path.join([outputPath,"ceramic_runtime"]);
			if(!force && sys_FileSystem.exists(libPath)) {
				tools_Helpers.fail("Output already exists: " + libPath + ". Use --force to overwrite");
			}
			var runtimeSrcPath = haxe_io_Path.join([tools_Helpers.context.ceramicRuntimePath,"src"]);
			tools_Helpers.print("Export runtime to " + libPath);
			tools_Files.deleteRecursive(libPath);
			tools_Files.copyDirectory(runtimeSrcPath,haxe_io_Path.join([libPath,"src"]),true);
			var haxelibJson = this.createHaxelibJson("runtime","ceramic-engine/ceramic","Runtime for ceramic written in cross-platform Haxe. Needs to be used with a ceramic backend.",tools_Helpers.context.ceramicVersion.split("-")[0],"Exported from ceramic v" + tools_Helpers.context.ceramicVersion);
			var _g = 0;
			var _g1 = tools_Project.runtimeLibraries;
			while(_g < _g1.length) {
				var item = _g1[_g];
				++_g;
				if(typeof(item) == "string") {
					haxelibJson.dependencies[item] = "";
				} else {
					var libName = null;
					var libVersion = null;
					var _g2 = 0;
					var _g3 = Reflect.fields(item);
					while(_g2 < _g3.length) {
						var key = _g3[_g2];
						++_g2;
						libName = key;
						libVersion = Reflect.field(item,key);
						break;
					}
					if(libVersion != null && StringTools.startsWith(libVersion,"github:")) {
						haxelibJson.dependencies[libName] = "git:https://github.com/" + HxOverrides.substr(libVersion,"github:".length,null) + ".git";
					} else {
						haxelibJson.dependencies[libName] = libVersion;
					}
				}
			}
			js_node_Fs.writeFileSync(haxe_io_Path.join([libPath,"haxelib.json"]),JSON.stringify(haxelibJson,null,"  "));
		}
	}
	,createHaxelibJson: function(name,github,description,version,releaseNote) {
		return { "name" : "ceramic_" + name, "url" : "https://github.com/" + github, "license" : "MIT", "tags" : ["ceramic",name], "description" : description, "version" : version, "classPath" : "src/", "releasenote" : releaseNote, "contributors" : ["jeremyfa"], "dependencies" : { }};
	}
	,__class__: tools_tasks_haxelib_ExportLibrary
});
var tools_tasks_images_ExportImages = function() {
	tools_Task.call(this);
};
$hxClasses["tools.tasks.images.ExportImages"] = tools_tasks_images_ExportImages;
tools_tasks_images_ExportImages.__name__ = true;
tools_tasks_images_ExportImages.__super__ = tools_Task;
tools_tasks_images_ExportImages.prototype = $extend(tools_Task.prototype,{
	info: function(cwd) {
		return "Export images from a directory to usable assets.";
	}
	,run: function(cwd,args) {
		var project = tools_Helpers.ensureCeramicProject(cwd,args,tools_ProjectKind.App);
		if(project.app.images == null || !((project.app.images.export) instanceof Array)) {
			tools_Helpers.fail("Missing images export option in ceramic.yml file like:\n\n    images:\n        export:\n            - from: path/to/images/dummy/*.png\n              prefix: DUMMY_\n              scale:\n                  1x: 0.2\n                  2x: 0.4\n");
		}
		var exportList = project.app.images.export;
		var _g = 0;
		while(_g < exportList.length) {
			var item = exportList[_g];
			++_g;
			var from = item.from;
			var prefix = "";
			if(item.prefix != null) {
				prefix = item.prefix;
			}
			var scales = { };
			if(item.scale == null) {
				scales["1x"] = 1.0;
			} else {
				scales = item.scale;
			}
			var _g1 = 0;
			var _g2 = npm_Glob.sync(haxe_io_Path.join([cwd,from]));
			while(_g1 < _g2.length) {
				var srcPath = _g2[_g1];
				++_g1;
				var srcName = haxe_io_Path.withoutExtension(haxe_io_Path.withoutDirectory(srcPath));
				var rawData = tools_Images.getRaw(srcPath);
				var _g3 = 0;
				var _g4 = Reflect.fields(scales);
				while(_g3 < _g4.length) {
					var suffix = _g4[_g3];
					++_g3;
					var scale = scales[suffix];
					var targetWidth = Math.round(rawData.width * scale) | 0;
					var targetHeight = Math.round(rawData.height * scale) | 0;
					var targetName = prefix + srcName + "@" + suffix + ".png";
					var targetPath = haxe_io_Path.join([cwd,"assets",targetName]);
					tools_Helpers.print("Export " + targetName + " (" + targetWidth + " x " + targetHeight + ")");
					tools_Images.resize(srcPath,targetPath,targetWidth,targetHeight);
				}
			}
		}
	}
	,__class__: tools_tasks_images_ExportImages
});
var tools_tasks_imgui_SetupJS = function() {
	tools_Task.call(this);
};
$hxClasses["tools.tasks.imgui.SetupJS"] = tools_tasks_imgui_SetupJS;
tools_tasks_imgui_SetupJS.__name__ = true;
tools_tasks_imgui_SetupJS.__super__ = tools_Task;
tools_tasks_imgui_SetupJS.prototype = $extend(tools_Task.prototype,{
	info: function(cwd) {
		return "Setup imgui-js files for this ceramic project.";
	}
	,run: function(cwd,args) {
		tools_Helpers.ensureCeramicProject(cwd,args,tools_ProjectKind.App);
		var webProjectPath = haxe_io_Path.join([cwd,"project/web"]);
		var imguiJSDistPath = haxe_io_Path.join([tools_Helpers.context.ceramicGitDepsPath,"imgui-hx/lib/imgui-js/dist"]);
		if(!sys_FileSystem.exists(webProjectPath)) {
			sys_FileSystem.createDirectory(webProjectPath);
		}
		var name = "imgui_impl.umd.js";
		var source = haxe_io_Path.join([imguiJSDistPath,name]);
		var dest = haxe_io_Path.join([webProjectPath,name]);
		if(!tools_Files.haveSameLastModified(source,dest)) {
			tools_Helpers.success("Copy " + name);
			sys_io_File.copy(source,dest);
			tools_Files.setToSameLastModified(source,dest);
		}
		var name = "imgui.umd.js";
		var source = haxe_io_Path.join([imguiJSDistPath,name]);
		var dest = haxe_io_Path.join([webProjectPath,name]);
		if(!tools_Files.haveSameLastModified(source,dest)) {
			tools_Helpers.success("Copy " + name);
			sys_io_File.copy(source,dest);
			tools_Files.setToSameLastModified(source,dest);
		}
	}
	,__class__: tools_tasks_imgui_SetupJS
});
var tools_tasks_plugin_BuildPlugin = function() {
	tools_Task.call(this);
};
$hxClasses["tools.tasks.plugin.BuildPlugin"] = tools_tasks_plugin_BuildPlugin;
tools_tasks_plugin_BuildPlugin.__name__ = true;
tools_tasks_plugin_BuildPlugin.__super__ = tools_Task;
tools_tasks_plugin_BuildPlugin.prototype = $extend(tools_Task.prototype,{
	info: function(cwd) {
		return "Build the current plugin or all enabled plugins (with --all).";
	}
	,run: function(cwd,args) {
		var pluginPaths = [];
		var all = tools_Helpers.extractArgFlag(args,"all",true);
		if(all) {
			var h = tools_Helpers.context.plugins.h;
			var plugin_h = h;
			var plugin_keys = Object.keys(h);
			var plugin_length = plugin_keys.length;
			var plugin_current = 0;
			while(plugin_current < plugin_length) {
				var plugin = plugin_h[plugin_keys[plugin_current++]];
				pluginPaths.push(plugin.path);
			}
			var h = tools_Helpers.context.unbuiltPlugins.h;
			var plugin_h = h;
			var plugin_keys = Object.keys(h);
			var plugin_length = plugin_keys.length;
			var plugin_current = 0;
			while(plugin_current < plugin_length) {
				var plugin = plugin_h[plugin_keys[plugin_current++]];
				pluginPaths.push(plugin.path);
			}
		} else {
			pluginPaths.push(cwd);
		}
		var _g = 0;
		while(_g < pluginPaths.length) {
			var pluginPath = pluginPaths[_g];
			++_g;
			var prevCwd = tools_Helpers.context.cwd;
			tools_Helpers.context.cwd = pluginPath;
			var toolsPluginPath = haxe_io_Path.join([pluginPath,"tools/src/tools/ToolsPlugin.hx"]);
			var toolsPluginIndexPath = haxe_io_Path.join([pluginPath,"index.js"]);
			if(all) {
				if(sys_FileSystem.exists(toolsPluginPath)) {
					tools_Helpers.print("Build " + tools_Colors.bold(pluginPath));
				} else {
					tools_Helpers.print("Skip " + tools_Colors.bold(pluginPath));
					if(sys_FileSystem.exists(toolsPluginIndexPath)) {
						js_node_Fs.unlinkSync(toolsPluginIndexPath);
					}
					if(sys_FileSystem.exists(toolsPluginIndexPath + ".map")) {
						js_node_Fs.unlinkSync(toolsPluginIndexPath + ".map");
					}
					continue;
				}
			}
			var task = new tools_tasks_plugin_PluginHxml();
			task.run(pluginPath,args.concat(["--output","plugin-build.hxml"]));
			var result = tools_Helpers.haxe(["plugin-build.hxml"]);
			js_node_Fs.unlinkSync(haxe_io_Path.join([pluginPath,"plugin-build.hxml"]));
			if(result.status != 0) {
				tools_Helpers.fail("Failed to build plugin.");
			}
			var targetFile = haxe_io_Path.join([pluginPath,"index.js"]);
			var content = js_node_Fs.readFileSync(targetFile,{ encoding : "utf8"});
			var lines = content.split("\n");
			var firstLine = lines[0];
			lines[0] = "require=m=>rReq(m);";
			while(lines[0].length < firstLine.length) lines[0] += "/";
			content = lines.join("\n");
			js_node_Fs.writeFileSync(targetFile,content);
			tools_Helpers.context.cwd = prevCwd;
		}
	}
	,__class__: tools_tasks_plugin_BuildPlugin
});
var tools_tasks_plugin_ListPlugins = function() {
	tools_Task.call(this);
};
$hxClasses["tools.tasks.plugin.ListPlugins"] = tools_tasks_plugin_ListPlugins;
tools_tasks_plugin_ListPlugins.__name__ = true;
tools_tasks_plugin_ListPlugins.__super__ = tools_Task;
tools_tasks_plugin_ListPlugins.prototype = $extend(tools_Task.prototype,{
	info: function(cwd) {
		return "List enabled plugins.";
	}
	,run: function(cwd,args) {
		var h = tools_Helpers.context.plugins.h;
		var key_h = h;
		var key_keys = Object.keys(h);
		var key_length = key_keys.length;
		var key_current = 0;
		while(key_current < key_length) {
			var key = key_keys[key_current++];
			var info = tools_Helpers.context.plugins.h[key];
			var path = info.path;
			var name = info.name;
			tools_Helpers.print(name + " " + tools_Colors.gray(path));
		}
	}
	,__class__: tools_tasks_plugin_ListPlugins
});
var tools_tasks_plugin_PluginHxml = function() {
	tools_Task.call(this);
};
$hxClasses["tools.tasks.plugin.PluginHxml"] = tools_tasks_plugin_PluginHxml;
tools_tasks_plugin_PluginHxml.__name__ = true;
tools_tasks_plugin_PluginHxml.__super__ = tools_Task;
tools_tasks_plugin_PluginHxml.prototype = $extend(tools_Task.prototype,{
	info: function(cwd) {
		return "Print hxml data for the current plugin.";
	}
	,run: function(cwd,args) {
		var isToolsKind = tools_Helpers.extractArgFlag(args,"tools",true);
		var isRuntimeKind = tools_Helpers.extractArgFlag(args,"runtime",true);
		var isEditorKind = tools_Helpers.extractArgFlag(args,"editor",true);
		var completionFlag = tools_Helpers.extractArgFlag(args,"completion",true);
		if(isToolsKind && isRuntimeKind || isToolsKind && isEditorKind || isRuntimeKind && isEditorKind) {
			tools_Helpers.fail("Ambiguous plugin kind.");
		}
		var kinds = [];
		if(isToolsKind) {
			kinds.push(tools_PluginKind.Tools);
			if(!Object.prototype.hasOwnProperty.call(tools_Helpers.context.defines.h,"tools")) {
				tools_Helpers.context.defines.h["tools"] = "";
			}
		}
		if(isRuntimeKind) {
			kinds.push(tools_PluginKind.Runtime);
			if(!Object.prototype.hasOwnProperty.call(tools_Helpers.context.defines.h,"runtime")) {
				tools_Helpers.context.defines.h["runtime"] = "";
			}
		}
		if(isEditorKind) {
			kinds.push(tools_PluginKind.Editor);
			if(!Object.prototype.hasOwnProperty.call(tools_Helpers.context.defines.h,"editor")) {
				tools_Helpers.context.defines.h["editor"] = "";
			}
		}
		tools_Helpers.ensureCeramicProject(cwd,args,tools_ProjectKind.Plugin(kinds));
		if(!isToolsKind) {
			tools_Helpers.fail("HXML output is not supported for this kind of plugin.");
		}
		var project = new tools_Project();
		project.loadPluginFile(haxe_io_Path.join([cwd,"ceramic.yml"]));
		project.plugin.paths.push(haxe_io_Path.join([tools_Helpers.context.ceramicToolsPath,"src"]));
		var extraHxml = [];
		var pluginLibs = project.plugin.libs;
		var _g = 0;
		while(_g < pluginLibs.length) {
			var lib = pluginLibs[_g];
			++_g;
			var libName = null;
			var libVersion = "*";
			if(typeof(lib) == "string") {
				libName = lib;
			} else {
				var _g1 = 0;
				var _g2 = Reflect.fields(lib);
				while(_g1 < _g2.length) {
					var k = _g2[_g1];
					++_g1;
					libName = k;
					libVersion = Reflect.field(lib,k);
					break;
				}
			}
			if(libVersion != "*") {
				extraHxml.push("-lib " + libName + ":" + libVersion);
			} else {
				extraHxml.push("-lib " + libName);
			}
		}
		if(project.plugin.hxml != null) {
			var parsedHxml = tools_Hxml.parse(project.plugin.hxml);
			if(parsedHxml != null && parsedHxml.length > 0) {
				parsedHxml = tools_Hxml.formatAndChangeRelativeDir(parsedHxml,cwd,cwd);
				var _g = 0;
				while(_g < parsedHxml.length) {
					var flag = parsedHxml[_g];
					++_g;
					extraHxml.push(flag);
				}
			}
		}
		var _g = 0;
		var _g1 = Reflect.fields(project.plugin.defines);
		while(_g < _g1.length) {
			var key = _g1[_g];
			++_g;
			var val = Reflect.field(project.plugin.defines,key);
			if(val == true) {
				extraHxml.push("-D " + key);
			} else {
				extraHxml.push("-D " + key + "=" + (val == null ? "null" : "" + val));
			}
		}
		var _g = 0;
		var _g1 = project.plugin.paths;
		while(_g < _g1.length) {
			var entry = _g1[_g];
			++_g;
			extraHxml.push("-cp " + entry);
		}
		if(completionFlag) {
			extraHxml.push("-D completion");
		}
		extraHxml.push("-main tools.ToolsPlugin");
		var hxmlOriginalCwd = cwd;
		var rawHxml = "\n        -cp tools/src\n        -lib hxnodejs\n        -lib hxnodejs-ws\n        -lib hscript\n        -js index.js\n        -debug\n        " + extraHxml.join("\n");
		var hxmlData = tools_Hxml.parse(rawHxml);
		var finalHxml = StringTools.trim(StringTools.replace(tools_Hxml.formatAndChangeRelativeDir(hxmlData,hxmlOriginalCwd,cwd).join(" ")," \n ","\n"));
		var output = tools_Helpers.extractArgValue(args,"output");
		if(output != null) {
			if(!haxe_io_Path.isAbsolute(output)) {
				output = haxe_io_Path.join([cwd,output]);
			}
			var outputDir = haxe_io_Path.directory(output);
			if(!sys_FileSystem.exists(outputDir)) {
				sys_FileSystem.createDirectory(outputDir);
			}
			var prevHxml = null;
			if(sys_FileSystem.exists(output)) {
				prevHxml = js_node_Fs.readFileSync(output,{ encoding : "utf8"});
			}
			if(finalHxml != prevHxml) {
				js_node_Fs.writeFileSync(output,StringTools.rtrim(finalHxml) + "\n");
			}
		} else {
			tools_Helpers.print(StringTools.rtrim(finalHxml));
		}
	}
	,__class__: tools_tasks_plugin_PluginHxml
});
function $getIterator(o) { if( o instanceof Array ) return new haxe_iterators_ArrayIterator(o); else return o.iterator(); }
function $bind(o,m) { if( m == null ) return null; if( m.__id__ == null ) m.__id__ = $global.$haxeUID++; var f; if( o.hx__closures__ == null ) o.hx__closures__ = {}; else f = o.hx__closures__[m.__id__]; if( f == null ) { f = m.bind(o); o.hx__closures__[m.__id__] = f; } return f; }
$global.$haxeUID |= 0;
if(typeof(performance) != "undefined" ? typeof(performance.now) == "function" : false) {
	HxOverrides.now = performance.now.bind(performance);
}
$hxClasses["Math"] = Math;
if( String.fromCodePoint == null ) String.fromCodePoint = function(c) { return c < 0x10000 ? String.fromCharCode(c) : String.fromCharCode((c>>10)+0xD7C0)+String.fromCharCode((c&0x3FF)+0xDC00); }
String.prototype.__class__ = $hxClasses["String"] = String;
String.__name__ = true;
$hxClasses["Array"] = Array;
Array.__name__ = true;
Date.prototype.__class__ = $hxClasses["Date"] = Date;
Date.__name__ = "Date";
var Int = { };
var Dynamic = { };
var Float = Number;
var Bool = Boolean;
var Class = { };
var Enum = { };
haxe_ds_ObjectMap.count = 0;
js_Boot.__toStr = ({ }).toString;
hscript_Parser.p1 = 0;
hscript_Parser.readPos = 0;
hscript_Parser.tokenMin = 0;
hscript_Parser.tokenMax = 0;
sys_io_File.copyBuf = js_node_buffer_Buffer.alloc(65536);
tools_Helpers.RE_STACK_FILE_LINE = new EReg("Called\\s+from\\s+([a-zA-Z0-9_:\\.]+)\\s+(.+?\\.hx)\\s+line\\s+([0-9]+)$","");
tools_Helpers.RE_STACK_FILE_LINE_BIS = new EReg("([a-zA-Z0-9_:\\.]+)\\s+\\((.+?\\.hx)\\s+line\\s+([0-9]+)\\)$","");
tools_Helpers.RE_TRACE_FILE_LINE = new EReg("(.+?\\.hx)::?([0-9]+):?\\s+","");
tools_Helpers.RE_HAXE_ERROR = new EReg("^(.+)::?(\\d+):? (?:lines \\d+-(\\d+)|character(?:s (\\d+)-| )(\\d+)) : (?:(Warning) : )?(.*)$","");
tools_Helpers.RE_JS_FILE_LINE = new EReg("^(?:\\[error\\] )?at ([a-zA-Z0-9_\\.-]+) \\((.+)\\)$","");
tools_Helpers.RE_HXCPP_LINE_MARKER = new EReg("^(HXLINE|HXDLIN)\\([^)]+\\)","");
tools_Hxml.RE_BEGINS_WITH_STRING = new EReg("^(?:\"(?:[^\"\\\\]*(?:\\\\.[^\"\\\\]*)*)\"|'(?:[^'\\\\]*(?:\\\\.[^'\\\\]*)*)')","");
tools_Project.runtimeLibraries = [{ "format" : "3.4.2"},{ "hscript" : "2.4.0"},{ "polyline" : "git:https://github.com/jeremyfa/polyline.git"},{ "tracker" : "git:https://github.com/jeremyfa/tracker.git"},{ "bind" : "git:https://github.com/jeremyfa/polyline.git"},{ "earcut" : "git:https://github.com/ceramic-engine/earcut.git"},{ "poly2tri" : "git:https://github.com/ceramic-engine/poly2tri.git"},{ "hsluv" : "git:https://github.com/ceramic-engine/hsluv.git"},{ "format-tiled" : "git:https://github.com/ceramic-engine/format-tiled.git"}];
tools_ProjectLoader.RE_ALNUM_CHAR = new EReg("^[a-zA-Z0-9_]$","g");
tools_ProjectLoader.RE_IDENTIFIER = new EReg("^[a-zA-Z_][a-zA-Z0-9_]*$","g");
tools_ToolsPlugin.main();
})(typeof window != "undefined" ? window : typeof global != "undefined" ? global : typeof self != "undefined" ? self : this);

//# sourceMappingURL=index.js.map