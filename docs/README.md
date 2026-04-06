# Robot Design Interface — Documentation

## Overview

A Godot 4.x robotics simulator with ROS 2 integration and blockchain-backed design sharing via ARIADNE.

**Status: In Development** — Core ROS 2 simulation is functional. AI code agent features are experimental.

---

## Contents

### [Getting Started](getting-started.md)
Quick start guide for new users.

### [godot_ros2 SDK](godot-ros2/README.md)
ROS 2 simulator plugin for Godot. Sensors, actuators, robot models, physics simulation.

### [ARIADNE Blockchain](arweave/README.md)
Decentralized robot design hosting on Arweave/AO blockchain.

### [Development](development/)
Coding standards, contributing guidelines, and code patterns.

---

## Quick Start

```bash
# Run headless
godot --headless --quit

# Open in editor
godot
```

---

## Architecture

```
┌──────────────────────────────────────────────────┐
│  Robot Design Interface                          │
│  ├── scripts/main.gd — UI Panel                  │
│  └── scenes/ — Robot scene files                 │
├──────────────────────────────────────────────────┤
│  godot_ros2 (addons/godot_ros2/)                │
│  ├── core/ — Robot bodies, physics, plugins      │
│  │   ├── actuator.gd, motor.gd, servo.gd        │
│  │   ├── thruster.gd, propeller.gd               │
│  │   ├── robot_model.gd, robot_link.gd          │
│  │   ├── robot_joint.gd, joint_controller.gd   │
│  │   ├── contact_manager.gd, differential_drive │
│  │   └── simulator_plugins/                     │
│  ├── sensors/ — Sensor classes                    │
│  │   ├── sensor.gd (base)                       │
│  │   ├── lidar_sensor.gd, camera_sensor.gd     │
│  │   ├── imu_sensor.gd, gps_sensor.gd          │
│  │   └── force_torque_sensor.gd, contact_sensor │
│  └── ros2/ — ROS 2 bridge client               │
├──────────────────────────────────────────────────┤
│  arweave/ — Blockchain integration               │
│  ├── ariadne_interface.gd — CLI wrapper         │
│  └── wallet_manager.gd — Wallet handling        │
└──────────────────────────────────────────────────┘
```

## Current Status

| Component | Status | Notes |
|-----------|--------|-------|
| godot_ros2 core | Working | Sensors, actuators, robot models |
| ROS 2 bridge | Working | TCP/UDP connection to godot_ros2_bridge |
| ARIADNE interface | New | Blockchain design sharing |
| AI code agent | Experimental | GameAI/ROSAI not yet verified |
