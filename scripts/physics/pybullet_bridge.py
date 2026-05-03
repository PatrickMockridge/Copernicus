#!/usr/bin/env python3
# pybullet_bridge.py
# Python bridge for PyBullet physics
# Receives JSON commands from stdin, executes, returns JSON responses
# Run by PyBulletBackend.gd as a subprocess

import pybullet as p
import pybullet_data
import json
import sys
import os
import socket
import argparse


class PyBulletBridge:
    def __init__(self):
        self.client_id = -1
        self.bodies = {}  # name -> body_id
        self.joints = {}  # name -> joint_id
        self.next_body_id = 0
        self.gravity = [0, -9.81, 0]
        self.timestep = 0.001
        self.running = True

    def send_response(self, response):
        """Send JSON response to stdout"""
        print(json.dumps(response), flush=True)

    def process_command(self, cmd):
        """Process a single command and send response"""
        command = cmd.get("cmd", "")

        try:
            if command == "init":
                self.cmd_init(cmd)
            elif command == "step":
                self.cmd_step(cmd)
            elif command == "get_state":
                self.cmd_get_state(cmd)
            elif command == "get_all_states":
                self.cmd_get_all_states(cmd)
            elif command == "create_body":
                self.cmd_create_body(cmd)
            elif command == "remove_body":
                self.cmd_remove_body(cmd)
            elif command == "apply_force":
                self.cmd_apply_force(cmd)
            elif command == "apply_torque":
                self.cmd_apply_torque(cmd)
            elif command == "reset_forces":
                self.cmd_reset_forces(cmd)
            elif command == "create_joint":
                self.cmd_create_joint(cmd)
            elif command == "remove_joint":
                self.cmd_remove_joint(cmd)
            elif command == "set_collision":
                self.cmd_set_collision(cmd)
            elif command == "get_contacts":
                self.cmd_get_contacts(cmd)
            elif command == "shutdown":
                self.cmd_shutdown(cmd)
            else:
                self.send_response({
                    "status": "error",
                    "cmd": command,
                    "message": f"Unknown command: {command}"
                })
        except Exception as e:
            self.send_response({
                "status": "error",
                "cmd": command,
                "message": str(e)
            })

    def cmd_init(self, cmd):
        """Initialize PyBullet"""
        self.gravity = cmd.get("gravity", [0, -9.81, 0])
        self.timestep = cmd.get("timestep", 0.001)

        # Connect to PyBullet in shared memory or GUI mode
        # Use shared memory for faster communication
        self.client_id = p.connect(p.SHARED_MEMORY)
        if self.client_id < 0:
            # Fallback to GUI if shared memory fails
            self.client_id = p.connect(p.GUI)

        p.setGravity(*self.gravity)
        p.setTimeStep(self.timestep)

        # Load default data (URDF paths, etc)
        p.setAdditionalSearchPath(pybullet_data.getDataPath())

        self.send_response({
            "status": "ok",
            "cmd": "init",
            "client_id": self.client_id
        })

    def cmd_step(self, cmd):
        """Step the simulation"""
        p.stepSimulation()
        self.send_response({"status": "ok", "cmd": "step"})

    def cmd_get_state(self, cmd):
        """Get state of a specific body"""
        name = cmd.get("name", "")
        if name not in self.bodies:
            self.send_response({
                "status": "error",
                "cmd": "get_state",
                "message": f"Body not found: {name}"
            })
            return

        body_id = self.bodies[name]
        pos, quat = p.getBasePositionAndOrientation(body_id)
        vel = p.getBaseVelocity(body_id)

        self.send_response({
            "status": "ok",
            "cmd": "get_state",
            "name": name,
            "data": {
                "pos": list(pos),
                "quat": list(quat),
                "vel": list(vel[0]),
                "avel": list(vel[1])
            }
        })

    def cmd_get_all_states(self, cmd):
        """Get states of all bodies"""
        states = {}
        for name, body_id in self.bodies.items():
            pos, quat = p.getBasePositionAndOrientation(body_id)
            vel = p.getBaseVelocity(body_id)
            states[name] = {
                "pos": list(pos),
                "quat": list(quat),
                "vel": list(vel[0]),
                "avel": list(vel[1])
            }

        self.send_response({
            "status": "ok",
            "cmd": "get_all_states",
            "data": states
        })

    def cmd_create_body(self, cmd):
        """Create a rigid body"""
        name = cmd.get("name", f"body_{self.next_body_id}")
        body_type = cmd.get("type", "box")
        pos = tuple(cmd.get("pos", [0, 1, 0]))
        quat = tuple(cmd.get("quat", [0, 0, 0, 1]))
        mass = cmd.get("mass", 1.0)

        if name in self.bodies:
            self.send_response({
                "status": "error",
                "cmd": "create_body",
                "message": f"Body already exists: {name}"
            })
            return

        collision_shape = -1
        visual_shape = -1

        if body_type == "box":
            size = tuple(cmd.get("size", [0.5, 0.5, 0.5]))
            collision_shape = p.createCollisionShape(p.GEOM_BOX, halfExtents=[s/2 for s in size])
            visual_shape = p.createVisualShape(p.GEOM_BOX, halfExtents=[s/2 for s in size], rgbaColor=[0.5, 0.5, 0.5, 1])

        elif body_type == "sphere":
            radius = cmd.get("radius", 0.5)
            collision_shape = p.createCollisionShape(p.GEOM_SPHERE, radius=radius)
            visual_shape = p.createVisualShape(p.GEOM_SPHERE, radius=radius, rgbaColor=[0.5, 0.8, 0.5, 1])

        elif body_type == "cylinder":
            radius = cmd.get("radius", 0.25)
            length = cmd.get("length", 0.5)
            collision_shape = p.createCollisionShape(p.GEOM_CYLINDER, radius=radius, height=length)
            visual_shape = p.createVisualShape(p.GEOM_CYLINDER, radius=radius, length=length, rgbaColor=[0.8, 0.5, 0.5, 1])

        elif body_type == "mesh":
            # For mesh loading, would need file path
            self.send_response({
                "status": "error",
                "cmd": "create_body",
                "message": "Mesh bodies not yet supported"
            })
            return

        else:
            self.send_response({
                "status": "error",
                "cmd": "create_body",
                "message": f"Unknown body type: {body_type}"
            })
            return

        # Create multi-body
        body_id = p.createMultiBody(
            baseMass=mass,
            baseCollisionShapeIndex=collision_shape,
            baseVisualShapeIndex=visual_shape,
            basePosition=pos,
            baseOrientation=quat
        )

        self.bodies[name] = body_id
        self.next_body_id += 1

        self.send_response({
            "status": "ok",
            "cmd": "create_body",
            "name": name,
            "body_id": body_id
        })

    def cmd_remove_body(self, cmd):
        """Remove a rigid body"""
        name = cmd.get("name", "")
        if name not in self.bodies:
            self.send_response({
                "status": "error",
                "cmd": "remove_body",
                "message": f"Body not found: {name}"
            })
            return

        body_id = self.bodies[name]
        p.removeBody(body_id)
        del self.bodies[name]

        self.send_response({"status": "ok", "cmd": "remove_body", "name": name})

    def cmd_apply_force(self, cmd):
        """Apply force to a body"""
        name = cmd.get("name", "")
        force = tuple(cmd.get("force", [0, 0, 0]))
        pos = tuple(cmd.get("pos", [0, 0, 0]))

        if name not in self.bodies:
            self.send_response({
                "status": "error",
                "cmd": "apply_force",
                "message": f"Body not found: {name}"
            })
            return

        body_id = self.bodies[name]
        p.applyExternalForce(body_id, -1, force, pos, p.WORLD_FRAME)

        self.send_response({"status": "ok", "cmd": "apply_force", "name": name})

    def cmd_apply_torque(self, cmd):
        """Apply torque to a body"""
        name = cmd.get("name", "")
        torque = tuple(cmd.get("torque", [0, 0, 0]))

        if name not in self.bodies:
            self.send_response({
                "status": "error",
                "cmd": "apply_torque",
                "message": f"Body not found: {name}"
            })
            return

        body_id = self.bodies[name]
        p.applyExternalTorque(body_id, -1, torque, p.WORLD_FRAME)

        self.send_response({"status": "ok", "cmd": "apply_torque", "name": name})

    def cmd_reset_forces(self, cmd):
        """Reset forces on a body"""
        name = cmd.get("name", "")
        if name not in self.bodies:
            self.send_response({
                "status": "error",
                "cmd": "reset_forces",
                "message": f"Body not found: {name}"
            })
            return

        # PyBullet doesn't have a direct "reset forces" - forces accumulate per step
        # To effectively reset, we would need to store applied forces and zero them
        self.send_response({"status": "ok", "cmd": "reset_forces", "name": name})

    def cmd_create_joint(self, cmd):
        """Create a joint between two bodies"""
        name = cmd.get("name", "")
        joint_type = cmd.get("type", "fixed")
        parent = cmd.get("parent", "")
        child = cmd.get("child", "")
        anchor_parent = tuple(cmd.get("anchor_parent", [0, 0, 0]))
        anchor_child = tuple(cmd.get("anchor_child", [0, 0, 0]))

        if parent not in self.bodies or child not in self.bodies:
            self.send_response({
                "status": "error",
                "cmd": "create_joint",
                "message": "Parent or child body not found"
            })
            return

        parent_id = self.bodies[parent]
        child_id = self.bodies[child]

        joint_type_map = {
            "revolute": p.JOINT_REVOLUTE,
            "prismatic": p.JOINT_PRISMATIC,
            "spherical": p.JOINT_SPHERICAL,
            "fixed": p.JOINT_FIXED
        }

        pybullet_type = joint_type_map.get(joint_type, p.JOINT_FIXED)

        joint_id = p.createConstraint(
            parent_id, -1,  # parent link (base)
            child_id, -1,   # child link (base)
            joint_type=pybullet_type,
            jointAxis=[1, 0, 0],
            parentFramePosition=anchor_parent,
            childFramePosition=anchor_child
        )

        self.joints[name] = joint_id

        self.send_response({
            "status": "ok",
            "cmd": "create_joint",
            "name": name,
            "joint_id": joint_id
        })

    def cmd_remove_joint(self, cmd):
        """Remove a joint"""
        name = cmd.get("name", "")
        if name not in self.joints:
            self.send_response({
                "status": "error",
                "cmd": "remove_joint",
                "message": f"Joint not found: {name}"
            })
            return

        joint_id = self.joints[name]
        p.removeConstraint(joint_id)
        del self.joints[name]

        self.send_response({"status": "ok", "cmd": "remove_joint", "name": name})

    def cmd_set_collision(self, cmd):
        """Enable/disable collision between bodies"""
        # PyBullet's collision filtering is complex
        # For now, just acknowledge
        self.send_response({"status": "ok", "cmd": "set_collision"})

    def cmd_get_contacts(self, cmd):
        """Get contact points for a body"""
        name = cmd.get("name", "")
        if name not in self.bodies:
            self.send_response({
                "status": "error",
                "cmd": "get_contacts",
                "message": f"Body not found: {name}"
            })
            return

        body_id = self.bodies[name]
        contacts = p.getContactPoints(body_id)

        contact_list = []
        for contact in contacts:
            contact_list.append({
                "pos": list(contact[5]),  # contact position
                "normal": list(contact[7]),  # normal on body A
                "depth": contact[8],  # penetration depth
                "other": contact[2]  # other body index
            })

        self.send_response({
            "status": "ok",
            "cmd": "get_contacts",
            "name": name,
            "contacts": contact_list
        })

    def cmd_shutdown(self, cmd):
        """Shutdown PyBullet connection"""
        self.running = False

        if self.client_id >= 0:
            p.disconnect(self.client_id)

        self.send_response({"status": "ok", "cmd": "shutdown"})
        sys.exit(0)


