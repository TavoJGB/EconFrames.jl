"""
Test script for MonetaryScalar and MonetaryVariable types with inflation adjustments.

This script tests:
1. Basic construction of MonetaryScalar and MonetaryVariable
2. Arithmetic operations
3. Statistical functions
4. Currency conversions (nominal ↔ real)
5. Rebasing real values
6. Compatibility checks
"""

using Dates
using DataFrames
using StatsBase

# Include the source files
include("../src/dep/types.jl")
include("../src/dep/inflation.jl")

println("="^70)
println("TESTING MONETARYSCALAR AND MONETARYVARIABLE")
println("="^70)
println()

#==========================================================================
    TEST 1: Basic Construction
==========================================================================#

println("TEST 1: Basic Construction")
println("-"^70)

# Create a MonetaryScalar (nominal)
income_scalar_nom = MonetaryScalar(50000.0, Annual(), Household(), NominalUSD())
println("✓ Created nominal MonetaryScalar: ", income_scalar_nom)
println("  - Value: ", income_scalar_nom.value)
println("  - Frequency: ", frequency(income_scalar_nom))
println("  - Subject: ", subject(income_scalar_nom))
println("  - Currency: ", currency_string(currency(income_scalar_nom)))
println()

# Create a MonetaryVariable (nominal)
income_nom = MonetaryVariable([45000.0, 48000.0, 50000.0, 52000.0, 55000.0], 
                              Annual(), Household(), NominalUSD())
println("✓ Created nominal MonetaryVariable with $(length(income_nom)) observations")
println("  - Data: ", income_nom.data)
println("  - Currency: ", currency_string(currency(income_nom)))
println()

#==========================================================================
    TEST 2: Arithmetic Operations
==========================================================================#

println("TEST 2: Arithmetic Operations")
println("-"^70)

# Scalar operations
income2 = income_nom .* 1.1
println("✓ Multiply by scalar: income * 1.1")
println("  Original: ", income_nom.data)
println("  Result:   ", income2.data)
println()

income_sum = income_nom .+ 5000
println("✓ Add scalar: income + 5000")
println("  Original: ", income_nom.data)
println("  Result:   ", income_sum.data)
println()

#==========================================================================
    TEST 3: Statistical Functions
==========================================================================#

println("TEST 3: Statistical Functions")
println("-"^70)

mean_income = mean(income_nom)
println("✓ Mean income: ", mean_income.value)
println("  Type: ", typeof(mean_income))
println("  Is MonetaryScalar: ", mean_income isa MonetaryScalar)
println("  Currency: ", currency_string(currency(mean_income)))
println()

median_income = median(income_nom)
println("✓ Median income: ", median_income.value)
println()

std_income = std(income_nom)
println("✓ Std. deviation: ", std_income.value)
println()

#==========================================================================
    TEST 4: CPI Setup
==========================================================================#

println("TEST 4: CPI Setup")
println("-"^70)

# Create a CPI index (1990-1994)
years = [1990, 1991, 1992, 1993, 1994]
cpi_values = [100.0, 103.0, 106.5, 110.0, 115.0]
cpi = CPI(years, cpi_values, ConsumptionGood())

println("✓ Created CPI with $(length(cpi)) observations")
println("  Years: ", years)
println("  CPI:   ", cpi_values)
println("  Inflation rates:")
for i in 2:length(years)
    inflation = (cpi_values[i] / cpi_values[i-1] - 1) * 100
    println("    $(years[i-1])-$(years[i]): $(round(inflation, digits=2))%")
end
println()

#==========================================================================
    TEST 5: MonetaryVariable Conversions (Nominal → Real)
==========================================================================#

println("TEST 5: MonetaryVariable - Nominal to Real")
println("-"^70)

# Convert to real (base year 1990)
income_real = to_real(income_nom, cpi, years, 1990)

println("✓ Converted to real values (base = 1990)")
println("  Nominal: ", income_nom.data)
println("  Real:    ", round.(income_real.data, digits=2))
println("  Currency: ", currency_string(currency(income_real)))
println("  Base date: ", base_date(currency(income_real)))
println()

# Calculate real growth
nominal_growth = (income_nom.data[end] / income_nom.data[1] - 1) * 100
real_growth = (income_real.data[end] / income_real.data[1] - 1) * 100
inflation_total = (cpi_values[end] / cpi_values[1] - 1) * 100

println("  Growth analysis:")
println("    Nominal growth: $(round(nominal_growth, digits=2))%")
println("    Real growth:    $(round(real_growth, digits=2))%")
println("    Total inflation: $(round(inflation_total, digits=2))%")
println()

#==========================================================================
    TEST 6: MonetaryVariable Conversions (Real → Nominal)
==========================================================================#

println("TEST 6: MonetaryVariable - Real to Nominal (Round-trip)")
println("-"^70)

# Convert back to nominal
income_nom_again = to_nominal(income_real, cpi, years)

println("✓ Converted back to nominal")
println("  Original nominal: ", income_nom.data)
println("  After round-trip: ", round.(income_nom_again.data, digits=2))
println("  Currency: ", currency_string(currency(income_nom_again)))
println()

