#==========================================================================
    BINNING / GROUPING
==========================================================================#

"""
    assign_groups!(
        ef::EconFrame, col::Symbol, thresholds::AbstractVector{<:Real};
        bin_col::Symbol=Symbol(string(col)*"_bin"),
        group_col::Symbol=Symbol(string(col)*"_group"),
        closed::Symbol=:left
    )

Add bin index and group label columns to an EconFrame based on threshold values.

# Arguments
- `ef`: EconFrame to modify
- `col`: Column name containing numeric values to bin
- `thresholds`: Vector of threshold values (can be created with `range` or vector literal)
- `bin_col`: Name for the numeric bin column (default: `<col>_bin`)
- `group_col`: Name for the categorical group column (default: `<col>_group`)
- `closed`: Which side of intervals is closed (`:left` or `:right`, default: `:left`)

# Details
Creates two new columns:
- Numeric bin index (1 = below min threshold, 2 = first bin, ..., n+1 = above max threshold)
- Categorical group label ("<25", "25-34", etc.)

With `closed=:left` (default), bins are `[a, b)` (includes a, excludes b).
With `closed=:right`, bins are `(a, b]` (excludes a, includes b).

# Examples
```julia
# Age groups (25-65 by 10s)
psid = read_data(PSID())
assign_groups!(psid, :age, 25:10:65)

# Wealth groups with irregular bins
assign_groups!(psid, :wealth, [0, 1000, 5000, 25000, 100000])

# Custom column names
assign_groups!(psid, :age, 20:5:70; bin_col=:age_bin, group_col=:age_gr)
```
"""
function assign_groups!(
    ef::EconFrame, col::Symbol, thresholds::AbstractVector{<:Real};
    bin_col::Symbol=Symbol(string(col)*"_bin"),
    group_col::Symbol=Symbol(string(col)*"_group"),
    closed::Symbol=:left
)
    # Validate column exists
    col in propertynames(ef.data) || throw(ArgumentError("Column $col not found in EconFrame"))
    
    # Create bin labels
    bin_labels = create_bin_labels(thresholds; closed)
    
    # Assign bins using searchsortedfirst
    ef.data[!, bin_col] = [searchsortedfirst(thresholds, val) for val in ef.data[!, col]]
    
    # Assign group labels
    ef.data[!, group_col] = [bin_labels[bin] for bin in ef.data[!, bin_col]]
    
    return nothing
end



#==========================================================================
    BIN LABELS
==========================================================================#

"""
    create_bin_labels(thresholds::AbstractVector{<:Real}; closed::Symbol=:left) -> Vector{String}

Create bin labels from a vector of thresholds.

# Arguments
- `thresholds`: Vector of threshold values defining bin edges
- `closed`: Which side of the interval is closed (`:left` or `:right`, default: `:left`)

# Returns
Vector of bin labels, e.g., ["<25", "25-34", "35-44", ..., "≥65"]

# Examples
```julia
create_bin_labels([25, 35, 45, 55, 65])
# Returns: ["<25", "25-34", "35-44", "45-54", "55-64", "≥65"]

create_bin_labels([0, 1000, 5000, 10000]; closed=:right)
# Returns: ["<0", "0-999", "1000-4999", "5000-9999", "≥10000"]
```
"""
function create_bin_labels(thresholds::AbstractVector{<:Real}; closed::Symbol=:left)
    n = length(thresholds)
    n < 1 && throw(ArgumentError("Need at least one threshold"))
    
    # Adjustment for closed interval
    adj = closed == :left ? -1 : 0
    
    # Create middle groups
    bin_labels = ["$(thresholds[i])-$(thresholds[i+1]+adj)" for i in 1:n-1]
    
    # Add lower bound
    pushfirst!(bin_labels, "<$(thresholds[1])")
    
    # Add upper bound
    push!(bin_labels, "≥$(thresholds[end])")
    
    return bin_labels
end



#==========================================================================
    RANKS
==========================================================================#

