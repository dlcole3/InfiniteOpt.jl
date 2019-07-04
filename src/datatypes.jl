"""
    AbstractInfiniteSet

An abstract type for sets that characterize infinite parameters.
"""
abstract type AbstractInfiniteSet end

"""
    InfOptParameter{T <: AbstractInfiniteSet} <: JuMP.AbstractVariable

A DataType for storing core infinite parameter information.

**Fields**
- `set::T` The infinite set that characterizes the parameter.
- `supports::Vector{<:Number}` The support points used to discretize this
                               parameter.
- `independent::Bool` Is independent of other parameters that share its group ID
                      number.
"""
struct InfOptParameter{T <: AbstractInfiniteSet} <: JuMP.AbstractVariable
    set::T
    supports::Vector{<:Number}
    independent::Bool
end

# Extend to handle InfOptParameters correctly
function Base.:(==)(p1::InfOptParameter, p2::InfOptParameter)
    check1 = p1.set == p2.set
    check2 = isequal(p1.supports, p2.supports)
    check3 = p1.independent == p2.independent
    return (check1 && check2 && check3)
end

"""
    AbstractMeasureData

An abstract type for infinite, point, and global variables.
"""
abstract type InfOptVariable <: JuMP.AbstractVariable end

"""
    AbstractMeasureData

An abstract type to define data for measures to define the behavior of
[`Measure`](@ref).
"""
abstract type AbstractMeasureData end

"""
    Measure{T <: JuMP.AbstractJuMPScalar, V <: AbstractMeasureData}

A DataType for measure abstractions.

**Fields**
- `func::T` Infinite variable expression.
- `data::V` Data of the abstraction as described in a `AbstractMeasureData`
            subtype.
"""
struct Measure{T <: JuMP.AbstractJuMPScalar, V <: AbstractMeasureData}
    func::T
    data::V
end

