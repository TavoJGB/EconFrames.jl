module EconFrames

    BASE_FOLDER = dirname(@__DIR__)

    #==========================================================================
        EXTERNAL DEPENDENCIES
    ==========================================================================#

    using CSV, DataFrames
    using Dates
    using Parameters        # unpack



    #==========================================================================
        LOCAL DEPENDENCIES
    ==========================================================================#

    using Reexport                      # @reexport
    @reexport using EconStats           # statistics
    @reexport using EconVariables       # vectors with economic metadata
        import EconVariables: currency_string
        import EconVariables: build_cpi_dict, validate_cpis_unique


    
    #==========================================================================
        PACKAGE DEPENDENCIES
    ==========================================================================#

    # Types
    include(joinpath(BASE_FOLDER, "src", "dep", "types_aux.jl"))
    include(joinpath(BASE_FOLDER, "src", "dep", "types_main.jl"))
        export EconFrame, EconCrossSection, EconRepeatedCrossSection, EconSet
        # export TenureStatus, Owner, Renter, NoTenure

    # Methods
    include(joinpath(BASE_FOLDER, "src", "dep", "collapse.jl"))
        export collapse
        export only_head, weighted_mean, weighted_sum
    include(joinpath(BASE_FOLDER, "src", "dep", "propagate.jl"))
        export propagate
    include(joinpath(BASE_FOLDER, "src", "dep", "compat_inflation.jl"))
        export to_real!, to_nominal!, rebase!
    include(joinpath(BASE_FOLDER, "src", "dep", "groups.jl"))
        export assign_groups!, groupby!, assign_quantiles!

end