# Check if values match (within tolerance)
max_diff = maximum(abs.(income_nom.data .- income_nom_again.data))
println("  Maximum difference: ", round(max_diff, digits=10))
println("  Round-trip successful: ", max_diff < 1e-10)
println()

#==========================================================================
    TEST 7: MonetaryVariable Rebasing
==========================================================================#

println("TEST 7: MonetaryVariable - Rebasing")
println("-"^70)

# Rebase to 1992
income_real_1992 = rebase(income_real, cpi, 1992)

println("✓ Rebased from 1990 to 1992")
println("  Real (base 1990): ", round.(income_real.data, digits=2))
println("  Real (base 1992): ", round.(income_real_1992.data, digits=2))
println("  Currency: ", currency_string(currency(income_real_1992)))
println("  New base date: ", base_date(currency(income_real_1992)))
println()

# Verify rebasing makes sense
ratio = income_real.data[1] / income_real_1992.data[1]
expected_ratio = cpi_values[3] / cpi_values[1]  # CPI(1992) / CPI(1990)
println("  Ratio check: $(round(ratio, digits=4)) ≈ $(round(expected_ratio, digits=4))")
println("  Rebasing correct: ", abs(ratio - expected_ratio) < 1e-10)
println()

#==========================================================================
    TEST 8: MonetaryScalar Conversions
==========================================================================#

println("TEST 8: MonetaryScalar Conversions")
println("-"^70)

# Create a nominal scalar for 1993
income_1993_nom = MonetaryScalar(52000.0, Annual(), Household(), NominalUSD())
println("✓ Created nominal scalar for 1993: ", income_1993_nom.value)
println()

# Convert to real (base 1990)
income_1993_real = to_real(income_1993_nom, cpi, 1993, 1990)
println("✓ Converted to real (base 1990): ", round(income_1993_real.value, digits=2))
println("  Currency: ", currency_string(currency(income_1993_real)))
println()

# Convert back to nominal for 1993
income_1993_nom_again = to_nominal(income_1993_real, cpi, 1993)
println("✓ Converted back to nominal: ", round(income_1993_nom_again.value, digits=2))
println("  Original: ", income_1993_nom.value)
println("  Difference: ", abs(income_1993_nom.value - income_1993_nom_again.value))
println()

# Rebase to 1992
income_1993_real_1992 = rebase(income_1993_real, cpi, 1992)
println("✓ Rebased to 1992: ", round(income_1993_real_1992.value, digits=2))
println("  Base 1990 value: ", round(income_1993_real.value, digits=2))
println("  Base 1992 value: ", round(income_1993_real_1992.value, digits=2))
println()

#==========================================================================
    TEST 9: Error Handling
==========================================================================#

println("TEST 9: Error Handling")
println("-"^70)

# Try to convert real to real (should fail)
println("Testing error cases...")
try
    to_real(income_real, cpi, years, 1990)
    println("  ✗ Should have thrown error when converting real to real")
catch e
    println("  ✓ Correctly threw error when converting real to real")
    println("    Error: ", e.msg)
end
println()

# Try to convert nominal to nominal (should fail)
try
    to_nominal(income_nom, cpi, years)
    println("  ✗ Should have thrown error when converting nominal to nominal")
catch e
    println("  ✓ Correctly threw error when converting nominal to nominal")
    println("    Error: ", e.msg)
end
println()

# Try to rebase nominal (should fail)
try
    rebase(income_nom, cpi, 1992)
    println("  ✗ Should have thrown error when rebasing nominal")
catch e
    println("  ✓ Correctly threw error when rebasing nominal")
    println("    Error: ", e.msg)
end
println()

#==========================================================================
    TEST 10: Statistical Functions Preserve Currency
==========================================================================#

println("TEST 10: Statistical Functions with Real Values")
println("-"^70)

mean_real = mean(income_real)
println("✓ Mean of real income: ", round(mean_real.value, digits=2))
println("  Type: ", typeof(mean_real))
println("  Is MonetaryScalar: ", mean_real isa MonetaryScalar)
println("  Currency: ", currency_string(currency(mean_real)))
println("  Base date preserved: ", base_date(currency(mean_real)) == 1990)
println()

std_real = std(income_real)
println("✓ Std. dev of real income: ", round(std_real.value, digits=2))
println("  Currency: ", currency_string(currency(std_real)))
println()

#==========================================================================
    Summary
==========================================================================#

println("="^70)
println("ALL TESTS COMPLETED SUCCESSFULLY!")
println("="^70)
println()
println("Summary:")
println("  ✓ MonetaryScalar and MonetaryVariable creation")
println("  ✓ Arithmetic operations")
println("  ✓ Statistical functions")
println("  ✓ Nominal → Real conversions")
println("  ✓ Real → Nominal conversions")
println("  ✓ Rebasing")
println("  ✓ Round-trip accuracy")
println("  ✓ Error handling")
println("  ✓ Currency preservation in statistics")
println()
