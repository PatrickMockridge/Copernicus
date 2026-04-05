# std_msgs.gd
# Standard ROS 2 message types

class_name StdMsgs

# ===== Header =====

static func create_header(stamp_sec: int, stamp_nsec: int, frame_id: String) -> Dictionary:
	return {
		"stamp": {
			"sec": stamp_sec,
			"nanosec": stamp_nsec
		},
		"frame_id": frame_id
	}


static func create_header_now(frame_id: String) -> Dictionary:
	var now = Time.get_datetime_dict_from_system()
	return create_header(now.get("day", 0), 0, frame_id)


# ===== String =====

static func create_string(text: String) -> Dictionary:
	return {"data": text}


# ===== Int32, Float64, etc. =====

static func create_int8(value: int) -> Dictionary:
	return {"data": value}


static func create_int16(value: int) -> Dictionary:
	return {"data": value}


static func create_int32(value: int) -> Dictionary:
	return {"data": value}


static func create_int64(value: int) -> Dictionary:
	return {"data": value}


static func create_uint8(value: int) -> Dictionary:
	return {"data": value}


static func create_uint16(value: int) -> Dictionary:
	return {"data": value}


static func create_uint32(value: int) -> Dictionary:
	return {"data": value}


static func create_uint64(value: int) -> Dictionary:
	return {"data": value}


static func create_float32(value: float) -> Dictionary:
	return {"data": value}


static func create_float64(value: float) -> Dictionary:
	return {"data": value}


# ===== Bool =====

static func create_bool(value: bool) -> Dictionary:
	return {"data": value}


# ===== Empty =====

static func create_empty() -> Dictionary:
	return {}


# ===== ColorRGBA =====

static func create_colorrgba(r: float, g: float, b: float, a: float) -> Dictionary:
	return {"r": r, "g": g, "b": b, "a": a}


# ===== Time =====

static func create_time(sec: int, nsec: int) -> Dictionary:
	return {"sec": sec, "nanosec": nsec}


# ===== Duration =====

static func create_duration(sec: int, nsec: int) -> Dictionary:
	return {"sec": sec, "nanosec": nsec}


# ===== MultiArrayDimension =====

static func create_multiarray_dimension(label: String, size: int, stride: int) -> Dictionary:
	return {"label": label, "size": size, "stride": stride}


# ===== MultiArrayLayout =====

static func create_multiarray_layout(dimensions: Array) -> Dictionary:
	return {"dim": dimensions, "data_offset": 0}


# ===== Float32MultiArray =====

static func create_float32_multiarray(layout: Dictionary, data: Array) -> Dictionary:
	return {"layout": layout, "data": data}


# ===== Int32MultiArray =====

static func create_int32_multiarray(layout: Dictionary, data: Array) -> Dictionary:
	return {"layout": layout, "data": data}
