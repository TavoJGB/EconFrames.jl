module EconFrames

    BASE_FOLDER = dirname(@__DIR__)

    # External dependencies
    using CSV, DataFrames
    using Dates
    using Parameters        # unpack

    # Other local
    using Reexport                      # @reexport
    @reexport using EconStats           # statistics
    @reexport using EconVariables       # vectors with economic metadata
        import EconVariables: currency_string

    # Package dependencies
    include(joinpath(BASE_FOLDER, "src", "dep", "types_aux.jl"))
    include(joinpath(BASE_FOLDER, "src", "dep", "types_main.jl"))
        export EconFrame, EconCrossSection, EconRepeatedCrossSection, EconSet
        # export TenureStatus, Owner, Renter, NoTenure
    include(joinpath(BASE_FOLDER, "src", "dep", "compat_inflation.jl"))
    include(joinpath(BASE_FOLDER, "src", "dep", "groups.jl"))
        export assign_groups!, groupby!, assign_quantiles!

end
