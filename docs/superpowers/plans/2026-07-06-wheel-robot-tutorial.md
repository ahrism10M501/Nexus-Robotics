# Wheel Robot Tutorial Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Help a complete beginner drive a wheeled robot in Isaac Sim by publishing ROS2 `/cmd_vel` messages from the container.

**Architecture:** Isaac Sim runs the simulated robot and ROS2 Bridge. The Docker container runs ROS2 CLI commands. The first working loop is manual: ROS2 terminal publishes a velocity command, Isaac Sim receives it, and the robot moves.

**Tech Stack:** Isaac Sim, ROS2 Jazzy, Fast DDS, `geometry_msgs/msg/Twist`, Docker Compose.

---

## File Structure

No code files are required for the first tutorial pass.

- Read: `docs/superpowers/specs/2026-07-06-wheel-robot-tutorial-design.md`
- Optional future create: `src/control/nexus_control/` for a Python `/cmd_vel` publisher node.
- Optional future modify: `README.md` to document the final beginner workflow.

## Task 1: Confirm ROS2 Container Is Ready

**Files:**
- Read: `compose.yml`
- Read: `docker/nexus_env.bash`

- [ ] **Step 1: Open a container shell**

Run from the host project directory:

```bash
cd /workspace
./run.sh up
./run.sh shell
```

Expected:

```text
root@...:/workspace#
```

- [ ] **Step 2: Confirm ROS2 is available**

Run inside the container:

```bash
source /opt/ros/jazzy/setup.bash
which ros2
ros2 --help | head
```

Expected:

```text
/opt/ros/jazzy/bin/ros2
usage: ros2 ...
```

- [ ] **Step 3: Confirm ROS domain**

Run inside the container:

```bash
echo $ROS_DOMAIN_ID
```

Expected:

```text
42
```

If the output is empty or not `42`, run:

```bash
export ROS_DOMAIN_ID=42
```

## Task 2: Prepare Isaac Sim for ROS2

**Files:**
- No repository files changed.

- [ ] **Step 1: Launch Isaac Sim from a ROS-aware terminal**

On the machine where Isaac Sim is installed, launch it with the same ROS domain:

```bash
export ROS_DOMAIN_ID=42
export FASTRTPS_DEFAULT_PROFILES_FILE=/workspace/config/fastdds.xml
~/isaacsim/isaac-sim.sh
```

Expected:

```text
Isaac Sim GUI opens.
```

If Isaac Sim is installed somewhere else, replace `~/isaacsim/isaac-sim.sh` with the actual Isaac Sim launch path.

- [ ] **Step 2: Enable the ROS2 Bridge extension**

In Isaac Sim:

```text
Window -> Extensions
Search: ROS2 Bridge
Enable: isaacsim.ros2.bridge
```

Expected:

```text
The ROS2 Bridge extension is enabled without an error popup.
```

- [ ] **Step 3: Confirm simulation can play**

In Isaac Sim, press the Play button.

Expected:

```text
The timeline starts running.
```

If Play does nothing, wait for Isaac Sim to finish loading and try again.

## Task 3: Load or Create the Wheeled Robot Example

**Files:**
- No repository files changed.

- [ ] **Step 1: Try the built-in TurtleBot ROS2 tutorial path**

In Isaac Sim, follow the available sample/tutorial path for driving TurtleBot with ROS2 messages. The official tutorial is:

```text
Driving TurtleBot using ROS 2 Messages
```

Expected:

```text
A TurtleBot or equivalent two-wheeled robot is visible in the stage.
```

- [ ] **Step 2: Confirm the robot graph subscribes to `/cmd_vel`**

In the Action Graph or robot setup, confirm there is a ROS2 Subscribe Twist node with:

```text
topicName = /cmd_vel
```

Expected:

```text
The robot has a path from ROS2 Subscribe Twist -> Differential Controller -> Articulation Controller.
```

- [ ] **Step 3: Press Play**

Press Play in Isaac Sim after the robot scene is loaded.

Expected:

```text
The robot stays visible and physics simulation runs.
```

## Task 4: Verify ROS2 Can See Isaac Sim Topics

**Files:**
- No repository files changed.

- [ ] **Step 1: List ROS2 topics from the container**

Run inside the container:

```bash
source /opt/ros/jazzy/setup.bash
ros2 topic list
```

Expected output includes at least:

```text
/parameter_events
/rosout
```

Expected output should also include:

```text
/cmd_vel
```

- [ ] **Step 2: If `/cmd_vel` is missing, verify domain and bridge**

Run inside the container:

```bash
echo $ROS_DOMAIN_ID
```

Expected:

```text
42
```

Then in Isaac Sim, verify:

```text
ROS2 Bridge is enabled.
Simulation is playing.
The ROS2 Subscribe Twist node topic name is /cmd_vel.
The ROS2 Context node uses the environment domain ID or is set to 42.
```

## Task 5: Drive the Robot Forward

**Files:**
- No repository files changed.

- [ ] **Step 1: Publish a forward velocity**

Run inside the container:

```bash
ros2 topic pub /cmd_vel geometry_msgs/msg/Twist \
  "{linear: {x: 0.2, y: 0.0, z: 0.0}, angular: {x: 0.0, y: 0.0, z: 0.0}}" \
  -r 10
```

Expected:

```text
publisher: beginning loop
publishing #1: geometry_msgs.msg.Twist(...)
```

Isaac Sim expected:

```text
The wheeled robot moves forward slowly.
```

- [ ] **Step 2: Stop the robot**

Press `Ctrl+C` to stop the publishing command, then send one zero command:

```bash
ros2 topic pub --once /cmd_vel geometry_msgs/msg/Twist \
  "{linear: {x: 0.0, y: 0.0, z: 0.0}, angular: {x: 0.0, y: 0.0, z: 0.0}}"
```

Expected:

```text
The robot stops.
```

- [ ] **Step 3: Rotate the robot**

Run inside the container:

```bash
ros2 topic pub /cmd_vel geometry_msgs/msg/Twist \
  "{linear: {x: 0.0, y: 0.0, z: 0.0}, angular: {x: 0.0, y: 0.0, z: 0.5}}" \
  -r 10
```

Expected:

```text
The robot rotates in place.
```

Stop with `Ctrl+C`, then publish the zero command again.

## Task 6: Explain the First Loop Back to the User

**Files:**
- No repository files changed.

- [ ] **Step 1: Confirm the user can describe the flow**

Ask the user to explain this in their own words:

```text
ROS2 publishes /cmd_vel.
Isaac Sim ROS2 Bridge receives /cmd_vel.
The robot controller converts velocity into wheel motion.
The simulated robot moves.
```

Expected:

```text
The user understands that /cmd_vel is a velocity command, not a model or training result.
```

- [ ] **Step 2: Decide next tutorial**

Offer two next steps:

```text
Option A: Make a tiny Python ROS2 node that publishes /cmd_vel.
Option B: Add sensors like /camera or /joint_states and inspect observations.
```

Expected:

```text
The next session builds on the same working /cmd_vel loop.
```

## Self-Review

- Spec coverage: The plan covers opening Isaac Sim, loading a wheeled robot, inspecting ROS2 topics, publishing `/cmd_vel`, confirming movement, and explaining the concept.
- Placeholder scan: No placeholder or vague implementation steps remain.
- Type consistency: The plan consistently uses ROS2 Jazzy and `geometry_msgs/msg/Twist`.
