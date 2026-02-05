module ncui.core.ncmenu;

import deimos.menu;

import ncui.lib.checks;
import ncui.core.ncwin;

import std.string : toStringz;

private alias dm = deimos.menu;

struct NCItem
{
	ITEM* _p;

	this(ITEM* p)
	{
		_p = p;
	}

	@property ITEM* ptr()
	{
		return _p;
	}

	alias ptr this;

	@property bool isNull() const
	{
		return _p is null;
	}

	void opAssign(NCItem rhs)
	{
		_p = rhs._p;
	}

	void opAssign(ITEM* rhs)
	{
		_p = rhs;
	}

	void newitem(string label, string description)
	{
		_p = isNull ? ncuiNotNull!(dm.new_item)(label.toStringz, description.toStringz) : _p;
	}

	int itemindex()
	{
		return dm.item_index(_p);
	}

	void freeitem()
	{
		if (isNull) return;

		ncuiLibNotErr!(dm.free_item)(_p);
		_p = null;
	}
}

struct NCMenu
{
	MENU* _p;

	this(MENU* p)
	{
		_p = p;
	}

	@property MENU* ptr()
	{
		return _p;
	}

	alias ptr this;

	@property bool isNull() const
	{
		return _p is null;
	}

	void opAssign(NCMenu rhs)
	{
		_p = rhs._p;
	}

	void opAssign(MENU* rhs)
	{
		_p = rhs;
	}

	void newmenu(NCItem[] items)
	{
		_p = isNull ? ncuiNotNull!new_menu(cast(ITEM**) items) : _p;
	}

	void setmenuwin(NCWin window)
	{
		ncuiLibNotErr!(dm.set_menu_win)(_p, window);
	}

	void setmenusub(NCWin window)
	{
		ncuiLibNotErr!(dm.set_menu_sub)(_p, window);
	}

	/*
	* rc = rows_count,  // количество строк
	* cc = cols_count   // количество колонок
	*/
	void setmenuformat(int rc, int cc)
	{
		ncuiLibNotErr!(dm.set_menu_format)(_p, rc, cc);
	}

	void setmenumark(string mark)
	{
		ncuiLibNotErr!(dm.set_menu_mark)(_p, mark.toStringz);
	}

	int menudriver(int command, int[] code = [])
	{
		if (code.length > 0)
		{
			return ncuiLibNotErrAny!(dm.menu_driver)([E_OK, E_REQUEST_DENIED], _p, command);
		}
		else
		{
			return ncuiLibNotErr!(dm.menu_driver)(_p, command);
		}
	}

	void setmenuback(int attr)
	{
		ncuiLibNotErr!(dm.set_menu_back)(_p, attr);
	}

	void setmenufore(int attr)
	{
		ncuiLibNotErr!(dm.set_menu_fore)(_p, attr);
	}

	void setmenugrey(int attr)
	{
		ncuiLibNotErr!(dm.set_menu_grey)(_p, attr);
	}

	void postmenu()
	{
		ncuiLibNotErrAny!(dm.post_menu)([E_OK, E_POSTED], _p);
	}

	NCItem currentitem()
	{
		return NCItem(dm.current_item(_p));
	}

	void unpostmenu()
	{
		if (isNull) return;

		ncuiLibNotErrAny!(dm.unpost_menu)([E_OK, E_NOT_POSTED], _p);
	}

	void freemenu()
	{
		if (isNull) return;

		ncuiLibNotErr!(dm.free_menu)(_p);
		_p = null;
	}
}
