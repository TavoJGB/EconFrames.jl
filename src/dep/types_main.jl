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
    # Key columns
    date_var::Union{Symbol,String}
    weight_var::Union{Symbol,String}
    # Constructors
    function EconRepeatedCrossSection(
        data::DataFrame, source::Ds, subject::Dl, frequency::Df, date_var::Union{Symbol,String};
        currency::Currency=NACurrency(), weight_var::Union{Symbol,String}=:weight
    ) where {Ds<:DataSource, Dl<:DataSubject, Df<:DataFrequency}
        data[!, date_var] = Date.(data[!, date_var])  # Ensure date variable is of Date type
        return new{Ds, Dl, Df}(data, source, subject, frequency, currency, date_var, weight_var)
    end
end
mutable struct EconPanel{Ds<:DataSource, Dl<:DataSubject, Df<:DataFrequency} <: EconFrame
    # Data
    data::DataFrame
    # Data characteristics
    source::Ds
    subject::Dl
    frequency::Df
    currency::Currency      # Currency for monetary variables (not parametric to allow mutation)
    # Key columns
    date_var::Union{Symbol,String}
    id_var::Union{Symbol,String}
    weight_var::Union{Symbol,String}
    # Constructor
    function EconPanel(
        data::DataFrame, source::Ds, subject::Dl, frequency::Df, date_var::Union{Symbol,String}, id_var::Union{Symbol,String};
        currency::Currency=NACurrency(), weight_var::Union{Symbol,String}=:weight
    ) where {Ds<:DataSource, Dl<:DataSubject, Df<:DataFrequency}
        data[!, date_var] = Date.(data[!, date_var])  # Ensure date variable is of Date type
        return new{Ds, Dl, Df}(data, source, subject, frequency, currency, date_var, id_var, weight_var)
    end
end
mutable struct EconCrossSection{Ds<:DataSource, Dl<:DataSubject} <: EconFrame
    # Data
    data::DataFrame
    # Data characteristics
    source::Ds
    subject::Dl
    currency::Currency      # Currency for monetary variables (not parametric to allow mutation)
    date::Date
    # Key columns
    weight_var::Union{Symbol,String}
    # Constructor
    function EconCrossSection(
        data::DataFrame, source::Ds, subject::Dl, date::Date;
        currency::Currency=NACurrency(), weight_var::Union{Symbol,String}=:weight
    ) where {Ds<:DataSource, Dl<:DataSubject}
        return new{Ds, Dl}(data, source, subject, currency, date, weight_var)
    end
    EconCrossSection(data::DataFrame, source::DataSource, subject::DataSubject, date; kwargs...) = EconCrossSection(data, source, subject, Date(date); kwargs...)
end

# Methods
# Mark columns as monetary variables (they will use the EconFrame's currency)
function monetary_variable!(
    ef::EconFrame, col::Symbol, good_type::GoodType=AnyGood();
    do_parse::Bool=true
)::Nothing
    # Ensure column contains Real numbers
    if !(eltype(ef.data[!, col]) <: Real) & do_parse
        ef.data[!, col] = parse.(Float64, string.(ef.data[!, col]))
    end
    # Set metadata
    colmetadata!(ef.data, col, "is_monetary", true)
    colmetadata!(ef.data, col, "good_type", good_type)
    return nothing
end
function monetary_variable!(ef::EconFrame, cols::AbstractVector{Symbol}, good_type::GoodType=AnyGood(); kwargs...)::Nothing
    for col in cols
        monetary_variable!(ef, col, good_type; kwargs...)
    end
    return nothing
end
function monetary_variable!(ef::EconFrame, cols::AbstractVector{<:Symbol}, good_types::Vector{<:GoodType}; kwargs...)::Nothing
    for (col, good_type) in zip(cols, good_types)
        monetary_variable!(ef, Symbol(col), good_type; kwargs...)
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
get_dates(ef::EconPanel) = ef.data[!, ef.date_var]
get_dates(ef::EconCrossSection) = ef.date
get_weights(ef::EconFrame) = ef.data[!, ef.weight_var]
get_ids(ef::EconPanel) = ef.data[!, ef.id_var]

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
function reconstruct(
    ef::EconPanel; 
    data=ef.data, 
    source=ef.source, 
    subject=ef.subject, 
    frequency=ef.frequency, 
    currency=ef.currency,
    date_var=ef.date_var,
    id_var=ef.id_var,
    weight_var=ef.weight_var
)
    return EconPanel(data, source, subject, frequency, date_var, id_var; currency, weight_var)
