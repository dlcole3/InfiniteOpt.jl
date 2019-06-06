# Define symbol inputs for different variable types
const Infinite = :Infinite
const Point = :Point
const Global = :Global

# Extend Base.copy for new variable types
Base.copy(v::GeneralVariableRef) = v
Base.copy(v::InfiniteVariableRef, new_model::InfiniteModel) = InfiniteVariableRef(new_model, v.index)
Base.copy(v::GlobalVariableRef, new_model::InfiniteModel) = GlobalVariableRef(new_model, v.index)
Base.copy(v::PointVariableRef, new_model::InfiniteModel) = PointVariableRef(new_model, v.index)

# Extend other Base functions
Base.:(==)(v::GeneralVariableRef, w::GeneralVariableRef) = v.model === w.model && v.index == w.index
Base.broadcastable(v::GeneralVariableRef) = Ref(v)

# Extend JuMP functions
JuMP.isequal_canonical(v::GeneralVariableRef, w::GeneralVariableRef) = v == w
JuMP.variable_type(m::InfiniteModel) = GeneralVariableRef
function JuMP.variable_type(m::InfiniteModel, type::Symbol)
    if type == Infinite
        return InfiniteVariableRef
    elseif type == Point
        return PointVariableRef
    elseif type == Global
        return GlobalVariableRef
    else
        error("Invalid variable type.")
    end
end

"""
    JuMP.add_variable((_error::Function, info::JuMP.VariableInfo, test_arg::Int; extra_kw_args...)
Extend the `JuMP.build_variable` function to accomodate our new variable types.
"""
function JuMP.build_variable(_error::Function, info::JuMP.VariableInfo, var_type::Symbol; extra_kw_args...)
    for (kwarg, _) in extra_kw_args
        _error("Unrecognized keyword argument $kwarg")
    end
    if var_type in [:Infinite, :Point, :Global]
        return InfOptVariable(info, var_type)
    else
        _error("Unrecognized variable type $var_type, should be Inf, Point, or Global.")
    end
end

# TODO Add functionality to add variable bounds/types to constraints
"""
    JuMP.add_variable(model::InfiniteModel, v::InfOptVariable, name::String="")
Extend the `JuMP.add_variable` function to accomodate our new variable types.
"""
function JuMP.add_variable(m::InfiniteModel, v::InfOptVariable, name::String="")
    m.next_var_index += 1
    if v.type == Infinite
        vref = InfiniteVariableRef(m, m.next_var_index)
    elseif v.type == Point
        vref = PointVariableRef(m, m.next_var_index)
    else
        vref = GlobalVariableRef(m, m.next_var_index)
    end
    m.vars[vref.index] = v
    JuMP.set_name(vref, name)
    return vref
end

"""
    JuMP.owner_model(vref::GlobalVariableRef)
Extend the `JuMP.owner_model` function for our new variable types.
"""
JuMP.owner_model(vref::GeneralVariableRef) = vref.model

"""
    JuMP.delete(model::InfiniteModel, vref::GlobalVariableRef)
Extend the `JuMP.delete` function to accomodate our new variable types.
"""
function JuMP.delete(model::InfiniteModel, vref::GeneralVariableRef)
    @assert JuMP.is_valid(model, vref)
    delete!(model.vars, vref.index)
    delete!(model.var_to_name, vref.index)
    return
end

"""
    JuMP.is_valid(model::InfiniteModel, vref::GlobalVariableRef)
Extend the `JuMP.is_valid` function to accomodate our new variable types.
"""
function JuMP.is_valid(model::InfiniteModel, vref::GeneralVariableRef)
        return (model === vref.model && vref.index in keys(model.vars))
end

"""
    JuMP.num_variables(m::InfiniteModel)
Extend the `JuMP.num_variables` function to accomodate our new variable types.
"""
JuMP.num_variables(m::InfiniteModel) = length(m.vars)

# Internal functions
_variable_info(vref::GeneralVariableRef) = vref.model.vars[vref.index].info
function _update_variable_info(vref::GeneralVariableRef, info::JuMP.VariableInfo)
    vref.model.vars[vref.index] = InfOptVariable(info, vref.model.vars[vref.index].type)
    return
end

"""
    JuMP.has_lower_bound(vref::GlobalVariableRef)
Extend the `JuMP.has_lower_bound` function to accomodate our new variable types.
"""
JuMP.has_lower_bound(vref::GeneralVariableRef) = _variable_info(vref).has_lb

"""
    JuMP.lower_bound(vref::GlobalVariableRef)::Float64
Extend the `JuMP.lower_bound` function to accomodate our new variable types.
"""
function JuMP.lower_bound(vref::GeneralVariableRef)::Float64
    @assert !JuMP.is_fixed(vref)
    return _variable_info(vref).lower_bound
end

