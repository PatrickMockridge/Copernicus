# std_msgs.gd
# Helpers for building std_msgs-compatible dictionaries.

class_name StdMsgs


static func create_header(sec: int, nanosec: int, frame_id: String) -> Dictionary:
	return {
		"sec": sec,
		"nanosec": nanosec,
		"frame_id": frame_id
	}


static func create_header_now(frame_id: String) -> Dictionary:
	var t: float = Time.get_unix_time_from_system()
	var sec: int = int(t)
	var nanosec: int = int((t - float(sec)) * 1000000000.0)
	return create_header(sec, nanosec, frame_id)
