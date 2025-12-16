#==========================================================================
    ECONFRAME
    Main type. DataFrames with economic metadata.
==========================================================================#

abstract type EconFrame end

mutable struct EconRepeatedCrossSection{Ds<:DataSource, Dl<:DataSubject, Df<:DataFrequency} <: EconFrame
    # Data
    data::DataFrame
    # Data characteristics
    source::Ds
    subject::Dl
    frequency::Df
    currency::Currency      # Currency for monetary variables (not parametric to allow mutation)
    N::Int                  # Number of observations
    # Key columns
    date_var::Union{Symbol,String}
    weight_var::Union{Symbol,String}
    # Constructors
    function EconRepeatedCrossSection(
        data::DataFrame, source::Ds, subject::Dl, frequency::Df, date_var::Union{Symbol,String};
        currency::Currency=NACurrency(), weight_var::Union{Symbol,String}=:weight
    ) where {Ds<:DataSource, Dl<:DataSubject, Df<:DataFrequency}
        N = nrow(data)
        data[!, date_var] = Date.(data[!, date_var])  # Ensure date variable is of Date type
        return new{Ds, Dl, Df}(data, source, subject, frequency, currency, N, date_var, weight_var)
    end
end
mutable struct EconCrossSection{Ds<:DataSource, Dl<:DataSubject} <: EconFrame
    # Data
    data::DataFrame
    # Data characteristics
    source::Ds
    subject::Dl
    currency::Currency      # Currency for monetary variables (not parametric to allow mutation)
    N::Int                  # Number of observations
    date::Date
    # Key columns
    weight_var::Union{Symbol,String}
    # Constructor
    function EconCrossSection(
        data::DataFrame, source::Ds, subject::Dl, date::Date;
        currency::Currency=NACurrency(), weight_var::Union{Symbol,String}=:weight
    ) where {Ds<:DataSource, Dl<:DataSubject}
        N = nrow(data)
        data[!, date_var] = Date.(data[!, date_var])  # Ensure date variable is of Date type
        return new{Ds, Dl}(data, source, subject, currency, N, date, weight_var)
    end
    EconCrossSection(data::DataFrame, source::DataSource, subject::DataSubject, date; kwargs...) = EconCrossSection(data, source, subject, Date(date); kwargs...)
end

# Methods
# Mark columns as monetary variables (they will use the EconFrame's currency)
function monetary_variable!(ef::EconFrame, col::Symbol, good_type::GoodType=AnyGood())::Nothing
    # Ensure column contains Real numbers
    if !(eltype(ef.data[!, col]) <: Real)
        ef.data[!, col] = parse.(Float64, string.(ef.data[!, col]))
    end
    # Set metadata
    colmetadata!(ef.data, col, "is_monetary", true)
    colmetadata!(ef.data, col, "good_type", good_type)
    return nothing
end
function monetary_variable!(ef::EconFrame, cols::AbstractVector{Symbol}, good_type::GoodType=AnyGood())::Nothing
    for col in cols
        monetary_variable!(ef, col, good_type)
    end
    return nothing
end
function monetary_variable!(ef::EconFrame, cols::AbstractVector{<:Symbol}, good_types::Vector{<:GoodType})::Nothing
    for (col, good_type) in zip(cols, good_types)
        monetary_variable!(ef, Symbol(col), good_type)
    end
    return nothing
end

# Get list of monetary variables
list_monetary_variables(ef::EconFrame) = [col for col in names(ef.data) if "is_monetary" in colmetadatakeys(ef.data, col) && colmetadata(ef.data, col, "is_monetary")]
function list_compatible_monetary_variables(ef::EconFrame, tg_cpi::GoodType; ensure_compatibility::Bool=false)
    all_mon_vars = list_monetary_variables(ef)
    
    # If CPI is AnyGood, return all monetary variables
    tg_cpi isa AnyGood && return all_mon_vars
    
    # Filter by compatibility
    compatible_vars = String[]
    for var in all_mon_vars
        # Get good type metadata for this variable
        if "good_type" in colmetadatakeys(ef.data, var)
            var_good_type = colmetadata(ef.data, var, "good_type")
            
            if ensure_compatibility
                # Strict: only exact match
                var_good_type == tg_cpi && push!(compatible_vars, var)
            else
                # Permissive: exact match OR AnyGood
                (var_good_type == tg_cpi || var_good_type isa AnyGood) && push!(compatible_vars, var)
            end
        else
            # No good_type metadata: treat as AnyGood
            !ensure_compatibility && push!(compatible_vars, var)
        end
    end
    
    return compatible_vars
end

# Accessors
currency(ef::EconFrame) = ef.currency
frequency(ef::EconFrame) = ef.frequency
subject(ef::EconFrame) = ef.subject
get_dates(ef::EconRepeatedCrossSection) = ef.data[!, ef.date_var]
get_dates(ef::EconCrossSection) = ef.date
get_weights(ef::EconFrame) = ef.data[!, ef.weight_var]

# Reconstruct EconFrame with updated fields
"""
    reconstruct(ef::EconRepeatedCrossSection; kwargs...)

Create a new EconRepeatedCrossSection with the same type and fields as `ef`, 
but with specified fields updated via keyword arguments.

# Arguments
- `ef`: Original EconRepeatedCrossSection
- `kwargs...`: Fields to update (data, source, subject, frequency, date_var, currency)

# Examples
```julia
ef2 = reconstruct(ef; data=new_df, currency=NominalEUR())
ef3 = reconstruct(ef; currency=RealUSD{2015}())
```
"""
function reconstruct(
    ef::EconRepeatedCrossSection; 
    data=ef.data, 
    source=ef.source, 
    subject=ef.subject, 
    frequency=ef.frequency, 
    currency=ef.currency,
    date_var=ef.date_var,
    weight_var=ef.weight_var
)
    return EconRepeatedCrossSection(data, source, subject, frequency, date_var; currency, weight_var)
