package renderer

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:os"
import sdl "vendor:sdl2"
import wgpu "vendor:wgpu"

// Constants are defined using ::
SDL_FLAGS :: sdl.INIT_EVENTS | sdl.INIT_VIDEO
WINDOW_FLAGS :: sdl.WINDOW_VULKAN | sdl.WINDOW_RESIZABLE | sdl.WINDOW_MAXIMIZED
RENDERER_FLAGS :: sdl.RENDERER_ACCELERATED

create_window :: proc(ctx: ^Rendering_Context) -> bool {
	if sdl.Init(SDL_FLAGS) != 0 {
		fmt.eprintfln("Error initializing SDL2: %s", sdl.GetError())
		return false
	}

	ctx.window = sdl.CreateWindow(
		"Odin + SDL + wgpu",
		sdl.WINDOWPOS_CENTERED,
		sdl.WINDOWPOS_CENTERED,
		800,
		600,
		WINDOW_FLAGS,
	)

	if ctx.window == nil {
		fmt.eprintfln("Error creating Window: %s", sdl.GetError())
		return false
	}


	return true
}

cleanup :: proc(ctx: ^Rendering_Context) {
	if ctx.window != nil {sdl.DestroyWindow(ctx.window)}

	sdl.Quit()
}
