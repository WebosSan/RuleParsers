package;

import rulescript.std.lua.LuaMath;
import rulescript.interps.RuleScriptInterp;
import rulescript.interps.BytecodeInterp;
import haxe.Log;
import hscript.Printer;
import rulescript.*;
import rulescript.parsers.*;
import rulescript.printers.*;
import sys.io.File;

using StringTools;

class Main
{
	static var script:RuleScript;

	static var callNum:Int = 0;
	static var errorsNum:Int = 0;

	static function main():Void
	{
		script = new RuleScript(new RuleScriptInterp(), new LuaParser());

		runScript('Script.lua', new LuaParser());
		runScript('Script.clear', new ClearParser());
	}

	static function runScript(path:String, parser:Parser)
	{
		Sys.println('[Init]: Reading $path\n');

		script.scriptPackage = path;
		script.parser = parser;

		var code:String = File.getContent('scripts/' + path);

		var expr = script.parser.parse(code);

		Sys.println('\n[Result]: \n\t${script.tryExecute(expr)}\n');
	}

	static function onError(e:haxe.Exception):Dynamic
	{
		errorsNum++;

		trace('[ERROR] : ${e.details()}');

		return e.details();
	}
}
