using Test
using Dates
using DataFrames

using EconFrames

# Include test modules
include(joinpath("dep", "test_inflation.jl"))
include(joinpath("dep", "test_filter.jl"))

# Auxiliary good type
struct OtherGood <: EconVariables.SomeGood end

@testset "Inflation Tests" begin
    test_econframe_single_cpi()
    test_econframe_multiple_cpis()
    test_econframe_partial_matching()
    test_econframe_already_converted()
end

@testset "Filter Tests" begin
    test_filter_methods()
end
