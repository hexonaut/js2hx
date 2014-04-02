package ;

import AST;
import sys.io.File;
import sys.io.FileOutput;

/**
 * Print Haxe file from AST.
 * 
 * @author Sam MacPherson
 */
class Printer {
	
	var output:FileOutput;

	public function new (outFile:String) {
		output = File.write(outFile, false);
	}
	
	function w (ln:String, ?t:Int = 0):Void {
		output.writeString(StringTools.lpad("", "\t", t) + ln + "\n");
	}
	
	public function write (cls:DClass):Void {
		w('package ${cls.pkg};');
		w('');
		w('@:native("${cls.native}")');
		var clsDef = 'extern class ${cls.name}';
		if (cls.ext != null) clsDef += ' extends ${cls.ext}';
		w('$clsDef {');
		for (i in cls.fields) {
			var str = '';
			if (i.stat) str += 'static ';
			switch (i.kind) {
				case FFun(params, ret):
					str += 'function ${i.name} (';
					var first = true;
					for (o in params) {
						if (!first) str += ', ';
						if (o.opt) str += '?';
						str += '${o.name}:${o.type}';
						if (o.value != null) str += ' = ${o.value}';
						first = false;
					}
					if (i.name != "new") str += '):${ret};';
					else str += ');';
				case FVar(t, g, s):
					str += 'var ${i.name}';
					if (g != null || s != null) {
						if (g == null) g = 'default';
						if (s == null) g = 'default';
						
						str += '($g, $s)';
					}
					str += ':$t;';
			}
			w(str, 1);
		}
		w('}');
		
		output.close();
	}
	
}