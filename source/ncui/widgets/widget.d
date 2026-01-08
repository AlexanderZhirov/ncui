module ncui.widgets.widget;

import ncui.core.window;
import ncui.core.event;
import ncui.engine.screen;
import ncui.engine.action;

/**
 * Базовый интерфейс виджета.
 */
interface IWidget
{
	// Можно ли на него поставить фокус.
	@property bool focusable();

	// Активен ли виджет.
	@property bool enabled();

	// Отрисовка.
	void render(Window window, ScreenContext context, bool focused);

	// Ввод.
	ScreenAction handle(ScreenContext context, KeyEvent event);
}

// Обработка стандартных нажатий клавиш.

bool isTab(KeyEvent ev)
{
	return ev.isChar && ev.ch == '\t';
}

bool isEnter(KeyEvent ev)
{
	if (ev.isChar && (ev.ch == '\n' || ev.ch == '\r')) return true;
	if (ev.isKeyCode && cast(int)ev.ch == 343) return true; // KEY_ENTER часто 343
	return false;
}

bool isSpace(KeyEvent ev)
{
	return ev.isChar && ev.ch == ' ';
}
