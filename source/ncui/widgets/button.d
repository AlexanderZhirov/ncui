module ncui.widgets.button;

import ncui.widgets.widget;
import ncui.core.window;
import ncui.core.event;
import ncui.engine.screen;
import ncui.engine.action;
import ncui.engine.theme;

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
	string _decor;
	int _width;
public:
	this(int y, int x, string text, OnClick onClick = null)
	{
		_y = y;
		_x = x;
		_text = text;
		_decor = "[ " ~ text ~ " ]";
		_width = cast(int) _decor.length;
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
		StyleId sid;

		if (!_enabled)
		{
			sid = StyleId.ButtonInactive;
		}
		else if (focused)
		{
			sid = StyleId.ButtonActive;
		}
		else
		{
			sid = StyleId.Button;
		}

		window.putAttr(_y, _x, _decor, context.theme.attr(sid));
	}

	override ScreenAction handle(ScreenContext context, KeyEvent event)
	{
		if (!_enabled)
		{
			return ScreenAction.none();
		}

		if (isEnter(event) || isSpace(event))
		{
			if (_onClick !is null)
			{
				return _onClick();
			}
			return ScreenAction.none();
		}

		return ScreenAction.none();
	}

	@property int width()
	{
		return _width;
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
