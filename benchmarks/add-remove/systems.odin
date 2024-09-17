
package add_remove

import ecs "../../src"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"
import rend "renderer"
import sdl "vendor:sdl2"
import "vendor:wgpu"


init_entities :: proc(world: ^ecs.World) {
	for i in 0 ..< BODIES {
		add_body(world)
	}
}

add_body :: proc(world: ^ecs.World) {
	eid := ecs.add_entity(world)

	angle := rand.float32_range(0, math.PI * 2)
	speed := rand.float32_range(0, 0.5)
	mass := random_int_range(1, 4)

	ecs.entity_add_components(
		world,
		eid,
		[]typeid{Position, Velocity, Color},
		[]rawptr {
			&Position {
				rand.float32_range(-60, 60),
				rand.float32_range(0, 5),
				rand.float32_range(-8, 8),
			},
			&Velocity{math.cos_f32(angle) * speed, math.sin_f32(angle) * speed, 0},
			&Color {
				rand.float32_range(0, 1),
				rand.float32_range(0, 1),
				rand.float32_range(0, 1),
				1,
			},
		},
	)

	// ecs.entity_add_component(
	// 	world,
	// 	eid,
	// 	Position{rand.float32_range(-6, 6), rand.float32_range(5, 10), rand.float32_range(-3, 3)},
	// )


	// ecs.entity_add_component(
	// 	world,
	// 	eid,
	// 	Velocity{math.cos_f32(angle) * speed, math.sin_f32(angle) * speed, 0},
	// )

	// ecs.entity_add_component(world, eid, Mass(mass))
	// ecs.entity_add_component(world, eid, Circle(mass))
	// ecs.entity_add_component(
	// 	world,
	// 	eid,
	// 	Color{rand.float32_range(0, 1), rand.float32_range(0, 1), rand.float32_range(0, 1), 1},
	// )
}

update :: proc(world: ^ecs.World) {
	move_bodies(world)
	update_gravity(world, DELTA)
	recycle_bodies(world)
	ecs.flush_removed_entities(world)
}

update_gravity :: proc(world: ^ecs.World, delta: f64) {
	it := ecs.query(world, {include = {Velocity}})
	defer delete(it.tables)

	dt := delta / 1000

	for ecs.query_next(&it) {
		velocities := ecs.query_get_field(&it, Velocity, [3]f32)

		for i in 0 ..< it.count {
			velocities[i].y += f32(GRAVITY * dt)
		}
	}
}

move_bodies :: proc(world: ^ecs.World) {
	it := ecs.query(world, {include = {Position, Velocity}})
	defer delete(it.tables)

	for ecs.query_next(&it) {
		positions := ecs.query_get_field(&it, Position, [3]f32)
		velocities := ecs.query_get_field(&it, Velocity, [3]f32)

		for i in 0 ..< it.count {
			positions[i] += velocities[i]
		}
	}
}

recycle_bodies :: proc(world: ^ecs.World) {
	it := ecs.query(world, {include = {Position, Velocity}})
	defer delete(it.tables)

	for ecs.query_next(&it) {
		positions := ecs.query_get_field(&it, Position, [3]f32)

		for i in 0 ..< it.count {
			if positions[i].y < FLOOR {
				eid := ecs.query_get_eid(&it, i)
				ecs.remove_entity(world, eid)
				add_body(world)
			}
		}
	}
}

Transform_Uniform :: struct {
	worldMatrix: matrix[4, 4]f32,
}

Instance_Uniform :: struct {
	color: [4]f32,
}

