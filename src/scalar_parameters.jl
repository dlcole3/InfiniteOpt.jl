################################################################################
#                   CORE DISPATCHVARIABLEREF METHOD EXTENSIONS
################################################################################
# Extend dispatch_variable_ref
function dispatch_variable_ref(model::InfiniteModel,
                               index::IndependentParameterIndex
                               )::IndependentParameterRef
    return IndependentParameterRef(model, index)
end

function dispatch_variable_ref(model::InfiniteModel,
                               index::FiniteParameterIndex
                               )::FiniteParameterRef
    return FiniteParameterRef(model, index)
end

# Extend _add_data_object
function _add_data_object(model::InfiniteModel,
                          object::ScalarParameterData{<:IndependentParameter}
                          )::IndependentParameterIndex
    index =  MOIUC.add_item(model.independent_params, object)
    push!(model.param_object_indices, index)
    return index
end

function _add_data_object(model::InfiniteModel,
                          object::ScalarParameterData{<:FiniteParameter}
                          )::FiniteParameterIndex
    return MOIUC.add_item(model.finite_params, object)
end

# Extend _data_dictionary (type based)
function _data_dictionary(model::InfiniteModel,
    ::Type{IndependentParameter})::MOIUC.CleverDict
    return model.independent_params
end

function _data_dictionary(model::InfiniteModel,
    ::Type{FiniteParameter})::MOIUC.CleverDict
    return model.finite_params
end

# Extend _data_dictionary (ref based)
function _data_dictionary(pref::IndependentParameterRef)::MOIUC.CleverDict
    return JuMP.owner_model(pref).independent_params
end

function _data_dictionary(pref::FiniteParameterRef)::MOIUC.CleverDict
    return JuMP.owner_model(pref).finite_params
end

# Extend _data_object
function _data_object(pref::ScalarParameterRef)::AbstractDataObject
    object = get(_data_dictionary(pref), JuMP.index(pref), nothing)
    object === nothing && error("Invalid scalar parameter reference, cannot find " *
                           "corresponding parameter in the model. This is likely " *
                           "caused by using the reference of a deleted parameter.")
    return object
end

################################################################################
#                             CORE OBJECT METHODS
################################################################################
# Extend _core_variable_object for IndependentParameterRefs
function _core_variable_object(pref::IndependentParameterRef)::IndependentParameter
    return _data_object(pref).parameter
end

# Extend _core_variable_object for FiniteParameterRefs
function _core_variable_object(pref::FiniteParameterRef)::FiniteParameter
    return _data_object(pref).parameter
end

# Extend _parameter_number
function _parameter_number(pref::IndependentParameterRef)::Int
    return _data_object(pref).parameter_num
end

# Extend _parameter_numbers
function _parameter_numbers(pref::IndependentParameterRef)::Vector{Int}
    return [_parameter_number(pref)]
end

# Extend _object_number
function _object_number(pref::IndependentParameterRef)::Int
    return _data_object(pref).object_num
end

# Extend _object_numbers
function _object_numbers(pref::IndependentParameterRef)::Vector{Int}
    return [_object_number(pref)]
end

## Set helper methods for adapting data_objects with parametric changes 
# No change needed 
function _adaptive_data_update(pref::ScalarParameterRef, param::P, 
                               data::ScalarParameterData{P})::Nothing where {P <: ScalarParameter}
    data.parameter = param
    return
end

# Reconstruction is necessary 
function _adaptive_data_update(pref::ScalarParameterRef, param::P1, 
                               data::ScalarParameterData{P2})::Nothing  where {P1, P2}
    new_data = ScalarParameterData(param, data.object_num, data.parameter_num, 
                                   data.name, data.parameter_func_indices,
                                   data.infinite_var_indices, 
                                   data.derivative_indices, data.measure_indices,
                                   data.constraint_indices, data.in_objective,
                                   data.has_internal_supports, 
                                   data.has_derivative_supports,
                                   data.has_deriv_constrs)
    _data_dictionary(pref)[JuMP.index(pref)] = new_data
    return
end

# Extend _set_core_variable_object for ScalarParameterRefs
function _set_core_variable_object(pref::ScalarParameterRef,
                                   param::ScalarParameter)::Nothing
    _adaptive_data_update(pref, param, _data_object(pref))
    return
end

################################################################################
#                           MACRO DEFINITION HELPERS
################################################################################
# Internal structure for building InfOptParameters
mutable struct _ParameterInfoExpr
    has_lb::Bool
    lower_bound::Any
    has_ub::Bool
    upper_bound::Any
    has_dist::Bool
    distribution::Any
    has_set::Bool
    set::Any
end

# Default constructor
function _ParameterInfoExpr(; lower_bound = NaN, upper_bound = NaN,
                            distribution = NaN, set = NaN)
    # isnan(::Expr) is not defined so we need to do !== NaN
    return _ParameterInfoExpr(lower_bound !== NaN, lower_bound,
                              upper_bound !== NaN, upper_bound,
                              distribution !== NaN, distribution,
                              set !== NaN, set)
end

# Internal function for use in processing valid key word arguments
function _is_set_keyword(kw::Expr)
    return kw.args[1] in [:set, :lower_bound, :upper_bound, :distribution]
end

# Extend to assist in building InfOptParameters
function _set_lower_bound_or_error(_error::Function,
                                   info::_ParameterInfoExpr, lower)::Nothing
    info.has_lb && _error("Cannot specify parameter lower_bound twice")
    info.has_dist && _error("Cannot specify parameter lower_bound and " *
                            "distribution")
    info.has_set && _error("Cannot specify parameter lower_bound and set")
    info.has_lb = true
    info.lower_bound = lower
    return
end

# Extend to assist in building InfOptParameters
function _set_upper_bound_or_error(_error::Function,
                                    info::_ParameterInfoExpr, upper)::Nothing
    info.has_ub && _error("Cannot specify parameter upper_bound twice")
    info.has_dist && _error("Cannot specify parameter upper_bound and " *
                            "distribution")
    info.has_set && _error("Cannot specify parameter upper_bound and set")
    info.has_ub = true
    info.upper_bound = upper
    return
end

# Extend to assist in building InfOptParameters
function _dist_or_error(_error::Function, info::_ParameterInfoExpr, dist)::Nothing
    info.has_dist && _error("Cannot specify parameter distribution twice")
    (info.has_lb || info.has_ub) && _error("Cannot specify parameter " *
                                           "distribution and upper/lower bounds")
    info.has_set && _error("Cannot specify parameter distribution and set")
    info.has_dist = true
    info.distribution = dist
    return
end

