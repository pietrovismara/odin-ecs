package renderer

import "base:runtime"
import "core:c"
import "core:fmt"
import sdl "vendor:sdl2"
import wgpu "vendor:wgpu"


Rendering_Context :: struct {
	window:                     ^sdl.Window,
	renderer:                   ^sdl.Renderer,
	event:                      sdl.Event,
	wm_info:                    sdl.SysWMinfo,
	instance:                   wgpu.Instance,
	adapter:                    wgpu.Adapter,
	surface:                    wgpu.Surface,
	device:                     wgpu.Device,
	queue:                      wgpu.Queue,
	render_pipeline:            wgpu.RenderPipeline,
	camera:                     Camera,
	depth_stencil_texture:      wgpu.Texture,
	depth_stencil_texture_view: wgpu.TextureView,
}

Renderer :: struct {
	render_pipeline:   wgpu.RenderPipeline,
	index_buffer:      wgpu.Buffer,
	vertex_buffers:    [dynamic]wgpu.Buffer,
	draw_count:        u32,
	instance_count:    u32,
	bind_group:        wgpu.BindGroup,
	bind_group_layout: wgpu.BindGroupLayout,
	transform_buffer:  wgpu.Buffer,
	instance_buffer:   wgpu.Buffer,
}

init :: proc(ctx: ^Rendering_Context) {
	create_instance(ctx)
	create_surface(ctx)

	// TODO: propagate errors up
	adapter, adapter_error := request_adapter_sync(ctx.instance, ctx.surface)
	if adapter_error != nil {
		fmt.panicf("Error retrieving adapter %s", adapter_error)
	}

	device, device_error := request_device_sync(adapter)
	if device_error != nil {
		fmt.panicf("Error retrieving device %s", device_error)
	}

	wgpu.AdapterRelease(adapter)

	ctx.device = device

	ctx.queue = wgpu.DeviceGetQueue(ctx.device)

	w, h: c.int
	sdl.GetWindowSize(ctx.window, &w, &h)

	init_surface(ctx, u32(w), u32(h))

	ctx.camera = Camera{}
	init_camera(&ctx.camera, ctx)
}

init_surface :: proc(ctx: ^Rendering_Context, width: u32, height: u32) {
	surface_config := wgpu.SurfaceConfiguration {
		device      = ctx.device,
		usage       = {.RenderAttachment},
		format      = .BGRA8Unorm,
		width       = width,
		height      = height,
		presentMode = .Fifo,
		alphaMode   = .Opaque,
	}
	wgpu.SurfaceConfigure(ctx.surface, &surface_config)

	depth_texture, depth_texture_view := create_depth_stencil_texture(ctx.device, width, height)
	ctx.depth_stencil_texture = depth_texture
	ctx.depth_stencil_texture_view = depth_texture_view
}

create_depth_stencil_texture :: proc(
	device: wgpu.Device,
	width: u32,
	height: u32,
) -> (
	wgpu.Texture,
	wgpu.TextureView,
) {
	depth_texture_desc := wgpu.TextureDescriptor {
		size = wgpu.Extent3D{width = width, height = height, depthOrArrayLayers = 1},
		mipLevelCount = 1,
		sampleCount = 1,
		dimension = ._2D,
		format = .Depth24Plus,
		usage = {.RenderAttachment},
	}

	depth_texture := wgpu.DeviceCreateTexture(device, &depth_texture_desc)

	depth_view_desc := wgpu.TextureViewDescriptor {
		format          = .Depth24Plus,
		dimension       = ._2D,
		aspect          = .DepthOnly,
		baseMipLevel    = 0,
		mipLevelCount   = 1,
		baseArrayLayer  = 0,
		arrayLayerCount = 1,
	}

	depth_texture_view := wgpu.TextureCreateView(depth_texture, &depth_view_desc)

	return depth_texture, depth_texture_view
}

render :: proc(ctx: ^Rendering_Context, renderer: Renderer) {
	surface_texture := wgpu.SurfaceGetCurrentTexture(ctx.surface)
	switch surface_texture.status {
	case .Success:
	// All good, could check for `surface_texture.suboptimal` here.
	case .Timeout, .Outdated, .Lost:
		// Skip this frame, and re-configure surface.
		fmt.printfln("Surface lost %v", surface_texture.status)
		if surface_texture.texture != nil {
			wgpu.TextureRelease(surface_texture.texture)
		}
		//resize()
		return
	case .OutOfMemory, .DeviceLost:
		// Fatal error
		fmt.panicf("[triangle] get_current_texture status=%v", surface_texture.status)
	}
	defer wgpu.TextureRelease(surface_texture.texture)

	frame := wgpu.TextureCreateView(surface_texture.texture, nil)
	defer wgpu.TextureViewRelease(frame)

	command_encoder := wgpu.DeviceCreateCommandEncoder(ctx.device)
	defer wgpu.CommandEncoderRelease(command_encoder)

	pass := wgpu.CommandEncoderBeginRenderPass(
		command_encoder,
		&wgpu.RenderPassDescriptor {
			label = "clear pass",
			colorAttachmentCount = 1,
			colorAttachments = &wgpu.RenderPassColorAttachment {
				view = frame,
				loadOp = .Clear,
				storeOp = .Store,
				clearValue = {r = 0.1, g = 0.1, b = 0.11},
			},
			depthStencilAttachment = &wgpu.RenderPassDepthStencilAttachment {
				view = ctx.depth_stencil_texture_view,
				depthClearValue = 1.0,
				depthLoadOp = .Clear,
				depthStoreOp = .Store,
			},
		},
	)
	defer wgpu.RenderPassEncoderRelease(pass)

	wgpu.RenderPassEncoderSetBindGroup(pass, 0, ctx.camera.bind_group)

	wgpu.RenderPassEncoderSetPipeline(pass, renderer.render_pipeline)

	wgpu.RenderPassEncoderSetBindGroup(pass, 1, renderer.bind_group)

	if renderer.index_buffer != nil {
		wgpu.RenderPassEncoderSetIndexBuffer(
			pass,
			renderer.index_buffer,
			.Uint16,
			0,
			wgpu.BufferGetSize(renderer.index_buffer),
		)
	}

	for buffer, i in renderer.vertex_buffers {
		wgpu.RenderPassEncoderSetVertexBuffer(pass, u32(i), buffer, 0, wgpu.BufferGetSize(buffer))
	}

	wgpu.RenderPassEncoderDrawIndexed(
		pass,
		indexCount = renderer.draw_count,
		instanceCount = renderer.instance_count,
		firstIndex = 0,
		baseVertex = 0,
		firstInstance = 0,
	)

	wgpu.RenderPassEncoderEnd(pass)
	command_buffer := wgpu.CommandEncoderFinish(command_encoder, nil)
	defer wgpu.CommandBufferRelease(command_buffer)

	wgpu.QueueSubmit(ctx.queue, {command_buffer})
	wgpu.SurfacePresent(ctx.surface)
}
