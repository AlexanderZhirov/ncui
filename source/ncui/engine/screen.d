/**
 * Контракты экранов (screen) и контекст выполнения.
 */
module ncui.engine.screen;

import ncui.core.session;
import ncui.core.event;
import ncui.core.ncwin;
import ncui.core.window;
import ncui.engine.theme;
import ncui.engine.action;

/**
 * Контекст выполнения экрана.
 */
struct ScreenContext
{
	Session session;
	ThemeManager themeManager;
	IThemeContext theme;

	this(Session s, ThemeManager tm)
	{
		session = s;
		themeManager = tm;
		theme = tm;
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
	// Вызывается движком, когда экран становится неактивным (оказался предыдущим в стеке).
	void onHide(ScreenContext context);
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

// Интерфейс динамического обновления содержимого.
interface IIdleScreen
{
	ScreenAction onTick(ScreenContext context);
	int tickMs() const;
}
