#==========================================================================
    GROUPBY METHODS
==========================================================================#

"""
    groupby(ef::EconFrame, cols; kwargs...)

Group an EconFrame by specified columns, returning a GroupedDataFrame.

This is a convenience wrapper around DataFrames.groupby that operates on the underlying DataFrame.
Use with combine, transform, transform!, or select for split-apply-combine operations.

# Examples
```julia
# Pattern 1: Standard DataFrames.jl workflow
gdf = groupby(psid, :year)
combine(gdf, :wealth => mean)

# Pattern 2: Direct methods on EconFrame (preserves metadata)
combine(psid, :year, :wealth => mean)
transform!(psid, :year, :wealth => (x -> x ./ mean(x)) => :wealth_normalized)
```
"""
DataFrames.groupby(ef::EconFrame, args...; kwargs...) = DataFrames.groupby(ef.data, args...; kwargs...)

# Normalize grouping columns to a vector for consistent internal handling.
_groupcols_vec(groupcols::AbstractVector) = collect(groupcols)
_groupcols_vec(groupcols::Tuple) = collect(groupcols)
_groupcols_vec(groupcols) = [groupcols]

# Helper: return true when we should run the two-stage combine:
# first within imputation, then average across imputations.
function _use_two_stage_operation(groupcols, imputation_var)
    isnothing(imputation_var) && return false
    return !(Symbol(imputation_var) in Symbol.(_groupcols_vec(groupcols)))
end

# Add second-stage grouped operation (across imputations)
function _across_imputation_ops(df::DataFrame, groupcols, imputation_var)
    by_cols = Symbol.(_groupcols_vec(groupcols))
    excluded = Set(vcat(by_cols, [Symbol(imputation_var)]))
    value_cols = [c for c in Symbol.(names(df)) if !(c in excluded)]

    ops = Any[]
    for col in value_cols
        T = nonmissingtype(eltype(df[!, col]))
        if T <: Real
            push!(ops, col => mean => col)
        else
            @warn "Column $col is not of a numeric type; using first non-missing value instead"
            push!(ops, col => (x -> all(ismissing.(x)) ? missing : first(skipmissing(x))) => col)
        end
    end
    return ops
end

# Standard grouped combine (single stage)
function _combine_standard(
    data::DataFrame, groupcols, args...;
    weight_var, skip_basic::Bool=false, kwargs...
)
    gdf = groupby(data, _groupcols_vec(groupcols); skipmissing=true)
    skip_basic && return combine(gdf, args...; kwargs...)

    basic_fs = (
        weight_var => length => :N,
        weight_var => sum => :weight
    )
    return combine(gdf, basic_fs..., args...; kwargs...)
end

# Two-stage combine for multiple imputations:
# first within imputation, then average across imputations.
function _combine_with_imputation(data::DataFrame, groupcols, args...; imputation_var, kwargs...)
    groupcols_vec = _groupcols_vec(groupcols)

    # First stage
    df_stage1 = _combine_standard(data, [groupcols_vec..., imputation_var], args...; kwargs...)

    # Second stage: combine across imputations
    ops = _across_imputation_ops(df_stage1, groupcols_vec, imputation_var)
    return combine(groupby(df_stage1, groupcols_vec; skipmissing=true), ops...)
end



#==========================================================================
    COMBINE METHODS
==========================================================================#

