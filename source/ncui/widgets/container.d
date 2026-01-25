module ncui.widgets.container;

import ncui.widgets.widget;
import ncui.core.window;
import ncui.core.event;
import ncui.engine.screen;
import ncui.engine.action;

/*
 * WidgetContainer — контейнер виджетов: хранит список, управляет фокусом и
 * раздаёт ввод/отрисовку.
 *
 *  - render(): вызывает render() у каждого виджета.
 *  - handle():
 *      * Tab -> focusNext(+1) и возвращает ScreenAction.none()
 *      * иначе: если фокус валиден -> передаём событие текущему виджету
 *
 * Правила фокуса:
 *  - нельзя поставить фокус на виджет, если он:
 *      * не focusable
 *      * или disabled (enabled == false)
 */
final class WidgetContainer
{
private:
	// Список дочерних виджетов.
	IWidget[] _children;
	// Индекс сфокусированного виджета или -1, если фокуса нет.
	int _focus = -1;
public:
	// Добавить виджет в контейнер.
	void add(IWidget widget)
	{
		// Индекс элемента ДО добавления.
		const int index = cast(int) _children.length;

		_children ~= widget;

		// Если фокуса ещё нет — дать первому фокусируемому/включенному.
		if (_focus < 0 && widget.focusable && widget.enabled)
		{
			_focus = index;
		}
	}

	// Текущий индекс фокуса (или -1).
	@property int focusIndex() const
	{
		return _focus;
	}

	// Установить фокус на виджет по индексу.
	bool setFocus(int index)
	{
		if (index < 0 || index >= _children.length)
		{
			return false;
		}

		auto widget = _children[index];

		if (!widget.focusable || !widget.enabled)
		{
			return false;
		}

		_focus = index;
		return true;
	}

	// Переключить фокус на следующий/предыдущий доступный виджет.
	bool focusNext(int delta = +1)
	{
		// Если нет элементов для фокуса.
		if (_children.length == 0)
		{
			return false;
		}

		const int count = cast(int) _children.length;
		// Точка начала текущего элемента.
		int index = _focus < 0 ? 0 : _focus;
		for (int step = 0; step < count; ++step)
		{
			index += delta;

			if (index < 0)
			{
				index = count - 1;
			}

			if (index >= count)
			{
				index = 0;
			}

			auto widget = _children[index];
			if (!widget.focusable || !widget.enabled)
			{
				continue;
			}

			_focus = index;
			return true;
		}

		return false;
	}

	// Отрисовка виджетов.
	void render(Window window, ScreenContext context)
	{
		foreach (index, child; _children)
		{
			child.render(window, context, index == _focus);
		}

		if (_focus >= 0 && _focus < _children.length)
		{
			if (auto child = cast(ICursorOwner) _children[_focus])
			{
				child.placeCursor(context);
			}
		}
	}

	// Обработка ввода для контейнера.
	ScreenAction handle(ScreenContext context, KeyEvent event)
	{
		// Tab — переключение фокуса внутри окна.
		if (isTab(event))
		{
			focusNext(+1);
			return ScreenAction.none();
		}

		// Если фокуса нет или он вышел за границы.
		if (_focus < 0 || _focus >= _children.length)
		{
			return ScreenAction.none();
		}

		// Иначе отдать ввод текущему виджету.
		return _children[_focus].handle(context, event);
	}

	// Освободить ресурсы виджетов, но оставить сами виджеты в контейнере.
	void closeResources()
	{
		foreach (child; _children)
		{
			if (auto widget = cast(IWidgetClosable) child)
			{
				widget.close();
			}
		}
	}

	// Детерминировано закрыть виджеты.
	void closeAll()
	{
		closeResources();
		_children.length = 0;
		_focus = -1;
	}
}
