# Test Core data accessors
@testset "Core Data Accessers" begin
    # Setup data
    m = InfiniteModel()
    ind_idx = IndependentParameterIndex(1)
    fin_idx = FiniteParameterIndex(1)
    set = IntervalSet(0, 1)
    supps_dict = SortedDict{Float64, Set{DataType}}(0. => Set{DataType}([UserDefined]))
    method = InfiniteOpt.DefaultDerivativeMethod
    ind_param = IndependentParameter(set, supps_dict, 5, method)
    fin_param = FiniteParameter(42)
    ind_object = ScalarParameterData(ind_param, 1, 1, "ind")
    fin_object = ScalarParameterData(fin_param, -1, -1, "fin")
    ind_pref = IndependentParameterRef(m, ind_idx)
    fin_pref = FiniteParameterRef(m, fin_idx)
    ind_gvref = GeneralVariableRef(m, 1, IndependentParameterIndex)
    fin_gvref = GeneralVariableRef(m, 1, FiniteParameterIndex)
    bad_ind_pref = IndependentParameterRef(m, IndependentParameterIndex(-1))
    bad_fin_pref = FiniteParameterRef(m, FiniteParameterIndex(-1))
    # test dispatch_variable_ref
    @testset "dispatch_variable_ref" begin
        @test dispatch_variable_ref(m, ind_idx) == ind_pref
        @test dispatch_variable_ref(ind_gvref) == ind_pref
        @test dispatch_variable_ref(m, fin_idx) == fin_pref
        @test dispatch_variable_ref(fin_gvref) == fin_pref
    end
    # test _add_data_object
    @testset "_add_data_object" begin
        @test InfiniteOpt._add_data_object(m, ind_object) == ind_idx
        @test InfiniteOpt._add_data_object(m, fin_object) == fin_idx
        @test InfiniteOpt._param_object_indices(m)[end] == ind_idx
    end
    # test _data_dictionary
    @testset "_data_dictionary" begin
        @test InfiniteOpt._data_dictionary(ind_pref) === m.independent_params
        @test InfiniteOpt._data_dictionary(ind_gvref) === m.independent_params
        @test InfiniteOpt._data_dictionary(fin_pref) === m.finite_params
        @test InfiniteOpt._data_dictionary(fin_gvref) === m.finite_params
        @test InfiniteOpt._data_dictionary(m, IndependentParameter) === m.independent_params
        @test InfiniteOpt._data_dictionary(m, FiniteParameter) === m.finite_params
    end
    # test _data_object
    @testset "_data_object" begin
        @test InfiniteOpt._data_object(ind_pref) == ind_object
        @test InfiniteOpt._data_object(ind_gvref) == ind_object
        @test InfiniteOpt._data_object(fin_pref) == fin_object
        @test InfiniteOpt._data_object(fin_gvref) == fin_object
        @test_throws ErrorException InfiniteOpt._data_object(bad_ind_pref)
        @test_throws ErrorException InfiniteOpt._data_object(bad_fin_pref)
    end
    # test _core_variable_object
    @testset "_core_variable_object" begin
        @test InfiniteOpt._core_variable_object(ind_pref) == ind_param
        @test InfiniteOpt._core_variable_object(ind_gvref) == ind_param
        @test InfiniteOpt._core_variable_object(fin_pref) == fin_param
        @test InfiniteOpt._core_variable_object(fin_gvref) == fin_param
    end
    # test _parameter_number
    @testset "_parameter_number" begin
        @test InfiniteOpt._parameter_number(ind_pref) == 1
        @test InfiniteOpt._parameter_number(ind_gvref) == 1
    end
    # test _parameter_numbers
    @testset "_parameter_numbers" begin
        @test InfiniteOpt._parameter_numbers(ind_pref) == [1]
        @test InfiniteOpt._parameter_numbers(ind_gvref) == [1]
    end
    # test _object_number
    @testset "_object_number" begin
        @test InfiniteOpt._object_number(ind_pref) == 1
        @test InfiniteOpt._object_number(ind_gvref) == 1
    end
    # test _object_numbers
    @testset "_object_numbers" begin
        @test InfiniteOpt._object_numbers(ind_pref) == [1]
        @test InfiniteOpt._object_numbers(ind_gvref) == [1]
    end
    # test _adaptive_data_update
    @testset "_adaptive_data_update" begin
        # test change of same type
        p = IndependentParameter(IntervalSet(0, 2), supps_dict, 12, method)
        data = InfiniteOpt._data_object(ind_pref)
        @test InfiniteOpt._adaptive_data_update(ind_pref, p, data) isa Nothing
        @test InfiniteOpt._core_variable_object(ind_pref) == p 
        # test change of different types 
        p = IndependentParameter(IntervalSet(0, 2), supps_dict, 12, TestMethod())
        data = InfiniteOpt._data_object(ind_pref)
        @test InfiniteOpt._adaptive_data_update(ind_pref, p, data) isa Nothing
        @test InfiniteOpt._core_variable_object(ind_pref) == p 
    end
    # test _set_core_variable_object
    @testset "_set_core_variable_object" begin
        @test InfiniteOpt._set_core_variable_object(ind_pref, ind_param) isa Nothing
        @test InfiniteOpt._set_core_variable_object(fin_pref, fin_param) isa Nothing
    end
    # test _delete_data_object
    @testset "_delete_data_object" begin
        @test is_valid(m, ind_pref)
        @test is_valid(m, fin_pref)
        @test InfiniteOpt._delete_data_object(ind_pref) isa Nothing
        @test InfiniteOpt._delete_data_object(fin_pref) isa Nothing
        @test !is_valid(m, ind_pref)
        @test !is_valid(m, fin_pref)
    end
end

