# Tests for Inflation/CPI functionality

function test_cpi_construction()
    @testset "CPI Construction" begin
        # Construction with years (Int)
        years = [1990, 1991, 1992, 1993, 1994]
        values = [100.0, 103.0, 106.5, 110.0, 115.0]
        cpi = CPI(years, values, ConsumptionGood())
        
        @test length(cpi) == 5
        @test cpi[1] == 100.0
        @test cpi[end] == 115.0
        
        # Construction with Dates
        dates = Date.(years)
        cpi2 = CPI(dates, values, ConsumptionGood())
        @test length(cpi2) == 5
        
        # CPI indexing by date
        idx = cpi_index(cpi, Date(1992))
        @test idx == 106.5
        
        # CPI indexing by vector of dates
        idxs = cpi_index(cpi, [1990, 1992, 1994])
        @test idxs == [100.0, 106.5, 115.0]
        
        # Multiple good types
        cpi_housing = CPI(years, [110.0, 115.0, 120.0, 125.0, 132.0], Housing())
        cpi_anygood = CPI(years, values, AnyGood())
        
        @test get_good(cpi) == ConsumptionGood()
        @test get_good(cpi_housing) == Housing()
        @test get_good(cpi_anygood) == AnyGood()
    end
end

function test_monetaryvariable_inflation()
    @testset "MonetaryVariable Inflation Conversions" begin
        # Setup
        years = [1990, 1991, 1992, 1993, 1994]
        cpi_values = [100.0, 103.0, 106.5, 110.0, 115.0]
        cpi = CPI(years, cpi_values, ConsumptionGood())
        
        income_nom = MonetaryVariable([45000.0, 48000.0, 50000.0, 52000.0, 55000.0], 
                                     Annual(), Household(), NominalUSD())
        
        # Nominal to Real
        income_real = to_real(income_nom, cpi, years, 1990)
        @test currency(income_real) isa RealUSD{1990}
        @test base_date(currency(income_real)) == 1990
        @test income_real.data[1] == 45000.0  # Base year unchanged
        @test income_real.data[2] > income_nom.data[2]  # Deflated
        
        # Real to Nominal (round-trip)
        income_nom_again = to_nominal(income_real, cpi, years)
        @test currency(income_nom_again) isa NominalUSD
        @test all(isapprox.(income_nom.data, income_nom_again.data, rtol=1e-10))
        
        # Rebasing
        income_real_1992 = rebase(income_real, cpi, 1992)
        @test currency(income_real_1992) isa RealUSD{1992}
        @test base_date(currency(income_real_1992)) == 1992
        # Value at position 3 should equal real value deflated to 1992 base
        @test income_real_1992.data[3] ≈ income_real.data[3] * cpi_values[3] / cpi_values[1]
    end
end

function test_monetaryscalar_inflation()
    @testset "MonetaryScalar Inflation Conversions" begin
        # Setup
        years = [1990, 1991, 1992, 1993, 1994]
        cpi_values = [100.0, 103.0, 106.5, 110.0, 115.0]
        cpi = CPI(years, cpi_values, ConsumptionGood())
        
        income_1993_nom = MonetaryScalar(52000.0, Annual(), Household(), NominalUSD())
        
        # Nominal to Real
        income_1993_real = to_real(income_1993_nom, cpi, 1993, 1990)
        @test currency(income_1993_real) isa RealUSD{1990}
        @test base_date(currency(income_1993_real)) == 1990
        @test income_1993_real.value > income_1993_nom.value  # Deflated
        
        # Real to Nominal (round-trip)
        income_1993_nom_again = to_nominal(income_1993_real, cpi, 1993)
        @test currency(income_1993_nom_again) isa NominalUSD
        @test isapprox(income_1993_nom.value, income_1993_nom_again.value, rtol=1e-10)
        
        # Rebasing
        income_1993_real_1992 = rebase(income_1993_real, cpi, 1992)
        @test currency(income_1993_real_1992) isa RealUSD{1992}
        @test base_date(currency(income_1993_real_1992)) == 1992
    end