"""
    combine(ef::EconFrame, groupcols, args...; kwargs...)

Group by `groupcols` and combine, returning a new EconFrame.

This is a convenience wrapper that combines groupby + combine in one call.
For more complex operations, use `groupby` explicitly.

# Examples
```julia
# Compute mean wealth by year
result = combine(psid, :year, :wealth => mean)

# Multiple aggregations
result = combine(psid, [:year, :age_group], 
                :wealth => mean => :mean_wealth,
                :income => median => :median_income)
```
"""
function DataFrames.combine(
    ef::EconFrame, groupcols, args...;
    skip_basic::Bool=false, kwargs...
)
    @unpack data, weight_var, imputation_var = ef;
    use_two_stage = _use_two_stage_operation(groupcols, imputation_var)
    df_combined = if use_two_stage
        _combine_with_imputation(
            data, groupcols, args...;
            weight_var, imputation_var, skip_basic, kwargs...
        )
    else
        _combine_standard(
            data, groupcols, args...;
            weight_var, skip_basic, kwargs...
        )
    end
    imputation_var_out = use_two_stage ? nothing : imputation_var
    return reconstruct(ef; data=df_combined, imputation_var=imputation_var_out)
end

"""
    combine(ef::EconPanel, groupcols, args...; kwargs...)

Group by `groupcols` and combine an EconPanel, returning an EconRepeatedCrossSection.

Combining a panel destroys the individual ID structure, so the result is converted
to an EconRepeatedCrossSection which preserves the time structure but not panel structure.

# Examples
```julia
# Returns EconRepeatedCrossSection
result = combine(psid, :year, :wealth => mean)
result = combine(psid, [:year, :age_group], :wealth => mean)
```
"""
function DataFrames.combine(
    ef::EconPanel, groupcols, args...;
    skip_basic::Bool=false, kwargs...
)
    @unpack data, weight_var, date_var, imputation_var = ef;
    use_two_stage = _use_two_stage_operation(groupcols, imputation_var)
    df_combined = if use_two_stage
        _combine_with_imputation(
            data, groupcols, args...;
            weight_var, imputation_var, skip_basic, kwargs...
        )
    else
        _combine_standard(
            data, groupcols, args...;
            weight_var, skip_basic, kwargs...
        )
    end
    imputation_var_out = use_two_stage ? nothing : imputation_var
    
    # Return EconRepeatedCrossSection (panel structure is lost after combine)
    return EconRepeatedCrossSection(
        df_combined, ef.source, ef.subject, ef.frequency, date_var;
        weight_var, imputation_var=imputation_var_out
    )
end



#==========================================================================
    TRANSFORM METHODS
==========================================================================#





#==========================================================================
    TRANSFORM! METHODS
==========================================================================#

function DataFrames.transform!(ef::EconFrame, arg::Union{Pair, Base.Callable}, args...; kwargs...)
    saved_meta = df_save_metadata(ef)
    transform!(ef.data, arg, args...; kwargs...)
    df_restore_metadata!(ef, saved_meta)
    return ef
end

"""
    transform!(ef::EconFrame, groupcols, args...; kwargs...)

Group by `groupcols`, transform in-place, and preserve column metadata.

This is a mutating operation that modifies the EconFrame's data while preserving
all column metadata (monetary variables, good types, etc.).

# Examples
```julia
# Normalize wealth within each year
transform!(psid, :year, :wealth => (x -> x ./ mean(x)) => :wealth_normalized)

# Add group means
transform!(psid, [:year, :age_group], 
          :wealth => mean => :group_mean_wealth)

# Multiple transformations
transform!(psid, :year,
          :wealth => mean => :mean_wealth,
          :income => std => :std_income)
```
"""
function DataFrames.transform!(
    ef::EconFrame,
    groupcols::Union{Symbol, AbstractString, AbstractVector{<:Union{Symbol, AbstractString}}, Tuple},
    args...; kwargs...
)
    # Save metadata
    saved_meta = df_save_metadata(ef)
    
    # Perform grouped transformation
    use_two_stage = _use_two_stage_operation(groupcols, ef.imputation_var)
    groupcols_vec = _groupcols_vec(groupcols)
    if use_two_stage
        gdf = groupby(ef.data, [groupcols_vec..., ef.imputation_var])
    else
        gdf = groupby(ef.data, groupcols_vec)
    end
    transform!(gdf, args...; kwargs...)
    
    # Restore metadata for all columns (including new ones)
    df_restore_metadata!(ef, saved_meta)
    
    return ef
end