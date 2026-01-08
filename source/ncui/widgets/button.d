module ncui.widgets.button;

import ncui.widgets.widget;
import ncui.core.window;
import ncui.core.event;
import ncui.engine.screen;
import ncui.engine.action;

// Опциональное действие, выполняемое при нажатии на кнопку.
alias OnClick = ScreenAction delegate();

final class Button : IWidget
{
private:
	// Кнопка по умолчанию активна.
	bool _enabled = true;
	// Опциональная функция обратного вызова, при нажатии на кнопку.
	OnClick _onClick;
	// Координаты начала рисования кнопки.
	int _y;
	int _x;
	// Надпись кнопки.
	string _text;
public:
	this(int y, int x, string text, OnClick onClick = null)
	{
		_y = y;
		_x = x;
		_text = text;
		_onClick = onClick;
	}

	override @property bool focusable()
	{
		return true;
	}

	override @property bool enabled()
	{
		return _enabled;
	}

	override void render(Window window, ScreenContext context, bool focused)
	{
		window.put(_y, _x, focused ? "* " : "[ ");
		window.put(_y, _x + 2, _text);
		window.put(_y, _x + 2 + cast(int) _text.length, focused ? " *" : " ]");
	}

	override ScreenAction handle(ScreenContext context, KeyEvent event)
	{
		if (!_enabled)
			return ScreenAction.none();

		if (isEnter(event) || isSpace(event))
		{
			if (_onClick !is null)
				return _onClick();
			return ScreenAction.none();
		}

		return ScreenAction.none();
	}

	void onClick(OnClick callback)
	{
		_onClick = callback;
	}

	void setText(string text)
	{
		_text = text;
	}

	void setEnabled(bool enabled)
	{
		_enabled = enabled;
	}
}
