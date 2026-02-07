module ncui.widgets.listbox;

import deimos.ncurses;

import ncui.widgets.widget;
import ncui.core.ncwin;
import ncui.core.window;
import ncui.core.event;
import ncui.engine.screen;
import ncui.engine.action;
import ncui.engine.theme;
import ncui.lib.checks;
import ncui.lib.wrap;

import std.utf : toUTF32, toUTF8;

alias AcceptResultCallback = ScreenAction delegate(size_t index, string value);

final class ListBox : IWidget, IWidgetClosable
{
private:
	// Флаг доступности виджета (влияет на обработку/стили).
	bool _enabled;

	int _y;
	int _x;
	int _width;
	int _height;

	bool _border;
	bool _inited;
	bool _hscroll;

	// Исходные элементы списка.
	dstring[] _items;
	// Индекс выбранного элемента в _items.
	size_t _selected;
	// Верхняя видимая "виртуальная строка" (индекс в _lines).
	int _topLine;
	// Левый сдвиг по X в "колонках" терминала (cells) для hscroll.
	int _leftCell;
	// Развёрнутые "виртуальные строки" для рендера (wrap или 1:1 при hscroll).
	dstring[] _lines;
	// Маппинг: индекс строки _lines -> индекс элемента _items.
	size_t[] _lineToItem;
	// Стартовая строка в _lines для каждого item.
	int[] _itemStartLine;
	// Количество строк в _lines для каждого item.
	int[] _itemLineCount;
	// Максимальная ширина строки (в cells) среди _lines (для clamp горизонтали и ширины pad).
	int _maxLineCells;
	// Флаг: требуется пересчитать _lines и маппинги.
	bool _layoutDirty = true;

	NCWin _windowBorder;
	NCWin _window;
	NCWin _pad;

	// Флаг: требуется пересобрать pad полностью (данные/размер/стили).
	bool _padDirty = true;

	// Последний "обычный" атрибут строк (для отслеживания смены темы/enable).
	int _lastAttrNormal = int.min;
	// Последний атрибут выделения (для отслеживания смены фокуса/темы).
	int _lastAttrSelected = int.min;
	// Последний выбранный индекс, уже "прорисованный" в pad.
	size_t _lastSelected = size_t.max;

	AcceptResultCallback _accept;

	// Внутренняя ширина (минус рамка).
	int innerWidth()
	{
		return _border ? _width - 2 : _width;
	}

	// Внутренняя высота (минус рамка).
	int innerHeight()
	{
		return _border ? _height - 2 : _height;
	}

	// Создать/пересоздать дочерние окна (_windowBorder/_window).
	void ensureWindows(Window window)
	{
		_windowBorder.derwin(window.handle(), _height, _width, _y, _x);
		_windowBorder.syncok();

		const int ih = innerHeight();
		const int iw = innerWidth();

		const int offY = _border ? 1 : 0;
		const int offX = _border ? 1 : 0;

		_window.derwin(_windowBorder, ih, iw, offY, offX);
		_window.syncok();
	}

	// Ленивая инициализация окон и стартовых параметров скролла/выбора.
	void ensureCreated(Window window)
	{
		if (_inited)
		{
			return;
		}

		ensureWindows(window);

		_selected = 0;
		_topLine = 0;
		_leftCell = 0;

		_inited = true;
	}

	// Нарисовать рамку и применить стиль рамки.
	void applyTheme(ScreenContext context, bool focused)
	{
		if (_border)
		{
			const int battr = context.theme.attr(focused ? StyleId.BorderActive : StyleId.BorderInactive);
			_windowBorder.boxattr(0, 0, battr);
		}
	}

	// Выбрать атрибут строки по enabled/focus/selected.
	int itemAttr(ScreenContext context, bool focused, bool selected)
	{
		if (!_enabled)
		{
			return context.theme.attr(StyleId.ListBoxItemInactive);
		}

		if (selected)
		{
			return context.theme.attr(focused ? StyleId.ListBoxItemActive : StyleId.ListBoxItemSelect);
		}

		return context.theme.attr(StyleId.ListBoxItem);
	}