# Test macro methods
@testset "Macro Helpers" begin
    @testset "Symbol Methods" begin
        @test InfiniteOpt._is_set_keyword(:(lower_bound = 0))
    end
    # test ParameterInfoExpr datatype
    @testset "_ParameterInfoExpr" begin
        @test InfiniteOpt._ParameterInfoExpr isa DataType
        @test InfiniteOpt._ParameterInfoExpr(ones(Bool, 8)...).has_lb
        @test !InfiniteOpt._ParameterInfoExpr().has_lb
    end
    # test InfiniteOpt._set_lower_bound_or_error
    @testset "InfiniteOpt._set_lower_bound_or_error" begin
        info = InfiniteOpt._ParameterInfoExpr()
        # test normal operation
        @test isa(InfiniteOpt._set_lower_bound_or_error(error, info, 0), Nothing)
        @test info.has_lb && info.lower_bound == 0
        # test double/lack of input errors
        @test_throws ErrorException InfiniteOpt._set_lower_bound_or_error(error,
                                                                   info, 0)
        info.has_lb = false; info.has_dist = true
        @test_throws ErrorException InfiniteOpt._set_lower_bound_or_error(error,
                                                                   info, 0)
        info.has_dist = false; info.has_set = true
        @test_throws ErrorException InfiniteOpt._set_lower_bound_or_error(error,
                                                                   info, 0)
    end
    # test InfiniteOpt._set_upper_bound_or_error
    @testset "InfiniteOpt._set_upper_bound_or_error" begin
        info = InfiniteOpt._ParameterInfoExpr()
        # test normal operation
        @test isa(InfiniteOpt._set_upper_bound_or_error(error, info, 0), Nothing)
        @test info.has_ub && info.upper_bound == 0
        # test double/lack of input errors
        @test_throws ErrorException InfiniteOpt._set_upper_bound_or_error(error,
                                                                   info, 0)
        info.has_ub = false; info.has_dist = true
        @test_throws ErrorException InfiniteOpt._set_upper_bound_or_error(error,
                                                                   info, 0)
        info.has_dist = false; info.has_set = true
        @test_throws ErrorException InfiniteOpt._set_upper_bound_or_error(error,
                                                                   info, 0)
    end
    # _dist_or_error
    @testset "_dist_or_error" begin
        info = InfiniteOpt._ParameterInfoExpr()
        # test normal operation
        @test isa(InfiniteOpt._dist_or_error(error, info, 0), Nothing)
        @test info.has_dist && info.distribution == 0
        # test double/lack of input errors
        @test_throws ErrorException InfiniteOpt._dist_or_error(error, info, 0)
        info.has_dist = false; info.has_lb = true
        @test_throws ErrorException InfiniteOpt._dist_or_error(error, info, 0)
        info.has_lb = false; info.has_set = true
        @test_throws ErrorException InfiniteOpt._dist_or_error(error, info, 0)
    end
    # _set_or_error
    @testset "_set_or_error" begin
        info = InfiniteOpt._ParameterInfoExpr()
        # test normal operation
        @test isa(InfiniteOpt._set_or_error(error, info, 0), Nothing)
        @test info.has_set && info.set == 0
        # test double/lack of input errors
        @test_throws ErrorException InfiniteOpt._set_or_error(error, info, 0)
        info.has_set = false; info.has_lb = true
        @test_throws ErrorException InfiniteOpt._set_or_error(error, info, 0)
        info.has_lb = false; info.has_dist = true
        @test_throws ErrorException InfiniteOpt._set_or_error(error, info, 0)
    end
    # _constructor_set
    @testset "InfiniteOpt._constructor_set" begin
        info = InfiniteOpt._ParameterInfoExpr()
        @test_throws ErrorException InfiniteOpt._constructor_set(error, info)
        info.has_lb = true; info.lower_bound = 0
        @test_throws ErrorException InfiniteOpt._constructor_set(error, info)
        info.has_ub = true; info.upper_bound = 1
        check = :(isa($(info.lower_bound), Real))
        expected = :($(check) ? IntervalSet($(info.lower_bound), $(info.upper_bound)) : error("Bounds must be a number."))
        @test InfiniteOpt._constructor_set(error, info) == expected
        info = InfiniteOpt._ParameterInfoExpr(distribution = Normal())
        check = :(isa($(info.distribution), Distributions.UnivariateDistribution))
        expected = :($(check) ? UniDistributionSet($(info.distribution)) : error("Distribution must be a Distributions.UnivariateDistribution."))
        @test InfiniteOpt._constructor_set(error, info) == expected
        info = InfiniteOpt._ParameterInfoExpr(set = IntervalSet(0, 1))
        check1 = :(isa($(info.set), InfiniteScalarSet))
        check2 = :(isa($(info.set), Distributions.UnivariateDistribution))
        expected = :($(check1) ? $(info.set) : ($(check2) ? UniDistributionSet($(info.set)) : error("Set must be a subtype of InfiniteScalarSet.")))
        @test InfiniteOpt._constructor_set(error, info) == expected
    end

    # _parse_one_operator_parameter
    @testset "_parse_one_operator_parameter" begin
        info = InfiniteOpt._ParameterInfoExpr()
        @test isa(InfiniteOpt._parse_one_operator_parameter(error, info,
                                                          Val(:<=), 0), Nothing)
        @test info.has_ub && info.upper_bound == 0
        @test isa(InfiniteOpt._parse_one_operator_parameter(error, info,
                                                          Val(:>=), 0), Nothing)
        @test info.has_lb && info.lower_bound == 0
        info = InfiniteOpt._ParameterInfoExpr()
        @test isa(InfiniteOpt._parse_one_operator_parameter(error, info,
                                                          Val(:in), esc(0)), Nothing)
        @test info.has_set && info.set == esc(0)
        info = InfiniteOpt._ParameterInfoExpr()
        @test isa(InfiniteOpt._parse_one_operator_parameter(error, info,
                                                          Val(:in), esc(:([0, 1]))), Nothing)
        @test info.has_lb && info.has_ub
        @test_throws ErrorException InfiniteOpt._parse_one_operator_parameter(error, info,
                                                                              Val(:d), 0)
    end
    # _parse_ternary_parameter
    @testset "_parse_ternary_parameter" begin
        info = InfiniteOpt._ParameterInfoExpr()
        @test isa(InfiniteOpt._parse_ternary_parameter(error, info, Val(:<=), 0,
                                                       Val(:<=), 0), Nothing)
        @test info.has_ub && info.upper_bound == 0
        @test info.has_lb && info.lower_bound == 0
        info = InfiniteOpt._ParameterInfoExpr()
        @test isa(InfiniteOpt._parse_ternary_parameter(error, info, Val(:>=), 0,
                                                       Val(:>=), 0), Nothing)
        @test info.has_ub && info.upper_bound == 0
        @test info.has_lb && info.lower_bound == 0
        @test_throws ErrorException InfiniteOpt._parse_ternary_parameter(error,
                                                 info, Val(:<=), 0, Val(:>=), 0)
    end
    # _parse_parameter
    @testset "_parse_parameter" begin
        info = InfiniteOpt._ParameterInfoExpr()
        @test InfiniteOpt._parse_parameter(error, info, :<=, :x, 0) == :x
        @test info.has_ub && info.upper_bound == 0
        @test InfiniteOpt._parse_parameter(error, info, :<=, 0, :x) == :x
        @test info.has_lb && info.lower_bound == 0
        info = InfiniteOpt._ParameterInfoExpr()
        @test InfiniteOpt._parse_parameter(error, info, 0, :<=, :x, :<=, 0) == :x
        @test info.has_ub && info.upper_bound == 0
        @test info.has_lb && info.lower_bound == 0
    end
end