"""
    InfiniteModel <: JuMP.AbstractModel

A DataType for storing all of the mathematical modeling information needed to
model an optmization problem with an infinite dimensional decision space.

**Fields**
- `next_meas_index::Int` Index - 1 of next measure.
- `measures::Dict{Int, Measure}` Measure indices to measure datatypes.
- `meas_to_name::Dict{Int, String}` Measure indices to names.
- `next_param_index::Int` Index - 1 of next infinite parameter.
- `next_param_id::Int` Index - 1 of the next infinite parameter group.
- `params::Dict{Int, InfOptParameter}` Infinite parameter indices to parameter
                                       datatype.
- `param_to_name::Dict{Int, String}` Infinite parameter indices to names.
- `name_to_param::Union{Dict{String, Int}, Nothing}` Names to infinite
                                                     parameters.
- `param_to_group_id::Dict{Int, Int}` Infinite parameter indices to group IDs.
- `param_to_constrs::Dict{Int, Vector{Int}}` Infinite parameter indices to list
                                             of dependent constraint indices.
- `param_to_meas::Dict{Int, Vector{Int}}` Infinite parameter indices to list
                                          of dependent measure indices.
- `param_to_vars::Dict{Int, Vector{Int}}` Infinite parameter indices to list
                                          of dependent variable indices.
- `next_var_index::Int` Index - 1 of next variable index.
- `vars::Dict{Int, InfOptVariable}` Variable indices to variable datatype.
- `var_to_name::Dict{Int, String}` Variable indices to names.
- `name_to_var::Union{Dict{String, Int}, Nothing}` Variable names to indices.
- `var_to_lower_bound::Dict{Int, Int}` Variable indices to lower bound index.
- `var_to_upper_bound::Dict{Int, Int}` Variable indices to upper bound index.
- `var_to_fix::Dict{Int, Int}` Variable indices to fix index.
- `var_to_zero_one::Dict{Int, Int}` Variable indices to binary index.
- `var_to_integrality::Dict{Int, Int}` Variable indices to integer index.
- `var_to_constrs::Dict{Int, Vector{Int}}` Variable indices to dependent
                                           constraint indices.
- `var_to_meas::Dict{Int, Vector{Int}}` Variable indices to dependent
                                        measure indices.
- `var_in_objective::Dict{Int, Bool}` Variable indices to if used in objective.
- `next_constr_index::Int` Index - 1 of next constraint.
- `constrs::Dict{Int, JuMP.AbstractConstraint}` Constraint indices to constraint
                                                datatypes.
- `constr_to_name::Dict{Int, String}` Constraint indices to names.
- `name_to_constr::Union{Dict{String, Int}, Nothing}` Constraint names to
                                                      indices.
- `constr_in_var_info::Dict{Int, Bool}` Constraint indices to if related to
                                        variable information constraints.
- `objective_sense::MOI.OptimizationSense` Objective sense.
- `objective_function::JuMP.AbstractJuMPScalar` Finite scalar function.
- `obj_dict::Dict{Symbol, Any}` Store Julia symbols used with `InfiniteModel`
- `optimizer_factory::Union{JuMP.OptimizerFactory, Nothing}` Optimizer
                                                             information.
- `optimizer_model::JuMP.Model` Model used to solve `InfiniteModel`
- `ready_to_optimize::Bool` Is the optimizer_model up to date.
"""
mutable struct InfiniteModel <: JuMP.AbstractModel
    # Measure Data
    next_meas_index::Int
    measures::Dict{Int, Measure}
    meas_to_name::Dict{Int, String}

    # Parameter Data
    next_param_index::Int
    next_param_id::Int
    params::Dict{Int, InfOptParameter}
    param_to_name::Dict{Int, String}
    name_to_param::Union{Dict{String, Int}, Nothing}
    param_to_group_id::Dict{Int, Int}
    param_to_constrs::Dict{Int, Vector{Int}}
    param_to_meas::Dict{Int, Vector{Int}}
    param_to_vars::Dict{Int, Vector{Int}}

    # Variable data
    next_var_index::Int
    vars::Dict{Int, InfOptVariable}
    var_to_name::Dict{Int, String}
    name_to_var::Union{Dict{String, Int}, Nothing}
    var_to_lower_bound::Dict{Int, Int}
    var_to_upper_bound::Dict{Int, Int}
    var_to_fix::Dict{Int, Int}
    var_to_zero_one::Dict{Int, Int}
    var_to_integrality::Dict{Int, Int}
    var_to_constrs::Dict{Int, Vector{Int}}
    var_to_meas::Dict{Int, Vector{Int}}
    var_in_objective::Dict{Int, Bool}

    # Constraint Data
    next_constr_index::Int
    constrs::Dict{Int, JuMP.AbstractConstraint}
    constr_to_name::Dict{Int, String}
    name_to_constr::Union{Dict{String, Int}, Nothing}
    constr_in_var_info::Dict{Int, Bool}

    # Objective Data
    objective_sense::MOI.OptimizationSense
    objective_function::JuMP.AbstractJuMPScalar

    # Objects
    obj_dict::Dict{Symbol, Any}

    # Optimize Data
    optimizer_factory::Union{JuMP.OptimizerFactory, Nothing}
    optimizer_model::JuMP.Model
    ready_to_optimize::Bool
end

