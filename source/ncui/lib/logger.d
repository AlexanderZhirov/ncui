module ncui.lib.logger;

import std.stdio : stderr;
import std.logger : MultiLogger, sharedLog, FileLogger;
public import std.logger : LogLevel,
	trace, tracef,
	info, infof,
	warning, warningf,
	error, errorf,
	critical, criticalf,
	fatal, fatalf;

void setLogLevel(int verbose = LogLevel.all, string logfile = string.init)
{
	LogLevel level = LogLevel.off;

	switch (verbose)
	{
	case 0:
		level = LogLevel.off;
		break;
	case 1:
		level = LogLevel.error;
		break;
	case 2:
		level = LogLevel.warning;
		break;
	case 3:
		level = LogLevel.info;
		break;
	case 4:
		level = LogLevel.trace;
		break;
	default:
		level = LogLevel.all;
	}

	auto multi = new MultiLogger(level);
	sharedLog = cast(shared) multi;

	if (logfile.length > 0)
	{
		multi.insertLogger("file", new FileLogger(logfile));
	}
	multi.insertLogger("stderr", new FileLogger(stderr));
}