# Test parameter definition methods
@testset "Definition" begin
    # _check_supports_in_bounds
    @testset "_check_supports_in_bounds" begin
        set = IntervalSet(0, 1)
        @test isa(InfiniteOpt._check_supports_in_bounds(error, 0, set), Nothing)
        @test_throws ErrorException InfiniteOpt._check_supports_in_bounds(error,
                                                                        -1, set)
        @test_throws ErrorException InfiniteOpt._check_supports_in_bounds(error,
                                                                         2, set)
        set = UniDistributionSet(Uniform())
        @test isa(InfiniteOpt._check_supports_in_bounds(error, 0, set), Nothing)
        @test_throws ErrorException InfiniteOpt._check_supports_in_bounds(error,
                                                                        -1, set)
        @test_throws ErrorException InfiniteOpt._check_supports_in_bounds(error,
                                                                         2, set)
    end
    # build_independent_parameter
    @testset "build_parameter (IndependentParameter)" begin
        set = IntervalSet(0, 1)
        supps = 0.
        supps_dict = SortedDict{Float64, Set{DataType}}(0. => Set([UserDefined]))
        method = TestMethod()
        @test build_parameter(error, set, supports = supps).set == set
        @test build_parameter(error, set, supports = supps).supports == supps_dict
        @test_throws ErrorException build_parameter(error, set, bob = 42)
        warn = "Ignoring num_supports since supports is not empty."
        @test_logs (:warn, warn) build_parameter(error, set,
                                            supports = [0, 1], num_supports = 2)
        repeated_supps = [1, 1]
        expected = IndependentParameter(set, SortedDict{Float64, Set{DataType}}(1. => Set{DataType}()), 5, method)
        warn = "Support points are not unique, eliminating redundant points."
        @test_logs (:warn, warn) build_parameter(error, set, supports = repeated_supps, 
                                                 derivative_method = method) == expected
        set = UniDistributionSet(Normal())
        @test length(build_parameter(error, set, num_supports = 5).supports) == 5
        @test build_parameter(error, set, derivative_method = method).derivative_method == method
    end
    # build_finite_parameter
    @testset "build_parameter (FiniteParameter)" begin
        @test_throws ErrorException build_parameter(error, 1, bob = 42)
        expected = FiniteParameter(1)
        @test build_parameter(error, 1) == expected
    end

    # add_parameter
    @testset "add_parameter" begin
        m = InfiniteModel()
        method = InfiniteOpt.DefaultDerivativeMethod
        param = IndependentParameter(IntervalSet(0, 1),
                                    SortedDict{Float64, Set{DataType}}(), 5, method)
        expected = GeneralVariableRef(m, 1, IndependentParameterIndex, -1)
        @test add_parameter(m, param) == expected
        @test InfiniteOpt._core_variable_object(expected) == param
        @test InfiniteOpt._param_object_indices(m)[InfiniteOpt._object_number(expected)] == index(expected)
        param = FiniteParameter(1.5)
        expected = GeneralVariableRef(m, 1, FiniteParameterIndex, -1)
        @test add_parameter(m, param) == expected
        @test InfiniteOpt._core_variable_object(expected) == param
    end
end

# Test Reference Queries
@testset "Basic Reference Queries" begin
    m = InfiniteModel()
    p = build_parameter(error, IntervalSet(0, 1), derivative_method = TestMethod())
    pref = add_parameter(m, p)
    dpref = dispatch_variable_ref(pref)
    # JuMP.index
    @testset "JuMP.index" begin
        @test JuMP.index(pref) == IndependentParameterIndex(1)
        @test JuMP.index(dpref) == IndependentParameterIndex(1)
    end
    # JuMP.owner_model
    @testset "JuMP.owner_model" begin
        @test owner_model(pref) === m
        @test owner_model(dpref) === m
    end
    # has_derivative_supports
    @testset "has_derivative_supports" begin
        @test !has_derivative_supports(pref)
        InfiniteOpt._data_object(pref).has_derivative_supports = true
        @test has_derivative_supports(dpref)
    end
    # _set_has_derivative_supports
    @testset "_set_has_derivative_supports" begin
        @test InfiniteOpt._set_has_derivative_supports(pref, true) isa Nothing
        @test has_derivative_supports(pref)
        @test InfiniteOpt._set_has_derivative_supports(dpref, false) isa Nothing
        @test !has_derivative_supports(pref)
    end
    # derivative_method
    @testset "derivative_method" begin
        @test derivative_method(pref) isa TestMethod
        @test derivative_method(dpref) isa TestMethod
    end
    # has_internal_supports
    @testset "has_internal_supports" begin
        @test !has_internal_supports(pref)
        InfiniteOpt._data_object(pref).has_internal_supports = true
        @test has_internal_supports(dpref)
    end
    # _set_has_internal_supports
    @testset "_set_has_internal_supports" begin
        @test InfiniteOpt._set_has_internal_supports(pref, true) isa Nothing
        @test has_internal_supports(pref)
        @test InfiniteOpt._set_has_internal_supports(dpref, false) isa Nothing
        @test !has_internal_supports(pref)
    end
    # has_derivative_constraints
    @testset "has_derivative_constraints" begin
        @test !has_derivative_constraints(pref)
        InfiniteOpt._data_object(pref).has_deriv_constrs = true
        @test has_derivative_constraints(dpref)
    end
    # _set_has_derivative_constraints
    @testset "_set_has_derivative_constraints" begin
        @test InfiniteOpt._set_has_derivative_constraints(pref, true) isa Nothing
        @test has_derivative_constraints(pref)
        @test InfiniteOpt._set_has_derivative_constraints(dpref, false) isa Nothing
        @test !has_derivative_constraints(pref)
    end
end

# Test name methods
@testset "Name" begin
    m = InfiniteModel()
    param = build_parameter(error, IntervalSet(0, 1))
    pref = add_parameter(m, param, "test")
    dpref = dispatch_variable_ref(pref)
    bad = TestVariableRef(m, TestIndex(-1))
    bad_pref = FiniteParameterRef(m, FiniteParameterIndex(-1))
    # JuMP.name
    @testset "JuMP.name" begin
        @test_throws ArgumentError name(bad)
        @test name(pref) == "test"
        @test name(dpref) == "test"
        @test name(bad_pref) == ""
    end
    # JuMP.set_name
    @testset "JuMP.set_name" begin
        @test_throws ArgumentError set_name(bad, "test")
        @test isa(set_name(pref, "new"), Nothing)
        @test name(pref) == "new"
        @test isa(set_name(dpref, "test"), Nothing)
        @test name(dpref) == "test"
    end
    # _make_parameter_ref
    @testset "_make_parameter_ref" begin
        @test InfiniteOpt._make_parameter_ref(m, IndependentParameterIndex(1)) == pref
    end
    # _param_name_dict
    @testset "_param_name_dict" begin
        @test isa(InfiniteOpt._param_name_dict(m), Nothing)
    end
    # _update_param_name_dict
    @testset "_update_param_name_dict" begin
        m.name_to_param = Dict{String, AbstractInfOptIndex}()
        @test InfiniteOpt._update_param_name_dict(m, m.independent_params) isa Nothing
        @test InfiniteOpt._update_param_name_dict(m, m.dependent_params) isa Nothing
        @test m.name_to_param["test"] == IndependentParameterIndex(1)
        m.name_to_param = nothing
    end
    # parameter_by_name
    @testset "parameter_by_name" begin
        @test parameter_by_name(m, "test") == pref
        @test isa(parameter_by_name(m, "test2"), Nothing)
        pref = add_parameter(m, param, "test")
        m.name_to_param = nothing
        @test_throws ErrorException parameter_by_name(m, "test")
    end
