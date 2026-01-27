module ncui.lib.wrap;

import std.array : appender;

private
{
	import core.stdc.wchar_ : wchar_t;

	extern (C) int wcwidth(wchar_t);

	/**
	 * Ширина символа в терминальных колонках (wide-aware через wcwidth).
	 * Некорректные/управляющие/неопределимые символы считаются шириной 1,
	 * чтобы перенос не зависал и не ломал расчёт.
	 */
	int cellWidth(dchar ch)
	{
		const width = wcwidth(cast(wchar_t) ch);
		return (width > 0) ? width : 1;
	}

	// Минимальный набор разделителей для word-wrap.
	bool isSpace(dchar ch)
	{
		return ch == ' ' || ch == '\t';
	}
}

/**
 * Выполняет перенос текста по словам (word-wrap) с учётом ширины wide/Unicode-символов
 * в терминальных колонках (cells).
 * 
 * Функция предполагает, что входной текст уже находится в `dstring` (UTF-32), чтобы:
 * - корректно резать строки без разрыва UTF-8 байтов;
 * - вычислять ширину в колонках на уровне Unicode codepoint'ов.
 *
 * ---
 * Поведение
 *
 * 1. Текст разбивается на исходные строки по `'\n'`.
 *    Это сделано для того, чтобы:
 *    - сохранить исходные пустые строки;
 *    - не "склеивать" параграфы при переносе.
 *
 * 2. Каждая исходная строка переносится по словам:
 *    - пробелы/табуляции в начале и между словами пропускаются;
 *    - слова добавляются в текущую строку, пока влезают в `widthCols`.
 *
 * 3. Если слово не помещается:
 *    - если текущая строка не пустая — она сбрасывается в результат;
 *    - если слово помещается целиком в пустую строку — оно добавляется;
 *    - иначе слово режется на куски по символам так, чтобы каждый кусок
 *      укладывался в `widthCols` колонок.
 *
 * 4. Если исходная строка пустая (между `\n\n`) — в результат добавляется
 *    `dstring.init` (пустая строка).
 */
dstring[] wrapWordsWide(dstring text, int widthCols)
{
	// При ширине <= 1 перенос по словам не имеет смысла.
	// Возвращается исходный текст одной строкой.
	if (widthCols <= 1)
	{
		return [text];
	}

	// Выходной массив строк.
	auto output = appender!(dstring[])();

	// Позиция чтения в исходном тексте (UTF-32).
	size_t textPos = 0;

	// Обход текста с разбиением на исходные строки по '\n' для сохранения переносов.
	while (textPos < text.length)
	{
		// Поиск конца исходной строки (до '\n' или конца текста).
		size_t lineEndPos = textPos;
		while (lineEndPos < text.length && text[lineEndPos] != '\n')
		{
			++lineEndPos;
		}

		// Текущая исходная строка без '\n'.
		auto sourceLine = text[textPos .. lineEndPos];

		// Признак наличия символа перевода строки после исходной строки.
		bool hasLineBreak = (lineEndPos < text.length && text[lineEndPos] == '\n');

		// Сдвиг позиции чтения на символ после '\n' или в конец текста.
		textPos = hasLineBreak ? (lineEndPos + 1) : lineEndPos;

		// Пустая исходная строка (например, между "\n\n") сохраняется как пустая строка результата.
		if (sourceLine.length == 0)
		{
			output.put(dstring.init);
			continue;
		}

		// Текущая формируемая строка результата.
		dstring currentLine;

		// Текущая ширина currentLine в терминальных колонках (сумма cellWidth по символам).
		int currentLineWidth = 0;

		// Сброс накопленной строки в результат и начало новой строки.
		void flushCurrentLine()
		{
			output.put(currentLine);
			currentLine = dstring.init;
			currentLineWidth = 0;
		}

		// Позиция чтения внутри исходной строки.
		size_t linePos = 0;

		// Токенизация исходной строки на слова, разделённые пробельными символами.
		// Пробельные последовательности нормализуются (в результате между словами остаётся один пробел).
		while (linePos < sourceLine.length)
		{
			// Пропуск пробелов/табов.
			while (linePos < sourceLine.length && isSpace(sourceLine[linePos]))
			{
				++linePos;
			}

			// Достигнут конец исходной строки.
			if (linePos >= sourceLine.length)
			{
				break;
			}

			// Поиск конца слова (до следующего пробельного символа или конца строки).
			size_t wordEndPos = linePos;
			while (wordEndPos < sourceLine.length && !isSpace(sourceLine[wordEndPos]))
			{
				++wordEndPos;
			}

			// Извлечение слова и продвижение позиции.
			auto word = sourceLine[linePos .. wordEndPos];
			linePos = wordEndPos;

			// Подсчёт ширины слова в терминальных колонках.
			int wordWidth = 0;
			foreach (ch; word)
			{
				wordWidth += cellWidth(ch);
			}

			// Ширина пробела перед словом (0 для первого слова в строке, иначе 1).
			int leadingSpaceWidth = (currentLine.length == 0) ? 0 : 1;

			// Случай: слово целиком помещается в текущую строку (с учётом пробела).
			if (currentLineWidth + leadingSpaceWidth + wordWidth <= widthCols)
			{
				if (leadingSpaceWidth == 1)
				{
					currentLine ~= ' ';
					currentLineWidth += 1;
				}

				currentLine ~= word;
				currentLineWidth += wordWidth;
				continue;
			}

			// Случай: слово не помещается в текущую строку.
			// При наличии накопленной строки она завершается и переносится в результат.
			if (currentLine.length != 0)
			{
				flushCurrentLine();
			}

			// Случай: слово помещается в пустую строку.
			if (wordWidth <= widthCols)
			{
				currentLine ~= word;
				currentLineWidth = wordWidth;
				continue;
			}

			// Случай: слово длиннее ширины строки.
			// Выполняется разрезание слова на куски по символам так, чтобы каждый кусок помещался по ширине.
			size_t wordPos = 0;
			while (wordPos < word.length)
			{
				int chunkWidth = 0;
				size_t chunkStartPos = wordPos;

				// Набор максимально возможного куска, помещающегося в widthCols колонок.
				while (wordPos < word.length)
				{
					int chWidth = cellWidth(word[wordPos]);
					if (chunkWidth + chWidth > widthCols)
					{
						break;
					}

					chunkWidth += chWidth;
					++wordPos;
				}

				// Страховка от зацикливания, если единичный символ шире widthCols.
				if (wordPos == chunkStartPos)
				{
					++wordPos;
				}

				// Добавление куска как отдельной строки результата.
				output.put(word[chunkStartPos .. wordPos]);
			}
		}

		// Добавление остатка текущей строки результата (если непустая).
		if (currentLine.length != 0)
		{
			output.put(currentLine);
		}
	}

	return output.data;
}
