module ncui.core.ncwin;

import deimos.ncurses;
import ncui.lib.checks;

private alias dc = deimos.ncurses;

struct NCWin
{
	WINDOW* _p;

	this(WINDOW* p)
	{
		_p = p;
	}

	@property WINDOW* ptr()
	{
		return _p;
	}

	alias ptr this;

	@property bool isNull() const
	{
		return _p is null;
	}

	void opAssign(NCWin rhs)
	{
		_p = rhs._p;
	}

	void opAssign(WINDOW* rhs)
	{
		_p = rhs;
	}

	/**
	* pw = parent_window,    // родительское окно
	* ch = child_height,     // высота дочернего окна
	* cw = child_width,      // ширина дочернего окна
	* sy = start_y,          // смещение по Y от начала родительского окна
	* sx = start_x           // смещение по X от начала родительского окна
	*/
	void derwin(NCWin pw, int ch, int cw, int sy, int sx)
	{
		_p = isNull ? ncuiNotNull!(dc.derwin)(pw, ch, cw, sy, sx) : _p;
	}

	void syncok()
	{
		if (isNull) return;

		ncuiNotErr!(dc.syncok)(_p, true);
	}

	void delwin()
	{
		if (isNull) return;

		ncuiLibNotErr!(dc.delwin)(_p);
		_p = null;
	}

	void werase()
	{
		if (isNull) return;

		ncuiNotErr!(dc.werase)(_p);
	}

	/**
	* sw = source_window,           // исходное окно
	* dw = destination_window,      // целевое окно
	* ssy = source_start_y,         // начальная строка в источнике
	* ssx = source_start_x,         // начальный столбец в источнике
	* dsy = destination_start_y,    // начальная строка в цели
	* dsx = destination_start_x,    // начальный столбец в цели
	* dey = destination_end_y,      // конечная строка в цели
	* dex = destination_end_x,      // конечный столбец в цели
	*/
	void copywin(WINDOW* sw, int ssy, int ssx, int dsy, int dsx, int dey, int dex)
	{
		if (isNull) return;

		ncuiNotErr!(dc.copywin)(sw, _p, ssy, ssx, dsy, dsx, dey, dex, 0);
	}

	void copywin(NCWin sw, int ssy, int ssx, int dsy, int dsx, int dey, int dex)
	{
		if (isNull) return;

		ncuiNotErr!(dc.copywin)(sw.ptr, _p, ssy, ssx, dsy, dsx, dey, dex, 0);
	}

	void wbkgd(int attr)
	{
		if (isNull) return;

		ncuiNotErr!(dc.wbkgd)(_p, attr);
	}

	void newpad(int height, int width)
	{
		_p = isNull ? ncuiNotNull!(dc.newpad)(height, width) : _p;
	}

	void wattron(int attr)
	{
		if (isNull) return;

		if (attr != 0)
		{
			ncuiNotErr!(dc.wattron)(_p, attr);
		}
	}

	void wattroff(int attr)
	{
		if (isNull) return;

		if (attr != 0)
		{
			ncuiNotErr!(dc.wattroff)(_p, attr);
		}
	}

	/**
	* target_window,              // целевое окно
	* cpy = cursor_position_y,    // новая позиция по вертикали (Y)
	* cpx = cursor_position_x     // новая позиция по горизонтали (X)
	*/
	void wmove(int cpy, int cpx)
	{
		if (isNull) return;

		ncuiNotErr!(dc.wmove)(_p, cpy, cpx);
	}

	/**
	* target_window,              // целевое окно
	* cpy = cursor_position_y,    // координата Y для курсора
	* cpx = cursor_position_x,    // координата X для курсора
	* ws = wide_string_to_add,    // строка широких символов для вывода
	* max_characters_count        // максимальное число символов для вывода
	*/
	void mvwaddnwstr(int cpy, int cpx, dstring ws)
	{
		if (isNull) return;

		ncuiNotErr!(dc.mvwaddnwstr)(_p, cpy, cpx, ws.ptr, cast(int) ws.length);
	}

	/**
	* target_window,                     // целевое окно
	* vl = vertical_line_character,      // символ для вертикальных линий
	* hl = horizontal_line_character     // символ для горизонтальных линий
	*/
	void box(int vl, int hl)
	{
		if (isNull) return;

		ncuiNotErr!(dc.box)(_p, vl, hl);
	}
}
