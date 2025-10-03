# RobotScriptEngine.gd
extends RefCounted
class_name RobotScriptEngine

# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

func bind(name: String, fn: Callable) -> void:
	# Bind a function name used by scripts to a game Callable (robot method, etc.)
	_builtins[name] = fn

func unbind(name: String) -> void:
	_builtins.erase(name)

func clear_builtins() -> void:
	_builtins.clear()

func run(script_text: String, variables: Dictionary = {}) -> Dictionary:
	# Compile + execute in one step.
	_errors.clear()
	var tokens := _tokenize(script_text)
	if _has_errors(): return _fail()
	var ast := _parse(tokens)
	if _has_errors(): return _fail()
	return _execute(ast, variables)

func compile(script_text: String) -> Dictionary:
	# Optionally: compile once, run many times.
	_errors.clear()
	var tokens := _tokenize(script_text)
	if _has_errors(): return _fail()
	var ast := _parse(tokens)
	if _has_errors(): return _fail()
	return { "ok": true, "ast": ast }

func execute(compiled: Dictionary, variables: Dictionary = {}) -> Dictionary:
	# Execute a compiled AST.
	if not compiled.has("ast"):
		return { "ok": false, "errors": PackedStringArray(["Missing 'ast' in compiled dictionary"]) }
	_errors.clear()
	return _execute(compiled["ast"], variables)

# ─────────────────────────────────────────────────────────────────────────────
# Internals
# ─────────────────────────────────────────────────────────────────────────────

# Token types
enum TokenType {
	IDENT, NUMBER, STRING,
	LPAREN, RPAREN, COMMA, PLUS, MINUS, STAR, SLASH, EQUAL, SEMICOLON,
	NEWLINE, EOF
}

# AST node tags
const N_PROGRAM := "program"
const N_ASSIGN  := "assign"
const N_EXPRST  := "expr_stmt"
const N_BINARY  := "binary"
const N_UNARY   := "unary"
const N_LITERAL := "literal"
const N_VAR     := "var"
const N_CALL    := "call"

# Runtime state
var _builtins: Dictionary = {}            # String -> Callable
var _errors: PackedStringArray = []       # Collected compile/runtime errors

# ─────────────────────────────────────────────────────────────────────────────
# Lexing
# ─────────────────────────────────────────────────────────────────────────────

class _Lexer:
	var src: String
	var i := 0
	var line := 1
	var col := 1
	var tokens: Array = []

	func _init(_src: String) -> void:
		src = _src

	func tokenize() -> Array:
		while not _at_end():
			var c := _advance()
			match c:
				" ", "\t", "\r":
					pass # ignore
				"\n":
					_emit(TokenType.NEWLINE, "\n")
					line += 1
					col = 1
				"#":
					_skip_comment()
				"(":
					_emit(TokenType.LPAREN, c)
				")":
					_emit(TokenType.RPAREN, c)
				",":
					_emit(TokenType.COMMA, c)
				"+":
					_emit(TokenType.PLUS, c)
				"-":
					_emit(TokenType.MINUS, c)
				"*":
					_emit(TokenType.STAR, c)
				"/":
					_emit(TokenType.SLASH, c)
				"=":
					_emit(TokenType.EQUAL, c)
				";":
					_emit(TokenType.SEMICOLON, c)
				"\"":
					_scan_string()
				_:
					if _is_alpha(c) or c == "_":
						_scan_ident(c)
					elif _is_digit(c):
						_scan_number(c)
					else:
						# Unknown character; report but keep going
						_emit_error("Unexpected character '%s'." % c)
		_emit(TokenType.EOF, "")
		return tokens

	func _peek() -> String:
		return "" if _at_end() else src[i]

	func _advance() -> String:
		if _at_end(): return ""
		var ch := src[i]
		i += 1
		col += 1
		return ch

	func _at_end() -> bool:
		return i >= src.length()

	func _emit(t: int, lex: String, lit: Variant = null) -> void:
		tokens.append({ "type": t, "lex": lex, "lit": lit, "line": line, "col": col - max(lex.length(), 1) })

	func _emit_error(msg: String) -> void:
		RobotScriptEngine._report_error("Lex %d:%d: %s" % [line, col, msg])

	func _skip_comment() -> void:
		while not _at_end() and _peek() != "\n":
			_advance()

	func _scan_ident(first: String) -> void:
		var s := first
		while not _at_end() and (_is_alnum(_peek()) or _peek() == "_"):
			s += _advance()
		_emit(TokenType.IDENT, s, s)

	func _scan_number(first: String) -> void:
		var s := first
		while not _at_end() and _is_digit(_peek()):
			s += _advance()
		if not _at_end() and _peek() == ".":
			s += _advance()
			while not _at_end() and _is_digit(_peek()):
				s += _advance()
		# parse number: prefer int if no dot
		var val: Variant = null
		if "." in s:
			val = float(s)
		else:
			# handle large ints gracefully
			val = int(s)
		_emit(TokenType.NUMBER, s, val)

	func _scan_string() -> void:
		var out := ""
		while not _at_end():
			var c := _advance()
			if c == "\"":
				_emit(TokenType.STRING, out, out)
				return
			if c == "\\":
				if _at_end():
					break
				var e := _advance()
				match e:
					"n": out += "\n"
					"t": out += "\t"
					"r": out += "\r"
					"\"": out += "\""
					"\\": out += "\\"
					_:
						out += e
			else:
				if c == "\n":
					# strings may span lines; keep NEWLINE in string (common for logs)
					line += 1
					col = 1
				out += c
		_emit_error("Unterminated string literal.")

	static func _is_digit(c: String) -> bool:
		return c >= "0" and c <= "9"

	static func _is_alpha(c: String) -> bool:
		return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z")

	static func _is_alnum(c: String) -> bool:
		return _Lexer._is_alpha(c) or _Lexer._is_digit(c)


