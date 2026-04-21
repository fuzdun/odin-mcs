package mcs

import "base:intrinsics"

Eid :: u16

Entity_State :: struct($T: typeid, $C: typeid) {
    data:         #soa[dynamic]T,
    components:   [dynamic]bit_set[C],
    dense:        [dynamic]Eid,
    sparse:       [dynamic]Eid,
    free_list:    [dynamic]Eid,
    entity_count: int,
    it:           Entity_State_Iter(C)
}

entity_state_init :: proc(es: ^Entity_State($T, $C)) {
    es.free_list = make([dynamic]Eid)
    es.dense     = make([dynamic]Eid)
    es.sparse    = make([dynamic]Eid)
    es.data      = make(#soa[dynamic]T)
}

entity_state_free :: proc(es: ^Entity_State($T, $C)) {
    delete(es.free_list)
    delete(es.dense)
    delete(es.sparse)
    delete(es.data)
}

Archetype :: struct($T: typeid, $C: typeid) {
    components: T,
    flags:      bit_set[C]
}

Entity_State_Iter :: struct($C: typeid) {
    idx:    Eid,
    filter: bit_set[C],
    init:   bool
}

make_entity_state_iter :: proc(filter: bit_set[$C]) -> Entity_State_Iter(C) {
    return {0, filter, true}
}

// Public Procs
// ================================================
entity_query :: proc(es: ^Entity_State($T, $C), filter: bit_set[C]) -> (data: T, eid: Eid, cond: bool) {
    if !es.it.init {
        es.it = make_entity_state_iter(filter)
        es.it.init = true
    }
    for es.it.idx < Eid(len(es.data)) {
        cond = _entity_valid_iter(es^, es.it.idx) && es.it.filter <= es.components[es.it.idx]
        if cond {
            data = es.data[es.it.idx]
            eid = es.dense[es.it.idx]
            es.it.idx += 1
            return
        }
        es.it.idx += 1
    }
    es.it.init = false
    return
}

entity_query_ptr :: proc(es: ^Entity_State($T, $C), filter: bit_set[C]) -> (data: #soa^#soa[dynamic]T, eid: Eid, cond: bool) {
    if !es.it.init {
        es.it = make_entity_state_iter(filter)
        es.it.init = true
    }
    for es.it.idx < Eid(len(es.data)) {
        cond = _entity_valid_iter(es^, es.it.idx) && es.it.filter <= es.components[es.it.idx]
        if cond {
            data = &es.data[es.it.idx]
            eid = es.dense[es.it.idx]
            es.it.idx += 1
            return
        }
        es.it.idx += 1
    }
    es.it.init = false
    return
}


entity_query_iter :: proc(it: ^Entity_State_Iter, es: Entity_State($T, $C), filter: bit_set[C]) -> (data: T, eid: Eid, cond: bool) {
    for it.idx < Eid(len(es.data)) {
        cond = _entity_valid_iter(es, it.idx) && it.filter <= es.components[it.idx]
        if cond {
            data = es.data[it.idx]
            eid = es.dense[it.idx]
            it.idx += 1
            return
        }
        it.idx += 1
    }
    return
}

entity_query_iter_ptr :: proc(it: ^Entity_State_Iter, es: ^Entity_State($T, $C), filter: bit_set[C]) -> (data: #soa^#soa[dynamic]T, eid: Eid, cond: bool) {
    for it.idx < Eid(len(es.data)) {
        cond = _entity_valid_iter(es^, it.idx) && it.filter <= es.components[it.idx]
        if cond {
            data = &es.data[it.idx]
            eid = es.dense[it.idx]
            it.idx += 1
            return
        }
        it.idx += 1
    }
    return
}

entity_create :: proc {
    entity_create_params,
    entity_create_archetype
}

entity_create_params :: proc(entity_state: ^Entity_State($T, $C), init_data: T, components: bit_set[C]) -> (ret_eid: Eid) {
    init_data := init_data
    dense_idx := Eid(len(entity_state.data))
    append(&entity_state.data, init_data)
    if len(entity_state.free_list) > 0 {
        ret_eid = pop(&entity_state.free_list)
        entity_state.sparse[ret_eid] = dense_idx
    } else {
        ret_eid = Eid(len(entity_state.sparse))
        append(&entity_state.sparse, dense_idx)
    }
    append(&entity_state.dense, ret_eid)
    append(&entity_state.components, components)
    entity_state.entity_count += 1
    return
}

entity_create_archetype :: proc(entity_state: ^Entity_State($T, $C), archetype: Archetype(T, C)) -> (ret_eid: Eid) {
    dense_idx := Eid(len(entity_state.data))
    append(&entity_state.data, archetype.components)
    if len(entity_state.free_list) > 0 {
        ret_eid = pop(&entity_state.free_list)
        entity_state.sparse[ret_eid] = dense_idx
    } else {
        ret_eid = Eid(len(entity_state.sparse))
        append(&entity_state.sparse, dense_idx)
    }
    append(&entity_state.dense, ret_eid)
    append(&entity_state.components, archetype.flags)
    entity_state.entity_count += 1
    return
}

entity_delete :: proc(entity_state: ^Entity_State($T, $C),  eid: Eid) {
    dense_idx := entity_state.sparse[eid]
    last := len(entity_state.dense) - 1
    entity_state.sparse[entity_state.dense[last]] = dense_idx
    entity_state.sparse[eid] = 0
    unordered_remove(&entity_state.dense, dense_idx)
    unordered_remove(&entity_state.components, dense_idx)
    unordered_remove_soa(&entity_state.data, dense_idx)
    entity_state.entity_count -= 1
}

entity_get :: proc(entity_state: ^Entity_State($T, $C), eid: Eid) -> (T, bool) {
    if _entity_valid_eid(entity_state^, eid) {
        return entity_state.data[entity_state.sparse[eid]], true 
    } 
    return {}, false
}

entity_get_ptr :: proc(entity_state: ^Entity_State($T, $C), eid: Eid) -> (entity: #soa^#soa[dynamic]T, ok: bool) {
    if _entity_valid_eid(entity_state^, eid) {
        return &entity_state.data[entity_state.sparse[eid]], true 
    } 
    return {}, false
}

add_components :: proc(entity_state: ^Entity_State($T, $C), eid: Eid, components: bit_set[C]) {
    if _entity_valid_eid(entity_state^, eid) {
        entity_state.components[entity_state.sparse[eid]] += components
    }
}

sub_components :: proc(entity_state: ^Entity_State($T, $C), eid: Eid, components: bit_set[C]) {
    if _entity_valid_eid(entity_state^, eid) {
        entity_state.components[entity_state.sparse[eid]] -= components
    }
}

// Internal Procs
// ================================================
_entity_valid_iter :: proc(es: Entity_State($T, $C), idx: Eid) -> bool {
    return es.sparse[es.dense[idx]] == idx
}

_entity_valid_eid :: proc(es: Entity_State($T, $C), idx: Eid) -> bool {
    return es.dense[es.sparse[idx]] == idx
}

