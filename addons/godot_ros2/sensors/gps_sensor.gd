# gps_sensor.gd
# GPS sensor

extends Sensor

var _publish_topic: String = "gps"
var _latitude: float = 0.0
var _longitude: float = 0.0
var _altitude: float = 0.0
var _origin_lat: float = 0.0
var _origin_lon: float = 0.0


func _init(name: String) -> void:
	 super(name)
	_frame_id = name


func set_publish_topic(topic: String) -> void:
	_publish_topic = topic


func set_origin(lat: float, lon: float) -> void:
	_origin_lat = lat
	_origin_lon = lon


func configure(params: Dictionary) -> void:
	super.configure(params)
	if "topic" in params:
		set_publish_topic(params["topic"])
	if "origin_lat" in params and "origin_lon" in params:
		set_origin(params["origin_lat"], params["origin_lon"])


func update_meas(position: Vector3) -> void:
	_latitude = _origin_lat + position.z * 0.00001
	_longitude = _origin_lon + position.x * 0.00001
	_altitude = position.y


func get_gps_message(header: Dictionary) -> Dictionary:
	return SensorMsgs.create_navsatfix(header, _latitude, _longitude, _altitude)