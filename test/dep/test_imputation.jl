function test_combine_multiple_imputation_two_stage()
    @testset "Combine with multiple imputations" begin
        df = DataFrame(
            year = Date.([2000, 2000, 2000, 2000]),
            wth_quant = ["B50", "B50", "B50", "B50"],
            imputation = [1, 1, 2, 2],
            n_re = [3, 0, 4, 0],
            weight = [1.0, 1.0, 1.0, 1.0],
        )

        ef = EconRepeatedCrossSection(
            df,
            TestSource(),
            Household(),
            Annual(),
            :year;
            currency=NominalUSD(),
            weight_var=:weight,
            imputation_var=:imputation,
        )

        out = combine(
            ef,
            [:year, :wth_quant],
            [:n_re, :weight] => ((n, w) -> weighted_mean(n .> 2, w)) => :share_multi_re,
            [:n_re, :weight] => ((n, w) -> weighted_mean(n .== 0, w)) => :share_no_re,
            [:n_re, :weight] => ((n, w) -> weighted_mean(n[n .> 0], w[n .> 0])) => :mean_owners_re,
            skip_basic=true,
        )

        @test nrow(out) == 1
        @test out.share_multi_re[1] ≈ 0.5 atol=1e-10
        @test out.share_no_re[1] ≈ 0.5 atol=1e-10
        @test out.mean_owners_re[1] ≈ 3.5 atol=1e-10
    end
end

function test_combine_single_imputation_passthrough()
    @testset "Combine without imputation variable" begin
        df = DataFrame(
            year = Date.([2000, 2000, 2001, 2001]),
            value = [1.0, 3.0, 2.0, 4.0],
            weight = ones(4),
        )

        ef = EconRepeatedCrossSection(
            df,
            TestSource(),
            Household(),
            Annual(),
            :year;
            currency=NominalUSD(),
            weight_var=:weight,
        )

        out = combine(ef, :year, :value => mean => :mean_value; skip_basic=true)

        @test nrow(out) == 2
        @test out.mean_value == [2.0, 3.0]
    end
end