"""
    InfiniteModel(; [caching_mode::MOIU.CachingOptimizerMode = MOIU.AUTOMATIC])

Return a new infinite model where no optimizer is specified. The
optimizer can later be set with the [`JuMP.optimizer!`](@ref) call. By default
the `optimizer_model` data field is initialized with a `TranscriptionModel`, but
a different type of model can be assigned via [`set_optimizer_model`](@ref) as
can be required by extensions.

**Example**
```julia
julia> model = InfiniteModel()
An InfiniteOpt Model
Feasibility problem with:
Variables: 0
Optimizer model backend information:
Model mode: AUTOMATIC
CachingOptimizer state: NO_OPTIMIZER
Solver name: No optimizer attached.
```
"""
function InfiniteModel(; kwargs...)
    return InfiniteModel(# Measures
                         0, Dict{Int, Measure}(), Dict{Int, String}(),
                         # Parameters
                         0, 0, Dict{Int, InfOptParameter}(), Dict{Int, String}(),
                         nothing, Dict{Int, Int}(), Dict{Int, Vector{Int}}(),
                         Dict{Int, Vector{Int}}(), Dict{Int, Vector{Int}}(),
                         # Variables
                         0, Dict{Int, JuMP.AbstractVariable}(),
                         Dict{Int, String}(), nothing, Dict{Int, Int}(),
                         Dict{Int, Int}(), Dict{Int, Int}(), Dict{Int, Int}(),
                         Dict{Int, Int}(), Dict{Int, Vector{Int}}(),
                         Dict{Int, Vector{Int}}(), Dict{Int, Bool}(),
                         # Constraints
                         0, Dict{Int, JuMP.AbstractConstraint}(),
                         Dict{Int, String}(), nothing, Dict{Int, Bool}(),
                         # Objective
                         MOI.FEASIBILITY_SENSE,
                         zero(JuMP.GenericAffExpr{Float64, FiniteVariableRef}),
                         # Object dictionary
                         Dict{Symbol, Any}(),
                         # Optimize data
                         nothing, TranscriptionModel(kwargs...), false)
end

"""
    InfiniteModel(optimizer_factory::JuMP.OptimizerFactory;
                  [caching_mode::MOIU.CachingOptimizerMode = MOIU.AUTOMATIC,
                  bridge_constraints::Bool = true])

Return a new infinite model using the optimizer factory `optimizer_factory` to
create the optimizer. The optimizer factory can be created by the
[`JuMP.with_optimizer`](@ref) function.

**Example**
```julia
julia> model = InfiniteModel(with_optimizer(Ipopt.Optimizer))
An InfiniteOpt Model
Feasibility problem with:
Variables: 0
Optimizer model backend information:
Model mode: AUTOMATIC
CachingOptimizer state: EMPTY_OPTIMIZER
Solver name: SolverName() attribute not implemented by the optimizer.
```
"""
function InfiniteModel(optimizer_factory::JuMP.OptimizerFactory; kwargs...)
    model = InfiniteModel()
    model.optimizer_factory = optimizer_factory
    model.optimizer_model = TranscriptionModel(optimizer_factory, kwargs...)
    return model
end

# Define basic InfiniteModel extensions
Base.broadcastable(model::InfiniteModel) = Ref(model)
JuMP.object_dictionary(model::InfiniteModel) = model.obj_dict

"""
    GeneralVariableRef <: JuMP.AbstractVariableRef

An abstract type to for variable references used with infinite models.
"""
abstract type GeneralVariableRef <: JuMP.AbstractVariableRef end

"""
    MeasureFiniteVariableRef <: GeneralVariableRef

An abstract type to define finite variable and measure references.
"""
abstract type MeasureFiniteVariableRef <: GeneralVariableRef end

"""
    FiniteVariableRef <: GeneralVariableRef

An abstract type to define new finite variable references.
"""
abstract type FiniteVariableRef <: MeasureFiniteVariableRef end

"""
    GlobalVariableRef <: FiniteVariableRef

A DataType for finite fixed variable references (e.g., first stage variables,
steady-state variables).

**Fields**
- `model::InfiniteModel` Infinite model.
- `index::Int` Index of variable in model.
"""
struct GlobalVariableRef <: FiniteVariableRef
    model::InfiniteModel
    index::Int
end

"""
    PointVariableRef <: FiniteVariableRef

A DataType for variables defined at a transcipted point (e.g., second stage
variable at a particular scenario, dynamic variable at a discretized time point).

**Fields**
- `model::InfiniteModel` Infinite model.
- `index::Int` Index of variable in model.
"""
struct PointVariableRef <: FiniteVariableRef
    model::InfiniteModel
    index::Int
end

