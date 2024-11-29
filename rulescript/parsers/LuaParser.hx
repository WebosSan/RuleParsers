package rulescript.parsers;

import haxe.ds.GenericStack;
import hscript.Expr;

using rulescript.Tools;

private enum Token
{
	TEof;
	TConst(c:Const);
	TOp(op:String);
	TId(id:String);
	TPOpen;
	TPClose;
	TDot;
	TComma;
	TSemicolon;
	TBkOpen;
	TBkClose;
	TQuestion;
	TDoubleDot;
}

class LuaParser extends Parser
{
	public var opChars:String;
	public var identChars:String;
	public var opPriority:Map<String, Int>;

	public var line:Int;

	var idents:Array<Bool>;

	public function new()
	{
		super();
		opChars = "+*/-=!><&|^%~";
		identChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_";
		opPriority = [];
		var priorities = [
			["%"],
			["*", "/"],
			["+", "-"],
			["<<", ">>", ">>>"],
			["|", "&", "^"],
			["==", "!=", ">", "<", ">=", "<="],
			["..."],
			["&&"],
			["||"],
			["="]
		];
		opPriority = new Map();
		for (i in 0...priorities.length)
			for (x in priorities[i])
			{
				opPriority.set(x, i);
			}
	}

	override public function parse(code:String):Expr
	{
		initParser();
		input = code;

		var exprs = [];
		while (true)
		{
			if (maybe(TEof))
				break;
			var e = parseExpr();

			if (e != null)
				exprs.push(e);
		}

		return mk(EBlock(exprs));
	}

	function initParser()
	{
		tokens = new GenericStack();
		char = -1;
		pos = 0;
		line = 1;

		idents = [];

		for (i in 0...identChars.length)
			idents[identChars.charCodeAt(i)] = true;
	}

	function parseExpr():Expr
	{
		var tk = token();
		return switch (tk)
		{
			case TConst(c):
				parseExprNext(mk(EConst(c)));
			case TId(id):
				parseExprNext(parseIdent(id));
			case TOp('-'):
				var e = parseExpr();
				if (e == null)
					return mk(EUnop('-', true, e));
				switch (e.getExpr())
				{
					case EConst(CInt(i)):
						return mk(EConst(CInt(-i)));
					case EConst(CFloat(f)):
						return mk(EConst(CFloat(-f)));
					default:
						return mk(EUnop('-', true, e));
				}
			case TOp('#'):
				parseExprNext(mk(EField(parseExpr(), 'length')));
			case TOp('not'):
				mk(EUnop('!', true, parseExpr()));
			case TPOpen:
				var e = parseExpr();
				ensure(TPClose);
				parseExprNext(mk(EParent(e)));
			default:
				if (tk == TEof)
					error(ECustom('Unexpected $tk'));
				null;
		}
	}

	function parseExprNext(e1:Expr):Expr
	{
		var tk = token();
		return mk(switch (tk)
		{
			case TOp(op):
				return makeBinop(op, e1, parseExpr());
			case TPOpen:
				var args = [];
				while (true)
				{
					var tk = token();
					if (tk == TPClose)
						break;
					else
						push(tk);

					args.push(parseExpr());
				}

				maybe(TSemicolon);

				return parseExprNext(mk(ECall(e1, args)));
			case TDot:
				var field = getIdent();
				return parseExprNext(mk(EField(e1, field)));

			default:
				push(tk);
				return e1;
		});
	}

	function parseIdent(id:String):Expr
	{
		return mk(switch (id)
		{
			case 'if':
				var cond = parseExpr();

				ensureToken(TId('then'));

				var e:Array<Expr> = [], e2:Expr = null;

				while (true)
				{
					var tk = token();
					switch (tk)
					{
						case TId(_id):
							switch (_id)
							{
								case 'elseif':
									return mk(EIf(cond, mk(EBlock(e)), parseIdent('if')));
								case 'else':
									e2 = parseExpr();
									break;
								case 'end':
									break;
							}
						default:
					}
					push(tk);

					e.push(parseExpr());
				}

				ensureToken(TId('end'));

				EIf(cond, mk(EBlock(e)), e2);
			case 'function':
				var name:String = null;
				var tk = token();

				switch (tk)
				{
					case TId(id):
						name = id;
					default:
						push(tk);
				}

				ensure(TPOpen);

				var args:Array<Argument> = [];

				while (true)
				{
					var tk = token();
					switch (tk)
					{
						case TId(id):
							args.push({name: id});
						case TPClose:
							break;
						default:
					}
				}

				EFunction(args, parseExpr(), name, null);
			case 'return':
				EReturn(parseExpr());
			default:
				var global = id != 'local';

				if (!global)
					id = getIdent();

				switch (token())
				{
					case TOp('='):
						if (!global)
							return mk(EVar(id, null, parseExpr(), false));
						else
							return makeBinop('=', mk(EIdent(id)), parseExpr());
					case tk:
						push(tk);
				}

				maybe(TSemicolon);

				EIdent(id);
		});
	}

