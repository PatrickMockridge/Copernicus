#!/usr/bin/env python3
# moveit_bridge.py
# Python ROS2 node that bridges to MoveIt IK service.
# Two modes:
#   --tcp   : JSON-lines TCP server (used by Godot via PythonBridge)
#   (stdin) : JSON-lines over stdin/stdout (manual testing)
# ROS2/MoveIt are imported lazily so the TCP server can report clean errors
# when the dependencies are missing instead of crashing before it binds.

import sys
import json
import argparse
import socket


class MoveItBridge:
    """Thin wrapper around the MoveIt /compute_ik ROS2 service."""

    def __init__(self, robot_description="robot_description", group="manipulator"):
        import rclpy
        from rclpy.node import Node
        from moveit_msgs.srv import GetPositionIK

        if not rclpy.ok():
            rclpy.init(args=None)
        self._rclpy = rclpy
        self._GetPositionIK = GetPositionIK

        self._node = Node("moveit_ik_bridge")
        self.robot_description = robot_description
        self.group = group
        self.ik_client = self._node.create_client(GetPositionIK, "/compute_ik")

        # Do not block forever: give MoveIt a couple seconds to be reachable.
        ready = self.ik_client.wait_for_service(timeout_sec=2.0)
        if not ready:
            raise RuntimeError("MoveIt /compute_ik service not available")

    def solve_ik(self, target_position, timeout=0.5):
        request = self._GetPositionIK.Request()
        request.ik_request.group_name = self.group
        request.ik_request.robot_description = self.robot_description
        request.ik_request.avoid_collisions = True
        request.ik_request.timeout.sec = int(timeout)
        request.ik_request.timeout.nanosec = int((timeout % 1) * 1e9)

        request.ik_request.pose_stamped.header.frame_id = "base_link"
        request.ik_request.pose_stamped.pose.position.x = target_position[0]
        request.ik_request.pose_stamped.pose.position.y = target_position[1]
        request.ik_request.pose_stamped.pose.position.z = target_position[2]
        request.ik_request.pose_stamped.pose.orientation.w = 1.0

        try:
            future = self.ik_client.call_async(request)
            self._rclpy.spin_until_future_complete(self._node, future, timeout_sec=timeout)
            response = future.result()
            if response is None:
                return {"status": "error", "message": "IK service call timed out", "solution": {}, "distance": float("inf")}
            if response.error_code.val != 1:  # moveit_msgs.msg.MoveItErrorCodes.SUCCESS == 1
                return {"status": "error", "message": "IK failed with error code %d" % response.error_code.val, "solution": {}, "distance": float("inf")}
            return {
                "status": "ok",
                "solution": {
                    "joint_names": list(response.solution.joint_state.name),
                    "joint_positions": list(response.solution.joint_state.position),
                },
                "distance": 0.0,
            }
        except Exception as e:
            return {"status": "error", "message": str(e), "solution": {}, "distance": float("inf")}

    def shutdown(self):
        try:
            self._node.destroy_node()
            if self._rclpy.ok():
                self._rclpy.shutdown()
        except Exception:
            pass


def _make_bridge(robot_description, group):
    try:
        return MoveItBridge(robot_description, group)
    except Exception as e:
        return None, {"status": "error", "message": "ROS2/MoveIt unavailable: %s" % e}


def process_cmd(cmd, bridge_state):
    """Handle one command dict. bridge_state is a list so we can lazily create + cache the bridge."""
    action = cmd.get("cmd", "")
    if action == "shutdown":
        return {"status": "ok", "cmd": "shutdown"}, True
    if action == "solve_ik":
        if bridge_state["bridge"] is None:
            bridge, err = _make_bridge(
                cmd.get("robot_description", "robot_description"),
                cmd.get("group", "manipulator"),
            )
            if bridge is None:
                return err, False
            bridge_state["bridge"] = bridge
        target = cmd.get("target_position", [0.0, 0.0, 0.0])
        timeout = cmd.get("timeout", 0.5)
        return bridge_state["bridge"].solve_ik(target, timeout), False
    return {"status": "error", "message": "Unknown command: %s" % action}, False


def run_tcp_server(port, robot_description, group):
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(("127.0.0.1", port))
    server.listen(1)
    sys.stderr.write("MoveIt bridge listening on 127.0.0.1:%d\n" % port)
    sys.stderr.flush()

    conn, _addr = server.accept()
    bridge_state = {"bridge": None}
    buffer = ""
    while True:
        try:
            data = conn.recv(4096).decode("utf-8")
            if not data:
                break
            buffer += data
            while "\n" in buffer:
                line, buffer = buffer.split("\n", 1)
                line = line.strip()
                if not line:
                    continue
                try:
                    cmd = json.loads(line)
                except json.JSONDecodeError:
                    conn.sendall((json.dumps({"status": "error", "message": "Invalid JSON"}) + "\n").encode("utf-8"))
                    continue
                cmd.setdefault("robot_description", robot_description)
                cmd.setdefault("group", group)
                response, shutdown = process_cmd(cmd, bridge_state)
                conn.sendall((json.dumps(response) + "\n").encode("utf-8"))
                if shutdown:
                    if bridge_state["bridge"] is not None:
                        bridge_state["bridge"].shutdown()
                    conn.close()
                    server.close()
                    return
        except (ConnectionResetError, BrokenPipeError):
            break
    if bridge_state["bridge"] is not None:
        bridge_state["bridge"].shutdown()
    conn.close()
    server.close()


def run_stdin(robot_description, group):
    bridge_state = {"bridge": None}
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            cmd = json.loads(line)
        except json.JSONDecodeError:
            print(json.dumps({"status": "error", "message": "Invalid JSON"}), flush=True)
            continue
        cmd.setdefault("robot_description", robot_description)
        cmd.setdefault("group", group)
        response, shutdown = process_cmd(cmd, bridge_state)
        print(json.dumps(response), flush=True)
        if shutdown:
            break
    if bridge_state["bridge"] is not None:
        bridge_state["bridge"].shutdown()


def main():
    parser = argparse.ArgumentParser(description="MoveIt IK bridge")
    parser.add_argument("--tcp", action="store_true", help="Run in TCP server mode")
    parser.add_argument("--port", type=int, default=9880, help="TCP port (default: 9880)")
    parser.add_argument("--robot-description", default="robot_description")
    parser.add_argument("--group", default="manipulator")
    args = parser.parse_args()

    if args.tcp:
        run_tcp_server(args.port, args.robot_description, args.group)
    else:
        run_stdin(args.robot_description, args.group)


if __name__ == "__main__":
    main()
