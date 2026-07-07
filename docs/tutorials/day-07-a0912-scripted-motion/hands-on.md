# Day 7 실습

## 오늘 만들 것

Day 6의 virtual A0912 bringup 위에서 Doosan `DSR_ROBOT2` Python API를 사용하는
초보자 scripted motion을 구성합니다. script는 `movej`로 known joint pose에 천천히
가고, `movel`로 작은 task-space motion을 실행합니다. 마지막에는 나중의 policy action을
`target_ee_delta + gripper_command`로 유지한다는 결정을 다시 연결합니다.

## 공식 튜토리얼 흐름

오늘의 중심 공식 튜토리얼은 `Doosan DSR_ROBOT2 Python Library Tutorial`입니다.

- Doosan DSR_ROBOT2 Python Library Tutorial:
  https://doosanrobotics.github.io/doosan-robotics-ros-manual/jazzy/tutorials/advanced_tutorials/dsr_robot_tutorial.html

Doosan tutorial의 package 구성과 실행 방식은 workspace setup에 맞춰 따릅니다. 이
문서에서는 초보자가 놓치기 쉬운 Python setup order와 motion primitive의 의미를
중심으로 봅니다.

## 시작하기 전에

Day 6의 virtual MoveIt bringup이 실행되어 있어야 합니다. real hardware에는 연결하지
않습니다.

```bash
ros2 launch dsr_bringup2 dsr_bringup2_moveit.launch.py \
  mode:=virtual \
  model:=a0912 \
  host:=127.0.0.1 \
  port:=12345
```

다른 container shell에서 ROS2와 Doosan workspace가 source되어 있는지 확인합니다.

```bash
source /etc/profile.d/nexus_env.bash
cd /workspace
ros2 pkg prefix dsr_bringup2
ros2 topic echo /joint_states --once
```

`/joint_states`가 보이지 않으면 script를 실행하기 전에 Day 6 bringup을 먼저 복구합니다.

## 1단계: DSR_ROBOT2 설정 패턴 읽기

Doosan `DSR_ROBOT2` Python Library Tutorial에서 `DR_init`, `ROBOT_ID`,
`ROBOT_MODEL`, ROS2 node setup, `DSR_ROBOT2` import 순서를 확인합니다. 오늘 가장
중요한 규칙은 `DSR_ROBOT2`를 너무 일찍 import하지 않는 것입니다.

순서는 아래처럼 읽으면 됩니다.

```text
set ROBOT_ID
set ROBOT_MODEL = "a0912"
create ROS2 node with namespace=ROBOT_ID
assign DR_init.__dsr__node
import DSR_ROBOT2
set_robot_mode(ROBOT_MODE_AUTONOMOUS)
call posj/posx with movej/movel
```

`ROBOT_ID`는 virtual bringup namespace와 맞아야 합니다. 예제에서는 `"dsr01"`을
사용하지만, 사용 중인 launch namespace가 다르면 그 값에 맞춥니다.

## 2단계: 초보자 motion script 만들기

개념용 script 형태:

```python
import rclpy
import DR_init

ROBOT_ID = "dsr01"
ROBOT_MODEL = "a0912"


def main(args=None):
    rclpy.init(args=args)

    DR_init.__dsr__id = ROBOT_ID
    DR_init.__dsr__model = ROBOT_MODEL

    node = rclpy.create_node("a0912_beginner_motion", namespace=ROBOT_ID)
    DR_init.__dsr__node = node

    from DSR_ROBOT2 import ROBOT_MODE_AUTONOMOUS
    from DSR_ROBOT2 import movej, movel, posj, posx, set_robot_mode

    try:
        set_robot_mode(ROBOT_MODE_AUTONOMOUS)

        ready = posj(0, 0, 90, 0, 90, 0)
        above_table = posx(450, 0, 500, 0, 180, 0)

        movej(ready, vel=10, acc=10)
        movel(above_table, vel=20, acc=20)
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
```

이 script는 conceptual shape입니다. Doosan tutorial에서 권장하는 package 구조나 실행
방식에 맞춰 파일 위치와 entry point를 정하세요. 중요한 것은 `DR_init.__dsr__node`를
assign한 뒤 `DSR_ROBOT2`를 import하는 순서와, 초보자에게 안전한 낮은 `vel`/`acc`입니다.

## 3단계: virtual A0912에만 script 실행하기

script를 실행하기 전에 RViz나 terminal에서 virtual A0912 bringup이 살아 있는지 다시
확인합니다.