end

# Test the parameter macro
@testset "Macro" begin
    m = InfiniteModel()
    # single parameter
    @testset "Single" begin
        pref = GeneralVariableRef(m, 1, IndependentParameterIndex, -1)
        @test @independent_parameter(m, 0 <= a <= 1) == pref
        @test InfiniteOpt._core_variable_object(pref).set == IntervalSet(0, 1)
        @test name(pref) == "a"
        pref = GeneralVariableRef(m, 2, IndependentParameterIndex, -1)
        @test @independent_parameter(m, b in Normal(), supports = [1; 2]) == pref
        @test InfiniteOpt._core_variable_object(pref).set == UniDistributionSet(Normal())
        @test InfiniteOpt._core_variable_object(pref).supports == SortedDict(i => Set{DataType}([UserDefined]) for i in [1,2])
        pref = GeneralVariableRef(m, 3, IndependentParameterIndex, -1)
        @test @independent_parameter(m, c in IntervalSet(0, 1)) == pref
        @test InfiniteOpt._core_variable_object(pref).set == IntervalSet(0, 1)
        pref = GeneralVariableRef(m, 4, IndependentParameterIndex, -1)
        @test @independent_parameter(m, set = IntervalSet(0, 1),
                                  base_name = "d") == pref
        @test name(pref) == "d"
        pref = GeneralVariableRef(m, 5, IndependentParameterIndex, -1)
        @test @independent_parameter(m, set = IntervalSet(0, 1)) == pref
        @test name(pref) == ""
        pref = GeneralVariableRef(m, 6, IndependentParameterIndex, -1)
        @test @independent_parameter(m, z in [0, 1], derivative_method = TestMethod()) == pref
        @test InfiniteOpt._core_variable_object(pref).set == IntervalSet(0, 1)
        @test name(pref) == "z"
        @test derivative_method(pref) isa TestMethod
        @test InfiniteOpt._param_object_indices(m)[InfiniteOpt._object_number(pref)] == index(pref)
    end
    # multiple parameters
    @testset "Array" begin
        prefs = [GeneralVariableRef(m, 7, IndependentParameterIndex, -1),
                 GeneralVariableRef(m, 8, IndependentParameterIndex, -1)]
        @test @independent_parameter(m, 0 <= e[1:2] <= 1) == prefs
        @test InfiniteOpt._core_variable_object(prefs[1]).set == IntervalSet(0, 1)
        @test InfiniteOpt._core_variable_object(prefs[2]).set == IntervalSet(0, 1)
        prefs = [GeneralVariableRef(m, 9, IndependentParameterIndex, -1),
                 GeneralVariableRef(m, 10, IndependentParameterIndex, -1)]
        @test @independent_parameter(m, [1:2], set = IntervalSet(0, 1)) == prefs
        @test InfiniteOpt._core_variable_object(prefs[1]).set == IntervalSet(0, 1)
        @test InfiniteOpt._core_variable_object(prefs[2]).set == IntervalSet(0, 1)
        prefs = [GeneralVariableRef(m, 11, IndependentParameterIndex, -1),
                 GeneralVariableRef(m, 12, IndependentParameterIndex, -1)]
        sets = [IntervalSet(0, 1), IntervalSet(-1, 2)]
        @test @independent_parameter(m, f[i = 1:2], set = sets[i]) == prefs
        @test InfiniteOpt._core_variable_object(prefs[1]).set == IntervalSet(0, 1)
        @test InfiniteOpt._core_variable_object(prefs[2]).set == IntervalSet(-1, 2)
        prefs = [GeneralVariableRef(m, 13, IndependentParameterIndex, -1),
                 GeneralVariableRef(m, 14, IndependentParameterIndex, -1)]
        @test @independent_parameter(m, [i = 1:2], set = sets[i]) == prefs
        @test InfiniteOpt._core_variable_object(prefs[1]).set == IntervalSet(0, 1)
        @test InfiniteOpt._core_variable_object(prefs[2]).set == IntervalSet(-1, 2)
        prefs = [GeneralVariableRef(m, 15, IndependentParameterIndex, -1),
                 GeneralVariableRef(m, 16, IndependentParameterIndex, -1)]
        @test @independent_parameter(m, [0, -1][i] <= g[i = 1:2] <= [1, 2][i]) == prefs
        @test InfiniteOpt._core_variable_object(prefs[1]).set == IntervalSet(0, 1)
        @test InfiniteOpt._core_variable_object(prefs[2]).set == IntervalSet(-1, 2)
        prefs = [GeneralVariableRef(m, 17, IndependentParameterIndex, -1),
                 GeneralVariableRef(m, 18, IndependentParameterIndex, -1)]
        prefs = convert(JuMP.Containers.SparseAxisArray, prefs)
        @test @independent_parameter(m, 0 <= i[1:2] <= 1,
                                  container = SparseAxisArray) == prefs
        @test InfiniteOpt._core_variable_object(prefs[1]).set == IntervalSet(0, 1)
        @test InfiniteOpt._core_variable_object(prefs[2]).set == IntervalSet(0, 1)
        @test InfiniteOpt._param_object_indices(m)[InfiniteOpt._object_number(prefs[2])] == index(prefs[2])
    end
    # test for errors
    @testset "Errors" begin
        @test_macro_throws ErrorException @independent_parameter(m, 0 <= [1:2] <= 1)
        @test_macro_throws ErrorException @independent_parameter(m, 0 <= "bob" <= 1)
        @test_macro_throws ErrorException @independent_parameter(m, 0 <= a <= 1)
        @test_macro_throws ErrorException @independent_parameter(m, 0 <= j)
        @test_macro_throws ErrorException @independent_parameter(m, j)
        @test_macro_throws ErrorException @independent_parameter(m, j, foo = 42)
        @test_macro_throws ErrorException @independent_parameter(m, j in Multinomial(3, [1/3, 1/3]))
        @test_macro_throws ErrorException @independent_parameter(m, 0 <= k <= 1, Int)
    end
end

