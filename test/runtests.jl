using Test
using Dates
using DataFrames
using StatsBase

using EconFrames
import EconFrames: base_date, get_good
import EconFrames: RealCurrency, NominalCurrency
import EconFrames: validate_cpis_unique, build_cpi_dict, monetary_variable!
import EconFrames: cpi_index

# Include test modules
include(joinpath("dep", "test_econscalar.jl"))
include(joinpath("dep", "test_monetaryscalar.jl"))
include(joinpath("dep", "test_econvariable.jl"))
include(joinpath("dep", "test_monetaryvariable.jl"))
include(joinpath("dep", "test_inflation.jl"))

# Auxiliary good type
struct OtherGood <: EconFrames.SomeGood end

@testset "EconFrames.jl" begin
    @testset "EconScalar Tests" begin
        test_econscalar_construction()
        test_econscalar_arithmetic()
        test_econscalar_comparison()
    end
    
    @testset "MonetaryScalar Tests" begin
        test_monetaryscalar_construction()
        test_monetaryscalar_arithmetic()
        test_monetaryscalar_currency()
    end
    
    @testset "EconVariable Tests" begin
        test_econvariable_construction()
        test_econvariable_arithmetic()
        test_econvariable_broadcasting()
        test_econvariable_statistics()
    end
    
    @testset "MonetaryVariable Tests" begin
        test_monetaryvariable_construction()
        test_monetaryvariable_arithmetic()
        test_monetaryvariable_broadcasting()
        test_monetaryvariable_statistics()
        test_monetaryvariable_currency()
    end
    
    @testset "Inflation Tests" begin
        test_cpi_construction()
        test_monetaryvariable_inflation()
        test_monetaryscalar_inflation()
        test_inflation_roundtrip()
        test_inflation_errors()
        test_multiple_cpis()
        test_econframe_single_cpi()
        test_econframe_multiple_cpis()
        test_econframe_partial_matching()
        test_econframe_already_converted()
    end
end
