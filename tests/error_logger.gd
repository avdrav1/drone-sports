extends Logger
# Collects engine and script errors so the runner can fail the test that caused them.
# Loaded by run.gd only on engines that have the Logger class (4.5+).

var sink: Array
var _mutex := Mutex.new()

func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	_mutex.lock()
	sink.append("%s (%s:%d %s)" % [rationale if rationale != "" else code, file, line, function])
	_mutex.unlock()
