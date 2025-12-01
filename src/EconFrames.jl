module EconFrames

    BASE_FOLDER = dirname(@__DIR__)

    using CSV, DataFrames
    using Dates
    using Parameters        # unpack
    using StatsBase         # weighted mean etc.
    using StatsBase: dot
        export mean, std, median, dot

    # Load dependencies
    include(joinpath(BASE_FOLDER, "src", "dep", "types.jl"))
        export EconVariable, EconScalar
        export MonetaryVariable, MonetaryScalar
        export EconFrame, EconCrossSection, EconRepeatedCrossSection
        export PSID, SCF, EFF
        export frequency, Annual, Quarterly, Monthly
        export subject, Household, Individual, Quantile
        export currency
        export NominalEUR, NominalUSD
        export RealEUR, RealUSD
        export get_dates
        # export TenureStatus, Owner, Renter, NoTenure
    include(joinpath(BASE_FOLDER, "src", "dep", "inflation.jl"))
        export CPI, AnyGood, ConsumptionGood, Housing
        export to_real, to_nominal, rebase
        export to_real!, to_nominal!, rebase!
    include(joinpath(BASE_FOLDER, "src", "dep", "groups.jl"))
        export assign_groups!, groupby!, assign_quantiles!
    include(joinpath(BASE_FOLDER, "src", "dep", "stats.jl"))

end
