# Tests for Inflation/CPI functionality
function test_econframe_single_cpi()
    @testset "EconFrame with Single CPI" begin
        # Create test data
        df = DataFrame(
            year = Date.([1990, 1991, 1992, 1993, 1994]),
            income = [45000.0, 48000.0, 50000.0, 52000.0, 55000.0],
            wealth = [120000.0, 135000.0, 150000.0, 165000.0, 180000.0]
        )
        
        ef = EconRepeatedCrossSection(df, PSID(), Household(), Annual(), :year; currency=NominalUSD())
        
        # Mark as monetary variables
        monetary_variable!(ef, [:income, :wealth])
        
        # Create CPI
        cpi = CPI([1990, 1991, 1992, 1993, 1994], [100.0, 103.0, 106.5, 110.0, 115.0], AnyGood())
        
        # Convert to real
        to_real!(ef, cpi, 1990)
        @test currency(ef) isa RealUSD{1990}
        @test ef.income[1] == 45000.0  # Base year unchanged
        @test ef.income[2] > 48000.0    # Deflated (real > nominal)
        
        # Convert back to nominal
        to_nominal!(ef, cpi)
        @test currency(ef) isa NominalUSD
        @test ef.income[1] ≈ 45000.0 atol=1e-8
        @test ef.income[2] ≈ 48000.0 atol=1e-8
        
        # Rebase
        to_real!(ef, cpi, 1990)
        rebase!(ef, cpi, 1992)
        @test currency(ef) isa RealUSD{1992}
        @test base_date(currency(ef)) == 1992
    end
end

function test_econframe_multiple_cpis()
    @testset "EconFrame with Multiple CPIs" begin
        # Create test data
        df = DataFrame(
            year = Date.([1990, 1991, 1992, 1993, 1994]),
            food_exp = [12000.0, 12500.0, 13000.0, 13500.0, 14000.0],
            housing_exp = [18000.0, 19000.0, 20000.0, 21000.0, 22500.0],
            other_exp = [8000.0, 8200.0, 8500.0, 8800.0, 9000.0]
        )
        
        ef = EconRepeatedCrossSection(df, PSID(), Household(), Annual(), :year; currency=NominalUSD())
        
        # Mark as monetary variables with specific good types
        monetary_variable!(ef, [:food_exp, :housing_exp, :other_exp])
        colmetadata!(ef.data, :food_exp, "good_type", ConsumptionGood())
        colmetadata!(ef.data, :housing_exp, "good_type", Housing())
        colmetadata!(ef.data, :other_exp, "good_type", AnyGood())
        
        # Create sector-specific CPIs
        cpi_consumption = CPI([1990, 1991, 1992, 1993, 1994], 
                             [100.0, 103.0, 106.5, 110.0, 115.0], ConsumptionGood())
        cpi_housing = CPI([1990, 1991, 1992, 1993, 1994], 
                         [110.0, 115.0, 120.0, 125.0, 132.0], Housing())
        cpi_general = CPI([1990, 1991, 1992, 1993, 1994], 
                         [105.0, 108.0, 111.0, 114.0, 118.0], AnyGood())
        
        # Store original values
        food_original = copy(ef.food_exp)
        housing_original = copy(ef.housing_exp)
        other_original = copy(ef.other_exp)
        
        # Convert with multiple CPIs
        to_real!(ef, [cpi_consumption, cpi_housing, cpi_general], 1990)
        
        # Check conversions happened
        @test currency(ef) isa RealUSD{1990}
        @test ef.food_exp[2] != food_original[2]      # Deflated
        @test ef.housing_exp[2] != housing_original[2] # Deflated  
        @test ef.other_exp[2] != other_original[2]    # Deflated
        
        # Different goods should have different deflation rates
        food_ratio = ef.food_exp[2] / food_original[2]
        housing_ratio = ef.housing_exp[2] / housing_original[2]
        @test food_ratio != housing_ratio  # Different CPIs applied
        
        # Convert back to nominal
        to_nominal!(ef, [cpi_consumption, cpi_housing, cpi_general])
        @test currency(ef) isa NominalUSD
        @test all(isapprox.(ef.food_exp, food_original, atol=1e-8))
        @test all(isapprox.(ef.housing_exp, housing_original, atol=1e-8))
        @test all(isapprox.(ef.other_exp, other_original, atol=1e-8))
    end
end

function test_econframe_partial_matching()
    @testset "EconFrame with Partial CPI Matching" begin
        # Create test data
        df = DataFrame(
            year = Date.([1990, 1991, 1992]),
            consumption = [12000.0, 12500.0, 13000.0],
            housing = [18000.0, 19000.0, 20000.0],
            unmatched = [5000.0, 5200.0, 5400.0]
        )
        
        ef = EconRepeatedCrossSection(df, PSID(), Household(), Annual(), :year; currency=NominalUSD())

        # Mark variables with good types
        monetary_variable!(ef, [:consumption, :housing, :unmatched])
        colmetadata!(ef.data, :consumption, "good_type", ConsumptionGood())
        colmetadata!(ef.data, :housing, "good_type", Housing())
        colmetadata!(ef.data, :unmatched, "good_type", OtherGood())  # No CPI for this
        
        # Create CPIs (missing OtherGood CPI)
        cpi_consumption = CPI([1990, 1991, 1992], [100.0, 103.0, 106.5], ConsumptionGood())
        cpi_housing = CPI([1990, 1991, 1992], [110.0, 115.0, 120.0], Housing())
        
        unmatched_original = copy(ef.unmatched)
        
        # Convert - should warn about unmatched variable
        @test_logs (:warn, r"not converted") to_real!(ef, [cpi_consumption, cpi_housing], 1990)
        
        # Check that matched variables were converted
        @test currency(ef) isa RealUSD{1990}
        
        # Check that unmatched variable has metadata
        @test "currency" in colmetadatakeys(ef.data, :unmatched)
        @test colmetadata(ef.data, :unmatched, "currency") == NominalUSD()
    end
end

function test_econframe_already_converted()
    @testset "EconFrame Already Converted Warning" begin
        df = DataFrame(
            year = Date.([1990, 1991, 1992]),
            income = [45000.0, 48000.0, 50000.0]
        )
        
        ef = EconRepeatedCrossSection(df, PSID(), Household(), Annual(), :year; currency=NominalUSD())
        monetary_variable!(ef, :income)
        
        cpi = CPI([1990, 1991, 1992], [100.0, 103.0, 106.5], AnyGood())
        
        # First conversion - should succeed
        to_real!(ef, cpi, 1990)
        @test currency(ef) isa RealUSD{1990}
        
        # Second conversion - should warn and do nothing
        @test_logs (:warn, r"already in real terms") to_real!(ef, cpi, 1990)
        
        # Try to_nominal on nominal - should warn
        to_nominal!(ef, cpi)
        @test currency(ef) isa NominalUSD
        @test_logs (:warn, r"not in real terms") to_nominal!(ef, cpi)
    end
end