# Extend to assist in building InfOptParameters
function _set_or_error(_error::Function, info::_ParameterInfoExpr, set)::Nothing
    info.has_set && _error("Cannot specify variable fixed value twice")
    (info.has_lb || info.has_ub) && _error("Cannot specify parameter set and " *
                                           "upper/lower bounds")
    info.has_dist && _error("Cannot specify parameter set and distribution")
    info.has_set = true
    info.set = set
    return
end

# Construct an expression to build an infinite set (use with @infinite_macro)
function _constructor_set(_error::Function, info::_ParameterInfoExpr)
    if (info.has_lb || info.has_ub) && !(info.has_lb && info.has_ub)
        _error("Must specify both an upper bound and a lower bound")
    elseif info.has_lb
        check = :(isa($(info.lower_bound), Real))
        return :($(check) ? IntervalSet($(info.lower_bound), $(info.upper_bound)) : error("Bounds must be a number."))
    elseif info.has_dist
        check = :(isa($(info.distribution), Distributions.UnivariateDistribution))
        return :($(check) ? UniDistributionSet($(info.distribution)) : error("Distribution must be a Distributions.UnivariateDistribution."))
    elseif info.has_set
        check1 = :(isa($(info.set), InfiniteScalarSet))
        check2 = :(isa($(info.set), Distributions.UnivariateDistribution))
        return :($(check1) ? $(info.set) : ($(check2) ? UniDistributionSet($(info.set)) : error("Set must be a subtype of InfiniteScalarSet.")))
    else
        _error("Must specify upper/lower bounds, a distribution, or a set")
    end
end

################################################################################
#                            PARAMETER DEFINITION
################################################################################
# Define the default derivative evaluation method 
const DefaultDerivativeMethod = FiniteDifference()

# Check that supports don't violate the set bounds
function _check_supports_in_bounds(_error::Function,
                                   supports::Union{<:Real, Vector{<:Real}},
                                   set::AbstractInfiniteSet)::Nothing
    if !supports_in_set(supports, set)
        _error("Supports violate the set domain bounds.")
    end
    return
end

"""
    build_parameter(_error::Function, set::InfiniteScalarSet;
                    [num_supports::Int = 0,
                    supports::Union{Real, Vector{<:Real}} = Real[],
                    sig_digits::Int = DefaultSigDigits,
                    derivative_method::AbstractDerivativeMethod = DefaultDerivativeMethod]
                    )::IndependentParameter

Returns a [`IndependentParameter`](@ref) given the appropriate information.
This is analagous to `JuMP.build_variable`. Errors if supports violate the
bounds associated with `set`. This is meant to primarily serve as a
helper method for [`@independent_parameter`](@ref). Here `derivative_method` 
specifies the numerical evalution method that will be applied to derivatives that 
are taken with respect to this infinite parameter.

**Example**
```julia-repl
julia> build_parameter(error, IntervalSet(0, 3), supports = Vector(0:3))
IndependentParameter{IntervalSet,FiniteDifference}([0, 3], DataStructures.SortedDict(0.0 => Set([UserDefined]),1.0 => Set([UserDefined]),2.0 => Set([UserDefined]),3.0 => Set([UserDefined])), 12, FiniteDifference())
```
"""
function build_parameter(_error::Function,
    set::S;
    num_supports::Int = 0,
    supports::Union{Real, Vector{<:Real}} = Real[],
    sig_digits::Int = DefaultSigDigits,
    derivative_method::M = DefaultDerivativeMethod,
    extra_kw_args...
    )::IndependentParameter{S, M} where {S <: InfiniteScalarSet, M <: AbstractDerivativeMethod}
    for (kwarg, _) in extra_kw_args
        _error("Unrecognized keyword argument $kwarg")
    end
    label = UserDefined
    length_supports = length(supports)
    if !isempty(supports)
        supports = round.(supports, sigdigits = sig_digits)
        _check_supports_in_bounds(_error, supports, set)
        num_supports == 0 || @warn("Ignoring num_supports since supports is not empty.")
    elseif num_supports != 0
        supports, label = generate_support_values(set, num_supports = num_supports,
                                                  sig_digits = sig_digits)
    end
    supports_dict = DataStructures.SortedDict{Float64, Set{DataType}}(
                                            i => Set([label]) for i in supports)
    if length_supports != 0 && (length(supports_dict) != length_supports)
        @warn("Support points are not unique, eliminating redundant points.")
    end
    return IndependentParameter(set, supports_dict, sig_digits, derivative_method)
end

"""
    build_parameter(_error::Function, value::Real)::FiniteParameter

Returns a [`FiniteParameter`](@ref) given the appropriate information.
This is analagous to `JuMP.build_variable`. This is meant to primarily serve as
a helper method for [`@finite_parameter`](@ref).

**Example**
```jldoctest; setup = :(using InfiniteOpt)
julia> build_finite_parameter(error, 1)
FiniteParameter(1.0)
```
"""
function build_parameter(_error::Function, value::Real;
                         extra_kw_args...)::FiniteParameter
    for (kwarg, _) in extra_kw_args
        _error("Unrecognized keyword argument $kwarg")
    end
    return FiniteParameter(value)
end

"""
    add_parameter(model::InfiniteModel,
                  p::Union{IndependentParameterRef, FiniteParameterRef},
                  [name::String = ""])::GeneralVariableRef

Returns a [`GeneralVariableRef`](@ref) associated with the parameter `p` that is added
to `model`. This adds a parameter to the model in a manner similar to
`JuMP.add_variable`. This can be used to add parameters with the use of
[`@infinite_parameter`](@ref). [`build_parameter`](@ref) should be used to
construct `p`.

**Example**
```jldoctest; setup = :(using InfiniteOpt; model = InfiniteModel())
julia> p = build_independent_parameter(error, IntervalSet(0, 3), supports = Vector(0:3));

julia> param_ref = add_parameter(model, p, "name")
name
```
"""
function add_parameter(model::InfiniteModel, p::IndependentParameter,
                       name::String = "")::GeneralVariableRef
    obj_num = length(_param_object_indices(model)) + 1
    param_num = model.last_param_num += 1
    data_object = ScalarParameterData(p, obj_num, param_num, name)
    obj_index = _add_data_object(model, data_object)
    return GeneralVariableRef(model, obj_index.value, typeof(obj_index))
end

# FiniteParameter
function add_parameter(model::InfiniteModel, p::FiniteParameter,
                       name::String = "")::GeneralVariableRef
    data_object = ScalarParameterData(p, -1, -1, name)
    obj_index = _add_data_object(model, data_object)
    return GeneralVariableRef(model, obj_index.value, typeof(obj_index))
end

################################################################################
#                           PARAMETER DEPENDENCIES
################################################################################
# Extend _infinite_variable_dependencies
function _infinite_variable_dependencies(pref::ScalarParameterRef
    )::Vector{InfiniteVariableIndex}
    return _data_object(pref).infinite_var_indices
end