# Test if used
@testset "Used" begin
    m = InfiniteModel()
    @independent_parameter(m, pref1 in [0, 1])
    @finite_parameter(m, pref2, 1)
    dpref1 = dispatch_variable_ref(pref1)
    dpref2 = dispatch_variable_ref(pref2)
    bad_pref = IndependentParameterRef(m, IndependentParameterIndex(-1))
    # _infinite_variable_dependencies
    @testset "_infinite_variable_dependencies" begin
        @test InfiniteOpt._infinite_variable_dependencies(pref1) == InfiniteVariableIndex[]
        @test InfiniteOpt._infinite_variable_dependencies(dpref1) == InfiniteVariableIndex[]
        @test InfiniteOpt._infinite_variable_dependencies(pref2) == InfiniteVariableIndex[]
        @test InfiniteOpt._infinite_variable_dependencies(dpref2) == InfiniteVariableIndex[]
        @test_throws ErrorException InfiniteOpt._infinite_variable_dependencies(bad_pref)
    end
    # _parameter_function_dependencies
    @testset "_parameter_function_dependencies" begin
        @test InfiniteOpt._parameter_function_dependencies(pref1) == ParameterFunctionIndex[]
        @test InfiniteOpt._parameter_function_dependencies(dpref1) == ParameterFunctionIndex[]
        @test InfiniteOpt._parameter_function_dependencies(pref2) == ParameterFunctionIndex[]
        @test InfiniteOpt._parameter_function_dependencies(dpref2) == ParameterFunctionIndex[]
        @test_throws ErrorException InfiniteOpt._parameter_function_dependencies(bad_pref)
    end
    # _derivative_dependencies
    @testset "_derivative_dependencies" begin
        @test InfiniteOpt._derivative_dependencies(pref1) == DerivativeIndex[]
        @test InfiniteOpt._derivative_dependencies(dpref1) == DerivativeIndex[]
        @test InfiniteOpt._derivative_dependencies(pref2) == DerivativeIndex[]
        @test InfiniteOpt._derivative_dependencies(dpref2) == DerivativeIndex[]
        @test_throws ErrorException InfiniteOpt._derivative_dependencies(bad_pref)
    end
    # _measure_dependencies
    @testset "_measure_dependencies" begin
        @test InfiniteOpt._measure_dependencies(pref1) == MeasureIndex[]
        @test InfiniteOpt._measure_dependencies(dpref1) == MeasureIndex[]
        @test InfiniteOpt._measure_dependencies(pref2) == MeasureIndex[]
        @test InfiniteOpt._measure_dependencies(dpref2) == MeasureIndex[]
        @test_throws ErrorException InfiniteOpt._measure_dependencies(bad_pref)
    end
    # _constraint_dependencies
    @testset "_constraint_dependencies" begin
        @test InfiniteOpt._constraint_dependencies(pref1) == ConstraintIndex[]
        @test InfiniteOpt._constraint_dependencies(dpref1) == ConstraintIndex[]
        @test InfiniteOpt._constraint_dependencies(pref2) == ConstraintIndex[]
        @test InfiniteOpt._constraint_dependencies(dpref2) == ConstraintIndex[]
        @test_throws ErrorException InfiniteOpt._constraint_dependencies(bad_pref)
    end
    # used_by_constraint
    @testset "used_by_constraint" begin
        @test !used_by_constraint(pref1)
        @test !used_by_constraint(pref2)
        @test !used_by_constraint(dpref1)
        @test !used_by_constraint(dpref2)
        push!(InfiniteOpt._constraint_dependencies(dpref1), ConstraintIndex(1))
        push!(InfiniteOpt._constraint_dependencies(dpref2), ConstraintIndex(1))
        @test used_by_constraint(pref1)
        @test used_by_constraint(pref2)
        @test used_by_constraint(dpref1)
        @test used_by_constraint(dpref2)
        popfirst!(InfiniteOpt._constraint_dependencies(dpref1))
        popfirst!(InfiniteOpt._constraint_dependencies(dpref2))
    end
    # used_by_measure
    @testset "used_by_measure" begin
        @test !used_by_measure(pref1)
        @test !used_by_measure(pref2)
        @test !used_by_measure(dpref1)
        @test !used_by_measure(dpref2)
        push!(InfiniteOpt._measure_dependencies(dpref1), MeasureIndex(1))
        push!(InfiniteOpt._measure_dependencies(dpref2), MeasureIndex(1))
        @test used_by_measure(pref1)
        @test used_by_measure(pref2)
        @test used_by_measure(dpref1)
        @test used_by_measure(dpref2)
        popfirst!(InfiniteOpt._measure_dependencies(dpref1))
        popfirst!(InfiniteOpt._measure_dependencies(dpref2))
    end
    # used_by_infinite_variable
    @testset "used_by_infinite_variable" begin
        @test !used_by_infinite_variable(pref1)
        @test !used_by_infinite_variable(pref2)
        @test !used_by_infinite_variable(dpref1)
        @test !used_by_infinite_variable(dpref2)
        push!(InfiniteOpt._infinite_variable_dependencies(dpref1), InfiniteVariableIndex(1))
        @test used_by_infinite_variable(pref1)
        @test used_by_infinite_variable(dpref1)
        popfirst!(InfiniteOpt._infinite_variable_dependencies(dpref1))
    end
    # used_by_parameter_function
    @testset "used_by_parameter_function" begin
        @test !used_by_parameter_function(pref1)
        @test !used_by_parameter_function(pref2)
        @test !used_by_parameter_function(dpref1)
        @test !used_by_parameter_function(dpref2)
        push!(InfiniteOpt._parameter_function_dependencies(dpref1), ParameterFunctionIndex(1))
        @test used_by_parameter_function(pref1)
        @test used_by_parameter_function(dpref1)
        popfirst!(InfiniteOpt._parameter_function_dependencies(dpref1))
    end
    # used_by_derivative
    @testset "used_by_derivative" begin
        @test !used_by_derivative(pref1)
        @test !used_by_derivative(pref2)
        @test !used_by_derivative(dpref1)
        @test !used_by_derivative(dpref2)
        push!(InfiniteOpt._derivative_dependencies(dpref1), DerivativeIndex(1))
        @test used_by_derivative(pref1)
        @test used_by_derivative(dpref1)
        popfirst!(InfiniteOpt._derivative_dependencies(dpref1))
    end
    # used_by_objective
    @testset "used_by_objective" begin
        @test !used_by_objective(pref1)
        @test !used_by_objective(dpref1)
        @test !used_by_objective(pref2)
        @test !used_by_objective(dpref2)
        InfiniteOpt._data_object(pref2).in_objective = true
        @test used_by_objective(pref2)
        @test used_by_objective(dpref2)
        InfiniteOpt._data_object(pref2).in_objective = false
    end
    # is_used
    @testset "is_used" begin
        @test !is_used(pref1)
        @test !is_used(pref2)
        @test !is_used(dpref1)
        @test !is_used(dpref2)
        push!(InfiniteOpt._constraint_dependencies(dpref1), ConstraintIndex(1))
        push!(InfiniteOpt._constraint_dependencies(dpref2), ConstraintIndex(1))
        @test is_used(pref1)
        @test is_used(pref2)
        @test is_used(dpref1)
        @test is_used(dpref2)
        popfirst!(InfiniteOpt._constraint_dependencies(dpref1))
        popfirst!(InfiniteOpt._constraint_dependencies(dpref2))
        push!(InfiniteOpt._measure_dependencies(dpref1), MeasureIndex(1))
        push!(InfiniteOpt._measure_dependencies(dpref2), MeasureIndex(1))
        @test is_used(pref1)
        @test is_used(pref2)
        @test is_used(dpref1)
        @test is_used(dpref2)
        popfirst!(InfiniteOpt._measure_dependencies(dpref1))
        popfirst!(InfiniteOpt._measure_dependencies(dpref2))
        push!(InfiniteOpt._infinite_variable_dependencies(dpref1), InfiniteVariableIndex(1))
        @test is_used(pref1)
        @test is_used(dpref1)
        popfirst!(InfiniteOpt._infinite_variable_dependencies(dpref1))
        push!(InfiniteOpt._parameter_function_dependencies(dpref1), ParameterFunctionIndex(1))
        @test is_used(pref1)
        @test is_used(dpref1)
        popfirst!(InfiniteOpt._parameter_function_dependencies(dpref1))
    end
