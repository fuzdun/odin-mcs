package ecs

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

