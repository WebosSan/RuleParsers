package;

import sys.FileSystem;
import rulescript.types.ScriptedTypeUtil;
import rulescript.scriptedClass.RuleScriptedClass;
import rulescript.scriptedClass.RuleScriptedClass.Access;
import rulescript.parsers.HxParser.HxParserMode;
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

		RuleScript.createInterp = function () {
			var interp:RuleScriptInterp = new RuleScriptInterp();
			interp.variables.set("this", interp);
			return interp;
		}

		ScriptedTypeUtil.resolveModule = function (name:String)
			{
				var path:Array<String> = name.split('.');
				var pack:Array<String> = [];
			
				while (path[0].charAt(0) == path[0].charAt(0).toLowerCase())
					pack.push(path.shift());
			
				var moduleName:String = null;
				if (path.length > 1)
					moduleName = path.shift();
			
				var baseName = (pack.length >= 1 ? pack.join('.') + '.' + (moduleName ?? path[0]) : path[0]).replace('.', '/');
			
				for (ext in ["hx", "js", "lua"]) {
					var filePath = 'scripts/$baseName.$ext';
			
					if (FileSystem.exists(filePath)) {
						var code = File.getContent(filePath);
			
						switch (ext) {
							case "hx":
								var parser = new HxParser();
								parser.mode = DEFAULT;
								return parser.parseModule(code);
			
							case "js":
								var parser = new JsParser();
								parser.mode = MODULE;
								return parser.parseModule(code);
			
							default:
								return null;
						}
					}
				}
			
				return null;
			}			

		runScript('Script.js');
	}

	static function runScript(path:String)
		{
			Sys.println('[Init]: Reading $path\n');
		
			var parser:Parser;
			var mode:HxParserMode = null;
		
			switch (path.split(".").pop()) {
				case "hx":
					parser = new HxParser();
					mode = DEFAULT;
				case "js":
					parser = new JsParser();
					mode = DEFAULT;
				case "lua":
					parser = new LuaParser();
				default:
					throw 'No parser available for file: $path';
			}
		
			script.scriptPackage = path;
			script.parser = parser;
		
			if (Std.isOfType(script.parser, JsParser) || Std.isOfType(script.parser, HxParser)) {
				var p:Dynamic = script.parser;
				p.mode = mode;
			}
		
			var code:String = File.getContent('scripts/' + path);
		
			var expr = script.parser.parse(code);
		
			Sys.println('\n[Result]: \n\t${script.tryExecute(expr)}\n');
		
			return expr;
		}		

	static function onError(e:haxe.Exception):Dynamic
	{
		errorsNum++;

		trace('[ERROR] : ${e.details()}');

		return e.details();
	}
}
