module ncui.lib.checks;

import std.traits : isCallable, isPointer;
import std.exception : enforce;
import std.format : format;

import deimos.ncurses : ERR;

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
) if (isCallable!fn && __traits(compiles, fn(args)))
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
) if (isCallable!fn && __traits(compiles, fn(args)))
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
) if (isCallable!fn && __traits(compiles, fn(args)))
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
) if (isCallable!fn && __traits(compiles, fn(args)))
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
