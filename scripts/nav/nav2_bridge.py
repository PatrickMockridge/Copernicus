#!/usr/bin/env python3
# nav2_bridge.py
# ROS2 node that bridges Copernicus to Nav2 for industry-standard navigation
# Provides path planning, SLAM, and localization via Nav2 stack

import json
import sys
import threading

try:
    import rclpy
    from rclpy.node import Node
    from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy
except ImportError:
    print(json.dumps({"status": "error", "message": "ROS2 Python not available. Install: pip install rclpy"}))
    sys.exit(1)

from geometry_msgs.msg import PoseStamped, Pose, Quaternion, Point
from nav_msgs.msg import Path as NavPath, OccupancyGrid
from nav2_msgs.srv import ComputePathToPose, ClearEntireCostmap
from std_srvs.srv import Empty
from tf_transformations import quaternion_from_euler, euler_from_quaternion


class Nav2Bridge(Node):
    """Bridge node between Copernicus and ROS2 Nav2"""

    def __init__(self):
        super().__init__('copernicus_nav2_bridge')

        # Publishers/Subscribers
        self._goal_pub = self.create_publisher(PoseStamped, '/goal_pose', 10)
        self._initial_pose_pub = self.create_publisher(PoseStamped, '/initialpose', 10)

        # Subscribers
        self._path_sub = self.create_subscription(
            NavPath,
            '/plan',
            self._path_callback,
            10
        )
        self._map_sub = self.create_subscription(
            OccupancyGrid,
            '/map',
            self._map_callback,
            QoSProfile(
                reliability=ReliabilityPolicy.RELIABLE,
                history=HistoryPolicy.KEEP_LAST,
                depth=1
            )
        )

        # Service clients
        self._compute_path_client = self.create_client(
            ComputePathToPose,
            '/compute_path_to_pose'
        )
        self._clear_costmap_client = self.create_client(
            ClearEntireCostmap,
            '/global_costmap/clear_entire_costmap'
        )

        # State
        self._current_path = []
        self._map_received = False
        self._last_request_id = 0

        # Wait for services
        self.get_logger().info('Waiting for Nav2 services...')
        while not self._compute_path_client.wait_for_service(timeout_sec=1.0):
            if not rclpy.ok():
                return
        self.get_logger().info('Nav2 services ready')

        self.get_logger().info('Copernicus Nav2 Bridge initialized')

    def _map_callback(self, msg: OccupancyGrid):
        """Handle incoming map updates"""
        self._map_received = True
        self.get_logger().debug(f'Map received: {msg.info.width}x{msg.info.height}')

    def _path_callback(self, msg: NavPath):
        """Handle path updates from Nav2"""
        self._current_path = []
        for pose in msg.poses:
            p = pose.pose.position
            self._current_path.append([p.x, p.y, p.z])

    def compute_path(self, start: list, goal: list, planner_id: str = "GridBased") -> dict:
        """Compute path from start to goal using Nav2"""
        if not self._map_received:
            return {"status": "error", "message": "No map received. Ensure SLAM is running."}

        # Wait for service
        if not self._compute_path_client.wait_for_service(timeout_sec=5.0):
            return {"status": "error", "message": "Compute path service unavailable"}

        # Create request
        request = ComputePathToPose.Request()
        request.goal.pose.header.stamp = self.get_clock().now().to_msg()
        request.goal.pose.header.frame_id = "map"
        request.goal.pose.pose.position = Point(x=goal[0], y=goal[1], z=goal[2])
        request.goal.pose.pose.orientation = Quaternion(w=1.0, x=0.0, y=0.0, z=0.0)

        request.start.pose.header.stamp = self.get_clock().now().to_msg()
        request.start.pose.header.frame_id = "map"
        request.start.pose.pose.position = Point(x=start[0], y=start[1], z=start[2])
        request.start.pose.pose.orientation = Quaternion(w=1.0, x=0.0, y=0.0, z=0.0)

        request.planner_id = planner_id

        # Call service
        future = self._compute_path_client.call_async(request)
        rclpy.spin_until_future_complete(self, future, timeout_sec=10.0)

        if future.result() is None:
            return {"status": "error", "message": "Path computation failed"}

        response = future.result()
        if response.error_code != 0:
            return {"status": "error", "message": f"Nav2 error code: {response.error_code}"}

        # Extract path
        path = []
        for pose in response.path.poses:
            p = pose.pose.position
            path.append([p.x, p.y, p.z])

        return {
            "status": "ok",
            "cmd": "plan",
            "path": path,
            "error_code": response.error_code
        }

    def localize_robot(self, position: list, rotation: list) -> dict:
        """Set robot's estimated pose for AMCL localization"""
        pose = PoseStamped()
        pose.header.stamp = self.get_clock().now().to_msg()
        pose.header.frame_id = "map"
        pose.pose.position = Point(x=position[0], y=position[1], z=position[2])

        # Convert euler to quaternion
        q = quaternion_from_euler(rotation[0], rotation[1], rotation[2])
        pose.pose.orientation = Quaternion(x=q[0], y=q[1], z=q[2], w=q[3])

        self._initial_pose_pub.publish(pose)

        return {"status": "ok", "cmd": "localize"}

    def clear_costmap(self) -> dict:
        """Clear the navigation costmap"""
        if not self._clear_costmap_client.wait_for_service(timeout_sec=5.0):
            return {"status": "error", "message": "Clear costmap service unavailable"}

        request = ClearEntireCostmap.Request()
        future = self._clear_costmap_client.call_async(request)
        rclpy.spin_until_future_complete(self, future, timeout_sec=5.0)

        if future.result() is not None:
            return {"status": "ok", "cmd": "clear_costmap"}
        return {"status": "error", "message": "Clear costmap failed"}

    def start_navigation(self) -> dict:
        """Start Nav2 navigation"""
        # Nav2 handles this via action servers
        # This is a placeholder for lifecycle management
        return {"status": "ok", "cmd": "start"}

    def stop_navigation(self) -> dict:
        """Stop Nav2 navigation"""
        # Could send cancel via action client
        return {"status": "ok", "cmd": "stop"}