end

# Test derivative methods 
@testset "Derivative Methods" begin 
    m = InfiniteModel()
    @independent_parameter(m, pref in [0, 1])
    dpref = dispatch_variable_ref(pref)
    func = (x) -> NaN
    num = 0.
    info = VariableInfo{Float64, Float64, Float64, Function}(true, num, true,
                                        num, true, num, false, func, false, false)
    d = Derivative(info, true, pref, pref) # this is wrong but that is ok
    object = VariableData(d)
    idx = InfiniteOpt._add_data_object(m, object)
    push!(InfiniteOpt._derivative_dependencies(pref), idx)
    dref = DerivativeRef(m, idx)
    gdref = GeneralVariableRef(m, idx.value, DerivativeIndex)
    cref = @constraint(m, gdref == 0)
    # test _reset_derivative_evaluations
    @testset "_reset_derivative_evaluations" begin 
        # test empty 
        @test InfiniteOpt._reset_derivative_evaluations(dpref) isa Nothing
        # test warning 
        InfiniteOpt._set_has_derivative_constraints(pref, true) 
        @test push!(InfiniteOpt._derivative_constraint_dependencies(dref), index(cref)) isa Vector
        warn = "Support/method changes will invalidate existing derivative evaluation " *
               "constraints that have been added to the InfiniteModel. Thus, " *
               "these are being deleted."
        @test_logs (:warn, warn) InfiniteOpt._reset_derivative_evaluations(dpref) isa Nothing
        @test !has_derivative_constraints(pref)
        @test !is_valid(m, cref)
        # test has derivative supports to deal with 
        supps = SortedDict{Float64, Set{DataType}}(42 => Set([InternalLabel]))
        param = IndependentParameter(IntervalSet(0, 1), supps, 12, TestGenMethod())
        InfiniteOpt._set_core_variable_object(dpref, param)
        InfiniteOpt._set_has_derivative_supports(pref, true)
        @test InfiniteOpt._reset_derivative_evaluations(dpref) isa Nothing
        @test !has_derivative_supports(dpref)
        @test length(InfiniteOpt._core_variable_object(dpref).supports) == 0 
    end
    # test set_derivative_method
    @testset "set_derivative_method" begin 
        push!(InfiniteOpt._constraint_dependencies(dpref), ConstraintIndex(1))
        @test set_derivative_method(pref, TestMethod()) isa Nothing
        @test derivative_method(dpref) isa TestMethod
    end
end

# Test parameter set methods
@testset "Infinite Set" begin
    m = InfiniteModel()
    @independent_parameter(m, pref_gen in [0, 1])
    pref_disp = dispatch_variable_ref(pref_gen)
    bad = Bad()
    bad_pref = IndependentParameterRef(m, IndependentParameterIndex(-1))
    # _parameter_set
    @testset "_parameter_set" begin
        @test InfiniteOpt._parameter_set(pref_disp) == IntervalSet(0, 1)
        @test_throws ErrorException InfiniteOpt._parameter_set(bad_pref)
    end
    # _update_parameter_set
    @testset "_update_parameter_set " begin
        push!(InfiniteOpt._constraint_dependencies(pref_disp), ConstraintIndex(1))
        @test isa(InfiniteOpt._update_parameter_set(pref_disp,
                                                    IntervalSet(1, 2)), Nothing)
        @test InfiniteOpt._parameter_set(pref_disp) == IntervalSet(1, 2)
    end
    # infinite_set
    @testset "infinite_set" begin
        @test_throws ArgumentError infinite_set(bad)
        @test infinite_set(pref_disp) == IntervalSet(1, 2)
        @test infinite_set(pref_gen) == IntervalSet(1, 2)
        @test_throws ErrorException infinite_set(bad_pref)
    end
    # set_infinite_set
    @testset "set_infinite_set" begin
        @test_throws ArgumentError set_infinite_set(bad, IntervalSet(0, 1))
        @test isa(set_infinite_set(pref_disp, IntervalSet(2, 3)), Nothing)
        @test infinite_set(pref_disp) == IntervalSet(2, 3)
        @test isa(set_infinite_set(pref_gen, IntervalSet(1, 3)), Nothing)
        @test infinite_set(pref_gen) == IntervalSet(1, 3)
        @test set_infinite_set(pref_gen, UniDistributionSet(Normal())) isa Nothing
        @test infinite_set(pref_disp) isa UniDistributionSet 
        push!(InfiniteOpt._data_object(pref_gen).measure_indices, MeasureIndex(1))
        @test_throws ErrorException set_infinite_set(pref_gen, IntervalSet(1, 3))
    end
end

