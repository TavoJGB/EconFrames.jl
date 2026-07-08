function test_create_quantile_labels()
    @testset "Create Quantile Labels" begin
        @test default_range_labels([0.5, 0.9]) == false
        @test default_range_labels([0.2, 0.4, 0.6, 0.8]) == true

        @test create_quantile_labels([0.2, 0.4, 0.6, 0.8]) == ["0-20", "20-40", "40-60", "60-80", "80-100"]
        @test create_quantile_labels([0.5, 0.9]) == ["B50", "M40", "T10"]
        @test create_quantile_labels([0.5, 0.9]; range_labels=true) == ["0-50", "50-90", "90-100"]

        @test create_quantile_labels([0.5, 0.9]; range_labels=false) == ["B50", "M40", "T10"]
        @test create_quantile_labels([0.5, 0.9]; range_labels=false,
                                     bottom_label="Bottom", middle_label="Middle", top_label="Top") ==
              ["Bottom50", "Middle40", "Top10"]
    end
end

function test_assign_quantiles_range_labels()
    @testset "Assign Quantiles Range Labels" begin
        df = DataFrame(
            year = Date.([2000 for _ in 1:10]),
            wealth_a = collect(1.0:10.0),
            weight = ones(10)
        )

        ef = EconRepeatedCrossSection(df, TestSource(), Household(), Annual(), :year;
                                      currency=NominalUSD(), weight_var=:weight)

        quants = [0.20, 0.40, 0.60, 0.80]
        assign_quantiles!(ef, :wealth_a, quants; by=[:year], col_name="liqwth")

        expected = Set(["0-20", "20-40", "40-60", "60-80", "80-100"])
        actual = Set(ef.data[!, :liqwth_quant])

        @test actual == expected
    end
end
