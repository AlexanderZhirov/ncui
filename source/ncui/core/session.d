module ncui.core.session;

import core.stdc.locale : setlocale, LC_ALL;
import std.exception : enforce;

import deimos.ncurses;

import ncui.core.ncwin;
import ncui.lib.common;

/**
 * Уровень видимости/типа курсора.
 *
 * - `hidden` — курсор скрыт.
 * - `normal` — обычный видимый курсор.
 * - `high`   — курсор повышенной заметности (зависит от терминала).
 */
enum Cursor : int
{
	/// Курсор скрыт.
	hidden = 0,
	/// Обычный курсор.
	normal = 1,
	/// Курсор повышенной заметности.
	high = 2,
}

/**
 * Режим обработки ввода терминалом.
 *
 * - `common` — канонический (построчный) режим — ввод приходит после Enter.
 * - `cbreak` — посимвольный режим — символы доступны сразу, но часть спец-клавиш/
 *              управляющих символов всё ещё может обрабатываться терминалом (сигналы).
 * - `raw`    — "сырой" посимвольный режим — минимальная обработка терминалом,
 *              управляющие символы обычно передаются программе как есть.
 */
enum InputMode
{
	/// Посимвольный ввод, часть обработки tty сохраняется.
	cbreak,
	/// Сырой посимвольный ввод с минимальной обработкой терминалом.
	raw,
	/// Канонический построчный ввод (поведение "как в обычной консоли").
	common
}

/**
 * Режим эхо терминала (отображение вводимых символов).
 *
 * Типичное соответствие ncurses:
 * - `on`  -> отображение вводимых символов.
 * - `off` -> скрытие вводимых символов.
 */
enum Echo
{
	/// Отображать вводимые символы.
	on,
	/// Скрывать вводимые символы.
	off
}

/**
 * Конфигурация терминальной сессии.
 *
 * Поля:
 * - `mode`   — режим ввода.
 * - `cursor` — видимость/тип курсора.
 * - `echo`   — отображать ли вводимые символы.
 */
struct SessionConfig
{
	/// Режим ввода терминала. По умолчанию `raw` (посимвольный ввод без обработки).
	InputMode mode = InputMode.raw;
	/// Режим курсора. По умолчанию виден (`normal`).
	Cursor cursor = Cursor.normal;
	/// Эхо ввода. По умолчанию отображает вводимые символы (`on`).
	Echo echo = Echo.on;
}

final class Session
{
private:
	NCWin _root;
	bool _ended;

	void setup(ref const(SessionConfig) config)
	{
		// Настройка режима обработки ввода терминалом.
		final switch (config.mode)
		{
		case InputMode.raw:
			ncuiCall!nocbreak(OK);
			ncuiCall!raw(OK);
			break;

		case InputMode.cbreak:
			ncuiCall!noraw(OK);
			ncuiCall!cbreak(OK);
			break;

		case InputMode.common:
			ncuiCall!noraw(OK);
			ncuiCall!nocbreak(OK);
			break;
		}
		// Настройка отображения вводимых символов.
		final switch (config.echo)
		{
		case Echo.on:
			ncuiCall!echo(OK);
			break;

		case Echo.off:
			ncuiCall!noecho(OK);
			break;
		}
	}

public:
	this(const SessionConfig config)
	{
		// Адекватное чтение юникода.
		setlocale(LC_ALL, "");
		_root = NCWin(ncuiNotNull!initscr());
		setup(config);
	}

	void close()
	{
		if (_ended)
			return;
		endwin();
		_ended = true;
	}

	~this()
	{
		close();
	}
}
