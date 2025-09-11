package rulescript.parsers;

import haxe.ds.GenericStack;
import hscript.Expr;

using rulescript.Tools;

private enum Token {
	TEof;
	TConst(c:Const);
	TOp(op:String);
	TId(id:String);
	TPOpen;
	TPClose;
	TDot;
	TComma;
	TSemicolon;
	TBOpen;
	TBClose;
	TBkOpen;
	TBkClose;
	TQuestion;
	TDoubleDot;
}

class ClearParser extends Parser {
	public var opChars:String;
	public var identChars:String;
	public var opPriority:Map<String, Int>;

	public var line:Int;

	var idents:Array<Bool>;

	public function new() {
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
			["=", "+=", "-=", "*=", "/=", "%=", "<<=", ">>=", ">>>=", "|=", "&=", "^=", "=>"],
			["->"],
			["in", "is"]
		];
		opPriority = new Map();
		for (i in 0...priorities.length)
			for (x in priorities[i]) {
				opPriority.set(x, i);
			}
	}

	override public function parse(code:String):Expr {
		initParser();
		input = code;

		var exprs = [];
		while (true) {
			if (maybe(TEof))
				break;
			var e = parseExpr();

			if (e != null)
				exprs.push(e);
		}

		return mk(EBlock(exprs));
	}

	function initParser() {
		tokens = new GenericStack();
		char = -1;
		pos = 0;
		line = 1;

		idents = [];

		for (i in 0...identChars.length)
			idents[identChars.charCodeAt(i)] = true;
	}

	function parseExpr():Expr {
		var tk = token();
		return switch (tk) {
			case TConst(c):
				parseExprNext(mk(EConst(c)));
			case TId(id):
				parseExprNext(parseIdent(id));
			case TBkOpen:
				var args:Array<{name:String, e:Expr}> = [];
				while (true) {
					var tk = token();
					switch (tk) {
						case TBkClose:
							break;
						case TId(id):
							var arg:{name:String, e:Expr} = {name: id, e: null};
							ensureToken(TDoubleDot);
							arg.e = parseExpr();
							args.push(arg);
						case TComma:
							continue;
						default:
							throw unexpected(tk);
					}
				}
				EObject(args);

			case TBOpen:
				var a = new Array();
				tk = token();
				var first = true;
				while (tk != TBClose) {
					if (!first) {
						if (tk != TComma)
							unexpected(tk);
						else {
							tk = token();
							if (tk == TBClose)
								break;
						}
					}
					first = false;
					push(tk);
					a.push(parseExpr());
					tk = token();
				}
				return parseExprNext(mk(EArrayDecl(a)));
			case TOp('-'):
				var e = parseExpr();
				if (e == null)
					return mk(EUnop('-', true, e));
				switch (e.getExpr()) {
					case EConst(CInt(i)):
						return mk(EConst(CInt(-i)));
					case EConst(CFloat(f)):
						return mk(EConst(CFloat(-f)));
					default:
						return mk(EUnop('-', true, e));
				}
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

	function parseExprNext(e1:Expr):Expr {
		var tk = token();
		return mk(switch (tk) {
			case TOp(op):
				return makeBinop(op, e1, parseExpr());
			case TPOpen:
				var args = [];
				while (true) {
					var tk = token();
					if (tk == TPClose)
						break;
					else
						push(tk);

					var expr:Expr = parseExpr();

					if (expr != null)
						args.push(expr);
				}

				maybe(TSemicolon);

				return parseExprNext(mk(ECall(e1, args)));
			case TBOpen:
				var index:Expr = parseExpr();
				ensureToken(TBClose);
				return parseExprNext(EArray(e1, index));

			case TDot:
				var field = getIdent();
				return parseExprNext(mk(EField(e1, field)));

			default:
				push(tk);
				return e1;
		});
	}

	function parseIdent(id:String):Expr {
		return mk(switch (id) {
			case "if":
				var cond = parseExpr();
				var e1 = parseBlock();
				var e2 = null;
				var semic = false;
				var tk = token();
				if (tk == TSemicolon) {
					semic = true;
					tk = token();
				}
				if (Type.enumEq(tk, TId("else")))
					e2 = parseBlock();
				else {
					push(tk);
					if (semic)
						push(TSemicolon);
				}
				mk(EIf(cond, e1, e2));
			case 'while':
				var cond = parseExpr();

				EWhile(cond, parseBlock());

				case "switch":
					var e = parseExpr();
					var def = null, cases = [];
					ensure(TBkOpen);
					while( true ) {
						var tk = token();
						switch( tk ) {
						case TId("case"):
							var c = { values : [], expr : null };
							cases.push(c);
							while( true ) {
								var e = parseExpr();
								c.values.push(e);
								tk = token();
								switch( tk ) {
								case TComma:
									// next expr
								case TDoubleDot:
									break;
								default:
									unexpected(tk);
									break;
								}
							}
							var exprs = [];
							while( true ) {
								tk = token();
								push(tk);
								switch( tk ) {
								case TId("case"), TId("default"), TBkClose:
									break;
								default:
									exprs = parseBlock().getParameters()[0];
								}
							}
							c.expr = if( exprs.length == 1)
								exprs[0];
							else if( exprs.length == 0 )
								EBlock([]);
							else
								mk(EBlock(exprs));
						case TId("default"):
							if( def != null ) unexpected(tk);
							ensure(TDoubleDot);
							var exprs = [];
							while( true ) {
								tk = token();
								push(tk);
								switch( tk ) {
								case TId("case"), TId("default"), TBkClose:
									break;
								default:
									exprs = parseBlock().getParameters()[0];
								}
							}
							def = if( exprs.length == 1)
								exprs[0];
							else if( exprs.length == 0 )
								EBlock([]);
							else
								mk(EBlock(exprs));
						case TBkClose:
							break;
						default:
							unexpected(tk);
							break;
						}
					}
					mk(ESwitch(e, cases, def));

			case 'func':
				var name:String = null;
				var tk = token();

				switch (tk) {
					case TId(id):
						name = id;
					default:
						push(tk);
				}

				ensure(TPOpen);

				var args:Array<Argument> = [];

				while (true) {
					var tk = token();
					switch (tk) {
						case TId(id):
							args.push({name: id});
							tk = token();
							if (tk.equals(TDoubleDot)) token(); else push(tk);
						case TPClose:
							break;
						default:
					}
				}

				EFunction(args, mk(parseBlock()), name, null);
			case 'for':
				var id:String = getIdent();
				ensureToken(TId("in"));
				var it:Expr = parseExpr();
				EFor(id, it, parseBlock());
			case 'let', 'const':
				var name:String = getIdent();
				var tk:Token = token();
				switch (tk) {
					case TDoubleDot:
						token();
					default:
						push(tk);
				}

				tk = token();

				var expr:Expr = null;

				switch (tk) {
					case TOp("="):
						expr = EVar(name, null, parseExpr(), null, id == "const");
					default:
						expr = EVar(name, null, EIdent("null"), null, id == "const");
				}
				maybe(TSemicolon);
				expr;
			case _:
				return EIdent(id);
		});
	}

	function parseBlock():Expr {
		var isBigBlock:Bool = maybe(TBkOpen);
		var exprs:Array<Expr> = [];

		if (!isBigBlock)
			exprs.push(parseExpr());
		else {
			while (true) {
				var tk:Token = token();
				switch (tk) {
					case TBkClose:
						break;
					default:
						push(tk);
				}

				exprs.push(parseExpr());
			}
		}

		return EBlock(exprs);
	}

	function makeBinop(op:String, e1:Expr, e:Expr) {
		if (e == null)
			return mk(EBinop(op, e1, e));

		return switch (e.getExpr()) {
			case EBinop(op2, e2, e3):
				if (opPriority.get(op) <= opPriority.get(op2)
					&& op != '=') mk(EBinop(op2, makeBinop(op, e1, e2), e3)); else mk(EBinop(op, e1, e));

			default:
				mk(EBinop(op, e1, e));
		}
	}

	var input:String;
	var pos:Int = 0;
	var tokens:haxe.ds.GenericStack<Token>;
	var char:Int = -1;

	function token() {
		if (!tokens.isEmpty())
			return tokens.pop();

		var char:Int = this.char < 0 ? readChar() : this.char;
		this.char = -1;

		while (true) {
			if (StringTools.isEof(char)) {
				this.char = char;
				return TEof;
			}

			switch (char) {
				case 32, 9, 13: // space, tab, CR
				case '\n'.code:
					line++; // LF
				case 48, 49, 50, 51, 52, 53, 54, 55, 56, 57: // 0...9
					var n = (char - 48) * 1.0;
					var exp = 0.;
					while (true) {
						char = readChar();
						exp *= 10;
						switch (char) {
							case 48, 49, 50, 51, 52, 53, 54, 55, 56, 57:
								n = n * 10 + (char - 48);
							case "e".code, "E".code:
								var tk = token();
								var pow:Null<Int> = null;
								switch (tk) {
									case TConst(CInt(e)): pow = e;
									case TOp("-"):
										tk = token();
										switch (tk) {
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
								if (exp > 0) {
									// in case of '0...'
									if (exp == 10 && readChar() == ".".code) {
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
								while (true) {
									char = readChar();
									switch (char) {
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
				case ':'.code:
					return TDoubleDot;
				case '('.code:
					return TPOpen;
				case ')'.code:
					return TPClose;
				case '['.code:
					return TBOpen;
				case ']'.code:
					return TBClose;
				case '{'.code:
					return TBkOpen;
				case '}'.code:
					return TBkClose;
				case ",".code:
					return TComma;
				case ".".code:
					char = readChar();
					switch (char) {
						case 48, 49, 50, 51, 52, 53, 54, 55, 56, 57:
							var n = char - 48;
							var exp = 1;
							while (true) {
								char = readChar();
								exp *= 10;
								switch (char) {
									case 48, 49, 50, 51, 52, 53, 54, 55, 56, 57:
										n = n * 10 + (char - 48);
									default:
										this.char = char;
										return TConst(CFloat(n / exp));
								}
							}
						case ".".code:
							char = readChar();
							if (char != ".".code) {
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
					if (char == '-'.code) {
						while (true) {
							switch (readChar()) {
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
					var nextChar:String;
					if (opPriority.exists(String.fromCharCode(char) + (nextChar = String.fromCharCode(readChar())))) {
						return TOp(String.fromCharCode(char) + nextChar);
					}
					pos--;
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
				default:
					if (idents[char]) {
						var id = String.fromCharCode(char);
						while (true) {
							char = readChar();
							if (StringTools.isEof(char))
								char = 0;
							if (!idents[char]) {
								this.char = char;
								return switch (id) {
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

	function readString(until) {
		var c = 0;
		var b = new StringBuf();
		var esc = false;
		var old = line;
		var s = input;
		while (true) {
			var c = readChar();
			if (StringTools.isEof(c)) {
				line = old;
				break;
			}
			if (esc) {
				esc = false;
				switch (c) {
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
			} else if (c == 92)
				esc = true;
			else if (c == until)
				break;
			else {
				if (c == 10)
					line++;
				b.addChar(c);
			}
		}
		return b.toString();
	}

	inline function pmax(e:Expr) {
		#if hscriptPos
		return e == null ? 0 : e.pmax;
		#else
		return 0;
		#end
	}

	inline function push(tk:Token):Void {
		tokens.add(tk);
	}

	inline function ensure(tk:Token) {
		var t = token();
		if (t != tk)
			unexpected(t);
	}

	function getIdent() {
		var tk = token();
		switch (tk) {
			case TId(id):
				return id;
			default:
				unexpected(tk);
				return null;
		}
	}

	inline function ensureToken(tk:Token) {
		var t = token();
		if (!Type.enumEq(t, tk))
			unexpected(t);
	}

	inline function error(err) {
		#if hscriptPos
		throw new Error(err, 0, 0, 'rulescript', line);
		#else
		throw err;
		#end
	}

	inline function invalidChar(c) {
		error(EInvalidChar(c));
	}

	function unexpected(tk:Token):Dynamic {
		error(EUnexpected('$tk'));
		return null;
	}

	inline function maybe(tk:Token):Bool {
		var _tk = token();
		if (tk.equals(_tk))
			return true;

		push(_tk);
		return false;
	}

	inline function readChar():Int
		return StringTools.fastCodeAt(input, pos++);

	inline function mk(e, ?pmin:Int, ?pmax:Int):Expr {
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
