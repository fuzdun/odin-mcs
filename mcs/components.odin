package mcs

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

