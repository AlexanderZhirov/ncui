/**
 * Контракты экранов (screen) и контекст выполнения.
 */
module ncui.engine.screen;

import ncui.core.session;
import ncui.core.event;
import ncui.core.ncwin;
import ncui.core.window;

import ncui.engine.action;

/**
 * Контекст выполнения экрана.
 */
struct ScreenContext
{
	Session session;

	this(Session s)
	{
		session = s;
	}
}

/**
 * Базовый интерфейс экрана.
 *
 * Правила:
 *  - `onShow` должен нарисовать экран.
 *  - `handle` обрабатывает ввод.
 *  - `inputWindow` говорит движку, из какого окна читать ввод.
 *  - `close` освобождает ресурс.
 */
interface IScreen
{
	// Вызывается движком, когда экран становится активным (оказался наверху стека)
	// или когда движок явно инициирует перерисовку (зависит от реализации).
	ScreenAction onShow(ScreenContext context);
	// Вызывается движком после закрытия дочернего экрана (Pop/PopTo),
	// чтобы передать родителю результат дочернего экрана.
	ScreenAction onChildResult(ScreenContext context, ScreenResult child);
	// Обработка события ввода.
	// Вызывается движком для активного экрана при получении события клавиатуры.
	ScreenAction handle(ScreenContext context, KeyEvent event);

	// Окно, из которого движок должен читать ввод для этого экрана.
	NCWin inputWindow();

	// Освобождение ресурсов экрана.
	void close();
}

// Интерфейс тега экрана.
interface ITaggedScreen
{
	int tag();
}

abstract class ScreenBase : IScreen
{
protected:
	Window _window;

public:
	override NCWin inputWindow()
	{
		return _window.handle();
	}

	override ScreenAction onShow(ScreenContext context)
	{
		return ScreenAction.none();
	}

	override ScreenAction onChildResult(ScreenContext context, ScreenResult child)
	{
		return ScreenAction.none();
	}

	override ScreenAction handle(ScreenContext context, KeyEvent event)
	{
		return ScreenAction.none();
	}

	override void close()
	{
		if (_window !is null)
			_window.close();
		_window = null;
	}
}
