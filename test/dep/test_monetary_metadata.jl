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
