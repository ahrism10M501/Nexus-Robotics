# Beginner Wheel Robot Tutorial Design

## Goal

Guide a complete beginner through the first practical loop for robot simulation:

1. Open Isaac Sim.
2. Load a simple wheeled robot example.
3. Use ROS2 from the container to inspect topics.
4. Publish a `/cmd_vel` velocity command.
5. Confirm that the robot moves in simulation.

The tutorial intentionally avoids MoveIt2, PyTorch, and LeRobot at first. Those layers will be added only after the user understands the basic simulator-control loop.

## Audience

The user is new to ROS2, MoveIt2, Isaac Sim, Python libraries, and robot simulation. Every step should explain:

- What the command or UI action does.
- What success looks like.
- What to do if the expected result does not appear.

## Approach

Use the recommended beginner path:

1. Start with an Isaac Sim wheeled robot example, preferably the ROS2 TurtleBot or equivalent mobile robot tutorial.
2. Use ROS2 topic commands directly before writing custom code.
3. Build a tiny Python ROS2 node only after manual topic publishing works.
4. Treat PyTorch and LeRobot as later policy layers that will publish the same kind of robot commands.

## Components

- Isaac Sim: simulator and robot world.
- ROS2 Bridge: connection between Isaac Sim and external ROS2 commands.
- ROS2 CLI: beginner-friendly inspection and command publishing.
- Future Python node: simple publisher for `/cmd_vel`.

## Data Flow

```text
ROS2 terminal
  -> /cmd_vel geometry_msgs/msg/Twist
  -> Isaac Sim ROS2 Bridge
  -> wheeled robot controller
  -> robot moves in simulation
```

Later, the ROS2 terminal can be replaced by a Python node, and then by a PyTorch or LeRobot policy node.

## Success Criteria

- The user can open Isaac Sim and load a wheeled robot scene.
- The user can run `ros2 topic list` in the container.
- The user can identify or confirm the velocity command topic.
- The user can publish a forward velocity command.
- The robot visibly moves in Isaac Sim.
- The user can explain in plain language what `/cmd_vel` does.

## Error Handling

If the robot does not move:

- Confirm Isaac Sim is playing, not paused.
- Confirm the ROS2 Bridge extension is enabled.
- Confirm `ROS_DOMAIN_ID` matches between Isaac Sim and the container.
- Confirm `/cmd_vel` or the expected command topic exists.
- Confirm the message type is `geometry_msgs/msg/Twist`.

If no ROS2 topics appear:

- Check that the container sourced ROS2 setup.
- Check Fast DDS configuration and domain ID.
- Check that Isaac Sim is publishing ROS2 topics.

## Testing

The tutorial is verified interactively:

- `ros2 topic list` shows simulator topics.
- `ros2 topic echo` can observe relevant state topics when available.
- `ros2 topic pub` sends `/cmd_vel`.
- Isaac Sim viewport shows movement.

No automated tests are required for this first learning session.
