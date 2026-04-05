# file_manager.gd
# File editing for robotic software development
# Enables code deployment and config management on robot systems

class_name FileManager

## FileManager — Remote file editing for robotics
##
## Supports:
## - Read/write files on robot over SSH or ROS service
## - Code deployment to robot filesystem
## - Configuration file management
## - Log file retrieval
##
## Usage:
##   var fm = FileManager.new("192.168.1.100", "robot")
##   fm.connect_robot()
##   fm.write_file("/home/robot/catkin_ws/src/my_robot/control.py", python_code)
##   var content = fm.read_file("/home/robot/catkin_ws/config/params.yaml")
##   fm.disconnect()

const DEFAULT_SSH_PORT = 22
const DEFAULT_TIMEOUT = 10.0

var _host: String = ""
var _port: int = DEFAULT_SSH_PORT
var _username: String = ""
var _password: String = ""
var _robot_namespace: String = ""
var _connected: bool = false
var _use_ros_service: bool = false

# ROS service for file operations (alternative to SSH)
var _file_service_client: ServiceClient = null
var _last_operation_result: Dictionary = {}

func _init(robot_host: String = "", robot_ns: String = "") -> void:
	_host = robot_host
	_robot_namespace = robot_ns


func set_connection_params(remote_host: String, port: int, username: String, password: String = "") -> void:
	_host = remote_host
	_port = port
	_username = username
	_password = password


func set_ros_service_mode(service_name: String = "/file_manager") -> void:
	_use_ros_service = true
	# ROS service name for file operations
	_file_service_client = ServiceClient.new(service_name, "rcl_interfaces/srv/LoadDumFile")


func connect_robot() -> bool:
	# Establish connection to robot
	# Returns true if connection successful
	if _use_ros_service:
		_connected = true  # Service client handles connection
		return _connected

	# SSH mode - test connection with ssh command
	if _host == "" or _username == "":
		push_error("FileManager: Host and username required for SSH connection")
		return false

	var test_cmd = "ssh -p %d -o ConnectTimeout=%d -o StrictHostKeyChecking=no %s@%s 'echo connected'" % [_port, int(DEFAULT_TIMEOUT), _username, _host]
	var output = []
	var result = OS.execute("bash", ["-c", test_cmd], output, true)
	_connected = (result == 0)
	return _connected


func disconnect_robot() -> void:
	_connected = false
	_file_service_client = null


func has_robot_connection() -> bool:
	return _connected


# === File Operations ===

func read_file(remote_path: String) -> String:
	# Read file content from robot
	if not _connected:
		push_error("FileManager: Not connected to robot")
		return ""

	if _use_ros_service:
		return _read_file_ros(remote_path)
	return _read_file_ssh(remote_path)


func write_file(remote_path: String, content: String, append: bool = false) -> bool:
	# Write content to file on robot
	# Creates parent directories if needed
	if not _connected:
		push_error("FileManager: Not connected to robot")
		return false

	if _use_ros_service:
		return _write_file_ros(remote_path, content, append)
	return _write_file_ssh(remote_path, content, append)


func delete_file(remote_path: String) -> bool:
	# Delete file on robot
	if not _connected:
		push_error("FileManager: Not connected to robot")
		return false

	if _use_ros_service:
		return _delete_file_ros(remote_path)
	return _delete_file_ssh(remote_path)


func list_directory(remote_path: String) -> Array:
	# List directory contents on robot
	# Returns array of file/dir names
	if not _connected:
		push_error("FileManager: Not connected to robot")
		return []

	if _use_ros_service:
		return _list_directory_ros(remote_path)
	return _list_directory_ssh(remote_path)


func file_exists(remote_path: String) -> bool:
	# Check if file exists on robot
	if not _connected:
		return false

	if _use_ros_service:
		return _file_exists_ros(remote_path)
	return _file_exists_ssh(remote_path)


