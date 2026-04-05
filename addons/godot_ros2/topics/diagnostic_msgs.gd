# diagnostic_msgs.gd
# Diagnostic message types

class_name DiagnosticMsgs

const KEY = 0
const WARN = 1
const ERROR = 2

const OK = 0
const WARN_STATUS = 1
const ERROR_STATUS = 2
const STALE_STATUS = 3


# ===== KeyValue =====

static func create_keyvalue(key: String, value: String) -> Dictionary:
	return {"key": key, "value": value}


# ===== DiagnosticStatus =====

static func create_diagnostic_status(
	level: int,
	name: String,
	message: String,
	hardware_id: String,
	values: Array
) -> Dictionary:
	return {
		"level": level,
		"name": name,
		"message": message,
		"hardware_id": hardware_id,
		"values": values
	}


static func create_diagnostic_status_ok(hardware_id: String = "") -> Dictionary:
	return create_diagnostic_status(OK, "", "OK", hardware_id, [])


static func create_diagnostic_status_warn(message: String, hardware_id: String = "") -> Dictionary:
	return create_diagnostic_status(WARN_STATUS, "", message, hardware_id, [])


static func create_diagnostic_status_error(message: String, hardware_id: String = "") -> Dictionary:
	return create_diagnostic_status(ERROR_STATUS, "", message, hardware_id, [])


# ===== DiagnosticArray =====

static func create_diagnostic_array(status: Array) -> Dictionary:
	return {"status": status}


# ===== AddDiagnostics =====

static func create_add_diagnostics_request(loaded_namespace: String) -> Dictionary:
	return {"loaded_namespace": loaded_namespace}


static func create_add_diagnostics_response(success: bool, message: String) -> Dictionary:
	return {"success": success, "message": message}
