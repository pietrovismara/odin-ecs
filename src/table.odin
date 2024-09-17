package ecs

import "core:fmt"
import "core:mem"
import "core:slice"

Table :: struct {
	storage_map:     map[typeid][dynamic]byte,
	eid_to_storage:  map[int]int,
	storage_to_eid:  [dynamic]int,
	entity_count:    int,
	components_mask: u128,
}

table_relocate_entity :: proc(world: ^World, eid: int, old_entity_mask: u128) -> ^Table {
	target_table, target_table_exists := get_table(world, world.entity_masks[eid])
	src_table, src_table_exists := get_table(world, old_entity_mask)

	assert(src_table_exists, "entity had no table")

	if !target_table_exists {
		// Create table and its storages
		target_table = new(Table)
		target_table.components_mask = world.entity_masks[eid]

		// Convert the component mask to a bit_set to iterate on its components
		mask := transmute(bit_set[0 ..< 128;u128])target_table.components_mask
		for flag in mask {
			// Create a new storage for each component and assign it to the new table
			info := world.flag_to_component[1 << uint(flag)]
			target_table.storage_map[info.tid] = [dynamic]byte{}
		}

		append(&world.tables, target_table)
	}

	assert(eid not_in target_table.eid_to_storage, "entity already in target table")

	// Make room for the new entity
	target_storage_index := target_table.entity_count
	target_table.entity_count += 1
	target_table.eid_to_storage[eid] = target_storage_index
	append(&target_table.storage_to_eid, eid)

	assert(eid in src_table.eid_to_storage, "entity not in source table")

	src_storage_index := src_table.eid_to_storage[eid]
	src_last_storage_index := src_table.entity_count - 1

	for key, &src_storage in src_table.storage_map {
		component_info := world.flag_to_component[world.components_bit_flag[key]]
		component_size := component_info.size

		// Copy the component value to the target table
		if key in target_table.storage_map {
			//fmt.printfln("relocating component %v", key)
			target_storage := &target_table.storage_map[key]

			start := src_storage_index * component_size
			end := start + component_size
			src_value := src_storage[start:end]
			append(target_storage, ..src_value)
		}

		// Remove the component value from the src table
		if src_storage_index != src_last_storage_index {
			// Move the last entity over the removed one
			mem.copy(
				&src_storage[src_storage_index * component_size],
				&src_storage[src_last_storage_index * component_size],
				component_size,
			)
		}

		resize(&src_storage, (src_table.entity_count - 1) * component_size)
	}

	// Assign the new index to the moved entity
	moved_eid := src_table.storage_to_eid[src_last_storage_index]
	src_table.eid_to_storage[moved_eid] = src_storage_index
	// Now update the reverse index
	src_table.storage_to_eid[src_storage_index] = moved_eid

	pop(&src_table.storage_to_eid)
	delete_key(&src_table.eid_to_storage, eid)
	src_table.entity_count -= 1

	return target_table
}

table_remove_entity :: proc(world: ^World, table: ^Table, eid: int) {
	assert(eid in table.eid_to_storage, "entity not in table")

	storage_index := table.eid_to_storage[eid]
	last_storage_index := table.entity_count - 1

	for key, &storage in table.storage_map {
		component_info := world.flag_to_component[world.components_bit_flag[key]]
		component_size := component_info.size

		if storage_index != last_storage_index {
			// Move the last element to the removed element's position
			mem.copy(
				&storage[storage_index * component_size],
				&storage[last_storage_index * component_size],
				component_size,
			)
		}

		// Remove the last element and update indices
		resize(&storage, (table.entity_count - 1) * component_size)
	}

	// Assign the new index to the moved entity
	moved_eid := table.storage_to_eid[last_storage_index]
	table.eid_to_storage[moved_eid] = storage_index
	// Now update the reverse index
	table.storage_to_eid[storage_index] = moved_eid

	pop(&table.storage_to_eid)
	delete_key(&table.eid_to_storage, eid)
	table.entity_count -= 1
}
