module ncui.core.ncform;

import deimos.form;

import ncui.core.ncwin;
import ncui.lib.checks;
import ncui.lib.logger;

import std.string : toStringz;

private alias df = deimos.form;

struct NCField
{
	FIELD* _p;

	this(FIELD* p)
	{
		_p = p;
	}

	@property FIELD* ptr()
	{
		return _p;
	}

	alias ptr this;

	@property bool isNull() const
	{
		return _p is null;
	}

	void opAssign(NCField rhs)
	{
		_p = rhs._p;
	}

	void opAssign(FIELD* rhs)
	{
		_p = rhs;
	}

	/*
	* fr = field_rows,                    // высота поля (количество строк)
	* fc = field_cols,                    // ширина поля (количество столбцов)
	* ftr = field_top_row,                 // начальная строка на экране (Y)
	* flc = field_left_col,                // начальный столбец на экране (X)
	* nsr = number_off_screen_rows,        // количество строк вне экрана (для прокрутки)
	* nab = number_of_additional_buffers   // количество дополнительных буферов
	*/
	void newfield(int fr, int fc, int ftr, int flc, int nsr, int nab)
	{
		_p = isNull ? ncuiNotNull!(df.new_field)(fr, fc, ftr, flc, nsr, nab) : _p;
	}

	void setfieldopts(int opts)
	{
		ncuiLibNotErr!(df.set_field_opts)(_p, opts);
	}

	void fieldoptsoff(int opts)
	{
		ncuiLibNotErr!(df.field_opts_off)(_p, opts);
	}

	void fieldoptson(int opts)
	{
		ncuiLibNotErr!(df.field_opts_on)(_p, opts);
	}

	void setfieldbuffer(string text)
	{
		ncuiLibNotErr!(df.set_field_buffer)(_p, 0, text.toStringz);
	}

	void setmaxfield(int size)
	{
		ncuiLibNotErr!(df.set_max_field)(_p, size);
	}

	void setfieldfore(int attr)
	{
		ncuiLibNotErr!(df.set_field_fore)(_p, attr);
	}

	void setfieldback(int attr)
	{
		ncuiLibNotErr!(df.set_field_back)(_p, attr);
	}

	void freefield()
	{
		if (isNull) return;

		ncuiLibNotErr!(df.free_field)(_p);
		_p = null;
	}
}

struct NCForm
{
	FORM* _p;
	// private FIELD*[] _fields;

	this(FORM* p)
	{
		_p = p;
	}

	@property FORM* ptr()
	{
		return _p;
	}

	alias ptr this;

	@property bool isNull() const
	{
		return _p is null;
	}

	void opAssign(NCForm rhs)
	{
		_p = rhs._p;
	}

	void opAssign(FORM* rhs)
	{
		_p = rhs;
	}

	void newform(NCField[] fields)
	{
		_p = isNull ? ncuiNotNull!(df.new_form)(cast(FIELD**) fields) : _p;
	}

	int formdriverw(int command, dchar wc, int[] code = [])
	{
		if (code.length > 0)
		{
			return ncuiLibNotErrAny!(df.form_driver_w)(code, _p, command, wc);
		}
		else
		{
			return ncuiLibNotErr!(df.form_driver_w)(_p, command, wc);
		}
	}

	void setformwin(NCWin window)
	{
		ncuiLibNotErr!(df.set_form_win)(_p, window);
	}

	void setformsub(NCWin window)
	{
		ncuiLibNotErr!(df.set_form_sub)(_p, window);
	}

	void postform()
	{
		ncuiLibNotErrAny!(df.post_form)([E_OK, E_POSTED], _p);
	}

	void posformcursor()
	{
		ncuiLibNotErr!(df.pos_form_cursor)(_p);
	}

	void setcurrentfield(NCField field)
	{
		ncuiLibNotErrAny!(df.set_current_field)([E_OK, E_CURRENT], _p, field);
	}

	void unpostform()
	{
		if (isNull) return;

		ncuiLibNotErrAny!(df.unpost_form)([E_OK, E_NOT_POSTED], _p);
	}

	void freeform()
	{
		if (isNull) return;

		ncuiLibNotErr!(df.free_form)(_p);
		_p = null;
	}
}