func _tokenize(src: String) -> Array:
	var lx := _Lexer.new(src)
	return lx.tokenize()

# ─────────────────────────────────────────────────────────────────────────────
# Parsing
# ─────────────────────────────────────────────────────────────────────────────

class _Parser:
	var tokens: Array
	var i := 0

	func _init(_tokens: Array) -> void:
		tokens = _tokens

	func parse_program() -> Dictionary:
		var body: Array = []
		_skip_separators()
		while not _check(TokenType.EOF):
			var stmt := _statement()
			if stmt != null:
				body.append(stmt)
			_consume_statement_separator()
			_skip_separators()
		return { "type": N_PROGRAM, "body": body }

	# statements

	func _statement() -> Dictionary:
		if _check(TokenType.IDENT) and _check_next(TokenType.EQUAL):
			return _assignment()
		# expression statement
		var expr := _expression()
		return { "type": N_EXPRST, "expr": expr }

	func _assignment() -> Dictionary:
		var name_tok := _consume(TokenType.IDENT, "Expected identifier before '='.")
		_consume(TokenType.EQUAL, "Expected '=' after identifier.")
		var expr := _expression()
		return { "type": N_ASSIGN, "name": name_tok["lex"], "expr": expr, "line": name_tok["line"], "col": name_tok["col"] }

	# expressions

	func _expression() -> Dictionary:
		return _term()

	func _term() -> Dictionary:
		var node := _factor()
		while _match(TokenType.PLUS) or _match(TokenType.MINUS):
			var op_tok := _previous()
			var right := _factor()
			node = { "type": N_BINARY, "op": op_tok["lex"], "left": node, "right": right, "line": op_tok["line"], "col": op_tok["col"] }
		return node

	func _factor() -> Dictionary:
		var node := _unary()
		while _match(TokenType.STAR) or _match(TokenType.SLASH):
			var op_tok := _previous()
			var right := _unary()
			node = { "type": N_BINARY, "op": op_tok["lex"], "left": node, "right": right, "line": op_tok["line"], "col": op_tok["col"] }
		return node

	func _unary() -> Dictionary:
		if _match(TokenType.MINUS):
			var op_tok := _previous()
			var expr := _unary()
			return { "type": N_UNARY, "op": "-", "expr": expr, "line": op_tok["line"], "col": op_tok["col"] }
		return _primary()

	func _primary() -> Dictionary:
		if _match(TokenType.NUMBER) or _match(TokenType.STRING):
			var t := _previous()
			return { "type": N_LITERAL, "value": t["lit"] }
		if _match(TokenType.IDENT):
			var ident := _previous()
			# function call?
			if _match(TokenType.LPAREN):
				var args: Array = []
				if not _check(TokenType.RPAREN):
					args.append(_expression())
					while _match(TokenType.COMMA):
						args.append(_expression())
				_consume(TokenType.RPAREN, "Expected ')' after arguments.")
				return { "type": N_CALL, "name": ident["lex"], "args": args, "line": ident["line"], "col": ident["col"] }
			# variable reference
			return { "type": N_VAR, "name": ident["lex"], "line": ident["line"], "col": ident["col"] }
		if _match(TokenType.LPAREN):
			var e := _expression()
			_consume(TokenType.RPAREN, "Expected ')' after expression.")
			return e
		_error_here("Unexpected token.")
		# attempt to recover
		return { "type": N_LITERAL, "value": null }

	# helpers

	func _consume_statement_separator() -> void:
		if _match(TokenType.SEMICOLON):
			return
		if _match(TokenType.NEWLINE):
			while _match(TokenType.NEWLINE):
				pass
			return
		# Allow EOF as a separator when the file ends
		if _check(TokenType.EOF):
			return
		_error_here("Expected end of statement (‘\\n’ or ‘;’).")

	func _skip_separators() -> void:
		while _match(TokenType.NEWLINE) or _match(TokenType.SEMICOLON):
			pass

	func _match(t: int) -> bool:
		if _check(t):
			i += 1
			return true
		return false

	func _check(t: int) -> bool:
		if _is_at_end():
			return t == TokenType.EOF
		return tokens[i]["type"] == t

	func _check_next(t: int) -> bool:
		if i + 1 >= tokens.size():
			return false
		return tokens[i + 1]["type"] == t

	func _consume(t: int, msg: String) -> Dictionary:
		if _check(t):
			i += 1
			return tokens[i - 1]
		_error_here(msg)
		# return a dummy token to keep parsing
		return { "type": t, "lex": "", "lit": null, "line": _line(), "col": _col() }

	func _previous() -> Dictionary:
		return tokens[i - 1]

	func _is_at_end() -> bool:
		return tokens[i]["type"] == TokenType.EOF

	func _line() -> int:
		return tokens[i]["line"] if i < tokens.size() else 0

	func _col() -> int:
		return tokens[i]["col"] if i < tokens.size() else 0

	func _error_here(msg: String) -> void:
		RobotScriptEngine._report_error("Parse %d:%d: %s" % [_line(), _col(), msg])


