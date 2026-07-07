# Tests for filter/filter! EconFrame overloads
function test_filter_methods()
    @testset "Filter Methods" begin
        df = DataFrame(
            year = Date.([1990, 1991, 1992, 1993]),
            hid_prev = [missing, 10, 20, missing],
            income = [100.0, 200.0, 300.0, 400.0]
        )

        ef = EconRepeatedCrossSection(df, TestSource(), Household(), Annual(), :year; currency=NominalUSD())
        monetary_variable!(ef, :income)

        # Non-mutating filter with function first
        ef_filtered = filter(row -> !ismissing(row.hid_prev), ef)
        @test nrow(ef_filtered) == 2
        @test all(.!ismissing.(ef_filtered.hid_prev))
        @test "is_monetary" in colmetadatakeys(ef_filtered.data, :income)
        @test colmetadata(ef_filtered.data, :income, "is_monetary") == true

        # Mutating filter! with function first
        ef_mut = deepcopy(ef)
        filter!(row -> !ismissing(row.hid_prev), ef_mut)
        @test nrow(ef_mut) == 2
        @test all(.!ismissing.(ef_mut.hid_prev))
        @test "is_monetary" in colmetadatakeys(ef_mut.data, :income)
        @test colmetadata(ef_mut.data, :income, "is_monetary") == true
    end
end