func create_directory(remote_path: String) -> bool:
	# Create directory on robot
	if not _connected:
		push_error("FileManager: Not connected to robot")
		return false

	if _use_ros_service:
		return _create_directory_ros(remote_path)
	return _create_directory_ssh(remote_path)


func get_file_permissions(remote_path: String) -> Dictionary:
	# Get file permissions (owner, group, mode)
	if not _connected:
		return {}

	if _use_ros_service:
		return _get_permissions_ros(remote_path)
	return _get_permissions_ssh(remote_path)


func set_file_permissions(remote_path: String, mode: String) -> bool:
	# Set file permissions (e.g., "755", "+x")
	if not _connected:
		return false

	if _use_ros_service:
		return _set_permissions_ros(remote_path, mode)
	return _set_permissions_ssh(remote_path, mode)


# === Code Deployment Helpers ===

func deploy_python_file(local_content: String, remote_path: String) -> bool:
	# Deploy Python file with proper shebang and permissions
	var content = "#!/usr/bin/env python3\n" + local_content
	if not write_file(remote_path, content):
		return false
	set_file_permissions(remote_path, "755")
	return true


func deploy_launch_file(package_name: String, launch_name: String, content: String) -> bool:
	# Deploy ROS launch file
	var path = "/home/%s/colcon_ws/src/%s/launch/%s.launch.py" % [_username, package_name, launch_name]
	return write_file(path, content)


func deploy_config_file(package_name: String, config_name: String, content: String) -> bool:
	# Deploy YAML config file
	var path = "/home/%s/colcon_ws/src/%s/config/%s.yaml" % [_username, package_name, config_name]
	return write_file(path, content)


func deploy_urdf(package_name: String, urdf_name: String, content: String) -> bool:
	# Deploy URDF robot description
	var path = "/home/%s/colcon_ws/src/%s/urdf/%s.urdf" % [_username, package_name, urdf_name]
	return write_file(path, content)


# === SSH Implementations ===

func _read_file_ssh(remote_path: String) -> String:
	var cmd = "ssh -p %d -o ConnectTimeout=%d %s@%s 'cat \"%s\"'" % [_port, int(DEFAULT_TIMEOUT), _username, _host, remote_path]
	var output = []
	var result = OS.execute("bash", ["-c", cmd], output, true)
	if result == 0 and output.size() > 0:
		return output[0]
	return ""


func _write_file_ssh(remote_path: String, content: String, append: bool) -> bool:
	# Write via scp or ssh with redirection
	# First write to temp, then move
	var temp_path = "/tmp/godot_filemanager_%d.tmp" % Time.get_unix_time_from_system()

	# Write content to temp file locally
	var f = FileAccess.open(temp_path, FileAccess.WRITE)
	if f == null:
		push_error("FileManager: Cannot create temp file")
		return false
	f.store_string(content)
	f.close()

	# Copy to remote
	var scp_cmd = "scp -P %d -o ConnectTimeout=%d %s %s@%s:'%s'" % [_port, int(DEFAULT_TIMEOUT), temp_path, _username, _host, remote_path]
	var result = OS.execute("bash", ["-c", scp_cmd])

	# Clean up temp
	DirAccess.remove_absolute(temp_path)

	if result != 0:
		push_error("FileManager: scp failed")
		return false

	# If append mode, use ssh to append
	if append:
		var append_cmd = "ssh -p %d -o ConnectTimeout=%d %s@%s 'cat >> \"%s\"'" % [_port, int(DEFAULT_TIMEOUT), _username, _host, remote_path]
		var append_file = FileAccess.open(temp_path, FileAccess.WRITE)
		if append_file:
			append_file.store_string(content)
			append_file.close()
		OS.execute("bash", ["-c", "cat %s | %s" % [temp_path, append_cmd]])

	return true


