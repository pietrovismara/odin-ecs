package renderer

import "base:runtime"
import "core:fmt"
import "core:sync"
import win "core:sys/windows"
import "core:thread"
import "core:time"
import sdl "vendor:sdl2"
import wgpu "vendor:wgpu"

create_instance :: proc(state: ^Rendering_Context) {
	descriptor := wgpu.InstanceDescriptor {
		nextInChain = nil,
	}

	state.instance = wgpu.CreateInstance(&descriptor)
}

create_surface :: proc(state: ^Rendering_Context) -> bool {
	wm_info: sdl.SysWMinfo
	sdl.GetVersion(&wm_info.version)
	if !sdl.GetWindowWMInfo(state.window, &wm_info) {
		fmt.eprintfln("Error when retrieving window WM info: %s", sdl.GetError())
		return false
	}

	hwnd_desc := wgpu.SurfaceDescriptorFromWindowsHWND{}

	hwnd_desc.chain.sType = wgpu.SType.SurfaceDescriptorFromWindowsHWND
	hwnd_desc.hwnd = wm_info.info.win.window
	hwnd_desc.hinstance = win.GetModuleHandleA(nil)

	surface_desc := wgpu.SurfaceDescriptor{}

	surface_desc.nextInChain = cast(^wgpu.ChainedStruct)&hwnd_desc

	state.surface = wgpu.InstanceCreateSurface(state.instance, &surface_desc)

	return true
}

RequestAdapterData :: struct {
	ctx:      runtime.Context,
	resolved: bool,
	adapter:  wgpu.Adapter,
	error:    cstring,
}

request_adapter_sync :: proc(
	instance: wgpu.Instance,
	surface: wgpu.Surface,
) -> (
	wgpu.Adapter,
	cstring,
) {
	data: RequestAdapterData
	data.ctx = context

	wgpu.InstanceRequestAdapter(
		instance,
		&{compatibleSurface = surface, powerPreference = .HighPerformance},
		on_adapter,
		rawptr(&data),
	)

	on_adapter :: proc "c" (
		status: wgpu.RequestAdapterStatus,
		adapter: wgpu.Adapter,
		message: cstring,
		userdata: rawptr,
	) {
		data := cast(^RequestAdapterData)userdata
		context = runtime.default_context()

		data.adapter = adapter

		if status != .Success || adapter == nil {
			data.error = message
		}

		data.resolved = true

	}

	assert(data.resolved)

	return data.adapter, data.error
}


RequestDeviceData :: struct {
	ctx:      runtime.Context,
	resolved: bool,
	device:   wgpu.Device,
	error:    cstring,
}

request_device_sync :: proc(adapter: wgpu.Adapter) -> (wgpu.Device, cstring) {
	data: RequestDeviceData
	data.ctx = context

	wgpu.AdapterRequestDevice(
		adapter,
		&wgpu.DeviceDescriptor {
			label = "main device",
			requiredFeatureCount = 1,
			requiredFeatures = raw_data([]wgpu.FeatureName{.VertexWritableStorage}),
		},
		on_device,
		rawptr(&data),
	)

	on_device :: proc "c" (
		status: wgpu.RequestDeviceStatus,
		device: wgpu.Device,
		message: cstring,
		userdata: rawptr,
	) {
		data := cast(^RequestDeviceData)userdata
		context = data.ctx

		data.device = device

		if status != .Success || device == nil {
			data.error = message
		}

		data.resolved = true

	}

	assert(data.resolved)

	return data.device, data.error
}
