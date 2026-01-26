/**
 * Команды, которые экран возвращает движку.
 */
module ncui.engine.action;

import ncui.engine.screen;

import std.variant : Variant;

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
	// Удалить один или несколько экранов с вершины стека до указанного тега.
	PopTo,
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
	Cancel,
	// Возврат корректного результата.
	Ok,
	// Возврат результата с ошибкой.
	Error
}

/**
 * Результат работы экрана.
 */
struct ScreenResult
{
	// Общий тип результата
	ScreenKind kind;
	Variant payload;

	static ScreenResult none()
	{
		return ScreenResult(ScreenKind.None);
	}

	static ScreenResult cancel()
	{
		return ScreenResult(ScreenKind.Cancel);
	}

	static ScreenResult ok(T)(T value)
	{
		return ScreenResult(ScreenKind.Ok, Variant(value));
	}

	static ScreenResult error(string message)
	{
		return ScreenResult(ScreenKind.Error, Variant(message));
	}

	bool has(T)() const
	{
		return payload.type == typeid(T);
	}

	T get(T)() const
	{
		import ncui.lib.checks;

		ncuiExpectMsg!((bool ok) => ok)(
			"ScreenResult payload has different type",
			true,
			has!T()
		);

		return payload.get!T;
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
	// Количество удаляемых экранов.
	int popScreenCount;
	// Целевой тег экрана, до которого необходимо удалить экраны из стека.
	int targetTag;

	/**
	 * Ничего не делать.
	 *
	 * Возвращается, если стек и состояние движка менять не требуется.
	 */
	static ScreenAction none()
	{
		return ScreenAction(ActionKind.None, null, ScreenResult.none(), 0, 0);
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
		return ScreenAction(ActionKind.Push, screen, ScreenResult.none(), 0, 0);
	}

	/**
	 * Заменить верхний экран стека новым.
	 *
	 * Params:
	 *  - screen: создаваемый экран (не должен быть `null`).
	 */
	static ScreenAction replace(IScreen screen)
	{
		return ScreenAction(ActionKind.Replace, screen, ScreenResult.none(), 0, 0);
	}

	/**
	 * Закрыть верхний экран и передать результат родителю.
	 *
	 * Params:
	 *  - result: результат закрываемого экрана.
	 */
	static ScreenAction pop(ScreenResult result)
	{
		return ScreenAction(ActionKind.Pop, null, result, 1, 0);
	}

	/**
	 * Закрыть верхний экран и передать результат родителю.
	 *
	 * Params:
	 *  - result: результат закрываемого экрана.
	 */
	static ScreenAction popN(int count, ScreenResult result)
	{
		return ScreenAction(ActionKind.Pop, null, result, count < 1 ? 1 : count, 0);
	}

	/**
	* Закрыть экраны до экрана с указанным тегом и передать ему результат.
	*
	* Params:
	*  - tag: целевой тег.
	*  - result: результат закрываемого экрана.
	*/
	static ScreenAction popTo(int targetTag, ScreenResult result)
	{
		return ScreenAction(ActionKind.PopTo, null, result, 0, targetTag);
	}

	/**
	 * Завершить UI-цикл и вернуть финальный результат наружу.
	 *
	 * Params:
	 *  - result: финальный результат приложения (возвращается из `NCUI.run()`).
	 */
	static ScreenAction quit(ScreenResult result)
	{
		return ScreenAction(ActionKind.Quit, null, result, 0, 0);
	}
}
