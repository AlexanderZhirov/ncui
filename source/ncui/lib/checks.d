module ncui.lib.checks;

import std.traits : isPointer;
import std.exception : enforce;
import std.format : format;

import deimos.ncurses : ERR;
import deimos.form;

/**
 * Возвращает имя функции `fn` для сообщений об ошибках.
 */
private string _fnName(alias fn)()
{
	return __traits(identifier, fn);
}

/**
 * Вызывает `fn(args)` и строго проверяет, что результат равен `expected`.
 *
 * - Тип `expected` обязан совпадать с типом результата `fn`.
 * - При несоответствии бросает исключение с местом вызова.
 */
auto ncuiExpect(alias fn, Expected, Args...)(
	Expected expected,
	Args args,
	string file = __FILE__,
	size_t line = __LINE__,
	string module_ = __MODULE__,
	string function_ = __FUNCTION__
) if (__traits(compiles, fn(args)))
{
	auto result = fn(args);

	static assert(is(typeof(result) == Expected),
		format("ncuiExpect: expected type must match the result type %s().", _fnName!fn));

	enforce(result == expected, format(
			"Unexpected return value: %s() returned=%s expected=%s [%s:%s | %s | %s]",
			_fnName!fn, result, expected, file, line, module_, function_
	));

	return result;
}

/**
 * Вызывает `fn(args)` и строго проверяет, что результат равен `expected`.
 *
 * - Тип `expected` обязан совпадать с типом результата `fn`.
 * - При несоответствии бросает исключение с пользовательским сообщением и местом вызова.
 */
auto ncuiExpectMsg(alias fn, Expected, Args...)(
	string message,
	Expected expected,
	Args args,
	string file = __FILE__,
	size_t line = __LINE__,
	string module_ = __MODULE__,
	string function_ = __FUNCTION__
) if (__traits(compiles, fn(args)))
{
	auto result = fn(args);

	static assert(is(typeof(result) == Expected),
		format("ncuiExpect: expected type must match the result type %s().", _fnName!fn));

	enforce(result == expected, format(
			"%s: %s() returned=%s expected=%s [%s:%s | %s | %s]",
			message, _fnName!fn, result, expected, file, line, module_, function_
	));

	return result;
}

/**
 * Вызывает `fn(args)` и проверяет, что результат не равен `ERR`.
 *
 * Требует, чтобы `fn` возвращала тот же тип, что и `ERR`.
 * При `ERR` бросает исключение с местом вызова.
 */
int ncuiNotErr(alias fn, Args...)(
	Args args,
	string file = __FILE__,
	size_t line = __LINE__,
	string module_ = __MODULE__,
	string function_ = __FUNCTION__
) if (__traits(compiles, fn(args)))
{
	auto result = fn(args);

	static assert(is(typeof(result) == typeof(ERR)),
		format("ncuiNotErr expects a function that returns an %s.", typeof(ERR)));

	enforce(result != ERR, format(
			"Function returned ERR: %s() [%s:%s | %s | %s]",
			_fnName!fn, file, line, module_, function_
	));

	return result;
}

/**
 * Вызывает `fn(args)` и проверяет, что результат (указатель) не `null`.
 *
 * При `null` бросает исключение с местом вызова.
 */
auto ncuiNotNull(alias fn, Args...)(
	Args args,
	string file = __FILE__,
	size_t line = __LINE__,
	string module_ = __MODULE__,
	string function_ = __FUNCTION__
) if (__traits(compiles, fn(args)))
{
	auto result = fn(args);

	static assert(isPointer!(typeof(result)),
		"ncuiNotNull expects a function that returns a pointer.");

	enforce(result !is null, format(
			"Function returned null: %s() [%s:%s | %s | %s]",
			_fnName!fn, file, line, module_, function_
	));
	return result;
}

private string errName(int code)
{
	switch (code)
	{
	case E_OK:
		return "E_OK";
	case E_SYSTEM_ERROR:
		return "E_SYSTEM_ERROR";
	case E_BAD_ARGUMENT:
		return "E_BAD_ARGUMENT";
	case E_POSTED:
		return "E_POSTED";
	case E_CONNECTED:
		return "E_CONNECTED";
	case E_BAD_STATE:
		return "E_BAD_STATE";
	case E_NO_ROOM:
		return "E_NO_ROOM";
	case E_NOT_POSTED:
		return "E_NOT_POSTED";
	case E_UNKNOWN_COMMAND:
		return "E_UNKNOWN_COMMAND";
	case E_NO_MATCH:
		return "E_NO_MATCH";
	case E_NOT_SELECTABLE:
		return "E_NOT_SELECTABLE";
	case E_NOT_CONNECTED:
		return "E_NOT_CONNECTED";
	case E_REQUEST_DENIED:
		return "E_REQUEST_DENIED";
	case E_INVALID_FIELD:
		return "E_INVALID_FIELD";
	case E_CURRENT:
		return "E_CURRENT";
	default:
		return format("E_?(%s)", code);
	}
}

/**
 * Вызывает функцию ncurses библиотек и строго проверяет успешность по коду возврата.
 *
 * Бросает исключение с местом вызова, если код возврата не равен `E_OK`.
 */
int ncuiLibNotErr(alias fn, Args...)(
	Args args,
	string file = __FILE__,
	size_t line = __LINE__,
	string module_ = __MODULE__,
	string function_ = __FUNCTION__
) if (__traits(compiles, fn(args)))
{
	static assert(is(typeof(fn(args)) == int),
		"ncuiLibNotErr: wrapped function must return int (ncurses libraries E_* codes).");

	const int result = fn(args);

	enforce(result == E_OK, format(
			"Function returned error: %s() result=%s(%s) expected=E_OK [%s:%s | %s | %s]",
			_fnName!fn, result, errName(result), file, line, module_, function_
	));

	return result;
}

/**
 * Вызывает функцию ncurses библиотек и проверяет, что код возврата входит в список допустимых.
 *
 * Бросает исключение с местом вызова, если код возврата не входит в список допустимых.
 */
int ncuiLibNotErrAny(alias fn, Allowed, Args...)(
	Allowed[] codes,
	Args args,
	string file = __FILE__,
	size_t line = __LINE__,
	string module_ = __MODULE__,
	string function_ = __FUNCTION__
) if (__traits(compiles, fn(args)))
{
	static assert(is(typeof(fn(args)) == int),
		"ncuiLibNotErrAny: wrapped function must return int (ncurses libraries E_* codes).");

	const int result = fn(args);

	bool match = false;

	foreach (code; codes)
	{
		if (result == code)
		{
			match = true;
			break;
		}
	}

	enforce(match, format(
			"Function returned error: %s() rc=%s(%s) allowed=%s [%s:%s | %s | %s]",
			_fnName!fn, result, errName(result), codes, file, line, module_, function_
	));

	return result;
}