	// Общее количество виртуальных строк для рендера.
	int totalLines()
	{
		return cast(int) _lines.length;
	}

	// Высота pad (минимум innerHeight, чтобы copywin не упирался в размер источника).
	int padHeight()
	{
		int h = totalLines();
		if (h < 1) h = 1;

		const int ih = innerHeight();
		if (ih > h) h = ih;

		return h;
	}

	// Ширина pad (минимум innerWidth, чтобы copywin не упирался в размер источника).
	int padWidth()
	{
		int w = _maxLineCells;
		if (w < 1) w = 1;

		const int iw = innerWidth();
		if (iw > w) w = iw;

		return w;
	}

	// Максимально допустимое значение _topLine (по высоте окна).
	int maxTopLine()
	{
		const int m = totalLines() - innerHeight();
		return (m > 0) ? m : 0;
	}

	// Максимально допустимое значение _leftCell (по ширине окна, только для hscroll).
	int maxLeftCell()
	{
		if (!_hscroll)
		{
			return 0;
		}

		const int m = _maxLineCells - innerWidth();
		return (m > 0) ? m : 0;
	}

	// Ограничить _topLine/_leftCell допустимыми границами.
	void clampScroll()
	{
		if (_topLine < 0) _topLine = 0;
		const int mt = maxTopLine();
		if (_topLine > mt) _topLine = mt;

		if (_leftCell < 0) _leftCell = 0;
		const int ml = maxLeftCell();
		if (_leftCell > ml) _leftCell = ml;
	}

	// Подогнать _topLine так, чтобы выбранный элемент был видим на странице.
	void ensureSelectedVisible()
	{
		if (_items.length == 0 || _selected >= _items.length)
		{
			_topLine = 0;
			return;
		}

		const int ih = innerHeight();
		if (ih <= 0)
		{
			_topLine = 0;
			return;
		}

		const int start = _itemStartLine[_selected];
		const int count = _itemLineCount[_selected] > 0 ? _itemLineCount[_selected] : 1;
		const int end = start + count - 1;

		if (start < _topLine)
		{
			_topLine = start;
		}
		else if (end >= _topLine + ih)
		{
			_topLine = end - ih + 1;
		}

		clampScroll();
	}

	// Пересчитать _lines/_lineToItem и статистику ширины по текущему режиму и ширине.
	void rebuildLayout()
	{
		_layoutDirty = false;

		_lines.length = 0;
		_lineToItem.length = 0;

		_itemStartLine.length = _items.length;
		_itemLineCount.length = _items.length;

		_maxLineCells = 0;

		const int iw = innerWidth();

		if (_items.length == 0)
		{
			_topLine = 0;
			_leftCell = 0;

			_padDirty = true;
			_lastSelected = size_t.max;
			return;
		}

		int lineIndex = 0;

		foreach (i, item; _items)
		{
			_itemStartLine[i] = lineIndex;

			if (_hscroll)
			{
				// 1 элемент = 1 виртуальная строка (без переносов).
				_lines ~= item;
				_lineToItem ~= i;

				_itemLineCount[i] = 1;
				lineIndex += 1;

				const int w = widthCells(item);
				if (w > _maxLineCells) _maxLineCells = w;
			}
			else
			{
				// Перенос по словам (если пусто — всё равно 1 строка).
				dstring[] parts;

				if (item.length == 0)
				{
					parts = [dstring.init];
				}
				else
				{
					parts = wrapWordsWide(item, iw);
					if (parts.length == 0)
					{
						parts = [dstring.init];
					}
				}

				_itemLineCount[i] = cast(int) parts.length;

				foreach (p; parts)
				{
					_lines ~= p;
					_lineToItem ~= i;
					lineIndex += 1;

					const int w = widthCells(p);
					if (w > _maxLineCells) _maxLineCells = w;
				}

				// В wrap-режиме горизонталь выключена, но pad пусть будет >= iw.
				if (iw > _maxLineCells) _maxLineCells = iw;
			}
		}

		if (_maxLineCells < 0) _maxLineCells = 0;

		if (_selected >= _items.length)
		{
			_selected = cast(int) _items.length - 1;
		}

		_padDirty = true;
		_lastSelected = size_t.max;
	}

