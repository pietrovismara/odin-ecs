package ecs

import "core:fmt"
import "core:mem"

Query_Params :: struct {
	include: []typeid,
	not:     []typeid,
}

Query_Iter :: struct {
	tables: [dynamic]^Table,
	offset: int, /**< Offset relative to current table */
	count:  int, /**< Number of entities to iterate */
}

query :: proc(world: ^World, query: Query_Params) -> Query_Iter {
	result: Query_Iter
	include_bit_mask: u128
	not_bit_mask: u128
	for param in query.include {
		assert(param in world.components_bit_flag, "component must be registered first")
		include_bit_mask |= world.components_bit_flag[param]
	}

	for param in query.not {
		assert(param in world.components_bit_flag, "component must be registered first")
		not_bit_mask |= world.components_bit_flag[param]
	}

	// Find tables matching this query
	for &table in world.tables {
		if (include_bit_mask & table.components_mask) == include_bit_mask {
			if len(query.not) > 0 && (not_bit_mask & table.components_mask) == not_bit_mask {
				continue
			}

			// Exclude empty tables
			if table.entity_count == 0 {
				continue
			}

			append(&result.tables, table)
		}
	}

	result.offset = -1

	return result
}

query_next :: proc(iter: ^Query_Iter) -> bool {
	iter.offset += 1
	// Moves to the next table with at least 1 entity
	if iter.offset < len(iter.tables) {
		table := iter.tables[iter.offset]
		iter.count = table.entity_count
		return true
	}

	return false
}

query_get_field :: proc {
	query_get_field_same,
	query_get_field_cast,
}

query_get_field_same :: proc(iter: ^Query_Iter, $Component: typeid) -> []Component {
	table := iter.tables[iter.offset]
	storage := &table.storage_map[Component]
	return (cast(^[dynamic]Component)(storage))[:]
}

query_get_field_cast :: proc(iter: ^Query_Iter, $Component: typeid, $CastTo: typeid) -> []CastTo {
	table := iter.tables[iter.offset]
	storage := &table.storage_map[Component]
	return (cast(^[dynamic]CastTo)(storage))[:]
}

query_get_eid :: proc(iter: ^Query_Iter, storage_index: int) -> int {
	table := iter.tables[iter.offset]
	return table.storage_to_eid[storage_index]
}