func _parse(tokens: Array) -> Dictionary:
	var p := _Parser.new(tokens)
	return p.parse_program()

# ─────────────────────────────────────────────────────────────────────────────
# Evaluation
# ─────────────────────────────────────────────────────────────────────────────

func _execute(ast: Dictionary, variables: Dictionary) -> Dictionary:
	var env := variables.duplicate()
	var last: Variant = null
	for stmt in ast["body"]:
		last = _exec_stmt(stmt, env)
		if _has_errors():
			return _fail(env)
	return { "ok": true, "result": last, "vars": env }

func _exec_stmt(stmt: Dictionary, env: Dictionary) -> Variant:
	match stmt["type"]:
		N_ASSIGN:
			var v := _eval_expr(stmt["expr"], env)
			if _has_errors(): return null
			env[stmt["name"]] = v
			return v
		N_EXPRST:
			return _eval_expr(stmt["expr"], env)
		_:
			_report_error("Runtime: Unknown statement type '%s'." % str(stmt["type"]))
			return null

func _eval_expr(node: Dictionary, env: Dictionary) -> Variant:
	match node["type"]:
		N_LITERAL:
			return node["value"]
		N_VAR:
			if not env.has(node["name"]):
				_report_error("Runtime %d:%d: Undefined variable '%s'." % [ node.get("line", 0), node.get("col", 0), node["name"] ])
				return null
			return env[node["name"]]
		N_UNARY:
			var v := _eval_expr(node["expr"], env)
			if _has_errors(): return null
			if node["op"] == "-":
				if not (v is float or v is int):
					_report_error("Runtime: Unary '-' requires a number, got %s." % typeof(v))
					return null 
				return -v
			_report_error("Runtime: Unknown unary operator '%s'." % node["op"])
			return null
		N_BINARY:
			var a := _eval_expr(node["left"], env)
			var b := _eval_expr(node["right"], env)
			if _has_errors(): return null
			match node["op"]:
				"+":
					if (a is float or a is int) and (b is float or b is int):
						return a + b
					if (a is String) or (b is String):
						return str(a) + str(b)
					_report_error("Runtime: '+' requires numbers or strings.")
					return null
				"-":
					if (a is float or a is int) and (b is float or b is int):
						return a - b
					_report_error("Runtime: '-' requires numbers.")
					return null
				"*":
					if (a is float or a is int) and (b is float or b is int):
						return a * b
					_report_error("Runtime: '*' requires numbers.")
					return null
				"/":
					if (a is float or a is int) and (b is float or b is int):
						if float(b) == 0.0:
							_report_error("Runtime: Division by zero.")
							return null
						return float(a) / float(b)
					_report_error("Runtime: '/' requires numbers.")
					return null
				_:
					_report_error("Runtime: Unknown binary operator '%s'." % node["op"])
					return null
		N_CALL:
			var fn_name: String = node["name"]
			var args: Array = []
			for a in node["args"]:
				args.append(_eval_expr(a, env))
				if _has_errors(): return null
			# Prefer env-bound callables if present, then builtins
			if env.has(fn_name) and env[fn_name] is Callable:
				var c: Callable = env[fn_name]
				return c.callv(args)
			if _builtins.has(fn_name):
				var cb: Callable = _builtins[fn_name]
				return cb.callv(args)
			_report_error("Runtime %d:%d: Unknown function '%s'." % [ node.get("line", 0), node.get("col", 0), fn_name ])
			return null
		_:
			_report_error("Runtime: Unknown expression type '%s'." % str(node["type"]))
			return null

# ─────────────────────────────────────────────────────────────────────────────
# Error handling helpers
# ─────────────────────────────────────────────────────────────────────────────

static func _report_error(msg: String) -> void:
	# Collected so we can return them to the caller instead of throwing
	RobotScriptEngine._errors.append(msg)

func _has_errors() -> bool:
	return _errors.size() > 0

func _fail(vars := {}) -> Dictionary:
	return { "ok": false, "errors": _errors.duplicate(), "vars": vars }
