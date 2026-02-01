module ncui.lib.userdata;

import std.variant : Variant;
import std.traits : isDynamicArray, isSomeString;
import ncui.lib.checks : ncuiExpectMsg;

final class UserData
{
private:
	Variant _v;
	bool _has;

	static auto normalize(T)(T value)
	{
		static if (isSomeString!T)
		{
			static if (is(T == immutable(char)[]))
			{
				return value;
			}
			else
			{
				return value.idup;
			}
		}
		else static if (isDynamicArray!T)
		{
			alias E = typeof(value[0]);
			static if (is(T == immutable(E)[]))
			{
				return value;
			}
			else
			{
				return value.dup;
			}
		}
		else
		{
			return value;
		}
	}

	void setImpl(T)(T value)
	{
		_v = Variant(normalize(value));
		_has = true;
	}

public:
	this()
	{
		_has = false;
	}

	this(T)(T value)
	{
		static if (__traits(compiles, value is null))
		{
			if (value is null)
			{
				_has = false;
				return;
			}
		}

		_v = Variant(normalize(value));
		_has = true;
	}

	@property bool has() const
	{
		return _has;
	}

	ref T get(T)()
	{
		auto p = pointer!T();
		ncuiExpectMsg!((bool ok) => ok)(
			"ScreenContext.data: value is not set or has different type",
			true,
			p !is null
		);
		return *p;
	}

	T* pointer(T)()
	{
		if (!_has)
		{
			return null;
		}

		return _v.peek!T;
	}

	T get(T)(T fallback)
	{
		if (auto p = pointer!T())
		{
			return *p;
		}

		return fallback;
	}

	// void clear()
	// {
	// 	_v = Variant.init;
	// 	_has = false;
	// }
}
