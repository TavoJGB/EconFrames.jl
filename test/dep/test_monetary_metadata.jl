struct TmpSource <: DataSource end

function test_monetary_metadata_persistence()
    @testset "Monetary Metadata Persistence" begin

        df = DataFrame(
            year = Date.([2002, 2002]),
            lab_income_direct = ["100.0", "200.0"],
            lab_income_inkind = ["10.0", "20.0"],
        )

        ef = EconRepeatedCrossSection(df, TmpSource(), Individual(), Annual(), :year; currency=NominalEUR())
        monetary_variable!(ef, [:lab_income_direct, :lab_income_inkind], AnyGood())

        ef.lab_income = @. ef.lab_income_direct + ef.lab_income_inkind

        @test sort(String.(list_monetary_variables(ef))) == [
            "lab_income",
            "lab_income_direct",
            "lab_income_inkind",
        ]
    end
end

function test_collapse_preserves_monetary_metadata()
    @testset "Collapse Preserves Monetary Metadata" begin
        ii_df = DataFrame(
            year = Date.([2002, 2002, 2002]),
            hid = [1, 1, 2],
            imputation = [1, 1, 1],
            head = [true, false, true],
            age = [40, 38, 50],
            lab_income = [100.0, 50.0, 70.0],
            weight = [1.0, 1.0, 1.0],
        )
        hh_df = DataFrame(
            year = Date.([2002, 2002]),
            hid = [1, 2],
            imputation = [1, 1],
            wealth = [1000.0, 2000.0],
            weight = [1.0, 1.0],
        )

        ef_ii = EconRepeatedCrossSection(ii_df, TmpSource(), Individual(), Annual(), :year; currency=NominalEUR())
        ef_hh = EconRepeatedCrossSection(hh_df, TmpSource(), Household(), Annual(), :year; currency=NominalEUR())

        monetary_variable!(ef_ii, :lab_income, AnyGood())
        monetary_variable!(ef_hh, :wealth, AnyGood())

        es = EconSet(Dict(:ii => ef_ii, :hh => ef_hh), (:ii, :hh) => [:year, :hid, :imputation])
        out = collapse(es, :hh, :ii, :lab_income => sum => :lab_income, :age => only_head)

        @test sort(String.(list_monetary_variables(out))) == ["lab_income", "wealth"]
    end
end
