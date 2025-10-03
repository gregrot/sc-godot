extends RefCounted
class_name RobotScriptParser

const LexerScript := preload("res://robot_script/robot_script_lexer.gd")
const TokenType := LexerScript.TokenType

const NODE_PROGRAM := "program"
const NODE_ASSIGN := "assign"
const NODE_EXPR_STMT := "expr_stmt"
const NODE_BINARY := "binary"
const NODE_UNARY := "unary"
const NODE_LITERAL := "literal"
const NODE_VAR := "var"
const NODE_CALL := "call"
const NODE_FUNCTION := "function"
const NODE_ARRAY := "array"
const NODE_OBJECT := "object"
const NODE_INDEX := "index"
const NODE_GET := "get"

static func parse(tokens: Array, err_cb: Callable) -> Dictionary:
	var parser := _Parser.new(tokens, err_cb)
	return parser.parse_program()

class _Parser:
	var tokens: Array
	var i: int = 0
	var _err_cb: Callable

	func _init(_tokens: Array, err_cb: Callable) -> void:
		tokens = _tokens
		_err_cb = err_cb

	func parse_program() -> Dictionary:
		var body: Array = []
		_skip_separators()
		while not _check(TokenType.EOF):
			var stmt: Dictionary = _statement()
			if stmt != null:
				body.append(stmt)
			_consume_statement_separator()
			_skip_separators()
		return {"type": NODE_PROGRAM, "body": body}

	func _statement() -> Dictionary:
		if _check_keyword("func"):
			return _function_decl()
		if _check(TokenType.IDENT) and _check_next(TokenType.EQUAL):
			return _assignment()
		var expr: Dictionary = _expression()
		return {"type": NODE_EXPR_STMT, "expr": expr}

	func _function_decl() -> Dictionary:
		var func_tok: Dictionary = _consume_keyword("func", "Expected 'func'.")
		var name_tok: Dictionary = _consume(TokenType.IDENT, "Expected function name after 'func'.")
		_consume(TokenType.LPAREN, "Expected '(' after function name.")
		var params: Array = []
		if not _check(TokenType.RPAREN):
			params.append(_consume(TokenType.IDENT, "Expected parameter name.")["lex"])
			while _match(TokenType.COMMA):
				params.append(_consume(TokenType.IDENT, "Expected parameter name.")["lex"])
		_consume(TokenType.RPAREN, "Expected ')' after parameter list.")
		_consume_optional_statement_separator()
		_skip_separators()
		var body: Array = []
		while not _check_keyword("end"):
			if _check(TokenType.EOF):
				_error_here("Expected 'end' to close function '%s'." % name_tok["lex"])
				return {"type": NODE_FUNCTION, "name": name_tok["lex"], "params": params, "body": body, "line": func_tok["line"], "col": func_tok["col"]}
			var stmt: Dictionary = _statement()
			if stmt != null:
				body.append(stmt)
			_consume_statement_separator()
			_skip_separators()
		_consume_keyword("end", "Expected 'end' after function body.")
		return {"type": NODE_FUNCTION, "name": name_tok["lex"], "params": params, "body": body, "line": func_tok["line"], "col": func_tok["col"]}

	func _assignment() -> Dictionary:
		var name_tok: Dictionary = _consume(TokenType.IDENT, "Expected identifier before '='.")
		_consume(TokenType.EQUAL, "Expected '=' after identifier.")
		var expr: Dictionary = _expression()
		return {"type": NODE_ASSIGN, "name": name_tok["lex"], "expr": expr, "line": name_tok["line"], "col": name_tok["col"]}

	func _expression() -> Dictionary:
		return _term()

	func _term() -> Dictionary:
		var node: Dictionary = _factor()
		while _match(TokenType.PLUS) or _match(TokenType.MINUS):
			var op_tok: Dictionary = _previous()
			var right: Dictionary = _factor()
			node = {"type": NODE_BINARY, "op": op_tok["lex"], "left": node, "right": right, "line": op_tok["line"], "col": op_tok["col"]}
		return node

	func _factor() -> Dictionary:
		var node: Dictionary = _unary()
		while _match(TokenType.STAR) or _match(TokenType.SLASH):
			var op_tok: Dictionary = _previous()
			var right: Dictionary = _unary()
			node = {"type": NODE_BINARY, "op": op_tok["lex"], "left": node, "right": right, "line": op_tok["line"], "col": op_tok["col"]}
		return node

        func _unary() -> Dictionary:
                if _match(TokenType.MINUS):
                        var op_tok: Dictionary = _previous()
                        var expr: Dictionary = _unary()
                        return {"type": NODE_UNARY, "op": "-", "expr": expr, "line": op_tok["line"], "col": op_tok["col"]}
                return _call()

        func _call() -> Dictionary:
                var expr: Dictionary = _primary()
                while true:
                        if _match(TokenType.LPAREN):
                                var lparen: Dictionary = _previous()
                                var args: Array = []
                                if not _check(TokenType.RPAREN):
                                        args.append(_expression())
                                        while _match(TokenType.COMMA):
                                                args.append(_expression())
                                _consume(TokenType.RPAREN, "Expected ')' after arguments.")
                                if expr.get("type") == NODE_VAR:
                                        expr = {"type": NODE_CALL, "name": expr.get("name"), "args": args, "line": lparen["line"], "col": lparen["col"]}
                                else:
                                        expr = {"type": NODE_CALL, "callee": expr, "args": args, "line": lparen["line"], "col": lparen["col"]}
                                continue
                        if _match(TokenType.LBRACKET):
                                var lbracket: Dictionary = _previous()
                                var index_expr: Dictionary = _expression()
                                _consume(TokenType.RBRACKET, "Expected ']' after index expression.")
                                expr = {"type": NODE_INDEX, "object": expr, "index": index_expr, "line": lbracket["line"], "col": lbracket["col"]}
                                continue
                        if _match(TokenType.DOT):
                                var dot_tok: Dictionary = _previous()
                                var name_tok: Dictionary = _consume(TokenType.IDENT, "Expected property name after '.'.")
                                expr = {"type": NODE_GET, "object": expr, "property": name_tok["lex"], "line": dot_tok["line"], "col": dot_tok["col"]}
                                continue
                        break
                return expr

        func _primary() -> Dictionary:
                if _match(TokenType.NUMBER) or _match(TokenType.STRING):
                        var t: Dictionary = _previous()
                        return {"type": NODE_LITERAL, "value": t["lit"]}
                if _match(TokenType.IDENT):
                        var ident: Dictionary = _previous()
                        return {"type": NODE_VAR, "name": ident["lex"], "line": ident["line"], "col": ident["col"]}
                if _match(TokenType.LPAREN):
                        var e: Dictionary = _expression()
                        _consume(TokenType.RPAREN, "Expected ')' after expression.")
                        return e
                if _match(TokenType.LBRACKET):
                        return _array_literal()
                if _match(TokenType.LBRACE):
                        return _object_literal()
                _error_here("Unexpected token.")
                return {"type": NODE_LITERAL, "value": null}

        func _array_literal() -> Dictionary:
                var lbracket: Dictionary = _previous()
                var items: Array = []
                if not _check(TokenType.RBRACKET):
                        items.append(_expression())
                        while _match(TokenType.COMMA):
                                items.append(_expression())
                _consume(TokenType.RBRACKET, "Expected ']' after array literal.")
                return {"type": NODE_ARRAY, "elements": items, "line": lbracket["line"], "col": lbracket["col"]}

        func _object_literal() -> Dictionary:
                var lbrace: Dictionary = _previous()
                var props: Array = []
                if not _check(TokenType.RBRACE):
                        props.append(_object_property())
                        while _match(TokenType.COMMA):
                                props.append(_object_property())
                _consume(TokenType.RBRACE, "Expected '}' after object literal.")
                return {"type": NODE_OBJECT, "properties": props, "line": lbrace["line"], "col": lbrace["col"]}

        func _object_property() -> Dictionary:
                var key_tok: Dictionary
                var key: Variant
                if _match(TokenType.STRING) or _match(TokenType.NUMBER):
                        key_tok = _previous()
                        key = key_tok["lit"]
                elif _match(TokenType.IDENT):
                        key_tok = _previous()
                        key = key_tok["lex"]
                else:
                        _error_here("Expected property name or string literal.")
                        return {"key": "", "value": {"type": NODE_LITERAL, "value": null}, "line": _line(), "col": _col()}
                _consume(TokenType.COLON, "Expected ':' after property name.")
                var value_expr: Dictionary = _expression()
                return {"key": key, "value": value_expr, "line": key_tok["line"], "col": key_tok["col"]}

	func _consume_statement_separator() -> void:
		if _match(TokenType.SEMICOLON):
			return
		if _match(TokenType.NEWLINE):
			while _match(TokenType.NEWLINE):
				pass
			return
		if _check(TokenType.EOF):
			return
		_error_here("Expected end of statement (‘\\n’ or ‘;’).")

	func _consume_optional_statement_separator() -> void:
		if _match(TokenType.NEWLINE):
			while _match(TokenType.NEWLINE):
				pass
			return
		if _match(TokenType.SEMICOLON):
			while _match(TokenType.SEMICOLON):
				pass

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

	func _check_keyword(name: String) -> bool:
		if not _check(TokenType.IDENT):
			return false
		return tokens[i]["lex"] == name

	func _consume_keyword(name: String, msg: String) -> Dictionary:
		if _check_keyword(name):
			i += 1
			return tokens[i - 1]
		_error_here(msg)
		return {"type": TokenType.IDENT, "lex": name, "lit": null, "line": _line(), "col": _col()}

	func _consume(t: int, msg: String) -> Dictionary:
		if _check(t):
			i += 1
			return tokens[i - 1]
		_error_here(msg)
		return {"type": t, "lex": "", "lit": null, "line": _line(), "col": _col()}

	func _previous() -> Dictionary:
		return tokens[i - 1]

	func _is_at_end() -> bool:
		return tokens[i]["type"] == TokenType.EOF

	func _line() -> int:
		return tokens[i]["line"] if i < tokens.size() else 0

	func _col() -> int:
		return tokens[i]["col"] if i < tokens.size() else 0

	func _error_here(msg: String) -> void:
		_err_cb.call("Parse %d:%d: %s" % [_line(), _col(), msg])
