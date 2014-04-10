package ;

import AST;
import sys.io.File;
import sys.io.FileOutput;

using StringTools;

/**
 * Print Haxe file from AST.
 * 
 * @author Sam MacPherson
 */
class Printer {
	
	var output:FileOutput;
	var funcs:Array<Array<String>>;

	public function new (outFile:String) {
		output = File.write(outFile, false);
	}
	
	function w (ln:String, ?t:Int = 0):Void {
		output.writeString(StringTools.lpad("", "\t", t) + ln + "\n");
	}
	
	function expandFunc (params:Array<{ opt:Bool, name:String, type:Array<String>, ?value:String }>, ?currParam:Int = 0):Void {
		if (currParam == 0) funcs.push(new Array<String>());
		
		if (currParam == params.length) return;
		
		var param = params[currParam];
		
		var len = funcs.length;
		for (i in 0 ... (param.type.length - 1)) {
			for (o in 0 ... len) {
				var arr = new Array<String>();
				for (p in 0 ... funcs[o].length) {
					arr.push(funcs[o][p]);
				}
				funcs.push(arr);
			}
		}
		for (i in 0 ... param.type.length) {
			for (o in 0 ... len) {
				funcs[i * len + o].push(param.type[i]);
			}
		}
		expandFunc(params, currParam + 1);
	}
	
	public function write (cls:DClass):Void {
		w('package ${cls.pkg};');
		w('');
		w('@:native("${cls.native}")');
		var clsDef = 'extern class ${cls.name}';
		if (cls.ext != null) clsDef += ' extends ${cls.ext}';
		w('$clsDef {');
		for (i in cls.fields) {
			w('', 1);
			if (i.doc != null) {
				var doc = i.doc.replace("\n", "\n\t * ");
				w('/**', 1);
				w(' * $doc', 1);
				w(' */', 1);
			}
			switch (i.kind) {
				case FFun(params, ret):
					funcs = new Array<Array<String>>();
					expandFunc(params);
					for (f in 0 ... funcs.length) {
						var lastIndex = f + 1 == funcs.length;
						var str = '';
						if (lastIndex) {
							if (i.stat) str += 'static ';
							str += 'function ${i.name} (';
						}
						else str += '@:overload(function (';
						var first = true;
						for (o in 0 ... funcs[f].length) {
							var p = params[o];
							if (!first) str += ', ';
							if (p.opt) str += '?';
							str += '${p.name}:${funcs[f][o]}';
							if (p.value != null) str += ' = ${p.value}';
							first = false;
						}
						if (i.name != "new" || !lastIndex) str += '):${ret}';
						else str += ')';
						if (lastIndex) str += ';';
						else str += ' {})';
						w(str, 1);
					}
				case FVar(t, g, s):
					var str = '';
					if (i.stat) str += 'static ';
					str += 'var ${i.name}';
					if (g != null || s != null) {
						if (g == null) g = 'default';
						if (s == null) g = 'default';
						
						str += '($g, $s)';
					}
					str += ':$t;';
					w(str, 1);
			}
		}
		w('', 1);
		w('}');
		
		output.close();
	}
	
}