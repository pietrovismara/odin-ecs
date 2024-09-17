package renderer

import "core:math"

Sphere_Params :: struct {
	radius:                     f32,
	subdivisions_axis:          uint,
	subdivisions_height:        uint,
	start_latitude_in_radians:  f32,
	end_latitude_in_radians:    f32,
	start_longitude_in_radians: f32,
	end_longitude_in_radians:   f32,
}

Sphere :: struct {
	positions: [dynamic]f32,
	normals:   [dynamic]f32,
	uv:        [dynamic]f32,
	indices:   [dynamic]u16,
}

init_sphere :: proc(params: Sphere_Params, sphere: ^Sphere) -> bool {
	// sphere.positions = {-1, -1, 0, 1, -1, 0, 1, 1, 0, -1, 1, 0}

	// sphere.indices = {0, 1, 3, 3, 1, 2}
	if params.subdivisions_axis <= 0 || params.subdivisions_height <= 0 {
		return false
	}

	lat_range := params.end_latitude_in_radians - params.start_latitude_in_radians
	long_range := params.end_longitude_in_radians - params.start_longitude_in_radians

	for y in 0 ..= params.subdivisions_height {
		for x in 0 ..= params.subdivisions_axis {
			u := f32(x) / f32(params.subdivisions_axis)
			v := f32(y) / f32(params.subdivisions_height)
			theta := long_range * u + params.start_longitude_in_radians
			phi := lat_range * v + params.start_latitude_in_radians
			sin_theta := math.sin_f32(theta)
			cos_theta := math.cos_f32(theta)
			sin_phi := math.sin_f32(phi)
			cos_phi := math.cos_f32(phi)
			ux := cos_theta * sin_phi
			uy := cos_phi
			uz := sin_theta * sin_phi
			append(&sphere.positions, params.radius * ux, params.radius * uy, params.radius * uz)
			append(&sphere.normals, ux, uy, uz)
			append(&sphere.uv, 1 - u, v)
		}
	}

	num_verts_around := u16(params.subdivisions_axis + 1)
	for x in 0 ..= params.subdivisions_axis {
		for y in 0 ..= params.subdivisions_height {
			xf := u16(x)
			yf := u16(y)
			// triangle 1 of quad.
			append(
				&sphere.indices,
				(yf + 0) * num_verts_around + xf,
				(yf + 0) * num_verts_around + xf + 1,
				(yf + 1) * num_verts_around + xf,
			)

			// triangle 2 of quad.
			append(
				&sphere.indices,
				(yf + 1) * num_verts_around + xf,
				(yf + 0) * num_verts_around + xf + 1,
				(yf + 1) * num_verts_around + xf + 1,
			)
		}
	}

	return true
}
