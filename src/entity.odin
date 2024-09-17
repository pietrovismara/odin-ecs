package ecs

import "core:fmt"
import "core:slice"

entity_has_component :: proc(world: ^World, eid: int, $Component: typeid) -> (result: bool) {
	component_bit_flag := world.components_bit_flag[Component]
	result = (world.entity_masks[eid] & component_bit_flag) == component_bit_flag
	return
}

entity_add_components :: proc(world: ^World, eid: int, components: []typeid, values: []rawptr) {
	old_entity_mask := world.entity_masks[eid]

	for tid in components {
		component_bit_flag := world.components_bit_flag[tid]
		world.entity_masks[eid] |= component_bit_flag
	}

	target_table := table_relocate_entity(world, eid, old_entity_mask)

	for tid, i in components {
		flag := world.components_bit_flag[tid]
		info := world.flag_to_component[flag]
		storage := &target_table.storage_map[tid]
		value := slice.bytes_from_ptr(values[i], info.size)
		append(storage, ..value)
	}
}

entity_add_component :: proc(world: ^World, eid: int, component: $Type) {
	tid := typeid_of(Type)

	if entity_has_component(world, eid, Type) {
		return
	}
	old_entity_mask := world.entity_masks[eid]
	component_bit_flag := world.components_bit_flag[tid]
	world.entity_masks[eid] |= component_bit_flag

	target_table := table_relocate_entity(world, eid, old_entity_mask)

	assert(tid in target_table.storage_map, "storage not in target table")
	storage := &target_table.storage_map[tid]
	tmp_comp := component

	component_size := size_of(component)

	storage_index := target_table.eid_to_storage[eid]
	value := slice.bytes_from_ptr(cast(^byte)&tmp_comp, component_size)

	append(storage, ..value)
}

entity_remove_component :: proc(world: ^World, eid: int, $Component: typeid) {
	if !entity_has_component(world, eid, Component) {
		return
	}

	old_entity_mask := world.entity_masks[eid]

	component_bit_flag := world.components_bit_flag[Component]
	world.entity_masks[eid] &= ~component_bit_flag

	table_relocate_entity(world, eid, old_entity_mask)
}
