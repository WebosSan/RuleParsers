package rulescript.printers;

import hscript.Expr;

using rulescript.Tools;

class LuaPrinter
{
	public static function print(expr:Expr, ?tabs:Int = 0):String
	{
		var s:String = '';

		var tab = '';
		for (_ in 0...tabs)
			tab += '  ';

		s += tab;
		switch (Tools.getExpr(expr))
		{
			case EBlock(e):
				for (expr in e)
					s += print(expr, tabs) + '\n' + tab;
			case EIdent(v):
				s += '$v';
			case EUnop('not', _, e):
				s += 'not ' + print(e);

			case EParent(e):
				s += '(${print(e)})';
			case EUnop(op, _, e):
				s += '$op' + print(e);
			case EBinop(op, e1, e2):
				s += print(e1) + ' $op ' + print(e2);
			case EFunction(args, e, name, ret):
				s += 'function';
				if (name != null)
					s += ' $name';

				s += '(${args.map(arg -> arg.name).join(',')})\n';

				s += print(e, tabs + 1);

				s += '\n';
			case EIf(cond, e1, e2):
				s += 'if ' + print(cond) + ' then\n';
				s += print(e1, tabs);
				if (e2 != null)
					s += 'else\n$tab' + print(e2, tabs) + '';
				s += tab + 'end\n';
			case EVar(n, _, e, global):
				s += (global ? '' : 'local ') + n;

				if (e != null)
					s += ' =' + print(e);

				s += '\n';
			case EConst(c):
				switch (c)
				{
					case CInt(v):
						s += v;
					case CFloat(f):
						s += f;
					case CString(_s):
						s += "'" + _s + "'";
				}
			case EReturn(e):
				s += 'return ' + print(e);
			case EField(e, params):
				s += print(e) + '.$params';
			case ECall(e, params):
				s += print(e) + '(';
				s += params.map(param -> print(param)).join(',');
				s += ')';
			default:
				s += 'hx.expr("$expr")';
		}
		return s;
	}
}
