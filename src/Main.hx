package ;

import AST;
import neko.Lib;
import sys.FileSystem;

class Main {
	
	var classes:Array<DClass>;
	var nativeTypes:Map<String, DClass>;
	var hxTypes:Map<String, DClass>;
	var filesParsed:Int;
	
	public function new (inDir:String, outDir:String) {
		classes = new Array<DClass>();
		nativeTypes = new Map<String, DClass>();
		hxTypes = new Map<String, DClass>();
		
		Lib.println("Parsing AST...");
		filesParsed = 0;
		parseDirectory(inDir);
		Lib.println("Resolving types...");
		resolveTypes();
		Lib.println("Checking for redefinitions in sub-classes...");
		removeSubClassRedefinitions();
		Lib.println("Writing output...");
		FileSystem.createDirectory(outDir);
		for (i in classes) {
			writeClass(outDir, i);
		}
		Lib.println("Done!");
	}
	
	function parseDirectory (dir:String):Void {
		for (i in FileSystem.readDirectory(dir)) {
			var name = '$dir/$i';
			if (FileSystem.exists(name)) {
				if (FileSystem.isDirectory(name)) {
					parseDirectory(name);
				} else {
					var ext = name.substr(name.lastIndexOf("."));
					if (ext == ".js") {
						var cls = new Parser(name.substr(0, name.lastIndexOf("."))).run();
						if (cls != null) {
							classes.push(cls);
							nativeTypes.set(cls.native, cls);
							hxTypes.set(DClassTools.getFullName(cls), cls);
							
							filesParsed++;
							Lib.println('Parsed $filesParsed files');
						}
					}
				}
			}
		}
	}
	
	function resolveTypes ():Void {
		for (i in classes) {
			if (i.ext != null) {
				var origExt = i.ext;
				i.ext = resolveType(i.ext);
				if (i.ext == "Dynamic") {
					//Could not find -- try prefixing native namespace
					i.ext = resolveType(i.native.substr(0, i.native.lastIndexOf(".")) + "." + origExt);
					if (i.ext == "Dynamic") {
						//If still not found then set to null
						Lib.println('Warning: Could not resolve extends type: $origExt in ${DClassTools.getFullName(i)}');
						i.ext = null;
					}
				}
			}
			
			for (o in i.fields) {
				switch (o.kind) {
					case FFun(params, ret):
						for (p in params) {
							p.type = resolveType(p.type);
						}
						o.kind = FFun(params, resolveType(ret));
					case FVar(t, g, s):
						o.kind = FVar(resolveType(t), g, s);
				}
			}
		}
	}
	
	function removeSubClassRedefinitions ():Void {
		for (i in classes) {
			if (i.ext != null) {
				var sup = hxTypes.get(i.ext);
				if (sup != null) {
					var index = 0;
					while (index < i.fields.length) {
						if (hasField(sup, i.fields[index].name)) {
							i.fields.splice(index, 1);
						} else {
							index++;
						}
					}
				}
			}
		}
	}
	
	function hasField (cls:DClass, name:String):Bool {
		for (i in cls.fields) {
			if (i.name == name) return true;
		}
		
		if (cls.ext != null) {
			var sup = hxTypes.get(cls.ext);
			if (sup != null) {
				return hasField(sup, name);
			}
		}
		
		return false;
	}
	
	function resolveType (t:String):String {
		if (t == "Void" || t == "Float" || t == "Int" || t == "String" || t == "Dynamic" || t == "Bool" || t == "Array<Dynamic>") return t;
		
		var cls = nativeTypes.get(t);
		if (cls != null) {
			return DClassTools.getFullName(cls);
		} else {
			if (Type.resolveClass(t) != null) {
				return t;
			} else {
				return "Dynamic";
			}
		}
	}
	
	function writeClass (dir:String, cls:DClass):Void {
		var path = dir;
		for (i in cls.pkg.split(".")) {
			path += '/$i';
			FileSystem.createDirectory(path);
		}
		
		new Printer('$path/${cls.name}.hx').write(cls);
	}
	
	static function main () {
		new Main(Sys.args()[0], Sys.args()[1]);
	}
	
}