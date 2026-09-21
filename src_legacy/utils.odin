package game
import "core:math"
import lg "core:math/linalg"
import gl "vendor:raylib/rlgl"

@(private, require_results)
back :: proc(arr: [dynamic]$T) -> T {
	return arr[len(arr) - 1]
}

@(require_results)
euler_to_quaternion :: proc(euler_angles: [3]f32) -> quaternion128 {
	return lg.quaternion_from_euler_angles(
		euler_angles.y,
		euler_angles.x,
		euler_angles.z,
		.YXZ,
	)
}

@(require_results)
euler_degrees_to_quat :: proc(euler_angle_degrees: [3]f32) -> quaternion128 {
	angles := euler_angle_degrees * math.RAD_PER_DEG
	return lg.quaternion_from_euler_angles(angles.y, angles.x, angles.z, .YXZ)
}

@(require_results, deferred_none = gl.PopMatrix)
gl_transform_scope :: proc "contextless" (
	position: [3]f32,
	rotation: quaternion128,
) -> bool {
	gl.PushMatrix()

	angle, axis := lg.angle_axis_from_quaternion(rotation)
	gl.Translatef(position.x, position.y, position.z)
	gl.Rotatef(angle * math.DEG_PER_RAD, axis.x, axis.y, axis.z)

	return true
}