# Extend _parameter_function_dependencies
function _parameter_function_dependencies(pref::ScalarParameterRef
    )::Vector{ParameterFunctionIndex}
    return _data_object(pref).parameter_func_indices
end

# Extend _derivative_dependencies
function _derivative_dependencies(pref::ScalarParameterRef
    )::Vector{DerivativeIndex}
    return _data_object(pref).derivative_indices
end

# Extend _measure_dependencies
function _measure_dependencies(pref::ScalarParameterRef
    )::Vector{MeasureIndex}
    return _data_object(pref).measure_indices
end

# Extend _constraint_dependencies
function _constraint_dependencies(pref::ScalarParameterRef
    )::Vector{ConstraintIndex}
    return _data_object(pref).constraint_indices
end

################################################################################
#                             USED_BY FUNCTIONS
################################################################################
"""
    used_by_infinite_variable(pref::IndependentParameterRef)::Bool

Return true if `pref` is used by an infinite variable or false otherwise.

**Example**
```julia-repl
julia> used_by_infinite_variable(t)
true
```
"""
function used_by_infinite_variable(pref::IndependentParameterRef)::Bool
    return !isempty(_infinite_variable_dependencies(pref))
end

# FiniteParameter
used_by_infinite_variable(pref::FiniteParameterRef)::Bool = false

"""
    used_by_parameter_function(pref::IndependentParameterRef)::Bool

Return true if `pref` is used by an infinite parameter function or false otherwise.

**Example**
```julia-repl
julia> used_by_parameter_function(t)
false
```
"""
function used_by_parameter_function(pref::IndependentParameterRef)::Bool
    return !isempty(_parameter_function_dependencies(pref))
end

# FiniteParameter
used_by_parameter_function(pref::FiniteParameterRef)::Bool = false

"""
    used_by_measure(pref::Union{IndependentParameterRef, FiniteParameterRef})::Bool

Return true if `pref` is used by a measure or false otherwise.

**Example**
```julia-repl
julia> used_by_measure(t)
false
```
"""
function used_by_measure(pref::ScalarParameterRef)::Bool
    return !isempty(_measure_dependencies(pref))
end

"""
    used_by_constraint(pref::Union{IndependentParameterRef, FiniteParameterRef})::Bool

Return true if `pref` is used by a constraint or false otherwise.

**Example**
```julia-repl
julia> used_by_constraint(t)
true
```
"""
function used_by_constraint(pref::ScalarParameterRef)::Bool
    return !isempty(_constraint_dependencies(pref))
end

"""
    used_by_objective(pref::FiniteParameterRef)::Bool

Return true if `pref` is used by the objective function.

**Example**
```julia-repl
```
"""
function used_by_objective(pref::FiniteParameterRef)::Bool
    return _data_object(pref).in_objective
end

# IndependentParameter
used_by_objective(::IndependentParameterRef)::Bool = false

"""
    used_by_derivative(pref::IndependentParameterRef)::Bool

Return true if `pref` is used by a derivative or false otherwise.

**Example**
```julia-repl
julia> used_by_derivative(t)
false
```
"""
function used_by_derivative(pref::IndependentParameterRef)::Bool
    return !isempty(_derivative_dependencies(pref))
end

# FiniteParameter
used_by_derivative(::FiniteParameterRef)::Bool = false

"""
    is_used(pref::Union{IndependentParameterRef, FiniteParameterRef})::Bool

Return true if `pref` is used in the model or false otherwise.

**Example**
```julia-repl
julia> is_used(t)
true
```
"""
function is_used(pref::ScalarParameterRef)::Bool
    return used_by_measure(pref) || used_by_constraint(pref) ||
           used_by_infinite_variable(pref) || used_by_objective(pref) || 
           used_by_derivative(pref) || used_by_parameter_function(pref)
end

################################################################################
#                              NAME METHODS
################################################################################

"""
    JuMP.name(pref::Union{IndependentParameterRef, FiniteParameterRef})::String

Extend the [`JuMP.name`](@ref JuMP.name(::JuMP.VariableRef)) function to
accomodate infinite parameters. Returns the name string associated with `pref`.

**Example**
```jldoctest; setup = :(using InfiniteOpt, JuMP; model = InfiniteModel(); @independent_parameter(model, t in [0, 1]))
julia> name(t)
"t"
```
"""
function JuMP.name(pref::ScalarParameterRef)::String
    object = get(_data_dictionary(pref), JuMP.index(pref), nothing)
    return object === nothing ? "" : object.name
end

"""
    JuMP.set_name(pref::ScalarParameterRef, name::String)

Extend the [`JuMP.set_name`](@ref JuMP.set_name(::JuMP.VariableRef, ::String))
function to accomodate infinite parameters. Set a new base name to be associated
with `pref`.

**Example**
```jldoctest; setup = :(using InfiniteOpt, JuMP; model = InfiniteModel(); @independent_parameter(model, t in [0, 1]))
julia> set_name(t, "time")

julia> name(t)
"time"
```
"""
function JuMP.set_name(pref::ScalarParameterRef, name::String)::Nothing
    _data_object(pref).name = name
    JuMP.owner_model(pref).name_to_param = nothing
    return
end

# Make a parameter reference
function _make_parameter_ref(model::InfiniteModel,
                             index::AbstractInfOptIndex)::GeneralVariableRef
    return GeneralVariableRef(model, MOIUC.key_to_index(index), typeof(index))
end

function _make_parameter_ref(model::InfiniteModel,
                             index::DependentParameterIndex
                             )::GeneralVariableRef
    return GeneralVariableRef(model, MOIUC.key_to_index(index.object_index),
                              typeof(index), index.param_index)
end

# Get the name_to_param Dictionary
function _param_name_dict(model::InfiniteModel
    )::Union{Dict{String, AbstractInfOptIndex}, Nothing}
    return model.name_to_param
end

# Update name_to_param
function _update_param_name_dict(model::InfiniteModel,
    param_dict::MOIUC.CleverDict{K, V}
    )::Nothing where {K, V <: ScalarParameterData}
    name_dict = _param_name_dict(model)
    for (index, data_object) in param_dict
        param_name = data_object.name
        if haskey(name_dict, param_name)
            # IndependentParameterIndex(-1) is a special value that means
            # this string does not map to a unique variable name.
            name_dict[param_name] = IndependentParameterIndex(-1)
        else
            name_dict[param_name] = index
        end
    end
    model.name_to_param = name_dict
    return
end

