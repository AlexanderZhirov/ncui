module ncui.core.panel;

import ncui.core.ncpanel;
import ncui.core.ncwin;
import ncui.lib.checks;

import deimos.panel;

final class Panel
{
private:
	NCPanel _panel;

public:
	this(NCWin window)
	{
		_panel = NCPanel(ncuiNotNull!new_panel(window));
		// Сделать панель видимой.
		ncuiNotErr!show_panel(_panel);
		// Переместить панель наверх.
		ncuiNotErr!top_panel(_panel);
	}

	@property NCPanel handle()
	{
		return _panel;
	}

	void top()
	{
		if (!_panel.isNull())
		{
			ncuiNotErr!top_panel(_panel);
		}
	}

	void show()
	{
		if (!_panel.isNull())
		{
			ncuiNotErr!show_panel(_panel);
		}
	}

	void hide()
	{
		if (!_panel.isNull())
		{
			ncuiNotErr!hide_panel(_panel);
		}
	}

	void close()
	{
		if (_panel.isNull())
		{
			return;
		}

		ncuiNotErr!del_panel(_panel);
		_panel = NCPanel(null);
	}

	void update()
	{
		if (!_panel.isNull())
		{
			update_panels();
			ncuiNotErr!doupdate();
		}
	}

	~this()
	{
		close();
	}
}
