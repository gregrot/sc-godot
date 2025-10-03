extends RefCounted
class_name RobotScriptLexer

# Token definitions and tokenizer for RobotScriptEngine.

enum TokenType {
	IDENT, NUMBER, STRING,
	LPAREN, RPAREN, COMMA, PLUS, MINUS, STAR, SLASH, EQUAL, SEMICOLON,
	DOT_DOT,
	NEWLINE, EOF
}

static func tokenize(src: String, err_cb: Callable) -> Array:
	var lexer := _Lexer.new(src, err_cb)
	return lexer.tokenize()

class _Lexer:
	var src: String
	var i: int = 0
	var line: int = 1
	var col: int = 1
	var tokens: Array = []
	var _err_cb: Callable

	func _init(_src: String, err_cb: Callable) -> void:
		src = _src
		_err_cb = err_cb

	func tokenize() -> Array:
		while not _at_end():
			var c: String = _advance()
			match c:
				" ", "\t", "\r":
					pass
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
				".":
					if _peek() == ".":
						_advance()
						_emit(TokenType.DOT_DOT, "..")
					else:
						_emit_error("Unexpected '.'.")
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
						_emit_error("Unexpected character '%s'." % c)
		_emit(TokenType.EOF, "")
		return tokens

	func _peek() -> String:
		return "" if _at_end() else src[i]

	func _peek_next() -> String:
		if i + 1 >= src.length():
			return ""
		return src[i + 1]

	func _advance() -> String:
		if _at_end():
			return ""
		var ch: String = src[i]
		i += 1
		col += 1
		return ch

	func _at_end() -> bool:
		return i >= src.length()

	func _emit(t: int, lex: String, lit: Variant = null) -> void:
		var start_col: int = col - int(max(lex.length(), 1))
		tokens.append({"type": t, "lex": lex, "lit": lit, "line": line, "col": start_col})

	func _emit_error(msg: String) -> void:
		_err_cb.call("Lex %d:%d: %s" % [line, col, msg])

	func _skip_comment() -> void:
		while not _at_end() and _peek() != "\n":
			_advance()

	func _scan_ident(first: String) -> void:
		var s: String = first
		while not _at_end() and (_is_alnum(_peek()) or _peek() == "_"):
			s += _advance()
		_emit(TokenType.IDENT, s, s)

	func _scan_number(first: String) -> void:
		var s: String = first
		while not _at_end() and _is_digit(_peek()):
			s += _advance()
		if not _at_end() and _peek() == "." and _peek_next() != ".":
			s += _advance()
			while not _at_end() and _is_digit(_peek()):
				s += _advance()
		var val: Variant = null
		if "." in s:
			val = float(s)
		else:
			val = int(s)
		_emit(TokenType.NUMBER, s, val)

	func _scan_string() -> void:
		var out: String = ""
		while not _at_end():
			var c: String = _advance()
			if c == "\"":
				_emit(TokenType.STRING, out, out)
				return
			if c == "\\":
				if _at_end():
					break
				var e: String = _advance()
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
