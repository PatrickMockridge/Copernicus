# pid_controller.gd
# PID (Proportional-Integral-Derivative) controller
# Common control loop for position/velocity control

class_name PIDController
extends RefCounted

## PID gains
var _kp: float = 1.0  # Proportional gain
var _ki: float = 0.0  # Integral gain
var _kd: float = 0.0  # Derivative gain

## Internal state
var _integral: float = 0.0
var _prev_error: float = 0.0
var _prev_time: float = 0.0

## Output limits
var _output_min: float = -INF
var _output_max: float = INF

## Derivative filter
var _derivative_filter: float = 0.0  # 0-1, higher = more smoothing
var _kff: float = 0.0  # Feed-forward gain

## Anti-windup
var _windup_limit: float = INF
var _use_anti_windup: bool = false


func _init(kp: float = 1.0, ki: float = 0.0, kd: float = 0.0) -> void:
	_kp = kp
	_ki = ki
	_kd = kd


func set_gains(kp: float, ki: float, kd: float) -> void:
	_kp = kp
	_ki = ki
	_kd = kd


func get_gains() -> Array:
	return [_kp, _ki, _kd]


func set_output_limits(min_val: float, max_val: float) -> void:
	_output_min = min_val
	_output_max = max_val


func set_anti_windup(limit: float) -> void:
	_windup_limit = limit
	_use_anti_windup = true


func set_feed_forward(kff: float) -> void:
	_kff = kff


func set_derivative_filter(alpha: float) -> void:
	_derivative_filter = clamp(alpha, 0.0, 1.0)


func reset() -> void:
	_integral = 0.0
	_prev_error = 0.0
	_prev_time = 0.0


func compute_output(error: float, dt: float) -> float:
	"""Compute PID output for given error and time step"""
	if dt <= 0:
		return 0.0

	# Proportional term
	var p_term = _kp * error

	# Integral term with anti-windup
	if _use_anti_windup:
		_integral += error * dt
		_integral = clamp(_integral, -_windup_limit, _windup_limit)
	else:
		_integral += error * dt
	var i_term = _ki * _integral

	# Derivative term with filtering
	var derivative = (error - _prev_error) / dt if dt > 0 else 0.0
	if _derivative_filter > 0:
		derivative = _derivative_filter * derivative + (1.0 - _derivative_filter) * _prev_error
	var d_term = _kd * derivative

	# Store for next iteration
	_prev_error = error
	_prev_time = dt

	# Compute output and clamp
	var output = p_term + i_term + d_term
	output = clamp(output, _output_min, _output_max)

	return output


func compute_output_with_setpoint(current: float, target: float, dt: float) -> float:
	"""Convenience method that computes error from current and target values"""
	var error = target - current
	return compute_output(error, dt)


func compute_output_with_feed_forward(error: float, dt: float, ff_target: float = 0.0) -> float:
	var pid_out = compute_output(error, dt)
	return pid_out + _kff * ff_target


class PositionPID:
	"""Factory for position control PID"""
	static func create_Kp(kp: float) -> PIDController:
		var pid = PIDController.new(kp, 0.0, 0.0)
		return pid


class VelocityPID:
	"""Factory for velocity control PID"""
	static func create(kp: float = 1.0, ki: float = 0.1, kd: float = 0.01) -> PIDController:
		var pid = PIDController.new(kp, ki, kd)
		pid.set_anti_windup(10.0)
		return pid


class JointPID:
	"""Factory for robot joint control PID"""
	static func create_position_controller(kp: float = 10.0, ki: float = 0.5, kd: float = 1.0) -> PIDController:
		var pid = PIDController.new(kp, ki, kd)
		pid.set_anti_windup(100.0)
		return pid

	static func create_velocity_controller(kp: float = 5.0, ki: float = 0.1, kd: float = 0.5) -> PIDController:
		var pid = PIDController.new(kp, ki, kd)
		pid.set_anti_windup(50.0)
		pid.set_derivative_filter(0.8)
		return pid