"""
    InfiniteVariableRef <: GeneralVariableRef

A DataType for untranscripted infinite dimensional variable references (e.g.,
second stage variables, time dependent variables).

**Fields**
- `model::InfiniteModel` Infinite model.
- `index::Int` Index of variable in model.
"""
struct InfiniteVariableRef <: GeneralVariableRef
    model::InfiniteModel # `model` owning the variable
    index::Int           # Index in `model.variables`
end

# An internal object used to evaluate measures
struct _ReducedInfiniteRef <: GeneralVariableRef
    model::InfiniteModel
    index::Int
    original::InfiniteVariableRef
    supports::Dict{Int, Union{Number, JuMP.Containers.SparseAxisArray{<:Number}}}
end

"""
    ParameterRef <: GeneralVariableRef

A DataType for untranscripted infinite parameters references that parameterize
the infinite variables.

**Fields**
- `model::InfiniteModel` Infinite model.
- `index::Int` Index of variable in model.
"""
struct ParameterRef <: GeneralVariableRef
    model::InfiniteModel
    index::Int
end

# Extend Base.copy for new variable types
function Base.copy(v::ParameterRef, new_model::InfiniteModel)
    return ParameterRef(new_model, v.index)
end

"""
    InfiniteVariable{S, T, U, V} <: InfOptVariable
A DataType for storing core infinite variable information. Note each element of
the parameter reference tuple must contain either a single
[`ParameterRef`](@ref) or an `AbstractArray` of `ParameterRef`s where each
`ParameterRef` has the same group ID number.

**Fields**
- `info::JuMP.VariableInfo{S, T, U, V}` JuMP variable information.
- `parameter_refs::Tuple` The infinite parameters(s) that parameterize the
                          variable.
"""
struct InfiniteVariable{S, T, U, V} <: InfOptVariable
    info::JuMP.VariableInfo{S, T, U, V}
    parameter_refs::Tuple
end

"""
    PointVariable{S, T, U, V} <: InfOptVariable
A DataType for storing point variable information. Note that the elements
`parameter_values` field must match the format of the parameter reference tuple
defined in [`InfiniteVariable`](@ref)

**Fields**
- `info::JuMP.VariableInfo{S, T, U, V}` JuMP Variable information.
- `infinite_variable_ref::InfiniteVariableRef` The infinite variable associated
                                               with the point variable.
- `parameter_values::Tuple` The infinite parameter values defining the point.
"""
struct PointVariable{S, T, U, V} <: InfOptVariable
    info::JuMP.VariableInfo{S, T, U, V}
    infinite_variable_ref::InfiniteVariableRef
    parameter_values::Tuple
end

"""
    GlobalVariable{S, T, U, V} <: InfOptVariable
A DataType for storing global variable information.

**Fields**
- `info::JuMP.VariableInfo{S, T, U, V}` JuMP variable information.
"""
struct GlobalVariable{S, T, U, V} <: InfOptVariable
    info::JuMP.VariableInfo{S, T, U, V}
end

# Define variable references without that aren't measures
const InfOptVariableRef = Union{InfiniteVariableRef, PointVariableRef,
                                GlobalVariableRef}

# Define infinite expressions
const InfiniteExpr = Union{InfiniteVariableRef,
                           JuMP.GenericAffExpr{Float64, InfiniteVariableRef},
                           JuMP.GenericAffExpr{Float64, GeneralVariableRef},
                           JuMP.GenericQuadExpr{Float64, InfiniteVariableRef},
                           JuMP.GenericQuadExpr{Float64, GeneralVariableRef}}
const ParameterExpr = Union{ParameterRef,
                            JuMP.GenericAffExpr{Float64, ParameterRef},
                            JuMP.GenericQuadExpr{Float64, ParameterRef}}

"""
    MeasureRef <: FiniteVariableRef

A DataType for referring to measure abstractions.

**Fields**
- `model::InfiniteModel` Infinite model.
- `index::Int` Index of variable in model.
"""
struct MeasureRef <: MeasureFiniteVariableRef
    model::InfiniteModel
    index::Int
end