def main():
    """Main entry point"""
    rclpy.init(args=sys.argv)

    bridge = Nav2Bridge()

    # Process requests from stdin (JSON lines)
    try:
        while rclpy.ok():
            line = input().strip()
            if not line:
                continue

            try:
                request = json.loads(line)
                cmd = request.get("cmd", "")

                if cmd == "plan":
                    start = request.get("start", [0, 0, 0])
                    goal = request.get("goal", [0, 0, 0])
                    planner_id = request.get("planner_id", "GridBased")
                    result = bridge.compute_path(start, goal, planner_id)
                    print(json.dumps(result), flush=True)

                elif cmd == "localize":
                    pos = request.get("position", [0, 0, 0])
                    rot = request.get("rotation", [0, 0, 0])
                    result = bridge.localize_robot(pos, rot)
                    print(json.dumps(result), flush=True)

                elif cmd == "clear_costmap":
                    result = bridge.clear_costmap()
                    print(json.dumps(result), flush=True)

                elif cmd == "start":
                    result = bridge.start_navigation()
                    print(json.dumps(result), flush=True)

                elif cmd == "stop":
                    result = bridge.stop_navigation()
                    print(json.dumps(result), flush=True)

                elif cmd == "shutdown":
                    print(json.dumps({"status": "ok", "cmd": "shutdown"}), flush=True)
                    break

                else:
                    print(json.dumps({"status": "error", "message": f"Unknown command: {cmd}"}), flush=True)

            except json.JSONDecodeError as e:
                print(json.dumps({"status": "error", "message": f"JSON parse error: {str(e)}"}), flush=True)

    except EOFError:
        pass
    except KeyboardInterrupt:
        pass
    finally:
        bridge.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()


class Nav2BridgeStandalone:
    """Standalone bridge for temp file IPC (used by Godot GDScript)"""

    def __init__(self):
        self._last_response = {"status": "error", "message": "Not initialized"}
        self._ros_initialized = False

        try:
            if not rclpy.ok():
                rclpy.init(args=sys.argv)
            self._node = Nav2Bridge()
            self._ros_initialized = True
        except Exception as e:
            self._last_response = {"status": "error", "message": f"ROS init failed: {str(e)}"}
            self._node = None

    def process_command(self, cmd: dict):
        """Process a command and store result"""
        if not self._ros_initialized or self._node is None:
            self._last_response = {"status": "error", "message": "ROS2 not initialized"}
            return

        command = cmd.get("cmd", "")

        try:
            if command == "plan":
                start = cmd.get("start", [0, 0, 0])
                goal = cmd.get("goal", [0, 0, 0])
                planner_id = cmd.get("planner_id", "GridBased")
                self._last_response = self._node.compute_path(start, goal, planner_id)

            elif command == "localize":
                pos = cmd.get("position", [0, 0, 0])
                rot = cmd.get("rotation", [0, 0, 0])
                self._last_response = self._node.localize_robot(pos, rot)

            elif command == "clear_costmap":
                self._last_response = self._node.clear_costmap()

            elif command == "start":
                self._last_response = self._node.start_navigation()

            elif command == "stop":
                self._last_response = self._node.stop_navigation()

            elif command == "shutdown":
                self._last_response = {"status": "ok", "cmd": "shutdown"}

            else:
                self._last_response = {"status": "error", "message": f"Unknown command: {command}"}

        except Exception as e:
            self._last_response = {"status": "error", "message": str(e)}

    def get_response(self) -> dict:
        return self._last_response