end

# Base methods
Base.size(ef::EconFrame) = size(ef.data)
Base.getindex(ef::EconFrame, args...) = getindex(ef.data, args...)
Base.setindex!(ef::EconFrame, val, args...) = setindex!(ef.data, val, args...)
Base.view(ef::EconFrame, args...) = view(ef.data, args...)
Base.propertynames(ef::EconFrame) = propertynames(ef.data)
Base.getproperty(ef::EconFrame, s::Symbol) = s in fieldnames(typeof(ef)) ? getfield(ef, s) : getproperty(ef.data, s)
Base.setproperty!(ef::EconFrame, s::Symbol, val) = s in fieldnames(typeof(ef)) ? setfield!(ef, s, val) : setproperty!(ef.data, s, val)
Base.sort!(ef::EconFrame, args...; kwargs...) = df_function_keeping_metadata!(ef, Base.sort!, args...; kwargs...)

# DataFrame methods
DataFrames.names(ef::EconFrame) = names(ef.data)
DataFrames.nrow(ef::EconFrame) = nrow(ef.data)
DataFrames.ncol(ef::EconFrame) = ncol(ef.data)
DataFrames.colmetadata(ef::EconFrame, args...) = DataFrames.colmetadata(ef.data, args...)
DataFrames.colmetadatakeys(ef::EconFrame, args...) = DataFrames.colmetadatakeys(ef.data, args...)
DataFrames.insertcols!(ef::EconFrame, args...) = DataFrames.insertcols!(ef.data, args...)
DataFrames.select(ef::EconFrame, args...; kwargs...) = reconstruct(ef;data=DataFrames.select(ef.data, args...; kwargs...), kwargs...)
DataFrames.select!(ef::EconFrame, args...) = df_function_keeping_metadata!(ef, DataFrames.select!, args...)
DataFrames.subset(ef::EconFrame, args...; kwargs...) = reconstruct(ef;data=DataFrames.subset(ef.data, args...), kwargs...)
DataFrames.subset!(ef::EconFrame, args...) = df_function_keeping_metadata!(ef, DataFrames.subset!, args...)

# Auxiliary
function df_function_keeping_metadata!(ef::EconFrame, df_func::Function, args...; kwargs...)
    # Save all column metadata
    saved_meta = df_save_metadata(ef)
    # Perform function
    df_func(ef.data, args...; kwargs...)
    ef.N = nrow(ef.data)
    # Restore metadata for remaining columns
    df_restore_metadata!(ef, saved_meta)
    return nothing
end
# - Saving metadata
function df_save_metadata(df::DataFrame)
    return [(col, key, DataFrames.colmetadata(df, col, key)) 
                  for col in names(df) 
                  for key in DataFrames.colmetadatakeys(df, col)]
end
df_save_metadata(ef::EconFrame) = df_save_metadata(ef.data)
# - Restoring metadata
function df_restore_metadata!(df::DataFrame, saved_meta)::Nothing
    for (col, key, value) in saved_meta
        col in names(df) && DataFrames.colmetadata!(df, col, key, value)
    end
    return nothing
end
df_restore_metadata!(ef::EconFrame, saved_meta)::Nothing = df_restore_metadata!(ef.data, saved_meta)

# Formatting - show
function Base.show(io::IO, ef::EconRepeatedCrossSection{Ds,Dl,Df}) where {Ds,Dl,Df}
    dates = get_dates(ef)
    # Get first and last dates
    date_range = if isempty(dates)
        "no dates"
    elseif length(dates) == 1
        "$(dates[1])"
    else
        "$(minimum(dates)) to $(maximum(dates))"
    end
    
    # Get currency string
    curr_str = currency_string(ef.currency)
    
    # Print type with abbreviated date range
    print(io, "EconRepeatedCrossSection{$(Ds.name.name), $(Dl.name.name), $(Df.name.name), $curr_str}(")
    print(io, "$(ef.source), $(ef.subject), $(ef.frequency), ")
    print(io, "dates: $date_range, ")
    print(io, "currency: $curr_str, ")
    print(io, "$(ef.N) observations, ")
    print(io, "$(ncol(ef.data))×$(nrow(ef.data)) DataFrame\n")
    show(io, ef.data)
end



#==========================================================================
    ECONSET
    Struct to hold multiple EconFrames. For example, when there are
    variables at the individual and household levels.
==========================================================================#

struct EconSet
    efs::Dict{Symbol,<:EconFrame}
    cross_id::SymmetricDict{Symbol, <:Any}     # Links between frames
    # Constructors
    function EconSet(efs::Dict{Symbol,<:EconFrame}, cross_id::SymmetricDict{Symbol, <:Any})
        # Verify that all cross_id keys belong to efs
        for (a, b) in keys(cross_id)
            @assert a in keys(efs) "EconFrame $a not found in EconSet"
            @assert b in keys(efs) "EconFrame $b not found in EconSet"
        end
        new(efs, cross_id)
    end
    EconSet(efs::Dict{Symbol,<:EconFrame}) = new(efs, SymmetricDict{Symbol, Symbol}())
    EconSet(efs::Dict{Symbol,<:EconFrame}, cid::Dict{Tuple{Symbol,Symbol}, <:Any}) = EconSet(efs, SymmetricDict(cid))
    EconSet(efs::Vector{<:EconFrame}, names::Vector{<:Symbol}, args...) = new(Dict(names .=> efs), args...)
    EconSet(efs::Tuple, args...) = new(Dict(efs), args...)
end
# Methods
getindex(es::EconSet, key::Symbol) = es.efs[key]