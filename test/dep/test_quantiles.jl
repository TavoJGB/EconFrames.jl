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