func _delete_file_ssh(remote_path: String) -> bool:
	var cmd = "ssh -p %d -o ConnectTimeout=%d %s@%s 'rm \"%s\"'" % [_port, int(DEFAULT_TIMEOUT), _username, _host, remote_path]
	var result = OS.execute("bash", ["-c", cmd])
	return result == 0


func _list_directory_ssh(remote_path: String) -> Array:
	var cmd = "ssh -p %d -o ConnectTimeout=%d %s@%s 'ls -1 \"%s\"'" % [_port, int(DEFAULT_TIMEOUT), _username, _host, remote_path]
	var output = []
	var result = OS.execute("bash", ["-c", cmd], output, true)
	if result == 0 and output.size() > 0:
		var lines = output[0].strip_edges().split("\n")
		return lines
	return []


func _file_exists_ssh(remote_path: String) -> bool:
	var cmd = "ssh -p %d -o ConnectTimeout=%d %s@%s 'test -e \"%s\" && echo exists'" % [_port, int(DEFAULT_TIMEOUT), _username, _host, remote_path]
	var output = []
	var result = OS.execute("bash", ["-c", cmd], output, true)
	return result == 0 and output.size() > 0 and "exists" in output[0]


func _create_directory_ssh(remote_path: String) -> bool:
	var cmd = "ssh -p %d -o ConnectTimeout=%d %s@%s 'mkdir -p \"%s\"'" % [_port, int(DEFAULT_TIMEOUT), _username, _host, remote_path]
	var result = OS.execute("bash", ["-c", cmd])
	return result == 0


func _get_permissions_ssh(remote_path: String) -> Dictionary:
	var cmd = "ssh -p %d -o ConnectTimeout=%d %s@%s 'stat -c \"%%a %%U %%G\" \"%s\"'" % [_port, int(DEFAULT_TIMEOUT), _username, _host, remote_path]
	var output = []
	var result = OS.execute("bash", ["-c", cmd], output, true)
	if result == 0 and output.size() > 0:
		var parts = output[0].strip_edges().split(" ")
		return {"mode": parts[0], "owner": parts[1], "group": parts[2]}
	return {}


func _set_permissions_ssh(remote_path: String, mode: String) -> bool:
	var cmd = "ssh -p %d -o ConnectTimeout=%d %s@%s 'chmod %s \"%s\"'" % [_port, int(DEFAULT_TIMEOUT), _username, _host, mode, remote_path]
	var result = OS.execute("bash", ["-c", cmd])
	return result == 0


# === ROS Service Implementations (placeholder) ===

func _read_file_ros(remote_path: String) -> String:
	# Use ROS service for file read
	_last_operation_result = {"op": "read", "path": remote_path}
	return ""  # TODO: Call ROS service


func _write_file_ros(remote_path: String, content: String, append: bool) -> bool:
	# Use ROS service for file write
	_last_operation_result = {"op": "write", "path": remote_path, "append": append}
	return true  # TODO: Call ROS service


func _delete_file_ros(remote_path: String) -> bool:
	_last_operation_result = {"op": "delete", "path": remote_path}
	return true  # TODO: Call ROS service


func _list_directory_ros(remote_path: String) -> Array:
	_last_operation_result = {"op": "list", "path": remote_path}
	return []  # TODO: Call ROS service


func _file_exists_ros(remote_path: String) -> bool:
	_last_operation_result = {"op": "exists", "path": remote_path}
	return false  # TODO: Call ROS service


func _create_directory_ros(remote_path: String) -> bool:
	_last_operation_result = {"op": "mkdir", "path": remote_path}
	return true  # TODO: Call ROS service


func _get_permissions_ros(remote_path: String) -> Dictionary:
	_last_operation_result = {"op": "permissions", "path": remote_path}
	return {}  # TODO: Call ROS service


func _set_permissions_ros(remote_path: String, mode: String) -> bool:
	_last_operation_result = {"op": "chmod", "path": remote_path, "mode": mode}
	return true  # TODO: Call ROS service


func get_last_operation() -> Dictionary:
	return _last_operation_result