function _update_param_name_dict(model::InfiniteModel,
    param_dict::MOIUC.CleverDict{K, V}
    )::Nothing where {K, V <: MultiParameterData}
    name_dict = _param_name_dict(model)
    for (index, data_object) in param_dict
        param_nums = data_object.parameter_nums
        for i in eachindex(param_nums)
            name = data_object.names[i]
            if haskey(name_dict, name)
                # IndependentParameterIndex(-1) is a special value that means
                # this string does not map to a unique variable name.
                name_dict[name] = IndependentParameterIndex(-1)
            else
                individual_index = DependentParameterIndex(index, i)
                name_dict[name] = individual_index
            end
         end
    end
    model.name_to_param = name_dict
    return
end

# TODO: this is not changing the name registered in model
"""
    parameter_by_name(model::InfiniteModel,
                      name::String)::Union{GeneralVariableRef, Nothing}

Return the parameter reference assoociated with a parameter name. Errors if
multiple parameters have the same name. Returns nothing if no such name exists.

**Example**
```jldoctest; setup = :(using InfiniteOpt, JuMP; model = InfiniteModel(); @independent_parameter(model, t in [0, 1], supports = [0, 1]))
julia> parameter_by_name(model, "t")
t
```
"""
function parameter_by_name(model::InfiniteModel,
                           name::String)::Union{GeneralVariableRef, Nothing}
    if _param_name_dict(model) === nothing
        model.name_to_param = Dict{String, AbstractInfOptIndex}()
        _update_param_name_dict(model, model.independent_params)
        _update_param_name_dict(model, model.dependent_params)
        _update_param_name_dict(model, model.finite_params)
    end
    index = get(_param_name_dict(model), name, nothing)
    if index isa Nothing
        return nothing
    elseif index == IndependentParameterIndex(-1)
        error("Multiple variables have the name $name.")
    else
        return _make_parameter_ref(model, index)
    end
end

################################################################################
#                        DERIVATIVE METHOD FUNCTIONS
################################################################################
"""
    has_derivative_supports(pref::IndependentParameterRef)::Bool

Return whether derivative specific supports have been added to `pref` in accordance 
with its derivative method.
"""
function has_derivative_supports(pref::IndependentParameterRef)::Bool
    return _data_object(pref).has_derivative_supports
end

# Specify if a parameter has derivative supports
function _set_has_derivative_supports(pref::IndependentParameterRef, 
                                     status::Bool)::Nothing
    _data_object(pref).has_derivative_supports = status 
    return
end

# Determine if any derivatives have derivative constraints
function has_derivative_constraints(pref::IndependentParameterRef)::Bool
    return _data_object(pref).has_deriv_constrs
end

# Make update function for whether it has derivative supports 
function _set_has_derivative_constraints(pref::IndependentParameterRef, 
                                         status::Bool)::Nothing 
    _data_object(pref).has_deriv_constrs = status
    return
end

"""
    derivative_method(pref::IndependentParameterRef)::AbstractDerivativeMethod

Returns the numerical derivative evaluation method employed with `pref` when it 
is used as an operator parameter in a derivative.

**Example**
```julia-repl
julia> derivative_method(pref) 
FiniteDifference(Backward, true)
```
"""
function derivative_method(pref::IndependentParameterRef)::AbstractDerivativeMethod
    return _core_variable_object(pref).derivative_method
end

# Make method to reset derivative supports/evaluations
function _reset_derivative_evaluations(pref::Union{IndependentParameterRef, 
                                                   DependentParameterRef})::Nothing
    if has_derivative_constraints(pref)
        @warn("Support/method changes will invalidate existing derivative evaluation " *
              "constraints that have been added to the InfiniteModel. Thus, " *
              "these are being deleted.")
        for idx in _derivative_dependencies(pref)
            delete_derivative_constraints(DerivativeRef(JuMP.owner_model(pref), idx))
        end
        _set_has_derivative_constraints(pref, false)
    end
    if has_derivative_supports(pref)
        old_label = support_label(derivative_method(pref))
        delete_supports(pref, label = old_label)
        _set_has_derivative_supports(pref, false)
    end
    return
end

"""
    set_derivative_method(pref::IndependentParameterRef, 
                          method::AbstractDerivativeMethod)::Nothing

Specfies the desired derivative evaluation method `method` for derivatives that are 
taken with respect to `pref`. Any internal supports exclusively associated with 
the previous method will be deleted. Also, if any derivatives were evaluated 
manually, the associated derivative evaluation constraints will be deleted.

**Example**
```julia-repl
julia> set_derivative_method(d, OrthogonalCollocation(2))

```
"""
function set_derivative_method(pref::IndependentParameterRef, 
    method::AbstractDerivativeMethod
    )::Nothing
    old_param = _core_variable_object(pref)
    set = _parameter_set(pref)
    supps = _parameter_supports(pref)
    sig_figs = significant_digits(pref)
    new_param = IndependentParameter(set, supps, sig_figs, method)
    _reset_derivative_evaluations(pref)
    _set_core_variable_object(pref, new_param)
    if is_used(pref)
        set_optimizer_model_ready(JuMP.owner_model(pref), false)
    end
    return
end

################################################################################
#                               SET FUNCTIONS
################################################################################
# Internal functions
function _parameter_set(pref::IndependentParameterRef)::InfiniteScalarSet
    return _core_variable_object(pref).set
end
function _update_parameter_set(pref::IndependentParameterRef,
                               set::AbstractInfiniteSet)::Nothing
    # old supports will always be discarded
    sig_digits = significant_digits(pref)
    method = derivative_method(pref)
    new_param = IndependentParameter(set, DataStructures.SortedDict{Float64, Set{DataType}}(),
                                     sig_digits, method)
    _set_core_variable_object(pref, new_param)
    _reset_derivative_evaluations(pref)
    _set_has_internal_supports(pref, false)
    if is_used(pref)
        set_optimizer_model_ready(JuMP.owner_model(pref), false)
    end
    return
end

"""
    infinite_set(pref::IndependentParameterRef)::InfiniteScalarSet

Return the infinite set associated with `pref`.

**Example**
```julia-repl
julia> infinite_set(t)
[0, 1]
```
"""
function infinite_set(pref::IndependentParameterRef)::InfiniteScalarSet
    return _parameter_set(pref)
end

"""
    set_infinite_set(pref::IndependentParameterRef,
                     set::InfiniteScalarSet)::Nothing

Reset the infinite set of `pref` with another `InfiniteScalarSet`. An error will 
be thrown if `pref` is being used by some measure.

**Example**
```julia-repl
julia> set_infinite_set(t, IntervalSet(0, 2))

julia> infinite_set(t)
[0, 2]
```
"""
function set_infinite_set(pref::IndependentParameterRef,
                          set::InfiniteScalarSet)::Nothing
    if used_by_measure(pref)
        error("$pref is used by a measure so changing its " *
              "infinite set is not allowed.")
    end
    _update_parameter_set(pref, set)
    return
end