end

# Base methods
Base.size(ef::EconFrame) = size(ef.data)
Base.getindex(ef::EconFrame, args...) = reconstruct(ef; data=getindex(ef.data, args...))
Base.setindex!(ef::EconFrame, val, args...) = setindex!(ef.data, val, args...)
Base.view(ef::EconFrame, args...) = view(ef.data, args...)
Base.dotview(ef::EconFrame, args...) = Base.dotview(ef.data, args...)
Base.propertynames(ef::EconFrame) = propertynames(ef.data)
function Base.getproperty(ef::EconFrame, s::Symbol)
    s in fieldnames(typeof(ef)) && return getfield(ef, s)
    col = getproperty(ef.data, s)
    return _maybe_wrap_monetary(ef, col, s)
end
Base.setproperty!(ef::EconFrame, s::Symbol, val) = s in fieldnames(typeof(ef)) ? setfield!(ef, s, val) : setproperty!(ef.data, s, val)

# Metadata helpers
_is_monetary(df::DataFrame, col::Symbol) = "is_monetary" in colmetadatakeys(df, col) && colmetadata(df, col, "is_monetary")
_col_good_type(df::DataFrame, col::Symbol) = "good_type" in colmetadatakeys(df, col) ? colmetadata(df, col, "good_type") : AnyGood()

# Wrap monetary columns in MonetaryVariable when accessed via getproperty
function _maybe_wrap_monetary(ef::EconFrame, col::AbstractVector, s::Symbol)
    (_is_monetary(ef.data, s) && nonmissingtype(eltype(col)) <: Real) || return col
    data = col isa Vector ? col : collect(col)
    return MonetaryVariable(data, _get_frequency(ef), getfield(ef, :subject), getfield(ef, :currency), _col_good_type(ef.data, s))
end

# Frequency accessor for _wrap_monetary (EconCrossSection has no frequency field)
_get_frequency(ef::EconRepeatedCrossSection) = getfield(ef, :frequency)
_get_frequency(ef::EconPanel) = getfield(ef, :frequency)
_get_frequency(::EconCrossSection) = NAFrequency()
Base.sort!(ef::EconFrame, args...; kwargs...) = df_function_keeping_metadata!(ef, Base.sort!, args...; kwargs...)