"""
    DiscreteMeasureData <: AbstractMeasureData

A DataType for one dimensional measure abstraction data where the measure
abstraction is of the form:
``measure = \\int_{\\tau \\in T} f(\\tau) w(\\tau) d\\tau \\approx \\sum_{i = 1}^N \\alpha_i f(\\tau_i) w(\\tau_i)``.

**Fields**
- `parameter_ref::ParameterRef` The infinite parameter over which the
                                integration occurs.
- `coefficients::Vector{<:Number}` Coefficients ``\\alpha_i`` for the above
                                   measure abstraction.
- `supports::Vector{<:Number}` Support points ``\\tau_i`` for the above
                               measure abstraction.
- `name::String` Name of the measure that will be implemented.
- `weight_function::Function` Weighting function ``w`` must map support value
                              input value of type `Number` to a scalar value.
"""
struct DiscreteMeasureData <: AbstractMeasureData
    parameter_ref::ParameterRef
    coefficients::Vector{<:Number}
    supports::Vector{<:Number}
    name::String
    weight_function::Function
    function DiscreteMeasureData(parameter_ref::ParameterRef,
                                 coeffs::Vector{<:Number},
                                 supports::Vector{<:Number},
                                 name::String, weight_func::Function)
        if length(coeffs) != length(supports)
            error("The amount of coefficients must match the amount of " *
                  "support points.")
        end
        if JuMP.has_lower_bound(parameter_ref)
            check1 = minimum(supports) < JuMP.lower_bound(parameter_ref)
            check2 = maximum(supports) > JuMP.upper_bound(parameter_ref)
            if check1 || check2
                error("Support points violate parameter bounds.")
            end
        end
        return new(parameter_ref, coeffs, supports, name, weight_func)
    end
end

"""
    MultiDiscreteMeasureData<: AbstractMeasureData

A DataType for multi-dimensional measure abstraction data where the measure
abstraction is of the form:
``measure = \\int_{\\tau \\in T} f(\\tau) w(\\tau) d\\tau \\approx \\sum_{i = 1}^N \\alpha_i f(\\tau_i) w(\\tau_i)``.

**Fields**
- `parameter_ref::JuMP.Containers.SparseAxisArray{<:ParameterRef}` The infinite
   parameters over which the integration occurs.
- `coefficients::Vector{<:Number}` Coefficients ``\\alpha_i`` for the above
                                   measure abstraction.
- `supports::Vector{<:JuMP.Containers.SparseAxisArray{<:Number}}` Support points
   ``\\tau_i`` for the above measure abstraction.
- `name::String` Name of the measure that will be implemented.
- `weight_function::Function` Weighting function ``w`` must map a numerical
                              support of type `JuMP.Containers.SparseAxisArray`
                              to a scalar value.
"""
struct MultiDiscreteMeasureData <: AbstractMeasureData
    parameter_ref::JuMP.Containers.SparseAxisArray{<:ParameterRef}
    coefficients::Vector{<:Number}
    supports::Vector{<:JuMP.Containers.SparseAxisArray}
    name::String
    weight_function::Function
    function MultiDiscreteMeasureData(parameter_ref::JuMP.Containers.SparseAxisArray{<:ParameterRef},
                                      coeffs::Vector{<:Number},
                                      supports::Vector{<:JuMP.Containers.SparseAxisArray},
                                      name::String, weight_func::Function)
        if length(coeffs) != length(supports)
            error("The amount of coefficients must match the amount of " *
                  "support points.")
        elseif keys(supports[1].data) != keys(parameter_ref.data)
            error("The keys/dimensions of the support points and parameters " *
                  "do not match.")
        end
        for i = 1:length(supports)
            for key in keys(parameter_ref.data)
                support = supports[i].data[key]
                pref = parameter_ref.data[key]
                if JuMP.has_lower_bound(pref)
                    check1 = support < JuMP.lower_bound(pref)
                    check2 = support > JuMP.upper_bound(pref)
                    if check1 || check2
                        error("Support points violate parameter bounds.")
                    end
                end
            end
        end
        return new(parameter_ref, coeffs, supports, name, weight_func)
    end
