# Odin ECS

A toy implementation of an archetype based ECS.

Supports up to 128 components of any type.

See `benchmarks` for usage examples.

```odin
Position :: distinct [3]f32
Velocity :: distinct [3]f32
Color :: distinct [4]f32

main :: proc() {
  world := ecs.World{}
  ecs.init(&world)
  defer ecs.destroy(&world)

  ecs.register_component(&world, Position)
  ecs.register_component(&world, Velocity)
  ecs.register_component(&world, Color)

  eid := ecs.add_entity(&world)

  ecs.entity_add_component(&world, eid, Position{0, 5, 0})
  ecs.entity_add_component(&world, eid, Velocity{0, -1, 0})

  it := ecs.query(world, {include = {Position, Velocity}, not = {Color}})
  defer delete(it.tables)

  for ecs.query_next(&it) {
    positions := ecs.query_get_field(&it, Position, [3]f32)
    velocities := ecs.query_get_field(&it, Velocity, [3]f32)

    for i in 0 ..< it.count {
      positions[i] += velocities[i]
    }
  }
}
```