# Test parameter support methods
@testset "Supports" begin
    m = InfiniteModel()
    @independent_parameter(m, pref in [0, 1], sig_digits = 5)
    @independent_parameter(m, pref2 in [0, 1])
    pref_disp = dispatch_variable_ref(pref)
    bad = Bad()
    push!(InfiniteOpt._data_object(pref).constraint_indices, ConstraintIndex(1))
    # _parameter_supports
    @testset "_parameter_supports" begin
        @test InfiniteOpt._parameter_supports(pref_disp) == SortedDict{Float64, Set{DataType}}()
    end
    @testset "_parameter_support_values" begin
        @test InfiniteOpt._parameter_support_values(pref_disp) == Float64[]
    end
    # _update_parameter_supports
    @testset "_update_parameter_supports " begin
        dict = SortedDict{Float64, Set{DataType}}(1. => Set{DataType}([MCSample]))
        @test isa(InfiniteOpt._update_parameter_supports(pref_disp, dict), Nothing)
        @test InfiniteOpt._parameter_support_values(pref_disp) == [1.]
    end
    # significant_digits
    @testset "significant_digits" begin
        @test significant_digits(pref) == 5
    end
    # num_supports
    @testset "num_supports" begin
        @test_throws ArgumentError num_supports(bad)
        @test num_supports(pref_disp) == 1
        @test num_supports(pref_disp, label = UserDefined) == 0
        @test num_supports(pref) == 1
        @test num_supports(pref, label = UserDefined) == 0
        @test num_supports(pref, label = SampleLabel) == 1
        @test num_supports(pref, label = All) == 1
    end
    # has_supports
    @testset "has_supports" begin
        @test_throws ArgumentError has_supports(bad)
        @test has_supports(pref_disp)
        @test has_supports(pref)
        InfiniteOpt._update_parameter_supports(pref_disp, SortedDict{Float64, Set{DataType}}())
        @test !has_supports(pref_disp)
        @test !has_supports(pref)
    end
    # supports
    @testset "supports" begin
        @test supports(pref_disp) == []
        @test supports(pref) == []
        dict = SortedDict{Float64, Set{DataType}}(1. => Set{DataType}([MCSample]))
        InfiniteOpt._update_parameter_supports(pref_disp, dict)
        @test supports(pref_disp) == [1.]
        @test supports(pref) == [1.]
        @test supports(pref, label = MCSample) == [1.]
        @test supports(pref, label = All) == [1.]
    end
    # supports (vector)
    @testset "supports (vector)" begin
        # test simple case
        @test supports([pref_disp], label = SampleLabel) == ones(1, 1)
        # test typical combinatorial case
        supps = [[-1, 0, 1], [-1, 1]] 
        @infinite_parameter(m, x[i = 1:2] in [-1, 1], supports = supps[i], independent = true)
        @test supports(x) == Float64[-1 0 1 -1 0 1; -1 -1 -1 1 1 1]
        # test non-combinatorial case 
        @test_throws ErrorException supports(x, use_combinatorics = false)
        @test set_supports(x[2], supps[1], force = true) isa Nothing 
        @test supports(x, use_combinatorics = false) == Float64[-1 0 1; -1 0 1]
    end
    # set_supports
    @testset "set_supports" begin
        @test_throws ArgumentError set_supports(bad, [0, 1])
        @test isa(set_supports(pref_disp, [0, 1], force = true), Nothing)
        @test isa(set_supports(pref, [0, 1], force = true), Nothing)
        @test supports(pref) == [0., 1.]
        @test_throws ErrorException set_supports(pref, [2, 3])
        warn = "Support points are not unique, eliminating redundant points."
        @test_logs (:warn, warn) set_supports(pref, [1, 1], force = true)
        @test_throws ErrorException set_supports(pref, [0.5])
        @test !has_internal_supports(pref)
    end
    # add_supports
    @testset "add_supports" begin
        @test_throws ArgumentError add_supports(bad, 0.5)
        @test isa(add_supports(pref_disp, 0.25), Nothing)
        @test isa(add_supports(pref, 0.5), Nothing)
        @test supports(pref) == [0.25, 0.5, 1.]
        @test isa(add_supports(pref, [0, 0.25, 1], check = false), Nothing)
        @test supports(pref) == [0, 0.25, 0.5, 1.]
        @test add_supports(pref, 0.2, label = InternalLabel) isa Nothing
        @test supports(pref) == [0, 0.25, 0.5, 1.]
        @test supports(pref, label = All) == [0, 0.2, 0.25, 0.5, 1.]
        @test has_internal_supports(pref)
    end
    # delete_supports
    @testset "delete_supports" begin
        # test bad parameter 
        @test_throws ArgumentError delete_supports(bad)
        # test label deletion
        set_derivative_method(pref, TestGenMethod())
        InfiniteOpt._set_has_derivative_supports(pref, true)
        add_supports(pref, 0.1, label = UniformGrid)
        @test delete_supports(pref_disp, label = UniformGrid) isa Nothing
        @test !has_derivative_supports(pref)
        @test !has_internal_supports(pref)
        @test supports(pref, label = All) == [0, 0.25, 0.5, 1.]
        # test total deletion
        @test isa(delete_supports(pref), Nothing)
        @test !has_derivative_supports(pref)
        @test !has_internal_supports(pref)
        @test supports(pref) == []
        # test array input 
        @test isa(delete_supports([pref]), Nothing)
        # prepare to test derivative constraints 
        func = (x) -> NaN
        num = 0.
        info = VariableInfo{Float64, Float64, Float64, Function}(true, num, true,
                                            num, true, num, false, func, false, false)
        deriv = Derivative(info, true, pref, pref)
        object = VariableData(deriv)
        idx = InfiniteOpt._add_data_object(m, object)
        push!(InfiniteOpt._derivative_dependencies(pref), idx)
        dref = DerivativeRef(m, idx)
        gdref = GeneralVariableRef(m, 1, DerivativeIndex)
        cref = @constraint(m, gdref == 0)
        InfiniteOpt._set_has_derivative_constraints(pref, true) 
        @test push!(InfiniteOpt._derivative_constraint_dependencies(dref), index(cref)) isa Vector
        # test derivative constraint warning 
        warn = "Deleting supports invalidated derivative evaluations. Thus, these " * 
               "are being deleted as well."
        @test_logs (:warn, warn) delete_supports(pref) isa Nothing
        @test !has_derivative_constraints(pref)
        @test !is_valid(m, cref)
        # test measure error
        push!(InfiniteOpt._data_object(pref).measure_indices, MeasureIndex(1))
        @test_throws ErrorException delete_supports(pref)
    end
end

# Test lower bound functions
@testset "Lower Bound" begin
    m = InfiniteModel()
    @independent_parameter(m, pref1 in [0, 1])
    @independent_parameter(m, pref2 in Normal())
    @independent_parameter(m, pref3 in BadScalarSet())
    bad = TestVariableRef(m, TestIndex(-1))
    # JuMP.has_lower_bound
    @testset "JuMP.has_lower_bound" begin
        @test_throws ArgumentError has_lower_bound(bad)
        @test has_lower_bound(dispatch_variable_ref(pref1))
        @test has_lower_bound(pref1)
        @test has_lower_bound(dispatch_variable_ref(pref2))
        @test has_lower_bound(pref2)
    end
    # JuMP.lower_bound
    @testset "JuMP.lower_bound" begin
        @test_throws ArgumentError lower_bound(bad)
        @test lower_bound(dispatch_variable_ref(pref1)) == 0
        @test lower_bound(dispatch_variable_ref(pref2)) == -Inf
        @test lower_bound(pref1) == 0
        @test lower_bound(pref2) == -Inf
        @test_throws ErrorException lower_bound(pref3)
    end
    # JuMP.set_lower_bound
    @testset "JuMP.set_lower_bound" begin
        @test_throws ArgumentError set_lower_bound(bad, 2)
        @test_throws ErrorException set_lower_bound(dispatch_variable_ref(pref1), 2)
        @test_throws ErrorException set_lower_bound(dispatch_variable_ref(pref3), 2)
        @test_throws ErrorException set_lower_bound(pref1, 2)
        @test_throws ErrorException set_lower_bound(pref3, 2)
        @test isa(set_lower_bound(dispatch_variable_ref(pref1), -1), Nothing)
        @test lower_bound(pref1) == -1
        @test isa(set_lower_bound(pref1, -2), Nothing)
        @test lower_bound(pref1) == -2
    end
end

