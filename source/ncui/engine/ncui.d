/**
 * Главный движок: стек экранов + цикл ввода.
 */
module ncui.engine.ncui;

import core.stdc.stdlib : EXIT_SUCCESS, EXIT_FAILURE, exit;
import std.array : popBack;

import ncui.lib.logger;
import ncui.core.session;
import ncui.engine.screen;
import ncui.engine.action;

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

	void apply(ScreenAction action)
	{
		while (_running && action.kind != ActionKind.None)
		{
			final switch (action.kind)
			{
			case ActionKind.Push:
				_session.clear();
				_stack ~= action.next;
				action = action.next.onShow(_context);
				break;

			case ActionKind.Replace:
				if (_stack.length != 0)
				{
					_stack[$ - 1].close();
					_stack.popBack();
				}
				_session.clear();
				_stack ~= action.next;
				action = action.next.onShow(_context);
				break;

			case ActionKind.Pop:
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

public:
	this(const SessionConfig config = SessionConfig.init)
	{
		try
		{
			_session = new Session(config);
		}
		catch (Exception e)
		{
			error("Failed to initialize the session: ", e.msg);
			exit(EXIT_FAILURE);
		}

		_context = ScreenContext(_session);
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
			// Ожидать события нажатия клавиш в извлеченном из стека экране.
			auto event = _session.readKey(currentScreen.inputWindow());
			// Обработать нажатие клавиши в текущем окне.
			auto action = currentScreen.handle(_context, event);
			// Обработать возвращенное действие из окна.
			apply(action);
		}

		// Завершить сессию ncurses.
		_session.close();

		info("Engine successfully stopped");

		return _result;
	}
}