################################################################################
#                        LOWER/UPPER BOUND FUNCTIONS
################################################################################
"""
    JuMP.has_lower_bound(pref::IndependentParameterRef)::Bool

Extend the `JuMP.has_lower_bound` function to accomodate infinite parameters.
Return true if the set associated with `pref` has a defined lower bound or if a
lower bound can be found. Extensions with user-defined infinite set types
should extend `JuMP.has_lower_bound(set::NewType)`.

**Example**
```julia-repl
julia> has_lower_bound(t)
true
```
"""
function JuMP.has_lower_bound(pref::IndependentParameterRef)::Bool
    set = _parameter_set(pref)
    return JuMP.has_lower_bound(set)
end

"""
    JuMP.lower_bound(pref::IndependentParameterRef)::Real

Extend the `JuMP.lower_bound` function to accomodate infinite parameters.
Returns the lower bound associated with the infinite set. Errors if such a bound
is not well-defined.

**Example**
```julia-repl
julia> lower_bound(t)
0.0
```
"""
function JuMP.lower_bound(pref::IndependentParameterRef)::Real
    set = _parameter_set(pref)
    if !JuMP.has_lower_bound(pref)
        error("Parameter $(pref) does not have a lower bound.")
    end
    return JuMP.lower_bound(set)
end

"""
    JuMP.set_lower_bound(pref::IndependentParameterRef, lower::Real)::Nothing

Extend the `JuMP.set_lower_bound` function to accomodate infinite parameters.
Updates the infinite set lower bound if such an operation is supported. Set
extensions that seek to employ this should extend
`JuMP.set_lower_bound(set::NewType, lower::Number)`.

**Example**
```julia-repl
julia> set_lower_bound(t, -1)

julia> lower_bound(t)
-1.0
```
"""
function JuMP.set_lower_bound(pref::IndependentParameterRef, lower::Real)::Nothing
    set = _parameter_set(pref)
    new_set = JuMP.set_lower_bound(set, lower)
    _update_parameter_set(pref, new_set)
    return
end

"""
    JuMP.has_upper_bound(pref::IndependentParameterRef)::Bool

Extend the `JuMP.has_upper_bound` function to accomodate infinite parameters.
Return true if the set associated with `pref` has a defined upper bound or if a
upper bound can be found. Extensions with user-defined sets should extend
`JuMP.has_upper_bound(set::NewType)`.

**Example**
```julia-repl
julia> has_upper_bound(t)
true
```
"""
function JuMP.has_upper_bound(pref::IndependentParameterRef)::Bool
    set = _parameter_set(pref)
    return JuMP.has_upper_bound(set)
end

"""
    JuMP.upper_bound(pref::IndependentParameterRef)::Real

Extend the `JuMP.upper_bound` function to accomodate infinite parameters.
Returns the upper bound associated with the infinite set. Errors if such a bound
is not well-defined. Extensions with user-defined set types should extend
`JuMP.has_upper_bound(set::NewType)` and `JuMP.upper_bound(set::NewType)` if
appropriate.

**Example**
```julia-repl
julia> upper_bound(t)
1.0
```
"""
function JuMP.upper_bound(pref::IndependentParameterRef)::Real
    set = _parameter_set(pref)
    if !JuMP.has_upper_bound(pref)
        error("Parameter $(pref) does not have a upper bound.")
    end
    return JuMP.upper_bound(set)
end

"""
    JuMP.set_upper_bound(pref::IndependentParameterRef, lower::Real)::Nothing

Extend the `JuMP.set_upper_bound` function to accomodate infinite parameters.
Updates the infinite set upper bound if and only if it is an IntervalSet. Errors
otherwise. Extensions with user-defined infinite sets should extend
`JuMP.set_upper_bound(set::NewType, upper::Number)` if appropriate.

**Example**
```julia-repl
julia> set_upper_bound(t, 2)

julia> upper_bound(t)
2.0
```
"""
function JuMP.set_upper_bound(pref::IndependentParameterRef, upper::Real)::Nothing
    set = _parameter_set(pref)
    new_set = JuMP.set_upper_bound(set, upper)
    _update_parameter_set(pref, new_set)
    return
end

################################################################################
#                               SUPPORT FUNCTIONS
################################################################################
# Internal functions
function _parameter_supports(pref::IndependentParameterRef)
    return _core_variable_object(pref).supports
end
function _parameter_support_values(pref::IndependentParameterRef)::Vector{Float64}
    return collect(keys(_parameter_supports(pref)))
end
function _update_parameter_supports(pref::IndependentParameterRef,
    supports::DataStructures.SortedDict{Float64, Set{DataType}})::Nothing
    set = _parameter_set(pref)
    method = derivative_method(pref)
    sig_figs = significant_digits(pref)
    new_param = IndependentParameter(set, supports, sig_figs, method)
    _set_core_variable_object(pref, new_param)
    _reset_derivative_evaluations(pref)
    if is_used(pref)
        set_optimizer_model_ready(JuMP.owner_model(pref), false)
    end
    return
end

"""
    has_internal_supports(pref::Union{IndependentParameterRef, DependentParameterRef})::Bool

Indicate if `pref` has internal supports that will be hidden from the user by 
default. 
"""
function has_internal_supports(
    pref::Union{IndependentParameterRef, DependentParameterRef}
    )::Bool 
    return _data_object(pref).has_internal_supports
end

# update has internal supports 
function _set_has_internal_supports(
    pref::Union{IndependentParameterRef, DependentParameterRef}, 
    status::Bool
    )::Nothing
    _data_object(pref).has_internal_supports = status
    return
end

"""
    significant_digits(pref::IndependentParameterRef)::Int

Return the number of significant digits enforced on the supports of `pref`.

**Example**
```julia-repl
julia> significant_digits(t)
12
```
"""
function significant_digits(pref::IndependentParameterRef)::Int
    return _core_variable_object(pref).sig_digits
end

"""
    num_supports(pref::IndependentParameterRef; 
                 [label::Type{<:AbstractSupportLabel} = PublicLabel])::Int

Return the number of support points associated with `pref`. By default, only the 
number of public supports are counted. The full amount can be determined by setting 
`label = All`. Moreover, the amount of labels that satisfy `label` is obtained 
using an [`AbstractSupportLabel`](@ref).

**Example**
```julia-repl
julia> num_supports(t)
2
```
"""
function num_supports(pref::IndependentParameterRef; 
                      label::Type{<:AbstractSupportLabel} = PublicLabel)::Int
    supports_dict = _parameter_supports(pref)
    if label == All || (!has_internal_supports(pref) && label == PublicLabel)
        return length(supports_dict)
    else
        return count(p -> any(v -> v <: label, p[2]), supports_dict)
    end
end

"""
    has_supports(pref::IndependentParameterRef)::Bool

Return true if `pref` has supports or false otherwise.

**Example**
```julia-repl
julia> has_supports(t)
true
```
"""
has_supports(pref::IndependentParameterRef)::Bool = !isempty(_parameter_supports(pref))