"""
    JuMP.set_lower_bound(vref::GlobalVariableRef, lower)
Extend the `JuMP.set_lower_bound` function to accomodate our new variable types.
"""
function JuMP.set_lower_bound(vref::GeneralVariableRef, lower)
    info = _variable_info(vref)
    _update_variable_info(vref,
                         JuMP.VariableInfo(true, convert(Float64, lower),
                                           info.has_ub, info.upper_bound,
                                           info.has_fix, info.fixed_value,
                                           info.has_start, info.start,
                                           info.binary, info.integer))
    return
end

"""
    JuMP.delete_lower_bound(vref::GlobalVariableRef)
Extend the `JuMP.delete_lower_bound` function to accomodate our new variable types.
"""
function JuMP.delete_lower_bound(vref::GeneralVariableRef)
    info = _variable_info(vref)
    _update_variable_info(vref,
                         JuMP.VariableInfo(false, info.lower_bound,
                                           info.has_ub, info.upper_bound,
                                           info.has_fix, info.fixed_value,
                                           info.has_start, info.start,
                                           info.binary, info.integer))
    return
end

"""
    JuMP.has_upper_bound(vref::GlobalVariableRef)
Extend the `JuMP.has_upper_bound` function to accomodate our new variable types.
"""
JuMP.has_upper_bound(vref::GeneralVariableRef) = _variable_info(vref).has_ub

"""
    JuMP.upper_bound(vref::GlobalVariableRef)
Extend the `JuMP.upper_bound` function to accomodate our new variable types.
"""
function JuMP.upper_bound(vref::GeneralVariableRef)::Float64
    @assert !JuMP.is_fixed(vref)
    return _variable_info(vref).upper_bound
end

"""
    JuMP.set_upper_bound(vref::GlobalVariableRef, upper)
Extend the `JuMP.set_upper_bound` function to accomodate our new variable types.
"""
function JuMP.set_upper_bound(vref::GeneralVariableRef, upper)
    info = _variable_info(vref)
    _update_variable_info(vref,
                         JuMP.VariableInfo(info.has_lb, info.lower_bound,
                                           true, convert(Float64, upper),
                                           info.has_fix, info.fixed_value,
                                           info.has_start, info.start,
                                           info.binary, info.integer))
    return
end

"""
    JuMP.delete_upper_bound(vref::GlobalVariableRef)
Extend the `JuMP.delete_upper_bound` function to accomodate our new variable types.
"""
function JuMP.delete_upper_bound(vref::GeneralVariableRef)
    info = _variable_info(vref)
    _update_variable_info(vref,
                         JuMP.VariableInfo(info.has_lb, info.lower_bound,
                                           false, info.upper_bound,
                                           info.has_fix, info.fixed_value,
                                           info.has_start, info.start,
                                           info.binary, info.integer))
    return
end

"""
    JuMP.is_fixed(vref::GlobalVariableRef)
Extend the `is_fixed` function to accomodate our new variable types.
"""
JuMP.is_fixed(vref::GeneralVariableRef) = _variable_info(vref).has_fix

"""
    JuMP.fix_value(vref::GlobalVariableRef)
Extend the `JuMP.fix_value` function to accomodate our new variable types.
"""
function JuMP.fix_value(vref::GeneralVariableRef)::Float64
    return _variable_info(vref).fixed_value
end

"""
    JuMP.fix(vref::GlobalVariableRef, value; force::Bool = false)
Extend the `JuMP.fix` function to accomodate our new variable types.
"""
function JuMP.fix(vref::GeneralVariableRef, value; force::Bool = false)
    info = _variable_info(vref)
    if !force && (info.has_lb || info.has_ub)
        error("Unable to fix $(vref) to $(value) because it has existing bounds.")
    end
    _update_variable_info(vref, JuMP.VariableInfo(
        false, info.lower_bound, false, info.upper_bound, true, convert(Float64, value),
        info.has_start, info.start, info.binary, info.integer)
    )
    return
end

"""
    JuMP.unfix(vref::GlobalVariableRef)
Extend the `JuMP.unfix` function to accomodate our new variable types.
"""
function JuMP.unfix(vref::GeneralVariableRef)
    info = _variable_info(vref)
    _update_variable_info(vref,
                         JuMP.VariableInfo(info.has_lb, info.lower_bound,
                                           info.has_ub, info.upper_bound,
                                           false, info.fixed_value,
                                           info.has_start, info.start,
                                           info.binary, info.integer))
    return
end

"""
    JuMP.start_value(vref::GlobalVariableRef)
Extend the `JuMP.start_value` function to accomodate our new variable types.
"""
function JuMP.start_value(vref::GeneralVariableRef)::Union{Nothing, Float64}
    return _variable_info(vref).start
end

"""
    JuMP.set_start_value(vref::GlobalVariableRef, start)
Extend the `JuMP.set_start_value` function to accomodate our new variable types.
"""
function JuMP.set_start_value(vref::GeneralVariableRef, start)
    info = _variable_info(vref)
    _update_variable_info(vref,
                         JuMP.VariableInfo(info.has_lb, info.lower_bound,
                                           info.has_ub, info.upper_bound,
                                           info.has_fix, info.fixed_value,
                                           true, start,
                                           info.binary, info.integer))
    return
end

