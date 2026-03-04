# odin-mcs (Megastruct Component System)

## a tiny ECS-like package for megastruct enthusiasts

### Example usage:
#### components.odin:
```odin
Component_Flags :: enum {
    Position,
    Velocity,
    Hp,
    Target,
    On_Fire
}

On_Fire :: struct {
    heat: f32
}

Entity_Data :: struct {
    position: [2]int,
    velocity: [2]int,
    hp: f32,
    on_fire: On_Fire,
    target: Eid,
}

Running_Man: Archetype: {
    components = {
        hp = 10,
        position = {0, 0},
        velocity = {1, 1},
    },
    flags = {.Hp, .Position, .Velocity}
}
```

#### main.odin:
```odin
import "mcs"

main :: proc() {
    es: mcs.Entity_State 
    mcs.entity_state_init(&es)
    defer mcs.entity_state_free(&es)

    qs: mcs.Query_State
    mcs.query_state_init(&qs, &es)

    e0 := mcs.entity_create(&es, mcs.Running_Man) // create using archetype

    e1 := mcs.entity_create(&es, { // create manually
        hp = 10,
        position = {-5, -5},
        velocity = {1, 1},
        on_fire = {heat = 20},
        target = e0
    }, {.Hp, .Position, .Velocity, .On_Fire, .Target})

    frame_loop: for {

        // move entities with position and velocity
        for e in mcs.entity_query_ptr(&qs, {.Position, .Velocity}) {
            e.position += e.velocity
        }

        // reduce heat of burning entities
        for e, eid in mcs.entity_query_ptr(&qs, {.On_Fire}) {
            e.on_fire.heat = max(0, e.on_fire.heat - 1)
            if e.on_fire.heat == 0 {
                mcs.deactivate_components(&es, eid, {.On_Fire})
            }
        }

        // reduce health of burning entities
        for e in mcs.entity_query_ptr(&qs, {.On_Fire, .Hp}) {
            e.hp = max(0, e.hp - 1)
        }

        // entities shoot at targets
        for e_shooter in mcs.entity_query(&qs, {.Target}) {
            if e_target, ok := mcs.entity_get_ptr(&es, e_shooter.target); ok {
                e_target.hp = max(0, e_target.hp - 1) 
            }
        }

        // remove entities with 0 hp
        for e, eid in mcs.entity_query(&qs, {.Hp}) {
            if e.hp == 0 {
                mcs.entity_delete(&es, eid)
            }
        }

        // end loop when everyone is dead
        if es.entity_count == 0 {
            break frame_loop
        }
    }
}
```
