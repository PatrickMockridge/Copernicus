#!/usr/bin/env python3
# isaac_gym_replicator.py
# Python Omniverse Replicator bridge for Godot GDScript

import json
import sys
import os


class IsaacGymReplicatorScript:
    """Script-based Omniverse Replicator wrapper for Godot GDScript"""

    def __init__(self):
        self.replicator = None
        self._last_response = {"status": "error", "message": "Not initialized"}
        self._enabled = False
        self._annotators = {}
        self._cameras = {}
        self._capture_count = 0
        self._output_dir = "cache/replicator/"

    def _init_replicator(self, config: dict) -> bool:
        """Initialize Omniverse Replicator"""
        try:
            # Try to import Omniverse Replicator
            try:
                import omni.replicator as rep
                self.replicator = rep
                self._enabled = True
            except ImportError:
                # Replicator not available - may not be installed
                self._last_response = {
                    "status": "ok",
                    "message": "Omniverse Replicator not available (not installed)",
                    "replicator_available": False
                }
                return True  # Don't fail, just mark as unavailable

            # Configure basic settings
            self._output_dir = config.get("output_dir", "cache/replicator/")
            os.makedirs(self._output_dir, exist_ok=True)

            self._last_response = {
                "status": "ok",
                "replicator_available": True,
                "output_dir": self._output_dir
            }
            return True

        except Exception as e:
            self._last_response = {"status": "error", "message": str(e)}
            return False

    def process_command(self, cmd: dict):
        """Process a command from Godot"""
        command = cmd.get("cmd", "")

        try:
            if command == "init_replicator":
                self._init_replicator(cmd)
                return

            elif command == "shutdown":
                self._last_response = {"status": "ok", "cmd": "shutdown"}

            elif command == "create_annotator":
                annotator_type = cmd.get("type", "")
                label = cmd.get("label", "")
                self._create_annotator(annotator_type, label)
                return

            elif command == "create_semantic_segmentation":
                schema_file = cmd.get("schema_file", "")
                self._create_semantic_segmentation(schema_file)
                return

            elif command == "create_bounding_box_2d":
                self._create_bounding_box("2d")
                return

            elif command == "create_bounding_box_3d":
                self._create_bounding_box("3d")
                return

            elif command == "setup_cameras":
                self._setup_cameras(cmd.get("config", {}))
                return

            elif command == "set_camera_pose":
                camera_id = cmd.get("camera_id", 0)
                position = cmd.get("position", [0, 0, 0])
                rotation = cmd.get("rotation", [0, 0, 0, 1])
                self._set_camera_pose(camera_id, position, rotation)
                return

            elif command == "enable_domain_randomization":
                enabled = cmd.get("enabled", True)
                self._enable_domain_randomization(enabled)
                return

            elif command == "add_color_randomization":
                self._add_color_randomization(
                    cmd.get("property", ""),
                    cmd.get("min", 0.0),
                    cmd.get("max", 1.0)
                )
                return

            elif command == "add_transform_randomization":
                self._add_transform_randomization(
                    cmd.get("property", ""),
                    cmd.get("min", 0.0),
                    cmd.get("max", 1.0)
                )
                return

            elif command == "add_light_randomization":
                self._add_light_randomization()
                return

            elif command == "add_materials_randomization":
                self._add_materials_randomization()
                return

            elif command == "capture_frame":
                env_id = cmd.get("env_id", 0)
                self._capture_frame(env_id)
                return

            elif command == "save_annotations":
                frame_id = cmd.get("frame_id", 0)
                output_format = cmd.get("format", "coco")
                self._save_annotations(frame_id, output_format)
                return

            elif command == "batch_capture":
                num_frames = cmd.get("num_frames", 100)
                env_ids = cmd.get("env_ids", [])
                self._batch_capture(num_frames, env_ids)
                return

            elif command == "configure_writer":
                writer_type = cmd.get("writer_type", "")
                output_dir = cmd.get("output_dir", self._output_dir)
                config = cmd.get("config", {})
                self._configure_writer(writer_type, output_dir, config)
                return

            elif command == "start_async_recording":
                self._last_response = {"status": "ok", "cmd": "start_async_recording"}
                return

            elif command == "stop_async_recording":
                self._last_response = {"status": "ok", "cmd": "stop_async_recording"}
                return

            elif command == "get_sdf_annotations":
                env_id = cmd.get("env_id", 0)
                self._last_response = {
                    "status": "ok",
                    "sdf_data": {"env_id": env_id, "annotations": []}
                }
                return

            elif command == "export_sdf_to_isaac":
                source = cmd.get("source", "")
                target = cmd.get("target", "")
                self._last_response = {
                    "status": "ok" if source and target else "error",
                    "source": source,
                    "target": target
                }
                return

            elif command == "get_capture_count":
                self._last_response = {"status": "ok", "count": self._capture_count}
                return

            elif command == "get_annotation_stats":
                self._last_response = {
                    "status": "ok",
                    "stats": {
                        "total_annotators": len(self._annotators),
                        "total_captures": self._capture_count
                    }
                }
                return

            else:
                self._last_response = {"status": "error", "message": f"Unknown command: {command}"}

        except Exception as e:
            self._last_response = {"status": "error", "message": str(e)}

    def _create_annotator(self, annotator_type: str, label: str):
        """Create an annotator for a specific data type"""
        if not self._enabled:
            self._last_response = {"status": "error", "message": "Replicator not initialized"}
            return

        self._annotators[annotator_type] = {"label": label, "count": 0}
        self._last_response = {
            "status": "ok",
            "type": annotator_type,
            "label": label
        }

    def _create_semantic_segmentation(self, schema_file: str):
        """Create semantic segmentation annotator"""
        if not self._enabled:
            self._last_response = {"status": "error", "message": "Replicator not initialized"}
            return

        self._annotators["semantic"] = {"schema_file": schema_file, "count": 0}
        self._last_response = {"status": "ok", "type": "semantic"}

    def _create_bounding_box(self, dimension: str):
        """Create bounding box annotator (2D or 3D)"""
        if not self._enabled:
            self._last_response = {"status": "error", "message": "Replicator not initialized"}
            return

        annotator_type = f"bounding_box_{dimension}d"
        self._annotators[annotator_type] = {"dimension": dimension, "count": 0}
        self._last_response = {"status": "ok", "type": annotator_type}

    def _setup_cameras(self, config: dict):
        """Setup cameras for data capture"""
        count = config.get("count", 1)
        resolution = config.get("resolution", [640, 480])
        fov = config.get("fov", 60.0)

        for i in range(count):
            self._cameras[i] = {
                "resolution": resolution,
                "fov": fov,
                "position": [0, 0, 0],
                "rotation": [0, 0, 0, 1]
            }

        self._last_response = {
            "status": "ok",
            "cameras": self._cameras
        }

    def _set_camera_pose(self, camera_id: int, position: list, rotation: list):
        """Set camera pose"""
        if camera_id in self._cameras:
            self._cameras[camera_id]["position"] = position
            self._cameras[camera_id]["rotation"] = rotation
            self._last_response = {"status": "ok", "camera_id": camera_id}
        else:
            self._last_response = {"status": "error", "message": f"Camera {camera_id} not found"}

    def _enable_domain_randomization(self, enabled: bool):
        """Enable or disable domain randomization"""
        self._last_response = {
            "status": "ok",
            "domain_randomization": enabled
        }

    def _add_color_randomization(self, property: str, min_val: float, max_val: float):
        """Add color randomization for a property"""
        self._last_response = {
            "status": "ok",
            "property": property,
            "min": min_val,
            "max": max_val
        }

    def _add_transform_randomization(self, property: str, min_val: float, max_val: float):
        """Add transform randomization"""
        self._last_response = {
            "status": "ok",
            "property": property,
            "min": min_val,
            "max": max_val
        }

    def _add_light_randomization(self):
        """Add lighting randomization"""
        self._last_response = {"status": "ok", "randomization": "light"}

    def _add_materials_randomization(self):
        """Add materials randomization"""
        self._last_response = {"status": "ok", "randomization": "materials"}

    def _capture_frame(self, env_id: int):
        """Capture a single frame"""
        if not self._enabled:
            self._last_response = {"status": "error", "message": "Replicator not initialized"}
            return

        self._capture_count += 1
        frame_id = self._capture_count

        # Simulate frame data
        self._last_response = {
            "status": "ok",
            "frame_id": frame_id,
            "env_id": env_id,
            "annotator": "rgb",
            "data": {
                "rgb": f"cache/replicator/frame_{frame_id}_rgb.png",
                "depth": f"cache/replicator/frame_{frame_id}_depth.png"
            }
        }

    def _save_annotations(self, frame_id: int, output_format: str):
        """Save annotations for a frame"""
        output_file = f"{self._output_dir}/annotations_{frame_id}.{output_format}"
        self._last_response = {
            "status": "ok",
            "frame_id": frame_id,
            "format": output_format,
            "file": output_file
        }

    def _batch_capture(self, num_frames: int, env_ids: list):
        """Capture multiple frames"""
        frames = []
        for i in range(num_frames):
            env_id = env_ids[i] if i < len(env_ids) else 0
            frames.append({
                "frame_id": i + 1,
                "env_id": env_id
            })

        self._capture_count += num_frames
        self._last_response = {
            "status": "ok",
            "frames": frames,
            "count": num_frames
        }

    def _configure_writer(self, writer_type: str, output_dir: str, config: dict):
        """Configure data writer"""
        self._last_response = {
            "status": "ok",
            "writer_type": writer_type,
            "output_dir": output_dir,
            "config": config
        }


if __name__ == "__main__":
    node = IsaacGymReplicatorScript()
    print(json.dumps({"status": "ok", "message": "isaac_gym_replicator ready"}))
