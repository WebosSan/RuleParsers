package;

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
		trace('Testing Commands:');

		script = new RuleScript(new LuaParser());

		runScript('Script.lua');

		Sys.println('\n	
	Tests: $callNum,
	Errors: $errorsNum
		');
	}

	static function runScript(path:String)
	{
		// Reset package, for reusing package keyword
		script.interp.scriptPackage = '';

		var code:String = File.getContent('scripts/' + path);

		var expr = script.parser.parse(code);

		Sys.println('[Running code #${++callNum}]: "\n$code\n"\n');
		Sys.println('[to hx]: \n${new Printer().exprToString(expr)}\n');
		Sys.println('\n[Result]: \n\t${script.tryExecute(expr)}\n');
		Sys.println('[Print]: "\n${LuaPrinter.print(expr)}\n"\n');
	}

	static function onError(e:haxe.Exception):Dynamic
	{
		errorsNum++;

		trace('[ERROR] : ${e.details()}');

		return e.details();
	}
}
