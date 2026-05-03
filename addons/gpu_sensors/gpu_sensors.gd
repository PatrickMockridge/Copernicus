# gpu_sensors.gd
# GPU-accelerated sensor simulation plugin
# RTX ray tracing for LIDAR, path tracing for camera

@tool
extends EditorPlugin


## GPU Sensors Plugin
# Provides GPU-accelerated sensor simulation using CUDA/OptiX:
# - RTX LIDAR with hardware-accelerated ray tracing
# - Path tracing for camera with global illumination
# - Realistic noise models


## Plugin Lifecycle

func _enter_tree() -> void:
	# Register GPU sensor types
	add_custom_type("RTXLidar", "Node3D", preload("res://addons/gpu_sensors/rtx_lidar.gd"), preload("res://addons/gpu_sensors/rtx_lidar.svg"))
	add_custom_type("RTXCamera", "Node3D", preload("res://addons/gpu_sensors/rtx_camera.gd"), preload("res://addons/gpu_sensors/rtx_camera.svg"))
	add_custom_type("SensorFusion", "Node3D", preload("res://addons/gpu_sensors/sensor_fusion.gd"), preload("res://addons/gpu_sensors/sensor_fusion.svg"))

	print("GPU Sensors plugin loaded")


func _exit_tree() -> void:
	# Unregister types
	remove_custom_type("RTXLidar")
	remove_custom_type("RTXCamera")
	remove_custom_type("SensorFusion")

	print("GPU Sensors plugin unloaded")


## Static Methods

static func is_cuda_available() -> bool:
	# Check if CUDA is available
	var result = OS.execute("nvidia-smi", [], [], true)
	return result == OK


static func get_supported_lidar_models() -> Array:
	return [
		"Velodyne VLP-16",
		"Velodyne HDL-32E",
		"Velodyne HDL-64E",
		"Ouster OS1-64",
		"Robosense RS-LiDAR-16",
		"Hesai Pandar XT32"
	]


static func get_supported_camera_models() -> Array:
	return [
		"Intel RealSense D455",
		"Azure Kinect DK",
		"ZED 2i",
		"LibreCamera",
		"FLIR Blackfly"
	]