	// Перерисовать один "виртуальный" ряд pad: залить фон и нарисовать текст.
	void redrawPadRow(int row, dstring line, int attr)
	{
		const int pw = padWidth();

		_pad.wattron(attr);
		scope (exit) _pad.wattroff(attr);

		_pad.mvwhline(row, 0, attr, pw);

		if (line.length == 0)
		{
			_pad.wmove(row, 0);
		}
		else
		{
			_pad.mvwaddnwstr(row, 0, line);
		}
	}

	// Перерисовать все строки конкретного item в pad заданным атрибутом.
	void redrawItemOnPad(size_t itemIndex, int attr)
	{
		if (_pad.isNull || _items.length == 0 || itemIndex >= _items.length)
		{
			return;
		}

		const int start = _itemStartLine[itemIndex];
		int count = _itemLineCount[itemIndex];
		if (count <= 0) count = 1;

		for (int k = 0; k < count; ++k)
		{
			const int row = start + k;
			if (row < 0 || row >= _lines.length)
			{
				break;
			}

			redrawPadRow(row, _lines[row], attr);
		}
	}

	// Создать/обновить pad: полный пересборка только когда надо, иначе — точечно по выделению.
	void ensurePad(ScreenContext context, bool focused)
	{
		const int normalAttr = itemAttr(context, false, false);
		const int selectedAttr = itemAttr(context, focused, true);

		if (_pad.isNull)
		{
			_padDirty = true;
		}

		if (normalAttr != _lastAttrNormal)
		{
			_padDirty = true;
		}

		// Полная пересборка pad (данные/размеры/обычный стиль).
		if (_padDirty)
		{
			_padDirty = false;

			_pad.delwin();
			_pad.newpad(padHeight(), padWidth());

			_pad.wbkgd(normalAttr);
			_pad.werase();

			for (int row = 0; row < _lines.length; ++row)
			{
				const size_t itemIndex = _lineToItem.length ? _lineToItem[row] : 0;
				const bool isSel = (_items.length != 0) && (itemIndex == _selected);

				const int attr = isSel ? selectedAttr : normalAttr;
				redrawPadRow(row, _lines[row], attr);
			}

			_lastAttrNormal = normalAttr;
			_lastAttrSelected = selectedAttr;
			_lastSelected = _selected;
			return;
		}

		// Точечное обновление: изменился фокус (а значит стиль выделения) или сам selected.
		if (_items.length && (_selected != _lastSelected || selectedAttr != _lastAttrSelected))
		{
			// Снять выделение со старого item.
			if (_lastSelected != size_t.max && _lastSelected < _items.length)
			{
				redrawItemOnPad(_lastSelected, normalAttr);
			}

			// Нарисовать выделение на новом item.
			if (_selected < _items.length)
			{
				redrawItemOnPad(_selected, selectedAttr);
			}

			_lastAttrSelected = selectedAttr;
			_lastSelected = _selected;
		}
	}

	// Скопировать видимую область pad в внутреннее окно (_window).
	void blitPadToWindow()
	{
		const int ih = innerHeight();
		const int iw = innerWidth();

		_window.werase();

		if (_pad.isNull || ih <= 0 || iw <= 0)
		{
			return;
		}

		_window.copywin(_pad, _topLine, _leftCell, 0, 0, ih - 1, iw - 1);
	}

	// Отрисовать список через pad и скопировать видимую область в _window.
	void renderContent(ScreenContext context, bool focused)
	{
		ensurePad(context, focused);
		blitPadToWindow();
	}