init_sphere_renderer :: proc(state: ^State) {
	sphere := rend.Sphere{}
	defer {
		delete(sphere.indices)
		delete(sphere.normals)
		delete(sphere.positions)
		delete(sphere.uv)
	}

	rend.init_sphere(
		{
			radius = 1,
			subdivisions_axis = 16,
			subdivisions_height = 16,
			end_latitude_in_radians = math.PI,
			end_longitude_in_radians = math.PI * 2,
		},
		&sphere,
	)
	// Create vertex buffers
	positions_size := u64(len(sphere.positions) * size_of(f32))
	position_vertex_buffer := wgpu.DeviceCreateBuffer(
		state.render_ctx.device,
		&wgpu.BufferDescriptor {
			size = positions_size,
			usage = {.CopyDst, .Vertex},
			mappedAtCreation = false,
		},
	)

	wgpu.QueueWriteBuffer(
		state.render_ctx.queue,
		position_vertex_buffer,
		0,
		raw_data(sphere.positions),
		uint(positions_size),
	)


	// normals_size := u64(len(sphere.normals)) * size_of(f32)
	// normal_vertex_buffer := wgpu.DeviceCreateBuffer(
	// 	state.render_ctx.device,
	// 	&wgpu.BufferDescriptor {
	// 		size = normals_size,
	// 		usage = {.CopyDst, .Vertex},
	// 		mappedAtCreation = false,
	// 	},
	// )
	// wgpu.QueueWriteBuffer(
	// 	state.render_ctx.queue,
	// 	normal_vertex_buffer,
	// 	0,
	// 	&sphere.normals,
	// 	uint(normals_size),
	// )

	// uv_size := u64(len(sphere.uv)) * size_of(f32)
	// uv_vertex_buffer := wgpu.DeviceCreateBuffer(
	// 	state.render_ctx.device,
	// 	&wgpu.BufferDescriptor {
	// 		size = uv_size,
	// 		usage = {.CopyDst, .Vertex},
	// 		mappedAtCreation = false,
	// 	},
	// )
	// wgpu.QueueWriteBuffer(state.render_ctx.queue, uv_vertex_buffer, 0, &sphere.uv, uint(uv_size))

	index_size := u64(len(sphere.indices) * size_of(f32))
	index_buffer := wgpu.DeviceCreateBuffer(
		state.render_ctx.device,
		&wgpu.BufferDescriptor {
			size = index_size,
			usage = {.CopyDst, .Index},
			mappedAtCreation = false,
		},
	)
	wgpu.QueueWriteBuffer(
		state.render_ctx.queue,
		index_buffer,
		0,
		raw_data(sphere.indices),
		uint(index_size),
	)

	state.sphere_renderer.draw_count = u32(len(sphere.indices))


	// TODO: write shaders
	shader :: `
	struct Camera {
		viewProjectionMatrix: mat4x4f,
		viewMatrix: mat4x4f,
		position: vec3f
	}
	@group(0) @binding(0) var<uniform> camera: Camera;

	struct Transform {
		worldMatrix: mat4x4f,		
	}
	@group(1) @binding(0) var<storage> transform: array<Transform>;

	struct Instance {
		color: vec4f,
	}
	@group(1) @binding(1) var<storage> instance: array<Instance>;

	struct FragmentInput {
		@builtin(position) position: vec4f,
		@location(0) color: vec4f
	}

	@vertex
	fn vs_main(@location(0) position: vec3f, @builtin(instance_index) iidx: u32) -> FragmentInput {
		var vsOutput: FragmentInput;
		vsOutput.position = camera.viewProjectionMatrix * transform[iidx].worldMatrix * vec4f(position, 1.0);
		vsOutput.color = instance[iidx].color;
		return vsOutput;
	}

	@fragment
	fn fs_main(input: FragmentInput) -> @location(0) vec4<f32> {
		return input.color;
	}`

	shader_module := wgpu.DeviceCreateShaderModule(
		state.render_ctx.device,
		&{
			nextInChain = &wgpu.ShaderModuleWGSLDescriptor {
				sType = .ShaderModuleWGSLDescriptor,
				code = shader,
			},
		},
	)

	bind_group_layout := wgpu.DeviceCreateBindGroupLayout(
		state.render_ctx.device,
		&wgpu.BindGroupLayoutDescriptor {
			entryCount = 2,
			entries = raw_data(
				[]wgpu.BindGroupLayoutEntry {
					{binding = 0, visibility = {.Vertex}, buffer = {type = .ReadOnlyStorage}},
					{binding = 1, visibility = {.Vertex}, buffer = {type = .ReadOnlyStorage}},
				},
			),
		},
	)

	state.sphere_renderer.bind_group_layout = bind_group_layout

	transform_buffer := wgpu.DeviceCreateBuffer(
		state.render_ctx.device,
		&wgpu.BufferDescriptor {
			label = "transform uniform buffer",
			size = u64(size_of(Transform_Uniform) * 1),
			usage = {.Storage, .CopyDst},
			mappedAtCreation = false,
		},
	)

	instance_buffer := wgpu.DeviceCreateBuffer(
		state.render_ctx.device,
		&wgpu.BufferDescriptor {
			label = "color uniform buffer",
			size = u64(size_of(Instance_Uniform) * 1),
			usage = {.Storage, .CopyDst},
			mappedAtCreation = false,
		},
	)

	bind_group := wgpu.DeviceCreateBindGroup(
		state.render_ctx.device,
		&wgpu.BindGroupDescriptor {
			label = "instance bind group",
			layout = state.sphere_renderer.bind_group_layout,
			entryCount = 2,
			entries = raw_data(
				[]wgpu.BindGroupEntry {
					{
						binding = 0,
						buffer = transform_buffer,
						size = wgpu.BufferGetSize(transform_buffer),
					},
					{
						binding = 1,
						buffer = instance_buffer,
						size = wgpu.BufferGetSize(instance_buffer),
					},
				},
			),
		},
	)


	state.sphere_renderer.transform_buffer = transform_buffer
	state.sphere_renderer.instance_buffer = instance_buffer
	state.sphere_renderer.bind_group = bind_group

	pipeline_layout_desc := wgpu.PipelineLayoutDescriptor{}
	pipeline_layout_desc.bindGroupLayoutCount = 2
	pipeline_layout_desc.bindGroupLayouts = raw_data(
		[]wgpu.BindGroupLayout{state.render_ctx.camera.bind_group_layout, bind_group_layout},
	)

	pipeline_layout := wgpu.DeviceCreatePipelineLayout(
		state.render_ctx.device,
		&pipeline_layout_desc,
	)

	render_pipeline := wgpu.DeviceCreateRenderPipeline(
		state.render_ctx.device,
		&{
			layout = pipeline_layout,
			vertex = {
				module      = shader_module,
				entryPoint  = "vs_main",
				bufferCount = 1,
				buffers     = raw_data(
					[]wgpu.VertexBufferLayout {
						{
							arrayStride    = 3 * 4, // 3 floats, 4 bytes each
							stepMode       = .Vertex,
							attributeCount = 1,
							attributes     = raw_data(
								[]wgpu.VertexAttribute {
									{shaderLocation = 0, offset = 0, format = .Float32x3}, // position
								},
							),
						},
					},
				),
			},
			fragment = &{
				module = shader_module,
				entryPoint = "fs_main",
				targetCount = 1,
				targets = &wgpu.ColorTargetState {
					format = .BGRA8Unorm,
					writeMask = wgpu.ColorWriteMaskFlags_All,
				},
			},
			primitive = {topology = .TriangleList},
			multisample = {count = 1, mask = 0xFFFFFFFF},
			depthStencil = &{
				format = .Depth24Plus,
				depthWriteEnabled = true,
				depthCompare = .Less,
				depthBias = 0,
				depthBiasSlopeScale = 0,
				depthBiasClamp = 0,
				stencilFront = {
					compare = .Always,
					failOp = .Keep,
					depthFailOp = .Keep,
					passOp = .Keep,
				},
				stencilBack = {
					compare = .Always,
					failOp = .Keep,
					depthFailOp = .Keep,
					passOp = .Keep,
				},
				stencilReadMask = 0xFF,
				stencilWriteMask = 0xFF,
			},
		},
	)

	state.sphere_renderer.index_buffer = index_buffer
	append(&state.sphere_renderer.vertex_buffers, position_vertex_buffer)
	state.sphere_renderer.render_pipeline = render_pipeline
}