"""
    supports(pref::IndependentParameterRef; 
             [label::Type{<:AbstractSupportLabel} = PublicLabel])::Vector{Float64}

Return the support points associated with `pref`. Errors if there are no
supports. Users can query just support points generated by a certain method
using the keyword argument `label`. By default, the function returns all public
support points regardless of the associated label. The full collection is given by setting 
`label = All`. Moreover, the amount of labels that satisfy `label` is obtained 
using an [`AbstractSupportLabel`](@ref).

**Example**
```julia-repl
julia> supports(t)
2-element Array{Float64,1}:
 0.0
 1.0
```
"""
function supports(pref::IndependentParameterRef; 
                  label::Type{<:AbstractSupportLabel} = PublicLabel)::Vector{Float64}
    if label == All || (!has_internal_supports(pref) && label == PublicLabel)
        return _parameter_support_values(pref)
    else
        return findall(x -> any(v -> v <: label, x), _parameter_supports(pref))
    end
end

# Return a matrix os supports when given a vector of IndependentParameterRefs (for measures)
function supports(prefs::Vector{IndependentParameterRef};
                  label::Type{<:AbstractSupportLabel} = PublicLabel,
                  use_combinatorics::Bool = true)::Matrix{Float64}
    # generate the support matrix considering all the unique combinations
    if use_combinatorics 
        supp_list = Tuple(supports(p, label = label) for p in prefs)
        inds = CartesianIndices(ntuple(i -> 1:length(supp_list[i]), length(prefs)))
        supps = Matrix{Float64}(undef, length(prefs), length(inds))
        for (k, idx) in enumerate(inds) 
            supps[:, k] = [supp_list[i][j] for (i, j) in enumerate(idx.I)]
        end
        return supps
    # generate the support matrix while negating the unique combinations
    else 
        num_supps = num_supports(first(prefs), label = label)
        trans_supps = Matrix{Float64}(undef, num_supps, length(prefs))
        for i in eachindex(prefs)
            supp = supports(prefs[i], label = label)
            if length(supp) != num_supps
                error("Cannot simultaneously query the supports of multiple " *
                      "independent parameters if the support dimensions do not match " *
                      "while ignoring the combinatorics. Try setting `use_combinatorics = true`.")
            else
                @inbounds trans_supps[:, i] = supp
            end
        end
        return permutedims(trans_supps)
    end
end

"""
    set_supports(pref::IndependentParameterRef, supports::Vector{<:Real};
                 [force::Bool = false,
                 label::Type{<:AbstractSupportLabel} = UserDefined]
                 )::Nothing

Specify the support points for `pref`. Errors if the supports violate the bounds
associated with the infinite set. Warns if the points are not unique. If `force`
this will overwrite exisiting supports otherwise it will error if there are
existing supports.

**Example**
```julia-repl
julia> set_supports(t, [0, 1])

julia> supports(t)
2-element Array{Int64,1}:
 0
 1
```
"""
function set_supports(pref::IndependentParameterRef, supports::Vector{<:Real};
                      force::Bool = false, 
                      label::Type{<:AbstractSupportLabel} = UserDefined
                      )::Nothing
    if has_supports(pref) && !force
        error("Unable set supports for $pref since it already has supports." *
              " Consider using `add_supports` or use set `force = true` to " *
              "overwrite the existing supports.")
    end
    set = _parameter_set(pref)
    supports = round.(supports, sigdigits = significant_digits(pref))
    _check_supports_in_bounds(error, supports, set)
    supports_dict = DataStructures.SortedDict{Float64, Set{DataType}}(
                                            i => Set([label]) for i in supports)
    if length(supports_dict) != length(supports)
        @warn("Support points are not unique, eliminating redundant points.")
    end
    _update_parameter_supports(pref, supports_dict)
    _set_has_internal_supports(pref, label <: InternalLabel)
    return
end

"""
    add_supports(pref::IndependentParameterRef,
                 supports::Union{Real, Vector{<:Real}};
                 [label::Type{<:AbstractSupportLabel} = UserDefined])::Nothing

Add additional support points for `pref` with identifying label `label`.

**Example**
```julia-repl
julia> add_supports(t, 0.5)

julia> supports(t)
3-element Array{Float64,1}:
 0.0
 0.5
 1.0

julia> add_supports(t, [0.25, 1])

julia> supports(t)
4-element Array{Float64,1}:
 0.0
 0.25
 0.5
 1.0
```
"""
function add_supports(pref::IndependentParameterRef,
                      supports::Union{Real, Vector{<:Real}};
                      label::Type{<:AbstractSupportLabel} = UserDefined, 
                      check::Bool = true)::Nothing
    set = infinite_set(pref)
    supports = round.(supports, sigdigits = significant_digits(pref))
    check && _check_supports_in_bounds(error, supports, set)
    supports_dict = _parameter_supports(pref)
    for s in supports
        if haskey(supports_dict, s)
            push!(supports_dict[s], label)
        else
            supports_dict[s] = Set([label])
        end
    end
    _reset_derivative_evaluations(pref)
    if label <: InternalLabel
        _set_has_internal_supports(pref, true)
    end
    if is_used(pref)
        set_optimizer_model_ready(JuMP.owner_model(pref), false)
    end
    return
end

"""
    delete_supports(pref::IndependentParameterRef; 
                    [label::Type{<:AbstractSupportLabel} = All])::Nothing

Delete the support points for `pref`. If `label != All` then delete `label` and 
any supports that solely depend on it.

**Example**
```julia-repl
julia> delete_supports(t)

julia> supports(t)
ERROR: Parameter t does not have supports.
```
"""
function delete_supports(pref::IndependentParameterRef; 
                         label::Type{<:AbstractSupportLabel} = All)::Nothing
    supp_dict = _parameter_supports(pref)
    if has_derivative_constraints(pref)
        @warn("Deleting supports invalidated derivative evaluations. Thus, these " * 
              "are being deleted as well.")
        for idx in _derivative_dependencies(pref)
            delete_derivative_constraints(DerivativeRef(JuMP.owner_model(pref), idx))
        end
        _set_has_derivative_constraints(pref, false)
    end
    if label == All
        if used_by_measure(pref)
            error("Cannot delete the supports of $pref since it is used by " *
                  "a measure.")
        end
        empty!(supp_dict)
        _set_has_derivative_supports(pref, false)
        _set_has_internal_supports(pref, false)
    else
        if has_derivative_supports(pref) && support_label(derivative_method(pref)) != label
            label = Union{label, support_label(pref)}
            _set_has_derivative_supports(pref, false)
        end
        filter!(p -> !all(v -> v <: label, p[2]), supp_dict)
        for (k, v) in supp_dict 
            filter!(l -> !(l <: label), v)
        end
        if has_internal_supports(pref) && num_supports(pref, label = InternalLabel) == 0
            _set_has_internal_supports(pref, false)
        end
    end
    if is_used(pref)
        set_optimizer_model_ready(JuMP.owner_model(pref), false)
    end
    return
