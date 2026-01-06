module ncui.core.session;

import core.stdc.locale : setlocale, LC_ALL;

import deimos.ncurses;

import ncui.core.ncwin;
import ncui.lib.checks;
import ncui.core.event;

/**
 * Глобальный флаг инициализации ncurses для всего процесса.
 *
 * Хранит "истину" о том, выполнялась ли успешная инициализация (`initscr()`).
 * Используется для защиты от повторной инициализации и для быстрых проверок
 * перед вызовами функций, требующих активной ncurses-сессии.
 */
private __gshared bool gInitialized;

/**
 * Проверяет, была ли ncurses-сессия уже инициализирована в текущем процессе.
 *
 * Возвращает:
 * `true`, если ранее была выполнена успешная инициализация (и был поднят `gInitialized`),
 * иначе `false`.
 */
bool cursesInitialized() @nogc nothrow
{
	return gInitialized;
}

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
 * - `cooked` — канонический (построчный) режим — ввод приходит после Enter.
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
	cooked
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
 * Режим обработки специальных клавиш в ncurses (`keypad`).
 *
 * Когда режим включён, ncurses преобразует специальные клавиши (стрелки, Home/End,
 * PgUp/PgDn, F1..F12 и т.п.) в коды `KEY_*`, которые удобно обрабатывать в программе.
 * Когда выключён — многие такие клавиши приходят как последовательности символов
 * (escape-последовательности), и их приходится разбирать вручную.
  */
enum Keypad : bool
{
	/// Включить обработку специальных клавиш (`KEY_*`).
	on = true,
	/// Выключить обработку специальных клавиш.
	off = false
}

/**
 * Конфигурация терминальной сессии.
 *
 * Поля:
 * - `mode`     — режим ввода.
 * - `cursor`   — видимость/тип курсора.
 * - `echo`     — отображать ли вводимые символы.
 * - `keypad`   — включение обработки специальных клавиш (стрелки, F-клавиши → `KEY_*`).
 * - `escDelay` — задержка (в миллисекундах) для различения одиночного `Esc` и
 *                escape-последовательностей (стрелки и т.п.). Обычно 0..50 для
 *                отзывчивого UI; слишком маленькое значение может повлиять на
 *                корректность распознавания некоторых клавиш в отдельных терминалах.
 */
struct SessionConfig
{
	/// Режим ввода терминала. По умолчанию `raw` (посимвольный ввод без обработки).
	InputMode mode = InputMode.raw;
	/// Режим курсора. По умолчанию виден (`normal`).
	Cursor cursor = Cursor.normal;
	/// Эхо ввода. По умолчанию отображает вводимые символы (`on`).
	Echo echo = Echo.on;
	/// Обработка специальных клавиш (стрелки, Home/End, PgUp/PgDn, F1..F12 → `KEY_*`).
	Keypad keypad = Keypad.on;
	/// Задержка распознавания ESC/escape-последовательностей в миллисекундах.
	int escDelay = 50;
}

/**
 * Терминальная сессия ncurses.
 */
final class Session
{
private:
	NCWin _root;
	bool _ended;

	// Применяет параметры конфигурации к активной ncurses-сессии.
	void setup(ref const(SessionConfig) config)
	{
		// Настройка режима обработки ввода терминалом.
		final switch (config.mode)
		{
		case InputMode.raw:
			ncuiNotErr!nocbreak();
			ncuiNotErr!raw();
			break;

		case InputMode.cbreak:
			ncuiNotErr!noraw();
			ncuiNotErr!cbreak();
			break;

		case InputMode.cooked:
			ncuiNotErr!noraw();
			ncuiNotErr!nocbreak();
			break;
		}
		// Настройка отображения вводимых символов.
		final switch (config.echo)
		{
		case Echo.on:
			ncuiNotErr!echo();
			break;

		case Echo.off:
			ncuiNotErr!noecho();
			break;
		}
		// Настройка видимости курсора.
		ncuiNotErr!curs_set(config.cursor);
		// Настройка задержки при нажатии на ESC
		ncuiNotErr!set_escdelay(config.escDelay);
		// Настройка обработки специальных клавиш
		ncuiNotErr!keypad(_root, config.keypad);
	}

public:
	this(const SessionConfig config)
	{
		// Если на этапе инициализации сработает проблема с конфигурированием сессии
		scope (failure)
		{
			if (cursesInitialized()) {
				endwin();
				gInitialized = false;
			}
		}

		// ncurses не должен быть инициализирован (false)
		ncuiExpectMsg!cursesInitialized("ncurses is already initialized", false);
		// Корректное чтение юникода.
		setlocale(LC_ALL, "");
		_root = NCWin(ncuiNotNull!initscr());

		// Установить флаг инициализации ncurses
		gInitialized = true;
		// Применение конфигурации
		setup(config);
	}

	NCWin root()
	{
		return _root;
	}

	KeyEvent readKey(NCWin inputWindow)
	{
		dchar ch;
		int status = wget_wch(inputWindow, &ch);
		return KeyEvent(status, ch);
	}

	void clear()
	{
		// Очищает окно.
		ncuiNotErr!erase();
		// Обновляет экран, выводя содержимое виртуального экрана на физический.
		ncuiNotErr!refresh();
	}

	void close()
	{
		if (_ended)
			return;
		endwin();
		_ended = true;
		gInitialized = false;
	}

	~this()
	{
		close();
	}
}