	function makeBinop(op:String, e1:Expr, e:Expr)
	{
		if (e == null)
			return mk(EBinop(op, e1, e));

		return switch (e.getExpr())
		{
			case EBinop(op2, e2, e3):
				if (opPriority.get(op) <= opPriority.get(op2) && op != '=')
					mk(EBinop(op2, makeBinop(op, e1, e2), e3));
				else
					mk(EBinop(op, e1, e));

			default:
				mk(EBinop(op, e1, e));
		}
	}

	var input:String;
	var pos:Int = 0;

	var tokens:haxe.ds.GenericStack<Token>;

	var char:Int = -1;

	function token()
	{
		if (!tokens.isEmpty())
			return tokens.pop();

		var char:Int = this.char < 0 ? readChar() : this.char;
		this.char = -1;

		while (true)
		{
			if (StringTools.isEof(char))
			{
				this.char = char;
				return TEof;
			}

			switch (char)
			{
				case 32, 9, 13: // space, tab, CR
				case '\n'.code:
					line++; // LF
				case 48, 49, 50, 51, 52, 53, 54, 55, 56, 57: // 0...9
					var n = (char - 48) * 1.0;
					var exp = 0.;
					while (true)
					{
						char = readChar();
						exp *= 10;
						switch (char)
						{
							case 48, 49, 50, 51, 52, 53, 54, 55, 56, 57:
								n = n * 10 + (char - 48);
							case "e".code, "E".code:
								var tk = token();
								var pow:Null<Int> = null;
								switch (tk)
								{
									case TConst(CInt(e)): pow = e;
									case TOp("-"):
										tk = token();
										switch (tk)
										{
											case TConst(CInt(e)): pow = -e;
											default: push(tk);
										}
									default:
										push(tk);
								}
								if (pow == null)
									invalidChar(char);
								return TConst(CFloat((Math.pow(10, pow) / exp) * n * 10));
							case ".".code:
								if (exp > 0)
								{
									// in case of '0...'
									if (exp == 10 && readChar() == ".".code)
									{
										push(TOp("..."));
										var i = Std.int(n);
										return TConst((i == n) ? CInt(i) : CFloat(n));
									}
									invalidChar(char);
								}
								exp = 1.;
							case "x".code:
								if (n > 0 || exp > 0)
									invalidChar(char);
								// read hexa
								var n = 0;
								while (true)
								{
									char = readChar();
									switch (char)
									{
										case 48, 49, 50, 51, 52, 53, 54, 55, 56, 57: // 0-9
											n = (n << 4) + char - 48;
										case 65, 66, 67, 68, 69, 70: // A-F
											n = (n << 4) + (char - 55);
										case 97, 98, 99, 100, 101, 102: // a-f
											n = (n << 4) + (char - 87);
										default:
											this.char = char;
											return TConst(CInt(n));
									}
								}
							default:
								this.char = char;
								var i = Std.int(n);
								return TConst((exp > 0) ? CFloat(n * 10 / exp) : ((i == n) ? CInt(i) : CFloat(n)));
						}
					}
				case ";".code:
					return TSemicolon;
				case '('.code:
					return TPOpen;
				case ')'.code:
					return TPClose;
				case ",".code:
					return TComma;
				case ".".code:
					char = readChar();
					switch (char)
					{
						case 48, 49, 50, 51, 52, 53, 54, 55, 56, 57:
							var n = char - 48;
							var exp = 1;
							while (true)
							{
								char = readChar();
								exp *= 10;
								switch (char)
								{
									case 48, 49, 50, 51, 52, 53, 54, 55, 56, 57:
										n = n * 10 + (char - 48);
									default:
										this.char = char;
										return TConst(CFloat(n / exp));
								}
							}
						case ".".code:
							char = readChar();
							if (char != ".".code)
							{
								this.char = char;
								return TOp("+");
							}
							return TOp("...");
						default:
							this.char = char;
							return TDot;
					}
				case '"'.code, "'".code:
					return TConst(CString(readString(char)));
				case '='.code:
					char = readChar();
					if (char == '='.code)
						return TOp("==");
					this.char = char;
					return TOp("=");
				case '~'.code:
					char = readChar();

					if (char == '='.code)
						return TOp("!=");

					this.char = char;
					return TOp("~");
				case '-'.code:
					var char = readChar();
					if (char == '-'.code)
					{
						while (true)
						{
							switch (readChar())
							{
								case '\n'.code:
									line++;
									return token();
							}
							if (StringTools.isEof(char))
								break;
						}
					}

					this.char = char;
					return TOp('-');
				case '+'.code, '*'.code, '/'.code, '%'.code:
					return TOp(String.fromCharCode(char));
				case '>'.code:
					char = readChar();

					if (char == '='.code)
						return TOp(">=");

					this.char = char;
					return TOp(">");
				case '<'.code:
					char = readChar();

					if (char == '='.code)
						return TOp("<=");

					this.char = char;
					return TOp("<");
				case '#'.code:
					return TOp('#');
				default:
					if (idents[char])
					{
						var id = String.fromCharCode(char);
						while (true)
						{
							char = readChar();
							if (StringTools.isEof(char))
								char = 0;
							if (!idents[char])
							{
								this.char = char;
								return switch (id)
								{
									case 'not':
										TOp('not');
									case 'and':
										TOp('&&');
									case 'or':
										TOp('||');
									default:
										TId(id);
								}
							}
							id += String.fromCharCode(char);
						}
					}
			}

			char = readChar();
		}
		return null;
	}