	// Сдвинуть выбор на delta элементов вверх/вниз с clamp по границам.
	bool moveSelectionDelta(int delta)
	{
		if (_items.length == 0 || delta == 0)
		{
			return false;
		}

		const long cur = cast(long) _selected;
		long next = cur + delta;

		if (next < 0) next = 0;
		if (next >= cast(long) _items.length) next = cast(long) _items.length - 1;

		if (cast(size_t) next == _selected)
		{
			return false;
		}

		_selected = cast(size_t) next;
		return true;
	}

	// Шаг страницы для PgUp/PgDn.
	int pageStep()
	{
		const h = innerHeight();
		return (h > 1) ? (h - 1) : 1;
	}

	// Переместиться на страницу вверх/вниз и выбрать крайний видимый элемент.
	bool pageMove(int deltaPages)
	{
		if (_lines.length == 0 || deltaPages == 0)
		{
			return false;
		}

		const int ih = innerHeight();
		if (ih <= 0)
		{
			return false;
		}

		const int oldTop = _topLine;
		const size_t oldSel = _selected;

		const int step = pageStep();
		_topLine += deltaPages * step;

		clampScroll();

		if (_lineToItem.length > 0)
		{
			// PgDn -> последний видимый, PgUp -> первый видимый.
			if (deltaPages > 0)
			{
				int lastLine = _topLine + ih - 1;
				if (lastLine >= totalLines()) lastLine = totalLines() - 1;
				if (lastLine < 0) lastLine = 0;

				_selected = _lineToItem[lastLine];
			}
			else
			{
				int firstLine = _topLine;
				if (firstLine < 0) firstLine = 0;
				if (firstLine >= totalLines()) firstLine = totalLines() - 1;

				_selected = _lineToItem[firstLine];
			}
		}

		ensureSelectedVisible();

		return (_topLine != oldTop) || (_selected != oldSel);
	}

	// Прокрутить по X на deltaCells колонок (только в _hscroll режиме).
	bool hscrollBy(int deltaCells)
	{
		if (!_hscroll || deltaCells == 0)
		{
			return false;
		}

		const int old = _leftCell;
		_leftCell += deltaCells;
		clampScroll();
		return _leftCell != old;
	}

public:
	this(int y, int x, int w, int h,
		string[] items = null,
		AcceptResultCallback accept = null,
		bool border = true,
		bool enabled = true,
		bool hscroll = false)
	{
		if (border)
		{
			ncuiExpectMsg!((int v) => v >= 3)("List.width must be >= 3 when border=true", true, w);
			ncuiExpectMsg!((int v) => v >= 3)("List.height must be >= 3 when border=true", true, h);
		}
		else
		{
			ncuiExpectMsg!((int v) => v > 0)("List.width must be > 0", true, w);
			ncuiExpectMsg!((int v) => v > 0)("List.height must be > 0", true, h);
		}

		_y = y;
		_x = x;
		_width = w;
		_height = h;

		_border = border;
		_enabled = enabled;

		_accept = accept;
		_hscroll = hscroll;

		setItems(items);
	}

	override @property bool focusable()
	{
		return true;
	}

	override @property bool enabled()
	{
		return _enabled;
	}

	void setEnabled(bool e)
	{
		if (_enabled == e)
		{
			return;
		}

		_enabled = e;

		_padDirty = true;
	}

	@property int width()
	{
		return _width;
	}

	@property int height()
	{
		return _height;
	}

	// Получить индекс выбранного элемента.
	@property size_t selectedIndex()
	{
		return _selected;
	}

	// Получить выбранное значение или пустую строку.
	string selectedValue()
	{
		if (_items.length == 0 || _selected >= _items.length)
		{
			return string.init;
		}

		return _items[_selected].toUTF8;
	}

