package renderer

import "core:fmt"
import "core:math"
import lg "core:math/linalg"
import wgpu "vendor:wgpu"

Camera :: struct {
	aspect_ratio:           f32,
	fovy:                   f32,
	near:                   f32,
	far:                    f32,
	zoom:                   f32,
	up:                     lg.Vector3f32,
	target:                 lg.Vector3f32,
	position:               lg.Vector3f32,
	view_matrix:            lg.Matrix4x4f32,
	projection_matrix:      lg.Matrix4x4f32,
	view_projection_matrix: lg.Matrix4x4f32,
	uniform_buffer:         wgpu.Buffer,
	bind_group:             wgpu.BindGroup,
	bind_group_layout:      wgpu.BindGroupLayout,
	angle:                  f32,
	rotation_radius:        f32,
	angular_velocity:       f32,
}

Camera_Uniform :: struct {
	view_projection_matrix: matrix[4, 4]f32,
	view_matrix:            matrix[4, 4]f32,
	position:               [3]f32,
}

init_camera :: proc(camera: ^Camera, renderer_state: ^Rendering_Context) {
	camera.up = lg.Vector3f32{0, 1, 0}
	camera.fovy = math.PI / 2
	camera.aspect_ratio = 800 / 600
	camera.near = 0.1
	camera.far = 50
	camera.target = lg.Vector3f32{}
	camera.zoom = 1

	camera.uniform_buffer = wgpu.DeviceCreateBuffer(
		renderer_state.device,
		&wgpu.BufferDescriptor {
			label = "camera uniform buffer",
			size = size_of(Camera_Uniform),
			usage = {.Uniform, .CopyDst},
			mappedAtCreation = false,
		},
	)

	camera.bind_group_layout = wgpu.DeviceCreateBindGroupLayout(
		renderer_state.device,
		&wgpu.BindGroupLayoutDescriptor {
			entryCount = 1,
			entries = raw_data(
				[]wgpu.BindGroupLayoutEntry {
					{binding = 0, visibility = {.Vertex, .Fragment}, buffer = {type = .Uniform}},
				},
			),
		},
	)

	camera.bind_group = wgpu.DeviceCreateBindGroup(
		renderer_state.device,
		&wgpu.BindGroupDescriptor {
			label = "camera bind group",
			layout = camera.bind_group_layout,
			entryCount = 1,
			entries = raw_data(
				[]wgpu.BindGroupEntry {
					{binding = 0, buffer = camera.uniform_buffer, size = size_of(Camera_Uniform)},
				},
			),
		},
	)
}

update_camera_matrices :: proc(camera: ^Camera) {
	camera.view_matrix = lg.matrix4_look_at_f32(camera.position, camera.target, camera.up)

	camera.projection_matrix = lg.matrix4_perspective_f32(
		camera.fovy,
		camera.aspect_ratio,
		camera.near,
		camera.far,
	)

	camera.view_projection_matrix = camera.projection_matrix * camera.view_matrix
}

update_camera_buffer :: proc(camera: ^Camera, renderer_state: ^Rendering_Context) {
	offset: u64
	mat4_size := uint(size_of(lg.Matrix4x4f32))

	wgpu.QueueWriteBuffer(
		renderer_state.queue,
		camera.uniform_buffer,
		offset,
		&camera.view_projection_matrix,
		mat4_size,
	)

	offset += u64(mat4_size)

	wgpu.QueueWriteBuffer(
		renderer_state.queue,
		camera.uniform_buffer,
		offset,
		&camera.view_matrix,
		mat4_size,
	)

	offset += u64(mat4_size)

	wgpu.QueueWriteBuffer(
		renderer_state.queue,
		camera.uniform_buffer,
		offset,
		&camera.position,
		size_of(lg.Vector3f32),
	)
}