```bash
ros2 topic echo /joint_states --once
```

Doosan tutorial의 실행 방식에 따라 script를 실행합니다. 예를 들어 Python file을 직접
실행하는 구조라면 source된 shell에서 실행하고, ROS2 package entry point로 만들었다면
`ros2 run`을 사용합니다. 어떤 방식이든 오늘은 `mode:=virtual`, `model:=a0912` bringup에만
연결합니다.

known joint pose로 움직이는 `movej`가 먼저 끝나는지 봅니다. 그다음 `movel`이 작은
task-space motion으로 이어지는지 확인합니다.

## 4단계: script 실행 중 joint state 보기

다른 terminal에서 `/joint_states`를 확인합니다.

```bash
ros2 topic echo /joint_states --once
ros2 topic hz /joint_states
```

`movej`는 `posj`로 만든 joint target을 향해 움직입니다. `movel`은 `posx`로 만든
task-space pose target을 향해 end-effector motion을 만듭니다. 둘 다 high-level Doosan
API command이고, 오늘은 command path 확인용으로만 작고 느리게 사용합니다.

## 5단계: scripted motion을 policy action과 연결하기

script가 성공하면 바로 learned policy로 넘어가지 않습니다. 먼저 오늘 확인한 것을
policy action contract와 연결합니다.

`movej`와 `movel`은 사람이 정한 scripted command입니다. ACT나 Diffusion Policy는
나중에 observation을 보고 action을 낼 것입니다. 이 curriculum에서는 그 action을
`target_ee_delta + gripper_command`로 둡니다.

`target_ee_delta`는 현재 end-effector pose에서 작게 이동하려는 의도입니다.
`gripper_command`는 open/close 같은 gripper intent입니다. joint-space pose를 직접
policy output으로 삼는 것보다 cube와 gripper의 상대 motion을 표현하기 쉽고, safety
gate에서 delta를 clamp하기도 쉽습니다.

## 확인하기

아래 내용을 확인합니다.

- script 안에서 `ROBOT_MODEL = "a0912"`를 사용합니다.
- ROS2 node를 `namespace=ROBOT_ID`로 만들고 `DR_init.__dsr__node`에 assign합니다.
- `DSR_ROBOT2` import가 node setup 뒤에 있습니다.
- `set_robot_mode(ROBOT_MODE_AUTONOMOUS)`를 motion command 전에 호출합니다.
- `posj`와 `movej`로 known joint pose에 천천히 이동합니다.
- `posx`와 `movel`로 작은 task-space motion을 천천히 실행합니다.
- 나중의 policy action은 `target_ee_delta + gripper_command`라고 설명할 수 있습니다.

## 막혔을 때

Python이 `DR_init` 또는 `DSR_ROBOT2`를 import하지 못하면 Doosan workspace가 build되고
현재 shell에서 source되어 있는지 확인합니다.

```bash
ros2 pkg prefix dsr_bringup2
```

script가 wrong namespace에 연결되는 것 같으면 `ROBOT_ID`가 virtual bringup namespace와
같은지 확인합니다. 초보자 예제의 `"dsr01"`이 항상 맞는 것은 아닙니다.

`DSR_ROBOT2` import 이후 node 관련 error가 나면 import 순서를 확인합니다.
`DR_init.__dsr__node`를 assign한 뒤 `DSR_ROBOT2`를 import해야 합니다.

robot이 움직이지 않으면 virtual bringup이 살아 있는지, controller가 active인지,
`set_robot_mode(ROBOT_MODE_AUTONOMOUS)`가 motion command 전에 호출됐는지 확인합니다.

motion이 빠르거나 불안하면 `vel`과 `acc`를 더 낮춥니다. 초보자 단계에서는 느린
motion이 맞습니다.

## 오늘 배운 것

Doosan `DSR_ROBOT2` script는 setup order가 중요합니다. `DR_init`에 `ROBOT_ID`와
`ROBOT_MODEL="a0912"`를 설정하고, namespace가 있는 ROS2 node를 만든 뒤,
`DR_init.__dsr__node`를 assign하고 나서 `DSR_ROBOT2`를 import합니다. 그런 다음
`set_robot_mode(ROBOT_MODE_AUTONOMOUS)`로 motion 준비를 하고, `posj`/`movej`와
`posx`/`movel`로 known scripted motion을 천천히 실행합니다. 이 안정적인 scripted
baseline 위에서 Day 8-9의 cube-pick sequence와 나중의 `target_ee_delta + gripper_command`
policy action을 해석할 수 있습니다.