# DataFrame methods
DataFrames.names(ef::EconFrame) = names(ef.data)
DataFrames.nrow(ef::EconFrame) = nrow(ef.data)
DataFrames.ncol(ef::EconFrame) = ncol(ef.data)
DataFrames.colmetadata(ef::EconFrame, args...) = DataFrames.colmetadata(ef.data, args...)
DataFrames.colmetadatakeys(ef::EconFrame, args...) = DataFrames.colmetadatakeys(ef.data, args...)
DataFrames.insertcols!(ef::EconFrame, args...) = DataFrames.insertcols!(ef.data, args...)
DataFrames.select(ef::EconFrame, args...; kwargs...) = reconstruct(ef;data=DataFrames.select(ef.data, args...; kwargs...))
DataFrames.select!(ef::EconFrame, args...) = df_function_keeping_metadata!(ef, DataFrames.select!, args...)
DataFrames.filter(ef::EconFrame, args...; kwargs...) = reconstruct(ef;data=DataFrames.filter(ef.data, args...; kwargs...))
DataFrames.filter(p::Pair, ef::EconFrame; kwargs...) = reconstruct(ef;data=DataFrames.filter(p, ef.data; kwargs...))
DataFrames.filter!(ef::EconFrame, args...) = df_function_keeping_metadata!(ef, DataFrames.filter!, args...)
DataFrames.filter!(p::Pair, ef::EconFrame) = df_function_keeping_metadata!(ef, (df, pair) -> DataFrames.filter!(pair, df), p)
DataFrames.subset(ef::EconFrame, args...; kwargs...) = reconstruct(ef;data=DataFrames.subset(ef.data, args...; kwargs...))
DataFrames.subset(p::Pair, ef::EconFrame; kwargs...) = reconstruct(ef;data=DataFrames.subset(p, ef.data; kwargs...))
DataFrames.subset!(ef::EconFrame, args...) = df_function_keeping_metadata!(ef, DataFrames.subset!, args...)
DataFrames.subset!(p::Pair, ef::EconFrame) = df_function_keeping_metadata!(ef, (df, pair) -> DataFrames.subset!(pair, df), p)
DataFrames.rename(ef::EconFrame, args...; kwargs...) = reconstruct(ef;data=DataFrames.rename(ef.data, args...; kwargs...))
DataFrames.rename!(ef::EconFrame, args...) = df_function_keeping_metadata!(ef, DataFrames.rename!, args...)
DataFrames.leftjoin(ef_L::EconFrame, df_R::DataFrame, args...; kwargs...) = df_join_keeping_metadata(ef_L, df_R, DataFrames.leftjoin, args...; kwargs...)
DataFrames.leftjoin(ef_L::EconFrame, ef_R::EconFrame, args...; kwargs...) = df_join_keeping_metadata(ef_L, ef_R, DataFrames.leftjoin, args...; kwargs...)
DataFrames.leftjoin(df_L::DataFrame, ef_R::EconFrame, args...; kwargs...) = leftjoin(df_L, ef_R.data, args...; kwargs...)
DataFrames.leftjoin!(ef_L::EconFrame, df_R::DataFrame, args...; kwargs...) = df_join_keeping_metadata!(ef_L, df_R, DataFrames.leftjoin, args...; kwargs...)
DataFrames.leftjoin!(ef_L::EconFrame, ef_R::EconFrame, args...; kwargs...) = df_join_keeping_metadata!(ef_L, ef_R, DataFrames.leftjoin, args...; kwargs...)
DataFrames.leftjoin!(df_L::DataFrame, ef_R::EconFrame, args...; kwargs...) = leftjoin!(df_L, ef_R.data, args...; kwargs...)
DataFrames.innerjoin(ef_L::EconFrame, df_R::DataFrame, args...; kwargs...) = df_join_keeping_metadata(ef_L, df_R, DataFrames.innerjoin, args...; kwargs...)
DataFrames.innerjoin(ef_L::EconFrame, ef_R::EconFrame, args...; kwargs...) = df_join_keeping_metadata(ef_L, ef_R, DataFrames.innerjoin, args...; kwargs...)
DataFrames.outerjoin(df_L::DataFrame, ef_R::EconFrame, args...; kwargs...) = outerjoin(df_L, ef_R.data, args...; kwargs...)
DataFrames.outerjoin(ef_L::EconFrame, df_R::DataFrame, args...; kwargs...) = df_join_keeping_metadata(ef_L, df_R, DataFrames.outerjoin, args...; kwargs...)
DataFrames.outerjoin(ef_L::EconFrame, ef_R::EconFrame, args...; kwargs...) = df_join_keeping_metadata(ef_L, ef_R, DataFrames.outerjoin, args...; kwargs...)
DataFrames.dropmissing(ef::EconFrame, args...; kwargs...) = reconstruct(ef; data=DataFrames.dropmissing(ef.data, args...; kwargs...))
DataFrames.dropmissing!(ef::EconFrame, args...) = df_function_keeping_metadata!(ef, DataFrames.dropmissing!, args...)

# Auxiliary
# - Single-frame helpers
function df_function_keeping_metadata(df::DataFrame, df_func::Function, args...; kwargs...)
    # Save all column metadata
    saved_meta = df_save_metadata(df)
    # Perform function
    df_new = df_func(df, args...; kwargs...)
    # Restore metadata for remaining columns
    df_restore_metadata!(df_new, saved_meta)
    return nothing