	// Установить выбранный индекс (без скролла), вернуть true если изменилось.
	bool setSelected(size_t index)
	{
		if (_items.length == 0)
		{
			_selected = 0;
			return false;
		}

		if (index >= _items.length)
		{
			return false;
		}

		if (_selected == index)
		{
			return false;
		}

		_selected = index;

		if (_inited)
		{
			if (_layoutDirty)
			{
				rebuildLayout();
			}

			ensureSelectedVisible();
		}

		return true;
	}

	// Включить/выключить горизонтальную прокрутку и пометить.
	void setHorizontalScroll(bool enabled)
	{
		if (_hscroll == enabled)
		{
			return;
		}

		_hscroll = enabled;
		_leftCell = 0;

		_layoutDirty = true;
		_padDirty = true;
		_lastSelected = size_t.max;
	}

	// Получить текущее состояние горизонтальной прокрутки.
	@property bool horizontalScroll() const
	{
		return _hscroll;
	}

	// Задать элементы списка.
	void setItems(string[] items)
	{
		_items.length = 0;

		if (items.length)
		{
			_items.length = items.length;

			foreach (i, s; items)
			{
				_items[i] = s.toUTF32;
			}
		}

		_selected = 0;
		_topLine = 0;
		_leftCell = 0;

		_layoutDirty = true;
		_padDirty = true;
		_lastSelected = size_t.max;
	}

	void onAccept(AcceptResultCallback cb)
	{
		_accept = cb;
	}

	override void render(Window window, ScreenContext context, bool focused)
	{
		ensureCreated(window);

		if (_layoutDirty)
		{
			rebuildLayout();
			clampScroll();
			ensureSelectedVisible();
		}
		else
		{
			ensureSelectedVisible();
		}

		applyTheme(context, focused);
		renderContent(context, focused);
	}

	override ScreenAction handle(ScreenContext context, KeyEvent event)
	{
		if (!_enabled)
		{
			return ScreenAction.none();
		}

		if (event.isEnter)
		{
			if (_accept is null || _items.length == 0 || _selected >= _items.length)
			{
				return ScreenAction.none();
			}

			return _accept(_selected, _items[_selected].toUTF8);
		}

		if (!event.isKeyCode)
		{
			return ScreenAction.none();
		}

		bool changed = false;

		switch (event.ch)
		{
		case KEY_UP:
			changed = moveSelectionDelta(-1);
			break;
		case KEY_DOWN:
			changed = moveSelectionDelta(+1);
			break;
		case KEY_HOME:
			changed = setSelected(0);
			break;
		case KEY_END:
			if (_items.length)
			{
				changed = setSelected(cast(int) _items.length - 1);
			}
			break;

		case KEY_PPAGE:
			changed = pageMove(-1);
			break;
		case KEY_NPAGE:
			changed = pageMove(+1);
			break;

		case KEY_LEFT:
			changed = hscrollBy(-1);
			break;
		case KEY_RIGHT:
			changed = hscrollBy(+1);
			break;
		case KEY_SHOME:
			if (_hscroll)
			{
				if (_leftCell != 0)
				{
					_leftCell = 0;
					clampScroll();
					changed = true;
				}
			}
			break;
		case KEY_SEND:
			if (_hscroll)
			{
				const int m = maxLeftCell();
				if (_leftCell != m)
				{
					_leftCell = m;
					clampScroll();
					changed = true;
				}
			}
			break;

		default:
			break;
		}

		if (changed)
		{
			ensureSelectedVisible();
		}

		return ScreenAction.none();
	}


	override void close()
	{
		_pad.delwin();
		_window.delwin();
		_windowBorder.delwin();

		_inited = false;
		_layoutDirty = true;
		_padDirty = true;

		_lines.length = 0;
		_lineToItem.length = 0;
		_itemStartLine.length = 0;
		_itemLineCount.length = 0;

		_items.length = 0;

		_selected = 0;
		_topLine = 0;
		_leftCell = 0;
		_maxLineCells = 0;

		_lastAttrNormal = int.min;
		_lastAttrSelected = int.min;
		_lastSelected = size_t.max;
	}

	~this()
	{
		close();
	}
}
