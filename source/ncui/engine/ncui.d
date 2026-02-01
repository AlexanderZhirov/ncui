/**
 * Главный движок: стек экранов + цикл ввода.
 */
module ncui.engine.ncui;

import core.stdc.stdlib : EXIT_SUCCESS, EXIT_FAILURE, exit;
import std.array : popBack;

import ncui.lib.logger;
import ncui.lib.userdata;
import ncui.core.session;
import ncui.engine.screen;
import ncui.engine.action;
import ncui.engine.theme;

final class NCUI
{
private:
	// Корневая сессия ncurses.
	Session _session;
	// Контекст выполнения действующей сессии.
	ScreenContext _context;
	// Стек экранов.
	IScreen[] _stack;
	// Флаг активности работы движка.
	bool _running;
	// Конечный результат выполнения.
	ScreenResult _result;
	ThemeManager _theme;

	// Извлечение из стека указанное количество экранов.
	void popMany(int screenCount)
	{
		if (screenCount < 1)
		{
			screenCount = 1;
		}

		for (int i = 0; i < screenCount && _stack.length != 0; ++i)
		{
			_stack[$ - 1].close();
			_stack.popBack();
		}
	}

	// Проверить наличие тега у экрана.
	int hasScreenTag(IScreen screen)
	{
		auto taggetScreen = cast(ITaggedScreen) screen;
		// Пользовательский тег не должен быть равен int.min!
		return (taggetScreen is null) ? int.min : taggetScreen.tag();
	}

	// Извлечение из стека экраны до указанного тега.
	void popToTag(int targetTag)
	{
		while (_stack.length != 0 && hasScreenTag(_stack[$ - 1]) != targetTag)
		{
			_stack[$ - 1].close();
			_stack.popBack();
		}
	}

	void apply(ScreenAction action)
	{
		while (_running && action.kind != ActionKind.None)
		{
			final switch (action.kind)
			{
			case ActionKind.Push:
				if (_stack.length != 0)
				{
					_stack[$ - 1].onHide(_context);
				}

				_stack ~= action.next;
				action = action.next.onShow(_context);
				break;

			case ActionKind.Replace:
				if (_stack.length != 0)
				{
					_stack[$ - 1].onHide(_context);
					_stack[$ - 1].close();
					_stack.popBack();
				}
				_stack ~= action.next;
				action = action.next.onShow(_context);
				break;

			case ActionKind.Pop:
				// Результат работы удаляемого экрана (дочерний экран).
				// Позже он будет передан родительскому экрану.
				auto childResult = action.result;
				// Количество удаляемых экранов.
				int screenCount = (action.popScreenCount <= 0) ? 1 : action.popScreenCount;
				popMany(screenCount);
				if (_stack.length == 0)
				{
					_result = childResult;
					_running = false;
					return;
				}
				auto parent = _stack[$ - 1];
				parent.onHide(_context);
				// Передача результата дочернего экрана первому экрану в стеке (родительскому экрану).
				auto actionResult = parent.onChildResult(_context, childResult);
				if (actionResult.kind != ActionKind.None)
				{
					action = actionResult;
					break;
				}
				action = parent.onShow(_context);
				break;

			case ActionKind.PopTo:
				// Результат работы удаляемого экрана (дочерний экран).
				// Позже он будет передан родительскому экрану.
				auto childResult = action.result;
				// Удалить экраны до указанного тега.
				popToTag(action.targetTag);
				if (_stack.length == 0)
				{
					_result = childResult;
					_running = false;
					return;
				}
				auto parent = _stack[$ - 1];
				parent.onHide(_context);
				// Передача результата дочернего экрана первому экрану в стеке (родительскому экрану).
				auto actionResult = parent.onChildResult(_context, childResult);
				if (actionResult.kind != ActionKind.None)
				{
					action = actionResult;
					break;
				}
				action = parent.onShow(_context);
				break;

			case ActionKind.Quit:
				_result = action.result;
				_running = false;
				return;

			case ActionKind.None:
				break;
			}
		}
	}

	int timeoutFor(IScreen s)
	{
		if (auto idle = cast(IIdleScreen) s)
		{
			return idle.tickMs();
		}

		return -1;
	}

public:
	this(const SessionConfig config = SessionConfig.init, ITheme initialTheme = null)
	{
		_session = new Session(config);
		_theme = new ThemeManager(initialTheme);
		_context = ScreenContext(_session, _theme, new UserData());
	}

	this(T)(const SessionConfig config = SessionConfig.init, ITheme initialTheme = null, T userdata)
	{
		_session = new Session(config);
		_theme = new ThemeManager(initialTheme);
		_context = ScreenContext(_session, _theme, new UserData(userdata));
	}

	ScreenResult run(IScreen screen)
	{
		// Пометить работу движка активным.
		_running = true;
		// Положить первый экран в стек для начала работы.
		apply(ScreenAction.push(screen));

		while (_running && _stack.length != 0)
		{
			// Взять из стека последний экран.
			auto currentScreen = _stack[$ - 1];
			auto currentWindow = currentScreen.inputWindow();

			if (!currentWindow.isNull)
			{
				_session.wait(currentWindow, timeoutFor(currentScreen));
			}

			// Ожидать события нажатия клавиш в извлеченном из стека экране.
			auto event = _session.readKey(currentWindow);

			ScreenAction action;

			if (event.isErr)
			{
				if (auto idle = cast(IIdleScreen) currentScreen)
				{
					action = idle.onTick(_context);
				}
				else
				{
					action = ScreenAction.none();
				}
			}
			else
			{
				// Обработать нажатие клавиши в текущем окне.
				action = currentScreen.handle(_context, event);
			}

			// Обработать возвращенное действие из окна.
			apply(action);
		}

		// Завершить сессию ncurses.
		stop();

		return _result;
	}

	void stop()
	{
		if (_stack.length > 0)
		{
			popMany(cast(int) _stack.length);
		}

		if (_session !is null)
		{
			_session.close();
		}
	}
}