"""
    JuMP.is_binary(vref::GlobalVariableRef)
Extend the `JuMP.is_binary` function to accomodate our new variable types.
"""
JuMP.is_binary(vref::GeneralVariableRef) = _variable_info(vref).binary

"""
    JuMP.set_binary(vref::GlobalVariableRef)
Extend the `JuMP.set_binary` function to accomodate our new variable types.
"""
function JuMP.set_binary(vref::GeneralVariableRef)
    @assert !JuMP.is_integer(vref)
    info = _variable_info(vref)
    _update_variable_info(vref,
                         JuMP.VariableInfo(info.has_lb, info.lower_bound,
                                           info.has_ub, info.upper_bound,
                                           info.has_fix, info.fixed_value,
                                           info.has_start, info.start,
                                           true, info.integer))
    return
end

"""
    JuMP.unset_binary(vref::GlobalVariableRef)
Extend the `JuMP.unset_binary` function to accomodate our new variable types.
"""
function JuMP.unset_binary(vref::GeneralVariableRef)
    info = _variable_info(vref)
    _update_variable_info(vref,
                         JuMP.VariableInfo(info.has_lb, info.lower_bound,
                                           info.has_ub, info.upper_bound,
                                           info.has_fix, info.fixed_value,
                                           info.has_start, info.start,
                                           false, info.integer))
    return
end

"""
    JuMP.is_integer(vref::GlobalVariableRef)
Extend the `JuMP.is_integer` function to accomodate our new variable types.
"""
JuMP.is_integer(vref::GeneralVariableRef) = _variable_info(vref).integer

"""
    JuMP.set_integer(vref::GlobalVariableRef)
Extend the `JuMP.set_integer` function to accomodate our new variable types.
"""
function JuMP.set_integer(vref::GeneralVariableRef)
    @assert !JuMP.is_binary(vref)
    info = _variable_info(vref)
    _update_variable_info(vref,
                         JuMP.VariableInfo(info.has_lb, info.lower_bound,
                                           info.has_ub, info.upper_bound,
                                           info.has_fix, info.fixed_value,
                                           info.has_start, info.start,
                                           info.binary, true))
    return
end

"""
    JuMP.unset_integer(vref::GlobalVariableRef)
Extend the `JuMP.unset_integer` function to accomodate our new variable types.
"""
function JuMP.unset_integer(vref::GeneralVariableRef)
    info = _variable_info(vref)
    _update_variable_info(vref,
                         JuMP.VariableInfo(info.has_lb, info.lower_bound,
                                           info.has_ub, info.upper_bound,
                                           info.has_fix, info.fixed_value,
                                           info.has_start, info.start,
                                           info.binary, false))
    return
end

"""
    JuMP.name(vref::GlobalVariableRef)
Extend the `JuMP.name` function to accomodate our new variable types.
"""
JuMP.name(vref::GeneralVariableRef) = vref.model.var_to_name[vref.index]

"""
    JuMP.set_name(vref::GlobalVariableRef, name::String)
Extend the `JuMP.set_name` function to accomodate our new variable types.
"""
function JuMP.set_name(vref::GeneralVariableRef, name::String)
    vref.model.var_to_name[vref.index] = name
    vref.model.name_to_var = nothing
    return
end

"""
    JuMP.variable_by_name(model::InfiniteModel, name::String)
Extend the `JuMP.variable_by_name` function to accomodate `InfiniteModel` objects.
"""
function JuMP.variable_by_name(model::InfiniteModel, name::String)
    if model.name_to_var === nothing
        # Inspired from MOI/src/Utilities/model.jl
        model.name_to_var = Dict{String, Int}()
        for (var, var_name) in model.var_to_name
            if haskey(model.name_to_var, var_name)
                # -1 is a special value that means this string does not map to
                # a unique variable name.
                model.name_to_var[var_name] = -1
            else
                model.name_to_var[var_name] = var
            end
        end
    end
    index = get(model.name_to_var, name, nothing)
    if index isa Nothing
        return nothing
    elseif index == -1
        error("Multiple variables have the name $name.")
    else
        if model.vars[index].type == :Infinite
            return InfiniteVariableRef(model, index)
        elseif model.vars[index].type == :Point
            return PointVariableRef(model, index)
        else
            return GlobalVariableRef(model, index)
        end
    end
    return
end

"""
    JuMP.all_variables(model::InfiniteModel)
Extend the `JuMP.all_variables` function to accomodate `InfiniteModel` objects.
"""
function JuMP.all_variables(model::InfiniteModel)
    vars_list = Vector{GeneralVariableRef}(undef, JuMP.num_variables(model))
    indexes = sort([index for index in keys(model.vars)])
    counter = 1
    for index in indexes
        if model.vars[index].type == :Infinite
            vars_list[counter] = InfiniteVariableRef(model, index)
        elseif model.vars[index].type == :Point
            vars_list[counter] = PointVariableRef(model, index)
        else
            vars_list[counter] = GlobalVariableRef(model, index)
        end
        counter += 1
    end
    return vars_list
end