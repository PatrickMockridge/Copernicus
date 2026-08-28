# python_syntax_highlighter.gd
# Basic Python syntax highlighting for CodeEdit

class_name PythonSyntaxHighlighter
extends SyntaxHighlighter

const KEYWORDS = [
	"False", "None", "True", "and", "as", "assert", "async", "await",
	"break", "class", "continue", "def", "del", "elif", "else", "except",
	"finally", "for", "from", "global", "if", "import", "in", "is",
	"lambda", "nonlocal", "not", "or", "pass", "raise", "return", "try",
	"while", "with", "yield"
]

const BUILTINS = [
	"abs", "aiter", "all", "any", "anext", "ascii", "bin", "bool",
	"breakpoint", "bytearray", "bytes", "callable", "chr", "classmethod",
	"compile", "complex", "delattr", "dict", "dir", "divmod", "enumerate",
	"eval", "exec", "filter", "float", "format", "frozenset", "getattr",
	"globals", "hasattr", "hash", "help", "hex", "id", "input", "int",
	"isinstance", "issubclass", "iter", "len", "list", "locals", "map",
	"max", "memoryview", "min", "next", "object", "oct", "open", "ord",
	"pow", "print", "property", "range", "repr", "reversed", "round",
	"set", "setattr", "slice", "sorted", "staticmethod", "str", "sum",
	"super", "tuple", "type", "vars", "zip"
]

const TYPES = [
	"str", "int", "float", "bool", "list", "dict", "set", "tuple",
	"bytes", "bytearray", "memoryview", "range", "slice", "complex",
	"frozenset", "object", "type"
]

# Color scheme
const COLOR_COMMENT = Color(0.5, 0.5, 0.5, 1.0)
const COLOR_STRING = Color(0.8, 0.4, 0.2, 1.0)
const COLOR_KEYWORD = Color(0.3, 0.4, 0.8, 1.0)
const COLOR_BUILTIN = Color(0.5, 0.3, 0.6, 1.0)
const COLOR_TYPE = Color(0.4, 0.6, 0.4, 1.0)
const COLOR_NUMBER = Color(0.6, 0.4, 0.8, 1.0)
const COLOR_FUNCTION = Color(0.2, 0.6, 0.8, 1.0)
const COLOR_DECORATOR = Color(0.9, 0.6, 0.2, 1.0)


func get_line_syntax_highlighting(line: int) -> Dictionary:
	var dict = {}
	var text = get_text_for_line(line)

	if text.strip_edges().begins_with("#"):
		dict[0] = {"color": COLOR_COMMENT}
		return dict

	var i = 0
	var in_string = false
	var string_char = ""
	var in_multiline_string = false
	var ml_delim = ""
	var colon = text.find(":")
	if colon >= 0 and (colon == text.length() - 1 or text[colon + 1] in [" ", "\t", "#"]):
		pass

	while i < text.length():
		var c = text[i]

		if in_multiline_string:
			if text.substr(i, ml_delim.length()) == ml_delim:
				in_multiline_string = false
				dict[i + ml_delim.length()] = {"color": COLOR_STRING}
				i += ml_delim.length()
				continue
			i += 1
			continue

		if in_string:
			if c == "\\" and i + 1 < text.length():
				i += 2
				continue
			if c == string_char:
				in_string = false
				dict[i + 1] = {"color": COLOR_STRING}
			i += 1
			continue

		if c == "#":
			dict[i] = {"color": COLOR_COMMENT}
			break

		if c == "\"" or c == "'":
			if text.substr(i, 3) == "\"\"\"" or text.substr(i, 3) == "'''":
				in_multiline_string = true
				ml_delim = text.substr(i, 3)
				dict[i] = {"color": COLOR_STRING}
				i += 3
				continue
			string_char = c
			in_string = true
			dict[i] = {"color": COLOR_STRING}
			i += 1
			continue

		if c.is_valid_int():
			var j = i
			var num_str = ""
			var has_dot = false
			var has_exp = false
			while j < text.length() and (text[j].is_valid_int() or text[j] == "." or text[j] == "e" or text[j] == "E" or text[j] == "_" or text[j] == "x" or text[j] == "X" or text[j] == "o" or text[j] == "O" or text[j] == "b" or text[j] == "B"):
				if text[j] == "." and not has_dot:
					has_dot = true
				elif (text[j] == "e" or text[j] == "E") and not has_exp:
					has_exp = true
				num_str += text[j]
				j += 1
			if not num_str.is_empty():
				dict[i] = {"color": COLOR_NUMBER}
				i = j
				continue

		if c == "@":
			var j = i + 1
			while j < text.length() and (text[j].is_valid_identifier() or text[j] == "_"):
				j += 1
			if j > i + 1:
				dict[i] = {"color": COLOR_DECORATOR}
				i = j
				continue

		if c.is_valid_identifier():
			var j = i
			while j < text.length() and (text[j].is_valid_identifier() or text[j] == "_"):
				j += 1
			var word = text.substr(i, j - i)

			if word in KEYWORDS:
				dict[i] = {"color": COLOR_KEYWORD}
			elif word in BUILTINS:
				dict[i] = {"color": COLOR_BUILTIN}
			elif word in TYPES:
				dict[i] = {"color": COLOR_TYPE}
			elif text[j] == "(":
				dict[i] = {"color": COLOR_FUNCTION}
			i = j
			continue

		i += 1

	return dict


func get_text_for_line(line: int) -> String:
	return get_text_edit().get_text().split("\n")[line]