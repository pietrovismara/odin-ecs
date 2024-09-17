package ecs

import "core:fmt"
import "core:mem"

Component_Info :: struct {
	size: int,
	tid:  typeid,
}

World :: struct {
	id_serial:           int,
	bit_flag_serial:     u8,
	components_bit_flag: map[typeid]u128,
	flag_to_component:   map[u128]Component_Info,
	entity_masks:        map[int]u128,
	tables:              [dynamic]^Table,
	removed_ids:         [dynamic]int,
	recycled_ids:        [dynamic]int,
}

init :: proc(world: ^World) {
	void_table := new(Table)
	append(&world.tables, void_table)
}

destroy :: proc(world: ^World) {
	for table in world.tables {
		delete(table.storage_to_eid)
		delete(table.eid_to_storage)
		for tid, storage in table.storage_map {
			delete(storage)
		}
		delete(table.storage_map)
		free(table)
	}
	delete(world.tables)
	delete(world.recycled_ids)
	delete(world.removed_ids)
	delete(world.components_bit_flag)
	delete(world.flag_to_component)
	delete(world.entity_masks)
}

add_entity :: proc(world: ^World) -> int {
	eid: int
	if len(world.recycled_ids) > 0 {
		eid = pop(&world.recycled_ids)
	} else {
		eid = world.id_serial
		world.id_serial += 1
	}

	world.entity_masks[eid] = 0

	// Add the entity to the void table, since it has no components yet
	void_table := get_table(world, 0) or_else fmt.panicf("call ecs.init before usage")

	// What does it mean to add an entity to a table when there's no storage?
	// It's just a matter of adding it to the index lookups and increasing its entity count
	void_table.eid_to_storage[eid] = void_table.entity_count
	void_table.entity_count += 1
	append(&void_table.storage_to_eid, eid)

	return eid
}

remove_entity :: proc(world: ^World, eid: int) {
	if eid not_in world.entity_masks {
		return
	}

	table, has_table := get_table(world, world.entity_masks[eid])
	assert(has_table, "entity has no table")

	table_remove_entity(world, table, eid)

	delete_key(&world.entity_masks, eid)
	append(&world.removed_ids, eid)
}

flush_removed_entities :: proc(world: ^World) {
	for eid in world.removed_ids {
		append(&world.recycled_ids, eid)
	}

	clear(&world.removed_ids)
}

get_table :: proc(world: ^World, query_mask: u128) -> (^Table, bool) {
	result_table: ^Table = ---
	found: bool
	loop: for &table in world.tables {
		if query_mask == table.components_mask {
			result_table = table
			found = true
			break loop
		}
	}

	return result_table, found
}

register_component :: proc(world: ^World, $Component: typeid) {
	world.components_bit_flag[Component] = 1 << world.bit_flag_serial
	world.flag_to_component[world.components_bit_flag[Component]] = Component_Info {
		size = size_of(Component),
		tid  = Component,
	}
	world.bit_flag_serial += 1
}
