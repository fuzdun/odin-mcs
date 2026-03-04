# odin-mcs (Megastruct Component System)

## a tiny ECS-like package for megastruct enthusiasts

### Example usage:
```odin
package main

import "mcs"

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
    target: mcs.Eid,
}

Running_Man: mcs.Archetype(Entity_Data, Component_Flags): {
    components = {
        hp = 10,
        position = {0, 0},
        velocity = {1, 1},
    },
    flags = {.Hp, .Position, .Velocity}
}

Data :: Entity_Data              // shorthand alias for entity data type
Comp :: bit_set[Component_Flags] // shorthand alias for component flags type

main :: proc() {

    // init mcs system
    // ------------------------------
    es: mcs.Entity_State(Data, Comp) 
    mcs.entity_state_init(&es); defer mcs.entity_state_free(&es)

    // create entities
    // ------------------------------
    e0 := mcs.entity_create(&es, Running_Man) // create using archetype

    e1 := mcs.entity_create(&es, Data{        // create manually
        hp = 10,
        position = {-5, -5},
        velocity = {1, 1},
        on_fire = {heat = 20},
        target = e0
    }, Comp{.Hp, .Position, .Velocity, .On_Fire, .Target})

    // simulated frame loop
    // ------------------------------
    frame_loop: for {

        // entity 1 runs NE, shooting entity 0 to death before burning alive :)

        // move entities with position and velocity
        // ------------------------------
        for e in mcs.entity_query_ptr(&es, Comp{.Position, .Velocity}) {
            e.position += e.velocity
        }

        // reduce heat of burning entities
        // ------------------------------
        for e, eid in mcs.entity_query_ptr(&es, Comp{.On_Fire}) {
            e.on_fire.heat = max(0, e.on_fire.heat - 1)
            if e.on_fire.heat == 0 {
                mcs.sub_components(&es, eid, Comp{.On_Fire})
            }
        }

        // reduce health of burning entities
        // ------------------------------
        for e in mcs.entity_query_ptr(&es, Comp{.On_Fire, .Hp}) {
            e.hp = max(0, e.hp - 1)
        }

        // entities shoot at targets
        // ------------------------------
        for e_shooter in mcs.entity_query(&es, Comp{.Target}) {
            if e_target, ok := mcs.entity_get_ptr(&es, e_shooter.target); ok {
                e_target.hp = max(0, e_target.hp - 1.5) 
            }
        }

        // remove entities with 0 hp
        // ------------------------------
        for e, eid in mcs.entity_query(&es, Comp{.Hp}) {
            if e.hp == 0 {
                mcs.entity_delete(&es, eid)
            }
        }

        // end loop when everyone is dead
        // ------------------------------
        if es.entity_count == 0 {
            break frame_loop
        }
    }
}
```
