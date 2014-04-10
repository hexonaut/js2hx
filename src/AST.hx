package ;

/**
 * AST definitions.
 * 
 * @author Sam MacPherson
 */

typedef DClass = {
	name:String,
	pkg:String,
	native:String,
	ext:Null<String>,
	fields:Array<DField>
}

typedef DField = {
	name:String,
	stat:Bool,
	kind:DFieldKind,
	doc:Null<String>
}

enum DFieldKind {
	FFun(params:Array<{ opt:Bool, name:String, type:Array<String>, ?value:String }>, ret:String);
	FVar(type:String, ?get:String, ?set:String);
}

class DClassTools {
	
	public static function getFullName (cls:DClass):String {
		if (cls.pkg == "") return cls.name;
		else return '${cls.pkg}.${cls.name}';
	}
	
}