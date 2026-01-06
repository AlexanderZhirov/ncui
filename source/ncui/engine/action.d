/**
 * Команды, которые экран возвращает движку.
 */
module ncui.engine.action;

import ncui.engine.screen;

/**
 * Тип команды, которую экран возвращает движку.
 *
 * `ActionKind` описывает, что именно движок должен сделать после обработки ввода:
 * изменить стек экранов, сменить тему, завершить приложение и т.д.
 */
enum ActionKind
{
	// Ничего не делать.
	None,
	// Добавить новый экран поверх текущего.
	Push,
	// Заменить верхний экран стека новым.
	Replace,
	// Удалить один или несколько экранов с вершины стека.
	Pop,
	// Завершить выполнение UI-цикла.
	Quit
}

/**
 * Базовые типы результата экрана.
 */
enum ScreenKind
{
	// Результат отсутствует или не имеет специальной семантики.
	None,
	// Отмена действия.
	Cancel
}

/**
 * Результат работы экрана.
 */
struct ScreenResult
{
	// Общий тип результата
	ScreenKind kind;

	static ScreenResult none()
	{
		return ScreenResult(ScreenKind.None);
	}

	static ScreenResult cancel()
	{
		return ScreenResult(ScreenKind.Cancel);
	}
}

/**
 * Действие, которое возвращает экран.
 */
struct ScreenAction
{
	// Тип действия.
	ActionKind kind;
	// Следующий экран (используется для `Push` и `Replace`).
	IScreen next;
	// Результат (используется для `Pop`, `Quit`).
	ScreenResult result;
	// Количество извлекаемых экранов.
	int popScreenCount;

	/**
	 * Ничего не делать.
	 *
	 * Возвращается, если стек и состояние движка менять не требуется.
	 */
	static ScreenAction none()
	{
		return ScreenAction(ActionKind.None, null, ScreenResult.none(), 0);
	}

	/**
	 * Добавить новый экран поверх текущего.
	 *
	 * Params:
	 *  - screen: создаваемый экран.
	 */
	static ScreenAction push(IScreen screen)
	{
		// assert(isPointer!(typeof(result)), "ncuiNotNull expects a function that returns a pointer.");
		return ScreenAction(ActionKind.Push, screen, ScreenResult.none(), 0);
	}

	/**
	 * Заменить верхний экран стека новым.
	 *
	 * Params:
	 *  - screen: создаваемый экран (не должен быть `null`).
	 */
	static ScreenAction replace(IScreen screen)
	{
		return ScreenAction(ActionKind.Replace, screen, ScreenResult.none(), 0);
	}

	/**
	 * Закрыть верхний экран и передать результат родителю.
	 *
	 * Params:
	 *  - result: результат закрываемого экрана.
	 */
	static ScreenAction pop(ScreenResult result)
	{
		return ScreenAction(ActionKind.Pop, null, result, 1);
	}

	/**
	 * Закрыть верхний экран и передать результат родителю.
	 *
	 * Params:
	 *  - result: результат закрываемого экрана.
	 */
	static ScreenAction popN(int count, ScreenResult result)
	{
		return ScreenAction(ActionKind.Pop, null, result, count < 1 ? 1 : count);
	}

	/**
	 * Завершить UI-цикл и вернуть финальный результат наружу.
	 *
	 * Params:
	 *  - result: финальный результат приложения (возвращается из `NCUI.run()`).
	 */
	static ScreenAction quit(ScreenResult result)
	{
		return ScreenAction(ActionKind.Quit, null, result, 0);
	}
}