function get_rank(
    values::AbstractVector{<:Real}, weights::AbstractVector{<:Real};
    position::Symbol=:right # :left starts from 0, :center places each rank in middle of weight interval, :right starts from weight and ends at 1
)
    length(values) == length(weights) || throw(ArgumentError("values and weights must have same length"))
    
    # Sort by values
    perm = sortperm(values)
    sorted_weights = weights[perm]
    
    # Calculate cumulative weights
    total_weight = sum(sorted_weights)
    cumsum_weights = cumsum(sorted_weights)
    
    # Rank = cumulative weight up to current observation / total weight
    if position == :left
        sorted_ranks = @. (cumsum_weights - sorted_weights) / total_weight
    elseif position == :center
        sorted_ranks = @. (cumsum_weights - sorted_weights / 2) / total_weight
    else # :right
        sorted_ranks = @. cumsum_weights / total_weight
    end

    # Unsort to match original order
    ranks = similar(sorted_ranks)
    ranks[perm] = sorted_ranks
    
    return ranks
end



#==========================================================================
    QUANTILES
==========================================================================#

"""
    assign_quantiles!(  ef::EconFrame, col::Symbol, thresholds::AbstractVector{<:Real};
                        by::Union{Symbol,Vector{Symbol},Nothing}=nothing,
                        weight_col::Union{Symbol,Nothing}=nothing,
                        rank_col::Symbol=Symbol(string(col)*"_rank"),
                        group_col::Symbol=Symbol(string(col)*"_group"),
                        bottom_label::String="B", middle_label::String="M", top_label::String="T")

Add quantile rank and group columns to an EconFrame based on a variable's distribution.

# Arguments
- `ef`: EconFrame to modify
- `col`: Column name to compute quantiles for
- `thresholds`: Vector of quantile thresholds (e.g., [0.5, 0.9] for bottom 50%, middle 40%, top 10%)
- `by`: Column(s) to group by before computing quantiles (e.g., :year, [:year, :age_group])
- `weight_col`: Column name for weights (default: uses :weight if available, uniform weights otherwise)
- `rank_col`: Name for the rank column (default: `<col>_rank`)
- `group_col`: Name for the group column (default: `<col>_group`)
- `bottom_label`, `middle_label`, `top_label`: Prefixes for group labels (defaults: "B", "M", "T")

# Details
Creates two new columns:
- Continuous rank in [0, 1] representing weighted percentile
- Categorical group label ("B50", "M40", "T10", etc.)

Ranks are computed within each group defined by `by` columns.

# Examples
```julia
psid = read_data(PSID())

# Wealth groups: bottom 50%, middle 40%, top 10%
assign_quantiles!(psid, :wealth, [0.5, 0.9])

# Within year and age group
assign_groups!(psid, :age, 25:10:65)
assign_quantiles!(psid, :wealth, [0.5, 0.9]; by=[:year, :age_group])
# With custom weight column
assign_quantiles!(psid, :income, [0.9]; weight_col=:person_weight)

# Custom labels
assign_quantiles!(psid, :wealth, [0.5, 0.9]; 
                    bottom_label="Bottom", middle_label="Middle", top_label="Top")
```
"""
function assign_quantiles!( ef::EconFrame, col::Symbol, thresholds::AbstractVector{<:Real};
                            by::Union{Symbol,Vector{Symbol},Nothing}=nothing,
                            col_name::String=string(col),
                            rank_col=col_name*"_rank",
                            group_col=col_name*"_quant",
                            bottom_label::String="B", 
                            middle_label::String="M", 
                            top_label::String="T")
    # Validate column exists
    col in propertynames(ef.data) || throw(ArgumentError("Column $col not found in EconFrame"))
    
    # Create quantile labels
    quantile_labels = create_quantile_labels(thresholds; bottom_label, middle_label, top_label)
    
    # Compute ranks
    if isnothing(by)
        # Global ranking
        weights = ef |> get_weights
        ef.data[!, rank_col] = get_rank(ef.data[!, col], weights)
    else
        @unpack weight_var = ef;

        # Ranking within groups
        by_cols = by isa Symbol ? [by] : by
        
        # Initialize rank column
        ef.data[!, rank_col] = zeros(Float64, nrow(ef.data))
        
        # Group by and compute ranks
        gdf = groupby(ef.data, by_cols)
        
        for subdf in gdf
            # Get row indices for this group
            row_indices = DataFrames.parentindices(subdf)[1]
            
            # Compute weights for this group
            weights = isnothing(weight_var) ? ones(length(row_indices)) : collect(subdf[!, weight_var])
            
            # Compute and assign ranks
            ef.data[row_indices, rank_col] = get_rank(subdf[!, col], weights)
        end
    end
    
    # Assign groups based on ranks
    ef.data[!, group_col] = [quantile_labels[searchsortedfirst(thresholds, r)] for r in ef.data[!, rank_col]]
    
    return nothing
