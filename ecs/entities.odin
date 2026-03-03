package ecs

Eid :: u16

// Entity State
// ================================================
Entity_State :: struct {
    data:       #soa[dynamic]Entity_Data,
    components: [dynamic]bit_set[Component_Flags],
    dense:      [dynamic]Eid,
    sparse:     [dynamic]Eid,
    free_list:  [dynamic]Eid,
}

entity_state_init :: proc(es: ^Entity_State) {
    es.free_list = make([dynamic]Eid)
    es.dense = make([dynamic]Eid)
    es.sparse = make([dynamic]Eid)
    es.data = make(#soa[dynamic]Entity_Data)
}

entity_state_free :: proc(es: ^Entity_State) {
    delete(es.free_list)
    delete(es.dense)
    delete(es.sparse)
    delete(es.data)
}

// Entity State Iter
// ================================================
Entity_State_Iter :: struct {
    es:     Entity_State,
    idx:    Eid,
    filter: bit_set[Component_Flags],
}

make_entity_state_iter :: proc(es: Entity_State, filter: bit_set[Component_Flags] = {}) -> Entity_State_Iter {
    return {es, 0, filter}
}

// Query State
// ================================================
Query_State :: struct {
    entity_state: ^Entity_State,
    it: Entity_State_Iter,
    it_init: bool
}

query_state_init :: proc(qs: ^Query_State, es: ^Entity_State) {
    qs.entity_state = es
}

// Public Procs
// ================================================
entity_query :: proc(qs: ^Query_State, filter: bit_set[Component_Flags] = {}) -> (data: Entity_Data, eid: Eid, cond: bool) {
    if !qs.it_init {
        qs.it = make_entity_state_iter(qs.entity_state^, filter)
        qs.it_init = true
    }
    for qs.it.idx < Eid(len(qs.it.es.data)) {
        cond = _entity_valid_iter(qs.it.es, qs.it.idx) && qs.it.filter <= qs.it.es.components[qs.it.idx]
        if cond {
            data = qs.it.es.data[qs.it.idx]
            eid = qs.entity_state.dense[qs.it.idx]
            qs.it.idx += 1
            return
        }
        qs.it.idx += 1
    }
    qs.it_init = false
    return
}

entity_query_ptr :: proc(qs: ^Query_State, filter: bit_set[Component_Flags] = {}) -> (data: #soa^#soa[dynamic]Entity_Data, eid: Eid, cond: bool) {
    if !qs.it_init {
        qs.it = make_entity_state_iter(qs.entity_state^, filter)
        qs.it_init = true
    }
    for qs.it.idx < Eid(len(qs.it.es.data)) {
        cond = _entity_valid_iter(qs.it.es, qs.it.idx) && qs.it.filter <= qs.it.es.components[qs.it.idx]
        if cond {
            data = &qs.it.es.data[qs.it.idx]
            eid = qs.entity_state.dense[qs.it.idx]
            qs.it.idx += 1
            return
        }
        qs.it.idx += 1
    }
    qs.it_init = false
    return
}


entity_query_iter :: proc(it: ^Entity_State_Iter, es: Entity_State, filter: bit_set[Component_Flags] = {}) -> (data: Entity_Data, eid: Eid, cond: bool) {
    for it.idx < Eid(len(it.es.data)) {
        cond = _entity_valid_iter(it.es, it.idx) && it.filter <= es.components[it.idx]
        if cond {
            data = it.es.data[it.idx]
            eid = es.dense[it.idx]
            it.idx += 1
            return
        }
        it.idx += 1
    }
    return
}

entity_query_iter_ptr :: proc(it: ^Entity_State_Iter, es: Entity_State, filter: bit_set[Component_Flags] = {}) -> (data: #soa^#soa[dynamic]Entity_Data, eid: Eid, cond: bool) {
    for it.idx < Eid(len(it.es.data)) {
        cond = _entity_valid_iter(it.es, it.idx) && it.filter <= es.components[it.idx]
        if cond {
            data = &it.es.data[it.idx]
            eid = es.dense[it.idx]
            it.idx += 1
            return
        }
        it.idx += 1
    }
    return
}

entity_create :: proc(entity_state: ^Entity_State, init_data: Entity_Data = {}, components: bit_set[Component_Flags] = {}) -> (ret_eid: Eid) {
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
    return
}

entity_delete :: proc(entity_state: ^Entity_State,  eid: Eid) {
    last := len(entity_state.dense) - 1
    entity_state.sparse[entity_state.dense[last]] = eid
    entity_state.sparse[eid] = 0
    unordered_remove(&entity_state.dense, eid)
    unordered_remove(&entity_state.components, eid)
    unordered_remove_soa(&entity_state.data, eid)
}

entity_get :: proc(entity_state: ^Entity_State, eid: Eid) -> (Entity_Data, bool) {
    if _entity_valid_eid(entity_state^, eid) {
        return entity_state.data[entity_state.sparse[eid]], true 
    } 
    return {}, false
}

entity_get_ptr :: proc(entity_state: ^Entity_State, eid: Eid) -> (entity: #soa^#soa[dynamic]Entity_Data, ok: bool) {
    if _entity_valid_eid(entity_state^, eid) {
        return &entity_state.data[entity_state.sparse[eid]], true 
    } 
    return {}, false
}

activate_components :: proc(entity_state: ^Entity_State, eid: Eid, components: bit_set[Component_Flags]) {
    if _entity_valid_eid(entity_state^, eid) {
        entity_state.components[entity_state.sparse[eid]] += components
    }
}

deactivate_components :: proc(entity_state: ^Entity_State, eid: Eid, components: bit_set[Component_Flags]) {
    if _entity_valid_eid(entity_state^, eid) {
        entity_state.components[entity_state.sparse[eid]] -= components
    }
}

// Internal Procs
// ================================================
_entity_valid_iter :: proc(es: Entity_State, idx: Eid) -> bool {
    return es.sparse[es.dense[idx]] == idx
}

_entity_valid_eid :: proc(es: Entity_State, idx: Eid) -> bool {
    return es.dense[es.sparse[idx]] == idx
}