def run_tcp_server(port):
    """Run as a TCP server for persistent connection with Godot."""
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(("127.0.0.1", port))
    server.listen(1)
    sys.stderr.write(f"PyBullet bridge listening on 127.0.0.1:{port}
")
    sys.stderr.flush()
    conn, addr = server.accept()
    sys.stderr.write(f"Connected: {addr}
")
    sys.stderr.flush()

    bridge = PyBulletBridge()
    buffer = ""
    while bridge.running:
        try:
            data = conn.recv(4096).decode("utf-8")
            if not data:
                break
            buffer += data
            while "
" in buffer:
                line, buffer = buffer.split("
", 1)
                line = line.strip()
                if not line:
                    continue
                try:
                    cmd = json.loads(line)
                    bridge.send_response_impl = lambda resp: conn.sendall(
                        (json.dumps(resp) + "
").encode("utf-8")
                    )
                    # Override send_response to write to socket
                    old_send = bridge.send_response
                    def socket_send(resp):
                        conn.sendall((json.dumps(resp) + "
").encode("utf-8"))
                    bridge.send_response = socket_send
                    bridge.process_command(cmd)
                except json.JSONDecodeError as e:
                    conn.sendall((json.dumps({"status": "error", "message": str(e)}) + "
").encode("utf-8"))
        except (ConnectionResetError, BrokenPipeError):
            break
        except Exception as e:
            sys.stderr.write(f"Error: {e}
")
            sys.stderr.flush()
            break

    conn.close()
    server.close()


def main():
    parser = argparse.ArgumentParser(description="PyBullet IPC bridge")
    parser.add_argument("--tcp", action="store_true", help="Run in TCP server mode")
    parser.add_argument("--port", type=int, default=9876, help="TCP port (default: 9876)")
    args = parser.parse_args()

    if args.tcp:
        run_tcp_server(args.port)
    else:
        bridge = PyBulletBridge()
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            try:
                cmd = json.loads(line)
                bridge.process_command(cmd)
            except json.JSONDecodeError as e:
                print(json.dumps({"status": "error", "message": f"Invalid JSON: {e}"}), flush=True)
            if not bridge.running:
                break


if __name__ == "__main__":
    main()