end
function df_function_keeping_metadata(ef::EconFrame, df_func::Function, args...; kwargs...)
    # Save all column metadata
    saved_meta = df_save_metadata(ef)
    # Perform function
    ef_new = reconstruct(ef; data=df_func(ef.data, args...; kwargs...))
    # Restore metadata for remaining columns
    df_restore_metadata!(ef_new, saved_meta)
    return ef_new
end
function df_function_keeping_metadata!(df::DataFrame, df_func::Function, args...; kwargs...)
    # Save all column metadata
    saved_meta = df_save_metadata(df)
    # Perform function
    df_func(df, args...; kwargs...)
    # Restore metadata for remaining columns
    df_restore_metadata!(df, saved_meta)
    return nothing
end
function df_function_keeping_metadata!(ef::EconFrame, df_func::Function, args...; kwargs...)
    # Save all column metadata
    saved_meta = df_save_metadata(ef)
    # Perform function
    df_func(ef.data, args...; kwargs...)
    # Restore metadata for remaining columns
    df_restore_metadata!(ef, saved_meta)
    return nothing
end
# - Join helpers (save & restore metadata from both frames; left takes precedence)
function df_join_keeping_metadata(ef_L::EconFrame, right, join_func::Function, args...; kwargs...)
    saved_meta_L = df_save_metadata(ef_L)
    saved_meta_R = df_save_metadata(right)
    right_data = right isa EconFrame ? right.data : right
    result = reconstruct(ef_L; data=join_func(ef_L.data, right_data, args...; kwargs...))
    df_restore_metadata!(result, saved_meta_R)
    df_restore_metadata!(result, saved_meta_L)
    return result
end
function df_join_keeping_metadata!(ef_L::EconFrame, right, join_func::Function, args...; kwargs...)
    saved_meta_L = df_save_metadata(ef_L)
    saved_meta_R = df_save_metadata(right)
    right_data = right isa EconFrame ? right.data : right
    ef_L.data = join_func(ef_L.data, right_data, args...; kwargs...)
    df_restore_metadata!(ef_L, saved_meta_R)
    df_restore_metadata!(ef_L, saved_meta_L)
    return ef_L
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
    print(io, "$(nrow(ef)) observations, ")
    print(io, "$(ncol(ef.data))×$(nrow(ef.data)) DataFrame\n")
    show(io, ef.data)
end
function Base.show(io::IO, ef::EconPanel{Ds,Dl,Df}) where {Ds,Dl,Df}
    dates = get_dates(ef)
    ids = get_ids(ef)
    
    # Get date range
    date_range = if isempty(dates)
        "no dates"
    elseif length(dates) == 1
        "$(dates[1])"
    else
        "$(minimum(dates)) to $(maximum(dates))"
    end
    
    # Get panel info
    n_individuals = length(unique(ids))
    n_periods = length(unique(dates))
    
    # Get currency string
    curr_str = currency_string(ef.currency)
    
    # Print type with panel info
    print(io, "EconPanel{$(Ds.name.name), $(Dl.name.name), $(Df.name.name), $curr_str}(")
    print(io, "$(ef.source), $(ef.subject), $(ef.frequency), ")
    print(io, "dates: $date_range, ")
    print(io, "$n_individuals individuals, $n_periods periods, ")
    print(io, "currency: $curr_str, ")
    print(io, "$(nrow(ef)) observations, ")
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
    EconSet(efs::Dict{Symbol,<:EconFrame}) = EconSet(efs, SymmetricDict{Symbol, <:Any}())
    EconSet(efs::Dict{Symbol,<:EconFrame}, args...) = EconSet(efs, SymmetricDict(args...))
    EconSet(efs::Vector{<:EconFrame}, names::Vector{<:Symbol}, args...) = EconSet(Dict(names .=> efs), args...)
    EconSet(efs::Tuple, args...) = EconSet(Dict(efs), args...)
end

# Methods
Base.getindex(es::EconSet, key::Symbol) = es.efs[key]