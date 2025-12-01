using BenchmarkTools
using StatsBase

# Include both implementations
include("../src/dep/Econ.jl")
include("../src/dep/EconVariable.jl")

println("="^60)
println("Comparison: Econ vs EconVariable")
println("="^60)

# Test with vectors of different sizes
for n in [100, 1000, 10000]
    println("\n--- Vector size: $n ---")
    
    # Create data
    data1 = rand(n)
    data2 = rand(n)
    
    # Old approach: Vector{Econ}
    vec_econ1 = [Econ(x, Annual(), Household()) for x in data1]
    vec_econ2 = [Econ(x, Annual(), Household()) for x in data2]
    
    # New approach: EconVariable
    econvar1 = EconVariable(data1, Annual(), Household())
    econvar2 = EconVariable(data2, Annual(), Household())
    
    # Plain vectors for reference
    plain1 = data1
    plain2 = data2
    
    println("\n1. Addition:")
    print("   Vector{Econ}:  ")
    @btime $vec_econ1 .+ $vec_econ2
    
    print("   EconVariable:  ")
    @btime $econvar1 + $econvar2
    
    print("   Plain Vector:  ")
    @btime $plain1 .+ $plain2
    
    println("\n2. Multiplication:")
    print("   Vector{Econ}:  ")
    @btime $vec_econ1 .* $vec_econ2
    
    print("   EconVariable:  ")
    @btime $econvar1 * $econvar2
    
    print("   Plain Vector:  ")
    @btime $plain1 .* $plain2
    
    println("\n3. Scalar multiplication:")
    print("   Vector{Econ}:  ")
    @btime $vec_econ1 .* 2.5
    
    print("   EconVariable:  ")
    @btime $econvar1 * 2.5
    
    print("   Plain Vector:  ")
    @btime $plain1 .* 2.5
    
    println("\n4. Combined operations:")
    print("   Vector{Econ}:  ")
    @btime ($vec_econ1 .+ $vec_econ2) .* 2.5
    
    print("   EconVariable:  ")
    @btime ($econvar1 + $econvar2) * 2.5
    
    print("   Plain Vector:  ")
    @btime ($plain1 .+ $plain2) .* 2.5
end

println("\n" * "="^60)
println("Memory allocation comparison (for n=1000):")
println("="^60)

n = 1000
data1 = rand(n)
data2 = rand(n)

vec_econ1 = [Econ(x, Annual(), Household()) for x in data1]
vec_econ2 = [Econ(x, Annual(), Household()) for x in data2]
econvar1 = EconVariable(data1, Annual(), Household())
econvar2 = EconVariable(data2, Annual(), Household())

println("\nSize in memory:")
println("   Vector{Econ}: ", Base.summarysize(vec_econ1), " bytes")
println("   EconVariable: ", Base.summarysize(econvar1), " bytes")
println("   Ratio: ", round(Base.summarysize(vec_econ1) / Base.summarysize(econvar1), digits=2), "x")
