module ncui.lib.common;

import std.traits : isCallable;
import std.exception : enforce;
import std.format : format;

import deimos.ncurses : OK;

/**
 * Вызывает функцию `fn`, проверяет её результат на равенство ожидаемому значению
 * и при несоответствии бросает исключение с подробным сообщением и местом вызова.
 *
 * Параметры шаблона:
 * - `fn`        — вызываемая функция.
 * - `Expected`  — тип ожидаемого значения `answer`.
 * - `Args...`   — типы аргументов, которые будут переданы в `fn`.
 *
 * Параметры:
 * - `answer`    — ожидаемое значение результата функции `fn`.
 * - `message`   — пользовательское сообщение (контекст ошибки) (по умолчанию подставляется "Function call error").
 * - `file`      — файл места вызова (по умолчанию подставляется `__FILE__`).
 * - `line`      — строка места вызова (по умолчанию подставляется `__LINE__`).
 * - `module_`   — модуль места вызова (по умолчанию подставляется `__MODULE__`).
 * - `function_` — функция места вызова (по умолчанию подставляется `__FUNCTION__`).
 * - `args`      — аргументы, которые будут переданы в `fn`.
 *
 * Возвращает:
 * Возвращает фактический результат вызова `fn(args)` (тот же тип, что и у `fn`).
 *
 * Исключения:
 * Бросает `Exception`, если `fn(args)` вернул значение, отличающееся от `answer`.
 */
auto ncuiCall(alias fn, Expected, Args...)(
	Expected answer,
	string message = "Function returned an error",
	string file = __FILE__,
	size_t line = __LINE__,
	string module_ = __MODULE__,
	string function_ = __FUNCTION__,
	Args args) if (isCallable!fn)
{
	auto result = fn(args);

	enforce(result == answer, new Exception(
			format("%s: %s() returned=%s expected=%s [%s:%s | %s | %s]",
			message, __traits(identifier, fn), result, answer, file, line, module_, function_)
	));

	return result;
}

/**
 * Вызывает функцию `fn`, которая должна вернуть ненулевой указатель, и проверяет,
 * что результат не `null`.
 *
 * Параметры шаблона:
 * - `fn`      — вызываемая функция (передаётся как `alias`, определяется на этапе компиляции).
 * - `Args...` — типы аргументов, которые будут переданы в `fn`.
 *
 * Параметры:
 * - `file`      — файл места вызова (по умолчанию подставляется `__FILE__`).
 * - `line`      — строка места вызова (по умолчанию подставляется `__LINE__`).
 * - `module_`   — модуль места вызова (по умолчанию подставляется `__MODULE__`).
 * - `function_` — функция места вызова (по умолчанию подставляется `__FUNCTION__`).
 * - `args`      — аргументы, передаваемые в `fn`.
 *
 * Возвращает:
 * Возвращает результат `fn(args)` (ожидается указатель), если он не `null`.
 *
 * Исключения:
 * Бросает `Exception`, если `fn(args)` вернул `null`.
 */
auto ncuiNotNull(alias fn, Args...)(
	string file = __FILE__,
	size_t line = __LINE__,
	string module_ = __MODULE__,
	string function_ = __FUNCTION__,
	Args args
) if (isCallable!fn)
{
	auto result = fn(args);

	enforce(result !is null, new Exception(
			format("%s() returned null [%s:%s | %s | %s]",
			__traits(identifier, fn), file, line, module_, function_)
	));

	return result;
}