end

# Define finite measure expressions (note infinite expression take precedence)
const MeasureExpr = Union{MeasureRef,
                          JuMP.GenericAffExpr{Float64, MeasureRef},
                          JuMP.GenericAffExpr{Float64, MeasureFiniteVariableRef},
                          JuMP.GenericQuadExpr{Float64, MeasureRef},
                          JuMP.GenericQuadExpr{Float64, MeasureFiniteVariableRef}}

"""
    IntervalSet <: AbstractInfiniteSet

A DataType that stores the lower and upper interval bounds for infinite
parameters that are continuous over a certain that interval.

**Fields**
- `lower_bound::Float64` Lower bound of the infinite parameter.
- `upper_bound::Float64` Upper bound of the infinite parameter.
"""
struct IntervalSet <: AbstractInfiniteSet
    lower_bound::Float64
    upper_bound::Float64
end

"""
    IntervalSet(lower_bound::Number, upper_bound::Number)

A constructor for [`IntervalSet`](@ref) that converts values of type `Number` to
values of type `Float64` as required by `IntervalSet`.
"""
IntervalSet(lb::Number, ub::Number) = IntervalSet(convert(Float64, lb),
                                                  convert(Float64, ub))

"""
    DistributionSet{T <: Distributions.NonMatrixDistribution} <: AbstractInfiniteSet

A DataType that stores the distribution characterizing infinite parameters that
are random.

**Fields**
- `distribution::T` Distribution of the random parameter.
"""
struct DistributionSet{T <: Distributions.NonMatrixDistribution} <: AbstractInfiniteSet
    distribution::T
end

"""
    BoundedScalarConstraint{F <: JuMP.AbstractJuMPScalar,
                            S <: MOI.AbstractScalarSet} <: JuMP.AbstractConstraint

A DataType that stores infinite constraints defined on a subset of the infinite
parameters on which they depend.

**Fields**
- `func::F` The JuMP object.
- `set::S` The MOI set.
- `bounds::Dict{ParameterRef, IntervalSet}` A dictionary mapping parameter
                                            references to an interval set.
"""
struct BoundedScalarConstraint{F <: JuMP.AbstractJuMPScalar,
                               S <: MOI.AbstractScalarSet} <: JuMP.AbstractConstraint
    func::F
    set::S
    bounds::Dict{ParameterRef, IntervalSet}
end

"""
    GeneralConstraintRef

An abstract type for constraint references unique to InfiniteOpt.
"""
abstract type GeneralConstraintRef end

"""
InfiniteConstraintRef{S <: JuMP.AbstractShape} <: GeneralConstraintRef

A DataType for constraints that contain infinite variables.

**Fields**
- `model::InfiniteModel` Infinite model.
- `index::Int` Index of constraint in model.
- `shape::JuMP.AbstractShape` Shape of constraint
"""
struct InfiniteConstraintRef{S <: JuMP.AbstractShape} <: GeneralConstraintRef
    model::InfiniteModel
    index::Int
    shape::S
end

"""
    FiniteConstraintRef{S <: JuMP.AbstractShape} <: GeneralConstraintRef

A DataType for constraints that contain finite variables.

**Fields**
- `model::InfiniteModel` Infinite model.
- `index::Int` Index of constraint in model.
- `shape::JuMP.AbstractShape` Shape of constraint
"""
struct FiniteConstraintRef{S <: JuMP.AbstractShape} <: GeneralConstraintRef
    model::InfiniteModel
    index::Int
    shape::S
end

"""
    MeasureConstraintRef{S <: JuMP.AbstractShape} <: GeneralConstraintRef

A DataType for constraints that contain finite variables and measures.

**Fields**
- `model::InfiniteModel` Infinite model.
- `index::Int` Index of constraint in model.
- `shape::JuMP.AbstractShape` Shape of constraint
"""
struct MeasureConstraintRef{S <: JuMP.AbstractShape} <: GeneralConstraintRef
    model::InfiniteModel
    index::Int
    shape::S
end
