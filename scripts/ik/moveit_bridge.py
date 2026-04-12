#!/usr/bin/env python3
# moveit_bridge.py
# Python ROS2 node that bridges to MoveIt IK service
# Receives IK requests from Godot, calls MoveIt, returns joint solutions

import sys
import json
import argparse

try:
    import rclpy
    from rclpy.node import Node
    from moveit_msgs.srv import GetPositionIK
    from sensor_msgs.msg import JointState
    import tf_transformations
except ImportError as e:
    print(json.dumps({
        "status": "error",
        "message": f"ROS2 import failed: {e}. Try: pip install rclpy"
    }), flush=True)
    sys.exit(1)


class MoveItBridge(Node):
    def __init__(self, robot_description: str = "robot_description", group: str = "manipulator"):
        super().__init__('moveit_ik_bridge')

        self.robot_description = robot_description
        self.group = group
        self.joint_names = []

        # Create IK service client
        self.ik_client = self.create_client(GetPositionIK, '/compute_ik')

        # Wait for service
        self.get_logger().info(f'Waiting for /compute_ik service...')
        self.ik_client.wait_for_service()
        self.get_logger().info(f'Service available')

    def solve_ik(self, target_position: list, timeout: float = 0.5) -> dict:
        """Solve IK for given target position."""

        # Build request
        request = GetPositionIK.Request()
        request.ik_request.group_name = self.group
        request.ik_request.robot_description = self.robot_description
        request.ik_request.avoid_collisions = True
        request.ik_request.timeout.sec = int(timeout)
        request.ik_request.timeout.nanosec = int((timeout % 1) * 1e9)

        # Set target position (pose)
        request.ik_request.pose_stamped.header.frame_id = "base_link"
        request.ik_request.pose_stamped.pose.position.x = target_position[0]
        request.ik_request.pose_stamped.pose.position.y = target_position[1]
        request.ik_request.pose_stamped.pose.position.z = target_position[2]

        # Default orientation (identity quaternion)
        request.ik_request.pose_stamped.pose.orientation.w = 1.0

        try:
            # Call service
            future = self.ik_client.call_async(request)
            rclpy.spin_until_future_complete(self, future, timeout_sec=timeout)

            if future.result() is None:
                return {
                    "status": "error",
                    "message": "IK service call failed",
                    "solution": {},
                    "distance": float('inf')
                }

            response = future.result()

            if response.error_code.val != 1:  # SUCCESS = 1
                return {
                    "status": "error",
                    "message": f"IK failed with error code: {response.error_code.val}",
                    "solution": {},
                    "distance": float('inf')
                }

            # Extract solution
            joint_positions = list(response.solution.joint_state.position)

            return {
                "status": "ok",
                "solution": {
                    "joint_names": list(response.solution.joint_state.name),
                    "joint_positions": joint_positions
                },
                "distance": 0.0
            }

        except Exception as e:
            return {
                "status": "error",
                "message": str(e),
                "solution": {},
                "distance": float('inf')
            }


def main():
    # Parse arguments
    parser = argparse.ArgumentParser(description='MoveIt IK Bridge')
    parser.add_argument('--robot-description', default='robot_description',
                        help='Robot description parameter name')
    parser.add_argument('--group', default='manipulator',
                        help='MoveIt group name')
    args = parser.parse_args()

    # Initialize ROS
    rclpy.init(args=None)
    bridge = MoveItBridge(args.robot_description, args.group)

    print(json.dumps({
        "status": "ok",
        "cmd": "init",
        "message": f"MoveIt bridge initialized for group '{args.group}'"
    }), flush=True)

    # Process commands from stdin
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue

        try:
            cmd = json.loads(line)
            command = cmd.get("cmd", "")

            if command == "shutdown":
                print(json.dumps({"status": "ok", "cmd": "shutdown"}), flush=True)
                break

            elif command == "solve_ik":
                target = cmd.get("target_position", [0, 0, 0])
                timeout = cmd.get("timeout", 0.5)

                result = bridge.solve_ik(target, timeout)
                print(json.dumps(result), flush=True)

            else:
                print(json.dumps({
                    "status": "error",
                    "cmd": command,
                    "message": f"Unknown command: {command}"
                }), flush=True)

        except json.JSONDecodeError as e:
            print(json.dumps({
                "status": "error",
                "message": f"Invalid JSON: {e}"
            }), flush=True)

        except Exception as e:
            print(json.dumps({
                "status": "error",
                "message": str(e)
            }), flush=True)

    # Cleanup
    bridge.destroy_node()
    rclpy.shutdown()


if __name__ == "__main__":
    main()


class MoveItBridgeStandalone:
    """Standalone bridge for temp file IPC (used by Godot GDScript)"""

    def __init__(self, robot_description: str = "robot_description", group: str = "manipulator"):
        self._last_response = {"status": "error", "message": "Not initialized"}
        self._ros_initialized = False

        try:
            if not rclpy.ok():
                rclpy.init(args=None)
            self._bridge = MoveItBridge(robot_description, group)
            self._ros_initialized = True
        except Exception as e:
            self._last_response = {"status": "error", "message": f"ROS init failed: {str(e)}"}
            self._bridge = None

    def process_command(self, cmd: dict):
        """Process a command and store result"""
        if not self._ros_initialized or self._bridge is None:
            self._last_response = {"status": "error", "message": "ROS2/MoveIt not available"}
            return

        command = cmd.get("cmd", "")

        try:
            if command == "solve_ik":
                target = cmd.get("target_position", [0, 0, 0])
                timeout = cmd.get("timeout", 0.5)
                self._last_response = self._bridge.solve_ik(target, timeout)

            elif command == "shutdown":
                self._last_response = {"status": "ok", "cmd": "shutdown"}

            else:
                self._last_response = {"status": "error", "message": f"Unknown command: {command}"}

        except Exception as e:
            self._last_response = {"status": "error", "message": str(e)}

    def get_response(self) -> dict:
        return self._last_response