	function readString(until)
	{
		var c = 0;
		var b = new StringBuf();
		var esc = false;
		var old = line;
		var s = input;
		while (true)
		{
			var c = readChar();
			if (StringTools.isEof(c))
			{
				line = old;
				break;
			}
			if (esc)
			{
				esc = false;
				switch (c)
				{
					case 'n'.code:
						b.addChar('\n'.code);
					case 'r'.code:
						b.addChar('\r'.code);
					case 't'.code:
						b.addChar('\t'.code);
					case "'".code, '"'.code, '\\'.code:
						b.addChar(c);
					default:
				}
			}
			else if (c == 92)
				esc = true;
			else if (c == until)
				break;
			else
			{
				if (c == 10)
					line++;
				b.addChar(c);
			}
		}
		return b.toString();
	}

	inline function push(tk:Token):Void
	{
		tokens.add(tk);
	}

	inline function ensure(tk:Token)
	{
		var t = token();
		if (t != tk)
			unexpected(t);
	}

	function getIdent()
	{
		var tk = token();
		switch (tk)
		{
			case TId(id):
				return id;
			default:
				unexpected(tk);
				return null;
		}
	}

	inline function ensureToken(tk:Token)
	{
		var t = token();
		if (!Type.enumEq(t, tk))
			unexpected(t);
	}

	inline function error(err)
	{
		#if hscriptPos
		throw new Error(err, 0, 0, 'rulescript', line);
		#else
		throw err;
		#end
	}

	inline function invalidChar(c)
	{
		error(EInvalidChar(c));
	}

	function unexpected(tk:Token):Dynamic
	{
		error(EUnexpected('$tk'));
		return null;
	}

	inline function maybe(tk:Token):Bool
	{
		var _tk = token();
		if (tk.equals(_tk))
			return true;

		push(_tk);
		return false;
	}

	inline function readChar():Int
		return StringTools.fastCodeAt(input, pos++);

	inline function mk(e, ?pmin:Int, ?pmax:Int):Expr
	{
		#if hscriptPos
		if (e == null)
			return null;
		return {
			e: e,
			pmin: 0,
			pmax: 0,
			origin: 'rulescript',
			line: line
		};
		#else
		return e;
		#end
	}
}
