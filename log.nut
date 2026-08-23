class Log {
	static function DateStamp() {
		local d = AIDate.GetCurrentDate();
		local y = AIDate.GetYear(d);
		local m = AIDate.GetMonth(d);
		local day = AIDate.GetDayOfMonth(d);
		local ms = m < 10 ? "0" + m : m.tostring();
		local ds = day < 10 ? "0" + day : day.tostring();
		return y + "-" + ms + "-" + ds;
	}

	static function Sanitize(value) {
		local s = value.tostring();
		local out = "";
		for (local i = 0; i < s.len(); i++) {
			local ch = s[i];
			if (ch == 32 || ch == 9) out += "_";
			else if (ch < 32) out += "?";
			else out += ch.tochar();
		}
		return out;
	}

	static function Line(kind, pairs) {
		local msg = "CHUB " + kind + " y=" + Log.DateStamp() + " t=" + AIController.GetTick();
		if (pairs != null) {
			foreach (key, value in pairs) {
				msg += " " + key + "=" + Log.Sanitize(value);
			}
		}
		return msg;
	}

	static function Info(kind, pairs) {
		AILog.Info(Log.Line(kind, pairs));
	}

	static function Warn(kind, pairs) {
		AILog.Warning(Log.Line(kind, pairs));
	}

	static function Fail(reason, extra) {
		local pairs = { reason = reason };
		if (extra != null) {
			foreach (key, value in extra) pairs[key] <- value;
		}
		local err = AIError.GetLastErrorString();
		if (err != null) pairs.err <- err;
		AILog.Error(Log.Line("FAIL", pairs));
		if (AIController.GetSetting("IsDebug")) {
			AIController.Break("CHUB FAIL " + reason);
		}
	}

	static function IsDebug() {
		return AIController.GetSetting("IsDebug") != 0;
	}
}