# Test upper bound functions
@testset "Upper Bound" begin
    m = InfiniteModel()
    @independent_parameter(m, pref1 in [0, 1])
    @independent_parameter(m, pref2 in Normal())
    @independent_parameter(m, pref3 in BadScalarSet())
    bad = TestVariableRef(m, TestIndex(-1))
    # JuMP.has_upper_bound
    @testset "JuMP.has_upper_bound" begin
        @test_throws ArgumentError has_upper_bound(bad)
        @test has_upper_bound(dispatch_variable_ref(pref1))
        @test has_upper_bound(dispatch_variable_ref(pref2))
        @test has_upper_bound(pref1)
        @test has_upper_bound(pref2)
    end
    # JuMP.lower_bound
    @testset "JuMP.upper_bound" begin
        @test_throws ArgumentError upper_bound(bad)
        @test upper_bound(dispatch_variable_ref(pref1)) == 1
        @test upper_bound(dispatch_variable_ref(pref2)) == Inf
        @test upper_bound(pref1) == 1
        @test upper_bound(pref2) == Inf
        @test_throws ErrorException upper_bound(pref3)
    end
    # JuMP.set_lower_bound
    @testset "JuMP.set_upper_bound" begin
        @test_throws ArgumentError set_upper_bound(bad, -1)
        @test_throws ErrorException set_upper_bound(dispatch_variable_ref(pref1), -1)
        @test_throws ErrorException set_upper_bound(dispatch_variable_ref(pref3), -1)
        @test_throws ErrorException set_upper_bound(pref1, -1)
        @test_throws ErrorException set_upper_bound(pref3, -1)
        @test isa(set_upper_bound(dispatch_variable_ref(pref1), 2), Nothing)
        @test upper_bound(pref1) == 2
        @test isa(set_upper_bound(pref1, 3), Nothing)
        @test upper_bound(pref1) == 3
    end
end

# Test methods for finite parameters
@testset "Finite Parameters" begin
    # initialize the model
    m = InfiniteModel()
    bad = TestVariableRef(m, TestIndex(-1))
    # test @finite_parameter
    @testset "@finite_parameter" begin
        m2 = Model()
        # test errors
        @test_macro_throws ErrorException @finite_parameter(m)
        @test_macro_throws ErrorException @finite_parameter(m, a, 2, 3)
        @test_macro_throws ErrorException @finite_parameter(m, (2, 3, 4), 2)
        @test_macro_throws ErrorException @finite_parameter(m2, 2)
        @test_macro_throws ErrorException @finite_parameter(m, "bob")
        @test_macro_throws ErrorException @finite_parameter(m2, test, 2)
        @test_macro_throws ErrorException @finite_parameter(m, test, 2, bob = 2)
        # test anonymous definition
        pref = GeneralVariableRef(m, 1, FiniteParameterIndex)
        @test @finite_parameter(m, 42) == pref
        @test InfiniteOpt._core_variable_object(pref).value == 42
        # test vector anonymous definition
        prefs = [GeneralVariableRef(m, 2, FiniteParameterIndex),
                 GeneralVariableRef(m, 3, FiniteParameterIndex)]
        @test @finite_parameter(m, [1:2], 42, base_name = "a") == prefs
        @test InfiniteOpt._core_variable_object(prefs[1]).value == 42
        @test name.(prefs) == ["a[1]", "a[2]"]
        # test named definition
        pref = GeneralVariableRef(m, 4, FiniteParameterIndex)
        @test @finite_parameter(m, b, 42) == pref
        @test InfiniteOpt._core_variable_object(pref).value == 42
        @test name(pref) == "b"
        # test named vector definition
        prefs = [GeneralVariableRef(m, 5, FiniteParameterIndex),
                 GeneralVariableRef(m, 6, FiniteParameterIndex)]
        prefs = convert(JuMPC.SparseAxisArray, prefs)
        @test @finite_parameter(m, c[i = 1:2], [3, 7][i],
                                container = SparseAxisArray) == prefs
        @test InfiniteOpt._core_variable_object(prefs[2]).value == 7
        @test name(prefs[2]) == "c[2]"
    end
    # initialize the model
    m = InfiniteModel()
    # test parameter_value
    @testset "parameter_value" begin
        pref = GeneralVariableRef(m, 1, FiniteParameterIndex)
        dpref = dispatch_variable_ref(pref)
        @test_throws ArgumentError parameter_value(bad)
        @test @finite_parameter(m, g, 1) == pref
        @test parameter_value(dpref) == 1
        @test parameter_value(pref) == 1
    end
    # test JuMP.set_value
    @testset "JuMP.set_value" begin
        pref = GeneralVariableRef(m, 1, FiniteParameterIndex)
        dpref = dispatch_variable_ref(pref)
        push!(InfiniteOpt._constraint_dependencies(dpref), ConstraintIndex(1))
        @test_throws ArgumentError set_value(bad, 42)
        @test isa(set_value(dpref, 42), Nothing)
        @test parameter_value(pref) == 42
        @test isa(set_value(pref, 41), Nothing)
        @test parameter_value(pref) == 41
    end
end

# Test support flll-in and geneartion functions
@testset "Support Fill-in and Generation" begin
    @testset "generate_and_add_supports! (AbstractInfiniteSet)" begin
        m = InfiniteModel()
        gvref1 = @independent_parameter(m, 0 <= a <= 1)
        pref1 = dispatch_variable_ref(gvref1)
        set1 = infinite_set(pref1)
        dist = Normal(0., 1.)
        gvref2 = @independent_parameter(m, c in dist)
        pref2 = dispatch_variable_ref(gvref2)
        set2 = infinite_set(pref2)
        @test generate_and_add_supports!(pref1, set1, num_supports = 4) isa Nothing
        @test generate_and_add_supports!(pref2, set2, num_supports = 4) isa Nothing
        @test length(supports(pref1)) == 4
        @test length(supports(pref2)) == 4
    end
    # fill_in_supports! (ParameterRef)
    @testset "fill_in_supports! (ParameterRef)" begin
        m = InfiniteModel()
        pref1 = @independent_parameter(m, 0 <= a <= 1)
        pref2 = @independent_parameter(m, 0 <= b[1:2] <= 1)
        dist = Normal(0., 1.)
        pref3 = @independent_parameter(m, c in dist, supports = [-0.5, 0.5])
        @test fill_in_supports!(pref1, num_supports = 11) isa Nothing
        @test fill_in_supports!.(pref2, num_supports = 11) isa Array{Nothing}
        @test fill_in_supports!(pref3, num_supports = 11) isa Nothing
        @test length(supports(pref1)) == 11
        @test length(supports(pref2[1])) == 11
        @test length(supports(pref2[2])) == 11
        @test length(supports(pref3)) == 11
        @test -0.5 in supports(pref3)
        @test 0.5 in supports(pref3)
        @test fill_in_supports!(pref1, num_supports = 20) isa Nothing
        @test length(supports(pref1)) == 20
    end
end
