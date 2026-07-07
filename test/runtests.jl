using Test
using Dates
using DataFrames

using EconFrames

# Auxiliary test source type (avoids dependency on external source names)
struct TestSource <: DataSource end

# Include test modules
include(joinpath("dep", "test_inflation.jl"))
include(joinpath("dep", "test_filter.jl"))
include(joinpath("dep", "test_monetary_metadata.jl"))

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

@testset "Monetary Metadata Tests" begin
    test_monetary_metadata_persistence()
    test_collapse_preserves_monetary_metadata()
end