end

function test_inflation_roundtrip()
    @testset "Inflation Round-trip Accuracy" begin
        years = [1990, 1991, 1992, 1993, 1994]
        cpi_values = [100.0, 103.0, 106.5, 110.0, 115.0]
        cpi = CPI(years, cpi_values, ConsumptionGood())
        
        # MonetaryVariable round-trip
        v_nom = MonetaryVariable([45000.0, 48000.0, 50000.0, 52000.0, 55000.0], 
                                Annual(), Household(), NominalUSD())
        v_real = to_real(v_nom, cpi, years, 1990)
        v_nom_again = to_nominal(v_real, cpi, years)
        
        max_diff = maximum(abs.(v_nom.data .- v_nom_again.data))
        @test max_diff < 1e-10
        
        # MonetaryScalar round-trip
        s_nom = MonetaryScalar(52000.0, Annual(), Household(), NominalUSD())
        s_real = to_real(s_nom, cpi, 1993, 1990)
        s_nom_again = to_nominal(s_real, cpi, 1993)
        
        @test abs(s_nom.value - s_nom_again.value) < 1e-10
    end
end

function test_inflation_errors()
    @testset "Inflation Error Handling" begin
        years = [1990, 1991, 1992, 1993, 1994]
        cpi_values = [100.0, 103.0, 106.5, 110.0, 115.0]
        cpi = CPI(years, cpi_values, ConsumptionGood())
        
        # Try to convert real to real (should fail)
        v_real = MonetaryVariable([45000.0, 48000.0], Annual(), Household(), RealUSD{1990}())
        @test_throws ArgumentError to_real(v_real, cpi, [1990, 1991], 1990)
        
        # Try to convert nominal to nominal (should fail)
        v_nom = MonetaryVariable([45000.0, 48000.0], Annual(), Household(), NominalUSD())
        @test_throws ArgumentError to_nominal(v_nom, cpi, [1990, 1991])
        
        # Try to rebase nominal (should fail)
        @test_throws ArgumentError rebase(v_nom, cpi, 1992)
        
        # Same for scalars
        s_real = MonetaryScalar(50000.0, Annual(), Household(), RealUSD{1990}())
        @test_throws ArgumentError to_real(s_real, cpi, 1990, 1990)
        
        s_nom = MonetaryScalar(50000.0, Annual(), Household(), NominalUSD())
        @test_throws ArgumentError to_nominal(s_nom, cpi, 1990)
        @test_throws ArgumentError rebase(s_nom, cpi, 1992)
    end
end

function test_multiple_cpis()
    @testset "Multiple CPIs for Different Good Types" begin
        years = [1990, 1991, 1992, 1993, 1994]
        cpi_consumption = CPI(years, [100.0, 103.0, 106.5, 110.0, 115.0], ConsumptionGood())
        cpi_housing = CPI(years, [110.0, 115.0, 120.0, 125.0, 132.0], Housing())
        
        # Test with multiple CPIs - should not throw
        cpis = [cpi_consumption, cpi_housing]
        @test length(cpis) == 2
        
        # Test duplicate good types (should fail)
        cpi_consumption2 = CPI(years, [101.0, 104.0, 107.0, 111.0, 116.0], ConsumptionGood())
        @test_throws ArgumentError validate_cpis_unique([cpi_consumption, cpi_consumption2])
        
        # Test build_cpi_dict
        cpi_dict, anygood_cpi = build_cpi_dict(cpis)
        @test haskey(cpi_dict, ConsumptionGood())
        @test haskey(cpi_dict, Housing())
        @test isnothing(anygood_cpi)
        
        # Test with AnyGood CPI
        cpi_general = CPI(years, [105.0, 108.0, 111.0, 114.0, 118.0], AnyGood())
        cpi_dict2, anygood_cpi2 = build_cpi_dict([cpi_consumption, cpi_general])
        @test !isnothing(anygood_cpi2)
        @test get_good(anygood_cpi2) == AnyGood()
    end
end

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
