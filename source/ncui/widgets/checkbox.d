module ncui.widgets.checkbox;

import ncui.widgets.widget;
import ncui.core.event;
import ncui.core.window;
import ncui.engine.screen;
import ncui.engine.action;

alias OnChange = void delegate(bool checked);

final class Checkbox : IWidget
{
private:
	OnChange _onChange;
	int _y;
	int _x;
	string _label;
	bool _checked;
	bool _enabled = true;

	void notifyChange()
	{
		if (_onChange !is null)
		{
			_onChange(_checked);
		}
	}

public:
	this(int y, int x, string label, bool checked = false, OnChange onChange = null)
	{
		_y = y;
		_x = x;
		_label = label;
		_checked = checked;
		_onChange = onChange;
	}

	override @property bool focusable()
	{
		return true;
	}

	override @property bool enabled()
	{
		return _enabled;
	}

	void setChecked(bool checked)
	{
		if (_checked == checked)
		{
			return;
		}

		_checked = checked;
		notifyChange();
	}

	void toggle()
	{
		setChecked(!_checked);
	}

	void setEnabled(bool enabled)
	{
		_enabled = enabled;
	}

	void onChange(OnChange callback)
	{
		_onChange = callback;
	}

	override void render(Window window, ScreenContext context, bool focused)
	{
		const string mark = _checked ? "x" : " ";
		string checkbox = (focused ? "*" : "[") ~ mark ~ (focused ? "* " : "] ") ~ _label;
		window.put(_y, _x, checkbox);
	}

	override ScreenAction handle(ScreenContext context, KeyEvent event)
	{
		if (!_enabled)
		{
			return ScreenAction.none();
		}

		if (isEnter(event) || isSpace(event))
		{
			toggle();
			return ScreenAction.none();
		}

		return ScreenAction.none();
	}
}
