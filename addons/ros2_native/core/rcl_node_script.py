#!/usr/bin/env python3
# rcl_node_script.py
# Python ROS2 node for Godot - provides rclpy integration via temp file IPC

import json
import sys


class RclNodeScript:
    """Script-based rclpy wrapper for Godot GDScript"""

    def __init__(self):
        self.node = None
        self._last_response = {"status": "error", "message": "Not initialized"}
        self.publishers = {}
        self.subscribers = {}
        self.services = {}

    def _init_rcl(self, node_name: str):
        """Initialize rclpy node"""
        try:
            import rclpy
            from rclpy.node import Node

            if not rclpy.ok():
                rclpy.init(args=None)

            class GodotNode(Node):
                def __init__(self, name):
                    super().__init__(name)
                    self._publishers = {}
                    self._subscribers = {}

                def create_godot_publisher(self, topic: str, msg_type: str, qos: int = 10):
                    from rclpy.qos import QoSProfile
                    publisher = self.create_publisher(
                        self._get_msg_class(msg_type),
                        topic,
                        QoSProfile(depth=qos)
                    )
                    self._publishers[topic] = publisher
                    return publisher

                def create_godot_subscription(self, topic: str, msg_type: str, callback, qos: int = 10):
                    from rclpy.qos import QoSProfile
                    sub = self.create_subscription(
                        self._get_msg_class(msg_type),
                        topic,
                        callback,
                        QoSProfile(depth=qos)
                    )
                    self._subscribers[topic] = sub
                    return sub

                def _get_msg_class(self, msg_type: str):
                    # Map common msg types
                    msg_map = {
                        "geometry_msgs/PoseStamped": "geometry_msgs.msg.PoseStamped",
                        "geometry_msgs/Twist": "geometry_msgs.msg.Twist",
                        "geometry_msgs/Transform": "geometry_msgs.msg.Transform",
                        "sensor_msgs/JointState": "sensor_msgs.msg.JointState",
                        "sensor_msgs/Image": "sensor_msgs.msg.Image",
                        "sensor_msgs/PointCloud2": "sensor_msgs.msg.PointCloud2",
                        "nav_msgs/Path": "nav_msgs.msg.Path",
                        "nav_msgs/Odometry": "nav_msgs.msg.Odometry",
                        "nav_msgs/OccupancyGrid": "nav_msgs.msg.OccupancyGrid",
                        "std_msgs/String": "std_msgs.msg.String",
                        "std_msgs/Empty": "std_msgs.msg.Empty",
                    }
                    # Dynamic import
                    try:
                        parts = msg_type.split("/")
                        module_path = parts[0].replace("_", "") + ".msg"
                        msg_name = parts[1] if len(parts) > 1 else "Empty"
                        mod = __import__(module_path, fromlist=[msg_name])
                        return getattr(mod, msg_name)
                    except Exception:
                        return None

            self.node = GodotNode(node_name)
            self._rclpy = rclpy
            return True

        except ImportError as e:
            self._last_response = {"status": "error", "message": f"rclpy not available: {e}"}
            return False
        except Exception as e:
            self._last_response = {"status": "error", "message": str(e)}
            return False

    def process_command(self, cmd: dict):
        """Process a command from Godot"""
        command = cmd.get("cmd", "")

        try:
            if command == "init":
                node_name = cmd.get("node_name", "godot_node")
                if self._init_rcl(node_name):
                    self._last_response = {"status": "ok", "cmd": "init", "node_name": node_name}
                else:
                    # ROS not available - still return ok but mark as unavailable
                    self._last_response = {"status": "ok", "cmd": "init", "ros_available": False}

            elif command == "shutdown":
                if self.node:
                    self.node.destroy_node()
                    if self._rclpy.ok():
                        self._rclpy.shutdown()
                self._last_response = {"status": "ok", "cmd": "shutdown"}

            elif command == "create_publisher":
                if not self.node:
                    self._last_response = {"status": "error", "message": "Node not initialized"}
                    return
                topic = cmd.get("topic", "")
                msg_type = cmd.get("msg_type", "std_msgs/String")
                qos = cmd.get("qos", 10)
                self.node.create_godot_publisher(topic, msg_type, qos)
                self.publishers[topic] = msg_type
                self._last_response = {"status": "ok", "cmd": "create_publisher", "topic": topic}

            elif command == "publish":
                if not self.node:
                    self._last_response = {"status": "error", "message": "Node not initialized"}
                    return
                topic = cmd.get("topic", "")
                message = cmd.get("message", {})
                if topic in self.publishers and self.node:
                    pub = self.node._publishers.get(topic)
                    if pub:
                        # Create message from dict
                        msg = self._dict_to_msg(message)
                        if msg:
                            pub.publish(msg)
                self._last_response = {"status": "ok", "cmd": "publish"}

            elif command == "create_subscription":
                if not self.node:
                    self._last_response = {"status": "error", "message": "Node not initialized"}
                    return
                topic = cmd.get("topic", "")
                msg_type = cmd.get("msg_type", "std_msgs/String")
                qos = cmd.get("qos", 10)
                self.node.create_godot_subscription(topic, msg_type, lambda msg: None, qos)
                self.subscribers[topic] = msg_type
                self._last_response = {"status": "ok", "cmd": "create_subscription", "topic": topic}

            elif command == "get_time":
                if self.node:
                    now = self.node.get_clock().now()
                    self._last_response = {
                        "status": "ok",
                        "time": now.nanoseconds / 1e9
                    }
                else:
                    self._last_response = {"status": "ok", "time": 0.0}

            elif command == "spin_once":
                if self.node:
                    self._rclpy.spin_once(self.node, timeout_sec=0.001)
                self._last_response = {"status": "ok"}

            else:
                self._last_response = {"status": "error", "message": f"Unknown command: {command}"}

        except Exception as e:
            self._last_response = {"status": "error", "message": str(e)}

    def _dict_to_msg(self, data: dict):
        """Convert dictionary to ROS message"""
        try:
            # Try to create appropriate message type
            if not data:
                return None

            # Handle geometry_msgs/PoseStamped
            if "pose" in data:
                from geometry_msgs.msg import PoseStamped, Pose, Point, Quaternion
                msg = PoseStamped()
                if "header" in data:
                    msg.header.stamp = self.node.get_clock().now().to_msg()
                    msg.header.frame_id = data["header"].get("frame_id", "map")
                if "pose" in data:
                    p = data["pose"]
                    if "position" in p:
                        msg.pose.position.x = p["position"].get("x", 0)
                        msg.pose.position.y = p["position"].get("y", 0)
                        msg.pose.position.z = p["position"].get("z", 0)
                    if "orientation" in p:
                        msg.pose.orientation.x = p["orientation"].get("x", 0)
                        msg.pose.orientation.y = p["orientation"].get("y", 0)
                        msg.pose.orientation.z = p["orientation"].get("z", 0)
                        msg.pose.orientation.w = p["orientation"].get("w", 1)
                return msg

            # Handle geometry_msgs/Twist
            if "linear" in data:
                from geometry_msgs.msg import Twist
                msg = Twist()
                msg.linear.x = data["linear"].get("x", 0)
                msg.linear.y = data["linear"].get("y", 0)
                msg.linear.z = data["linear"].get("z", 0)
                msg.angular.x = data["angular"].get("x", 0)
                msg.angular.y = data["angular"].get("y", 0)
                msg.angular.z = data["angular"].get("z", 0)
                return msg

            return None

        except Exception:
            return None


if __name__ == "__main__":
    # Standalone test
    node = RclNodeScript()
    print(json.dumps({"status": "ok", "message": "rcl_node_script ready"}))