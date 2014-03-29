package ;

import AST;
import haxe.io.Eof;
import haxe.Json;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileOutput;
import sys.io.Process;

using Lambda;
using StringTools;

/**
 * Parses a JavaScript file in AST.
 * 
 * @author Sam MacPherson
 */
class Parser {
	
	static var RESERVED = ["override", "private", "public", "dynamic", "inline", "static"];
	
	var file:String;
	
	public function new (file:String) {
		this.file = file;
	}
	
	public function run ():Null<DClass> {
		var fields = new Array<DField>();
		var native = null;
		var ext = null;
		for (i in cast(jsToJson(file), Array<Dynamic>)) {
			var field = parseField(i);
			if (field != null && !fields.exists(function (e) { return e.name == field.name; } )) {
				fields.push(field);
			}
			
			for (o in cast(i.tags, Array<Dynamic>)) {
				var isClass = false;
				switch (o.type) {
					case "class":
						isClass = true;
					case "extends":
						ext = o.string;
					default:
				}
				if (!isClass && i.description != null) {
					isClass = cast(i.description.full, String).indexOf("@class") != -1;
				}
				if (isClass) {
					if (i.ctx != null && i.ctx.type == "method" && i.ctx.receiver != null && i.ctx.name != null) {
						//Preferentially use context for native location
						native = i.ctx.receiver + "." + i.ctx.name;
					} else {
						native = o.string;
					}
				}
			}
			if (native == null && i.ctx != null) {
				switch (i.ctx.type) {
					case "declaration":
						native = i.ctx.name;
						break;
					default:
				}
			}
			if (native == null && i.description != null) {
				var fullStr:String = i.description.full;
				var start = fullStr.indexOf("@class");
				if (start != -1) {
					fullStr = fullStr.substr(start + "@class".length).trim();
					var regex = ~/^([A-Za-z0-9\.]+)/;
					regex.match(fullStr);
					native = regex.matched(1);
				}
			}
		}
		if (native == null) return null;
		var pkg = file.split("/");
		return { name:pkg[pkg.length - 1], pkg:pkg.length > 1 ? pkg.slice(0, pkg.length - 1).join(".") : "", native:native, ext:ext, fields:fields };
	}
	
	function parseField (field:Dynamic):Null<DField> {
		var name = null;
		var fun = false;
		var params = new Array();
		var ret = "Dynamic";	//Should be Void, but missing return statements are too common
		var type = "Dynamic";
		var argIndex = 0;
		var stat = false;
		var cls = false;
		var get = null;
		var set = null;
		for (i in cast(field.tags, Array<Dynamic>)) {
			switch (i.type) {
				case "constructor":
					name = "new";
					fun = true;
				case "param":
					var param:Dynamic = parseName(i.name, 'a${argIndex++}');
					param.type = getHaxeType(i.types[0]);
					params.push(param);
				case "returns":
					var str:String = i.string;
					ret = getHaxeType(str.substr(str.indexOf("{") + 1, str.indexOf("}") - str.indexOf("{") - 1));
				case "method":
					var str:String = i.string;
					var hashIndex = str.lastIndexOf("#");
					if (hashIndex == -1) hashIndex = str.lastIndexOf(".");
					name = hashIndex != -1 ? str.substr(hashIndex + 1) : (i.name != null ? i.name.substr(i.name.lastIndexOf(".") + 1) : null);
					fun = true;
				case "static":
					stat = true;
				case "class":
					cls = true;
				case "property":
					var str:String = i.string;
					var data = str.split(" ");
					if (data[0].charAt(0) == "{") {
						type = getHaxeType(data[0].substr(1, data[0].length - 2));
						name = parseName(data[1], 'a${argIndex++}').name;
					} else {
						name = parseName(data[0], 'a${argIndex++}').name;
					}
				case "readonly":
					set = "null";
				case "type":
					type = getHaxeType(i.types[0]);
				default:
			}
		}
		if (cls && !fun) return null;
		
		if (field.ctx != null && name == null) {
			if (field.ctx.type == "property") {
				name = field.ctx.name;
				fun = false;
				
				if (field.description != null) {
					var str:String = field.description.full;
					if (str != null) {
						type = getHaxeType(str.substr(str.indexOf("{") + 1, str.indexOf("}") - str.indexOf("{") - 1));
					}
				}
			}
		}
		
		if (field.description != null && name == null) {
			if (cast(field.description.full, String).indexOf("@const") != -1) {
				var code = cast(field.code, String).split("=");
				var n = code[0].trim();
				name = n.substr(n.lastIndexOf(".") + 1);
				stat = true;
			}
		}
		
		if (name != null && !isReserved(name)) {
			if (fun) {
				return { name:name, stat:stat, kind:FFun(params, ret) };
			} else {
				return { name:name, stat:stat, kind:FVar(type, get, set) };
			}
		} else {
			return null;
		}
	}
	
	function getHaxeType (type:String):String {
		return switch (type) {
			case "number": "Float";
			case "integer": "Int";
			case "string": "String";
			case "object": "Dynamic";
			case "boolean": "Bool";
			case "Array": "Array<Dynamic>";
			default: type;
		}
	}
	
	function parseName (name:String, alt:String): { name:String, opt:Bool, ?value:String } {
		var regex1 = ~/\[([A-Za-z][A-Za-z0-9]*)=([^\]]+)\]/;
		var regex2 = ~/\[([A-Za-z][A-Za-z0-9]*)\]/;
		var regex3 = ~/([A-Za-z][A-Za-z0-9]*)/;
		
		var n = null;
		var opt = false;
		var value = null;
		
		if (regex1.match(name)) {
			n = regex1.matched(1);
			opt = true;
			value = regex1.matched(2);
			
			//Only store contants
			if ((value.charCodeAt(0) < '0'.code || value.charCodeAt(0) > '9'.code) && value.charAt(0) != "'" && value.charAt(0) != '"' && value != "true" && value != "false") {
				value = null;
			}
		} else if (regex2.match(name)) {
			n = regex2.matched(1);
			opt = true;
		} else if (regex3.match(name)) {
			n = regex3.matched(1);
		} else {
			n = alt;
		}
		
		if (isReserved(n)) n = alt;
		
		return { name:n, opt:opt, value:value };
	}
	
	function jsToJson (file:String):Dynamic {
		Sys.command("dox.cmd", ["<", file + ".js", ">", file + ".json"]);
		var json = Json.parse(File.getContent(file + ".json"));
		FileSystem.deleteFile(file + ".json");
		return json;
	}
	
	static function isReserved (name:String):Bool {
		return RESERVED.has(name);
	}
	
}