end

# Make dispatch for an array of parameters 
function delete_supports(prefs::AbstractArray{<:IndependentParameterRef}; 
                         label::Type{<:AbstractSupportLabel} = All)::Nothing
    delete_supports.(prefs, label = label)
    return
end

"""
    parameter_value(pref::FiniteParameterRef)::Float64

Return the value of a finite parameter reference `pref`. Errors if it is
an infinite parameter.

**Example**
```julia-repl
julia> value(cost)
42.0
```
"""
function parameter_value(pref::FiniteParameterRef)::Real
    return _core_variable_object(pref).value
end

"""
    JuMP.set_value(pref::FiniteParameterRef, value::Real)::Nothing

Set the value of `pref` so long as it is a finite parameter. Errors if it is
an infinite parameter.

**Example**
```julia-repl
julia> set_value(cost, 27)

julia> value(cost)
27.0
```
"""
function JuMP.set_value(pref::FiniteParameterRef, value::Real)::Nothing
    _data_object(pref).parameter = FiniteParameter(value)
    if is_used(pref)
        set_optimizer_model_ready(JuMP.owner_model(pref), false)
    end
    return
end

"""
    fill_in_supports!(pref::IndependentParameterRef;
                      [num_supports::Int = DefaultNumSupports])::Nothing

Automatically generate support points for a particular independent parameter `pref`.
Generating `num_supports` for the parameter. The supports are generated uniformly
if the underlying infinite set is an `IntervalSet` or they are generating randomly
accordingly to the distribution if the set is a `UniDistributionSet`.
Will add nothing if there are supports
and `modify = false`. Extensions that use user defined set types should extend
[`generate_and_add_supports!`](@ref) and/or [`generate_support_values`](@ref)
as needed. Errors if the infinite set type is not recognized.

**Example**
```julia-repl
julia> fill_in_supports!(x, num_supports = 4)

julia> supports(x)
4-element Array{Number,1}:
 0.0
 0.333
 0.667
 1.0

```
"""
function fill_in_supports!(pref::IndependentParameterRef;
                           num_supports::Int = DefaultNumSupports,
                           modify::Bool = true)::Nothing
    set = infinite_set(pref)
    current_amount = length(_parameter_supports(pref))
    if (modify || current_amount == 0) && current_amount < num_supports
        generate_and_add_supports!(pref, set,
                                   num_supports = num_supports - current_amount,
                                   adding_extra = (current_amount > 0))
    end
    return
end

"""
    generate_and_add_supports!(pref::IndependentParameterRef,
                               set::AbstractInfiniteSet,
                               [method::Type{<:AbstractSupportLabel}];
                               [num_supports::Int = DefaultNumSupports])::Nothing

Generate supports for independent parameter `pref` via [`generate_support_values`](@ref)
and add them to `pref`. This is intended as an extendable internal method for
[`fill_in_supports!`](@ref fill_in_supports!(::IndependentParameterRef)).
Most extensions that empoy user-defined infinite sets can typically enable this
by extending [`generate_support_values`](@ref). Errors if the infinite set type
is not recognized.
"""
function generate_and_add_supports!(pref::IndependentParameterRef,
                                    set::AbstractInfiniteSet;
                                    num_supports::Int = DefaultNumSupports,
                                    adding_extra::Bool = false)::Nothing
    sig_digits = significant_digits(pref)
    if isa(set, IntervalSet) && adding_extra
        supports, label = generate_support_values(set, MCSample,
                                                  num_supports = num_supports,
                                                  sig_digits = sig_digits)
    else
        supports, label = generate_supports(set,
                                            num_supports = num_supports,
                                            sig_digits = sig_digits)
    end
    add_supports(pref, supports, label = label)
    return
end

# Dispatch with method 
function generate_and_add_supports!(pref::IndependentParameterRef,
                                    set::AbstractInfiniteSet,
                                    method::Type{<:AbstractSupportLabel};
                                    num_supports::Int = DefaultNumSupports,
                                    adding_extra::Bool = false)::Nothing
    sig_digits = significant_digits(pref)
    supports, label = generate_supports(set, method,
                                        num_supports = num_supports,
                                        sig_digits = sig_digits)
    add_supports(pref, supports, label = label)
    return
end

################################################################################
#                               DELETE FUNCTIONS
################################################################################
# Check if parameter is used by measure data and error if it is to prevent bad
# deleting behavior
function _check_param_in_data(pref::GeneralVariableRef,
                              data::AbstractMeasureData)::Nothing
    prefs = parameter_refs(data)
    if (pref == prefs || pref in prefs)
        error("Unable to delete `$pref` since it is used to evaluate measures.")
    end
    return
end

# Update a reduced variable associated with an infinite variable whose parameter
# was removed
function _update_reduced_variable(vref::ReducedVariableRef,
                                  delete_indices::UnitRange{Int})::Nothing
    eval_supps = eval_supports(vref)
    new_supports = Dict{Int, Float64}()
    num_indices = length(delete_indices)
    for (index, support) in eval_supps
        if index < first(delete_indices)
            new_supports[index] = support
        elseif index > last(delete_indices)
            new_supports[index - num_indices] = support
        end
    end
    obj_nums = _object_numbers(vref)
    param_nums = _parameter_numbers(vref)
    new_var = ReducedVariable(infinite_variable_ref(vref), new_supports,
                              param_nums, obj_nums)
    _set_core_variable_object(vref, new_var)
    # TODO account for possibility that this becomes a point variable
    # TODO account for possibility that this becomes an infinite variable
    return
end

# Update the dependent measures
function _update_measures(model::InfiniteModel,
                          pref::GeneralVariableRef)::Nothing
    for mindex in _measure_dependencies(pref)
        mref = dispatch_variable_ref(model, mindex)
        func = measure_function(mref)
        if func isa GeneralVariableRef
            data = measure_data(mref)
            new_func = zero(JuMP.GenericAffExpr{Float64, GeneralVariableRef})
            new_meas = Measure(new_func, data, Int[], Int[], true)
            _set_core_variable_object(mref, new_meas)
        else
            _remove_variable(func, pref)
        end
    end
    return
end