render :: proc(state: ^State) {
	update_camera(&state.render_ctx)

	it := ecs.query(&state.world, {include = {Position, Color}})
	defer delete(it.tables)

	state.sphere_renderer.instance_count = 0

	for table in it.tables {
		state.sphere_renderer.instance_count += u32(table.entity_count)
	}

	wgpu.BufferRelease(state.sphere_renderer.transform_buffer)
	wgpu.BufferRelease(state.sphere_renderer.instance_buffer)
	wgpu.BindGroupRelease(state.sphere_renderer.bind_group)

	transform_buffer := wgpu.DeviceCreateBuffer(
		state.render_ctx.device,
		&wgpu.BufferDescriptor {
			label = "transform uniform buffer",
			size = u64(size_of(Transform_Uniform) * state.sphere_renderer.instance_count),
			usage = {.Storage, .CopyDst},
			mappedAtCreation = true,
		},
	)

	instance_buffer := wgpu.DeviceCreateBuffer(
		state.render_ctx.device,
		&wgpu.BufferDescriptor {
			label = "instance uniform buffer",
			size = u64(size_of(Instance_Uniform) * state.sphere_renderer.instance_count),
			usage = {.Storage, .CopyDst},
			mappedAtCreation = true,
		},
	)

	mapped_transform := wgpu.BufferGetMappedRange(
		transform_buffer,
		0,
		uint(size_of(Transform_Uniform) * state.sphere_renderer.instance_count),
	)

	mapped_instance := wgpu.BufferGetMappedRange(
		instance_buffer,
		0,
		uint(size_of(Instance_Uniform) * state.sphere_renderer.instance_count),
	)

	offset: uint = 0
	for ecs.query_next(&it) {
		positions := ecs.query_get_field(&it, Position, linalg.Vector3f32)
		colors := ecs.query_get_field(&it, Color, linalg.Vector4f32)

		for i in 0 ..< it.count {
			{

				world_matrix := linalg.matrix4_translate_f32(positions[i])
				byte_offset := offset * size_of(Transform_Uniform)
				m := mapped_transform[byte_offset:byte_offset + size_of(Transform_Uniform)]
				mem.copy(raw_data(m), &world_matrix, size_of(matrix[4, 4]f32))
			}

			{
				byte_offset := offset * size_of(Instance_Uniform)
				m := mapped_instance[byte_offset:byte_offset + size_of(Instance_Uniform)]
				mem.copy(raw_data(m), &colors[i], size_of([4]f32))
			}

			offset += 1
		}
	}

	wgpu.BufferUnmap(transform_buffer)
	wgpu.BufferUnmap(instance_buffer)

	bind_group := wgpu.DeviceCreateBindGroup(
		state.render_ctx.device,
		&wgpu.BindGroupDescriptor {
			label = "transform bind group",
			layout = state.sphere_renderer.bind_group_layout,
			entryCount = 2,
			entries = raw_data(
				[]wgpu.BindGroupEntry {
					{
						binding = 0,
						buffer = transform_buffer,
						size = wgpu.BufferGetSize(transform_buffer),
					},
					{
						binding = 1,
						buffer = instance_buffer,
						size = wgpu.BufferGetSize(instance_buffer),
					},
				},
			),
		},
	)

	state.sphere_renderer.transform_buffer = transform_buffer
	state.sphere_renderer.instance_buffer = instance_buffer
	state.sphere_renderer.bind_group = bind_group

	rend.render(&state.render_ctx, state.sphere_renderer)
}


update_camera :: proc(render_ctx: ^rend.Rendering_Context) {
	render_ctx.camera.angle += render_ctx.camera.angular_velocity
	render_ctx.camera.position.x =
		render_ctx.camera.rotation_radius * math.cos(render_ctx.camera.angle)
	render_ctx.camera.position.z =
		render_ctx.camera.rotation_radius * math.sin(render_ctx.camera.angle)


	rend.update_camera_matrices(&render_ctx.camera)
	rend.update_camera_buffer(&render_ctx.camera, render_ctx)
}
