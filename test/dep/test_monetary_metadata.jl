function test_monetary_metadata_persistence()
    @testset "Monetary Metadata Persistence" begin

        df = DataFrame(
            year = Date.([2002, 2002]),
            lab_income_direct = ["100.0", "200.0"],
            lab_income_inkind = ["10.0", "20.0"],
        )

        ef = EconRepeatedCrossSection(df, TestSource(), Individual(), Annual(), :year; currency=NominalEUR())
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

        ef_ii = EconRepeatedCrossSection(ii_df, TestSource(), Individual(), Annual(), :year; currency=NominalEUR())
        ef_hh = EconRepeatedCrossSection(hh_df, TestSource(), Household(), Annual(), :year; currency=NominalEUR())

        monetary_variable!(ef_ii, :lab_income, AnyGood())
        monetary_variable!(ef_hh, :wealth, AnyGood())

        es = EconSet(Dict(:ii => ef_ii, :hh => ef_hh), (:ii, :hh) => [:year, :hid, :imputation])
        out = collapse(es, :hh, :ii, :lab_income => sum => :lab_income, :age => only_head)

        @test sort(String.(list_monetary_variables(out))) == ["lab_income", "wealth"]
    end
end

function test_collapse_dropmissing_new_variables()
    @testset "Collapse dropmissing on new variables" begin
        ii_df = DataFrame(
            year = Date.([2002, 2002]),
            hid = [1, 1],
            imputation = [1, 1],
            income = [100.0, 50.0],
            weight = [1.0, 1.0],
        )
        hh_df = DataFrame(
            year = Date.([2002, 2002]),
            hid = [1, 2],
            imputation = [1, 1],
            wealth = [1000.0, 2000.0],
            weight = [1.0, 1.0],
        )

        ef_ii = EconRepeatedCrossSection(ii_df, TestSource(), Individual(), Annual(), :year; currency=NominalEUR())
        ef_hh = EconRepeatedCrossSection(hh_df, TestSource(), Household(), Annual(), :year; currency=NominalEUR())

        es = EconSet(Dict(:ii => ef_ii, :hh => ef_hh), (:ii, :hh) => [:year, :hid, :imputation])

        out_keep = collapse(es, :hh, :ii, :income => sum => :hh_income)
        @test eltype(out_keep.hh_income) == Union{Missing, Float64}

        out_drop = collapse(es, :hh, :ii, :income => sum => :hh_income; dropmissing=true)
        @test nrow(out_drop) == 1
        @test out_drop.hid == [1]
        @test eltype(out_drop.hh_income) == Float64
    end
end

function test_getindex_single_column_returns_vector()
    @testset "Single column getindex returns vector" begin
        rcs_df = DataFrame(
            year = Date.([2002, 2003]),
            income = [100, 200],
            weight = [1.0, 1.0],
        )
        panel_df = DataFrame(
            year = Date.([2002, 2003]),
            id = [1, 1],
            income = [300, 400],
            weight = [1.0, 1.0],
        )
        cs_df = DataFrame(
            income = [500, 600],
            weight = [1.0, 1.0],
        )

        ef_rcs = EconRepeatedCrossSection(rcs_df, TestSource(), Household(), Annual(), :year; currency=NominalEUR())
        ef_panel = EconPanel(panel_df, TestSource(), Household(), Annual(), :year, :id; currency=NominalEUR())
        ef_cs = EconCrossSection(cs_df, TestSource(), Household(), Date(2008, 1, 1); currency=NominalEUR())

        @test ef_rcs[!, :income] == ef_rcs.data[!, :income]
        @test ef_panel[!, :income] == ef_panel.data[!, :income]
        @test ef_cs[!, :income] == ef_cs.data[!, :income]

        @test ef_rcs[!, [:year, :income]] isa EconRepeatedCrossSection
        @test ef_panel[!, [:year, :id, :income]] isa EconPanel
        @test ef_cs[!, [:income]] isa EconCrossSection
    end
end