end



#==========================================================================
    QUANTILE LABELS
==========================================================================#

"""
    create_quantile_labels(thresholds::AbstractVector{<:Real}; 
                          bottom_label::String="B", middle_label::String="M", 
                          top_label::String="T") -> Vector{String}

Create quantile group labels from threshold values.

# Arguments
- `thresholds`: Vector of quantile thresholds (e.g., [0.5, 0.9] for bottom 50%, middle 40%, top 10%)
- `bottom_label`: Prefix for bottom group (default: "B")
- `middle_label`: Prefix for middle groups (default: "M")
- `top_label`: Prefix for top group (default: "T")

# Returns
Vector of group labels, e.g., ["B50", "M40", "T10"]

# Examples
```julia
create_quantile_labels([0.5, 0.9])
# Returns: ["B50", "M40", "T10"]

create_quantile_labels([0.9])
# Returns: ["B90", "T10"]

create_quantile_labels([0.5, 0.9]; bottom_label="Bottom", middle_label="Middle", top_label="Top")
# Returns: ["Bottom50", "Middle40", "Top10"]
```
"""
function create_quantile_labels(thresholds::AbstractVector{<:Real}; 
                               bottom_label::String="B", 
                               middle_label::String="M", 
                               top_label::String="T")
    n = length(thresholds)
    n < 1 && throw(ArgumentError("Need at least one threshold"))
    
    # Convert to percentages
    pcts = [Int(round(t * 100)) for t in thresholds]
    
    labels = String[]
    
    if n == 1
        # Two groups: bottom and top
        push!(labels, "$(bottom_label)$(pcts[1])")
        push!(labels, "$(top_label)$(100 - pcts[1])")
    else
        # Three or more groups: bottom, middle(s), top
        push!(labels, "$(bottom_label)$(pcts[1])")
        
        for i in 1:(n-1)
            pct_size = pcts[i+1] - pcts[i]
            push!(labels, "$(middle_label)$(pct_size)")
        end
        
        push!(labels, "$(top_label)$(100 - pcts[end])")
    end
    
    return labels
end



#==========================================================================
    DATAFRAMES METHODS
==========================================================================#

# groupby
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

# combine
"""
    combine(ef::EconFrame, groupcols, args...; kwargs...)

Group by `groupcols` and combine, returning a new DataFrame.

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
    gdf = groupby(ef.data, groupcols; skipmissing=true)
    if skip_basic
        df_combined = combine(gdf, args...; kwargs...)
    else
        basic_fs = (
            :weight => length => :N,
            :weight => sum => :weight
        )
        df_combined = combine(gdf, basic_fs..., args...; kwargs...)
    end
    return reconstruct(ef; data=df_combined)
end

# transform!
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
function DataFrames.transform!(ef::EconFrame, groupcols, args...; kwargs...)
    # Save metadata
    saved_meta = df_save_metadata(ef)
    
    # Perform grouped transformation
    gdf = groupby(ef.data, groupcols)
    transform!(gdf, args...; kwargs...)
    ef.N = nrow(ef.data)
    
    # Restore metadata for all columns (including new ones)
    df_restore_metadata!(ef, saved_meta)
    
    return ef
end