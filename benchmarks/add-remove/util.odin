package add_remove

import "core:math/rand"
import "core:slice"


average :: proc(values: []f64) -> f64 {
	if len(values) == 0 {
		return 0
	}
	sum: f64 = 0
	for v in values {
		sum += v
	}
	return sum / f64(len(values))
}

random_int_range :: proc(min, max: int) -> int {
	return min + int(rand.int31_max(i32(max - min)))
}