# Update the dependent constraints
function _update_constraints(model::InfiniteModel,
                             pref::GeneralVariableRef)::Nothing
    for cindex in _constraint_dependencies(pref)
        cref = _temp_constraint_ref(model, cindex)
        func = JuMP.jump_function(JuMP.constraint_object(cref))
        if func isa GeneralVariableRef
            set = JuMP.moi_set(JuMP.constraint_object(cref))
            new_func = zero(JuMP.GenericAffExpr{Float64, GeneralVariableRef})
            new_constr = JuMP.ScalarConstraint(new_func, set)
            _set_core_constraint_object(cref, new_constr)
            empty!(_object_numbers(cref))
        else
            _remove_variable(func, pref)
        end
    end
    return
end

# Remove given object/parameter number and update the list
function _update_number_list(nums::Vector{Int}, list::Vector{Int})::Nothing
    filter!(e -> !(e in nums), list)
    max_num = maximum(nums)
    for i in eachindex(list)
        if list[i] > max_num
            list[i] -= length(nums)
        end
    end
    return
end

# Update the model with the removed parameter/object numbers
function _update_model_numbers(model::InfiniteModel, obj_num::Int,
                               param_nums::Vector{Int})::Nothing
    # update the independent parameters
    for (_, object) in _data_dictionary(model, IndependentParameter)
        if object.object_num > obj_num
            object.object_num -= 1
            object.parameter_num -= length(param_nums)
        end
    end
    # update the dependent parameters
    for (_, object) in _data_dictionary(model, DependentParameters)
        if object.object_num > obj_num
            object.object_num -= 1
            object.parameter_nums = object.parameter_nums .- length(param_nums)
        end
    end
    # update the infinite variables
    for vref in JuMP.all_variables(model, InfiniteVariable)
        _update_number_list([obj_num], _object_numbers(vref))
        _update_number_list(param_nums, _parameter_numbers(vref))
    end
    # update the reduced variables
    for vref in JuMP.all_variables(model, ReducedVariable)
        _update_number_list([obj_num], _object_numbers(vref))
        _update_number_list(param_nums, _parameter_numbers(vref))
    end
    # update the measures
    for mref in all_measures(model)
        _update_number_list([obj_num], _object_numbers(mref))
        _update_number_list(param_nums, _parameter_numbers(mref))
    end
    # update the constraints
    for (_, object) in model.constraints
        _update_number_list([obj_num], object.object_nums)
    end
    # update the central info
    deleteat!(_param_object_indices(model), obj_num)
    model.last_param_num -= length(param_nums)
    return
end

"""
    JuMP.delete(model::InfiniteModel, pref::ScalarParameterRef)::Nothing

Extend [`JuMP.delete`](@ref JuMP.delete(::JuMP.Model, ::JuMP.VariableRef)) to delete
scalar parameters and their dependencies. All variables, constraints, and
measure functions that depend on `pref` are updated to exclude it. Errors if the
parameter is contained in an `AbstractMeasureData` datatype that is employed by
a measure since the measure becomes invalid otherwise. Thus, measures that
contain this dependency must be deleted first. Note that
[`parameter_refs`](@ref parameter_refs(::AbstractMeasureData)) needs to be
extended to allow deletion of parameters when custom `AbstractMeasureData`
datatypes are used. Note that any dependent infinite variables will have their
start values reset via [`reset_start_value_function`](@ref).

**Example**
```julia-repl
julia> print(model)
Min measure(g(t, x)*t + x) + z
Subject to
 z ≥ 0.0
 g(t, x) + z ≥ 42.0, ∀ t ∈ [0, 6], x ∈ [-1, 1]
 g(0.5, x) = 0, ∀ x ∈ [-1, 1]

julia> delete(model, x)

julia> print(model)
Min measure(g(t)*t) + z
Subject to
 g(t) + z ≥ 42.0, ∀ t ∈ [0, 6]
 g(0.5) = 0
```
"""
function JuMP.delete(model::InfiniteModel, pref::IndependentParameterRef)::Nothing
    @assert JuMP.is_valid(model, pref) "Parameter reference is invalid."
    gvref = _make_parameter_ref(JuMP.owner_model(pref), JuMP.index(pref))
    # ensure deletion is okay (pref isn't used by measure data)
    for mindex in _measure_dependencies(pref)
        data = measure_data(dispatch_variable_ref(model, mindex))
        _check_param_in_data(gvref, data)
    end
    # ensure pref is not used by a parameter function 
    if used_by_parameter_function(pref)
        error("Cannot delete `$pref` since it is used by an infinite parameter " * 
              "function.")
    end
    # update optimizer model status
    if is_used(pref)
        set_optimizer_model_ready(model, false)
    end
    # delete dependence of measures on pref
    _update_measures(model, gvref)
    # update infinite variables that depend on pref
    for vindex in _infinite_variable_dependencies(pref)
        # remove the parameter dependence
        vref = InfiniteVariableRef(model, vindex)
        prefs = raw_parameter_refs(vref)
        delete_index = findfirst(isequal(gvref), prefs)
        deleteat!(prefs, delete_index)
        reset_start_value_function(vref)
        # update any point variables that depend on vref accordingly
        for pindex in _point_variable_dependencies(vref)
            pvref = PointVariableRef(model, pindex)
            deleteat!(raw_parameter_values(pvref), delete_index)
        end
        # update any reduced variables that depend on vref accordingly
        for rindex in _reduced_variable_dependencies(vref)
            rvref = ReducedVariableRef(model, rindex)
            _update_reduced_variable(rvref, delete_index:delete_index)
        end
    end
    # delete any derivatives that use pref 
    for index in _derivative_dependencies(pref)
        JuMP.delete(model, dispatch_variable_ref(model, index))
    end
    # update constraints in mapping to remove the parameter
    _update_constraints(model, gvref)
    # delete parameter information stored in model
    obj_num = _object_number(pref)
    param_nums = _parameter_numbers(pref)
    _delete_data_object(pref)
    # update the object numbers and parameter numbers
    _update_model_numbers(model, obj_num, param_nums)
    return
end

# FiniteParameterRef
function JuMP.delete(model::InfiniteModel, pref::FiniteParameterRef)::Nothing
    @assert JuMP.is_valid(model, pref) "Parameter reference is invalid."
    # update optimizer model status
    if is_used(pref)
        set_optimizer_model_ready(model, false)
    end
    gvref = _make_parameter_ref(model, JuMP.index(pref))
    # delete dependence of measures on pref
    _update_measures(model, gvref)
    # update constraints in mapping to remove the parameter
    _update_constraints(model, gvref)
    # update the objective if necessary
    if used_by_objective(pref)
        func = JuMP.objective_function(model)
        if func isa GeneralVariableRef
            new_func = zero(JuMP.GenericAffExpr{Float64, GeneralVariableRef})
            JuMP.set_objective_function(model, new_func)
            JuMP.set_objective_sense(model, MOI.FEASIBILITY_SENSE)
        else
            _remove_variable(func, gvref)
        end
    end
    # delete parameter information stored in model
    _delete_data_object(pref)
    return
end
