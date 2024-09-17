package add_remove

import ecs "../../src"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:mem"
import "core:os"
import "core:time"
import rend "renderer"
import sdl "vendor:sdl2"
import "vendor:wgpu"


DELTA :: 1000.0 / 60.0
FLOOR :: -100
GRAVITY :: -0.981
when ODIN_OPTIMIZATION_MODE == .None {
	BODIES :: 50_000
} else {
	BODIES :: 150_000
}

/*
* Components
*/
Position :: distinct [3]f32
Velocity :: distinct [3]f32
Circle :: distinct f32
Mass :: distinct f32
Color :: distinct [4]f32

State :: struct {
	world:           ecs.World,
	render_ctx:      rend.Rendering_Context,
	sphere_renderer: rend.Renderer,
}

main :: proc() {
	when .Address in ODIN_SANITIZER_FLAGS {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		defer mem.tracking_allocator_destroy(&track)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			for _, leak in track.allocation_map {
				fmt.printf("%v leaked %m\n", leak.location, leak.size)
			}
			for bad_free in track.bad_free_array {
				fmt.printf(
					"%v allocation %p was freed badly\n",
					bad_free.location,
					bad_free.memory,
				)
			}
		}
	}


	exit_status := 0
	state := State{}
	defer {
		ecs.destroy(&state.world)
		rend.cleanup(&state.render_ctx)

		wgpu.BufferDestroy(state.sphere_renderer.index_buffer)
		for buffer in state.sphere_renderer.vertex_buffers {wgpu.BufferDestroy(buffer)}
		wgpu.RenderPipelineRelease(state.sphere_renderer.render_pipeline)
		delete(state.sphere_renderer.vertex_buffers)
		wgpu.TextureViewRelease(state.render_ctx.depth_stencil_texture_view)
		wgpu.TextureRelease(state.render_ctx.depth_stencil_texture)

		os.exit(exit_status)
	}

	// TODO: handle sdl init failure
	rend.create_window(&state.render_ctx)
	rend.init(&state.render_ctx)
	ecs.init(&state.world)

	ecs.register_component(&state.world, Position)
	ecs.register_component(&state.world, Velocity)
	ecs.register_component(&state.world, Mass)
	ecs.register_component(&state.world, Circle)
	ecs.register_component(&state.world, Color)

	init_sphere_renderer(&state)

	init_entities(&state.world)

	run(&state)
}

run :: proc(state: ^State) {
	accumulator: f64 = DELTA
	prev_time := time.now()

	state.render_ctx.camera.position = linalg.Vector3f32{0, 10, 20}
	state.render_ctx.camera.target = linalg.Vector3f32{0, 0, 0}
	state.render_ctx.camera.far = 60
	state.render_ctx.camera.angular_velocity = 0.005
	state.render_ctx.camera.rotation_radius = 60

	for {
		now := time.now()
		frame_duration := time.duration_milliseconds(time.diff(prev_time, now))
		prev_time = now

		accumulator += frame_duration

		for accumulator >= DELTA {
			for sdl.PollEvent(&state.render_ctx.event) {
				#partial switch state.render_ctx.event.type {
				case .QUIT:
					return
				case .KEYDOWN:
					#partial switch state.render_ctx.event.key.keysym.sym {
					case .ESCAPE:
						return
					}
				case .WINDOWEVENT:
					#partial switch state.render_ctx.event.window.event {
					case .RESIZED:
						width := u32(state.render_ctx.event.window.data1)
						height := u32(state.render_ctx.event.window.data2)

						rend.init_surface(&state.render_ctx, width, height)
						state.render_ctx.camera.aspect_ratio = f32(width) / f32(height)
					}
				}
			}

			update(&state.world)
			accumulator -= DELTA
		}


		render(state)
	}
}
