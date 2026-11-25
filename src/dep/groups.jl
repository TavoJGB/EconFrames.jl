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
    
    # Assign bins: closed=:left → [a,b), use searchsortedlast+1; closed=:right → (a,b], use searchsortedfirst
    ef.data[!, bin_col] = if closed == :left
        [searchsortedlast(thresholds, val) + 1 for val in ef.data[!, col]]
    else
        [searchsortedfirst(thresholds, val) for val in ef.data[!, col]]
    end
    
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
# Returns: ["≤0", "1-1000", "1001-5000", "5001-10000", ">10000"]
```
"""
function create_bin_labels(thresholds::AbstractVector{<:Real}; closed::Symbol=:left)
    n = length(thresholds)
    n < 1 && throw(ArgumentError("Need at least one threshold"))
    
    if closed == :left
        # [a, b): lower included, upper excluded → display upper as (b-1)
        bin_labels = ["$(thresholds[i])-$(thresholds[i+1]-1)" for i in 1:n-1]
        pushfirst!(bin_labels, "<$(thresholds[1])")
        push!(bin_labels, "≥$(thresholds[end])")
    else  # :right
        # (a, b]: lower excluded, upper included → display lower as (a+1)
        bin_labels = ["$(thresholds[i]+1)-$(thresholds[i+1])" for i in 1:n-1]
        pushfirst!(bin_labels, "≤$(thresholds[1])")
        push!(bin_labels, ">$(thresholds[end])")
    end
    
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
                        range_labels::Bool=default_range_labels(thresholds),
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
- `range_labels`: Use interval labels (`"0-20"`, `"20-40"`, ...) instead of prefix labels.
    Defaults to `default_range_labels(thresholds)`.
- `bottom_label`, `middle_label`, `top_label`: Prefixes for group labels when `range_labels=false` (defaults: "B", "M", "T")

# Details
Creates two new columns:
- Continuous rank in [0, 1] representing weighted percentile
- Categorical group label ("0-50", "50-90", "90-100", etc.)

Ranks are computed within each group defined by `by` columns.

# Examples
```julia
psid = read_data(PSID())

# Wealth groups: bottom 50%, middle 40%, top 10%
assign_quantiles!(psid, :wealth, [0.5, 0.9])

# Quintiles as ranges
assign_quantiles!(psid, :wealth, [0.2, 0.4, 0.6, 0.8])

# Within year and age group
assign_groups!(psid, :age, 25:10:65)
assign_quantiles!(psid, :wealth, [0.5, 0.9]; by=[:year, :age_group])
# With custom weight column
assign_quantiles!(psid, :income, [0.9]; weight_col=:person_weight)

# Custom labels
assign_quantiles!(psid, :wealth, [0.5, 0.9]; 
            range_labels=false,
            bottom_label="Bottom", middle_label="Middle", top_label="Top")
```
"""
function assign_quantiles!( ef::EconFrame, col::Symbol, thresholds::AbstractVector{<:Real};
                            by::Union{Symbol,Vector{Symbol},Nothing}=nothing,
                            col_name::String=string(col),
                            rank_col=col_name*"_rank",
                            group_col=col_name*"_quant",
                            range_labels::Bool=default_range_labels(thresholds),
                            bottom_label::String="B", 
                            middle_label::String="M", 
                            top_label::String="T")
    # Validate column exists
    col in propertynames(ef.data) || throw(ArgumentError("Column $col not found in EconFrame"))
    
    # Create quantile labels
    quantile_labels = create_quantile_labels(
        thresholds;
        range_labels,
        bottom_label,
        middle_label,
        top_label
    )
    
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
    default_range_labels(thresholds::AbstractVector{<:Real}) -> Bool

Choose default quantile label style based on number of quantile groups.

Returns `true` (range labels) when there are more than 3 groups,
and `false` (prefix labels) otherwise.
"""
function default_range_labels(thresholds::AbstractVector{<:Real})
    n_quants = length(thresholds) + 1
    return n_quants > 3
end

"""
    create_quantile_labels(thresholds::AbstractVector{<:Real}; 
                          range_labels::Bool=default_range_labels(thresholds),
                          bottom_label::String="B", middle_label::String="M", 
                          top_label::String="T") -> Vector{String}

Create quantile group labels from threshold values.

# Arguments
- `thresholds`: Vector of quantile thresholds (e.g., [0.5, 0.9] for bottom 50%, middle 40%, top 10%)
- `range_labels`: Use interval labels (`"0-50"`, `"50-90"`, `"90-100"`).
    Defaults to `default_range_labels(thresholds)`.
- `bottom_label`: Prefix for bottom group when `range_labels=false` (default: "B")
- `middle_label`: Prefix for middle groups when `range_labels=false` (default: "M")
- `top_label`: Prefix for top group when `range_labels=false` (default: "T")

# Returns
Vector of group labels, e.g., ["0-50", "50-90", "90-100"]

# Examples
```julia
create_quantile_labels([0.5, 0.9])
# Returns: ["B50", "M40", "T10"]

create_quantile_labels([0.9])
# Returns: ["B90", "T10"]

create_quantile_labels([0.2, 0.4, 0.6, 0.8])
# Returns: ["0-20", "20-40", "40-60", "60-80", "80-100"]

create_quantile_labels([0.5, 0.9]; range_labels=false,
                      bottom_label="Bottom", middle_label="Middle", top_label="Top")
# Returns: ["Bottom50", "Middle40", "Top10"]
```
"""
function create_quantile_labels(thresholds::AbstractVector{<:Real}; 
                               range_labels::Bool=default_range_labels(thresholds),
                               bottom_label::String="B", 
                               middle_label::String="M", 
                               top_label::String="T")
    n = length(thresholds)
    n < 1 && throw(ArgumentError("Need at least one threshold"))
    
    # Convert to percentages
    pcts = [Int(round(t * 100)) for t in thresholds]
    
    labels = String[]

    if range_labels
        edges = vcat(0, pcts, 100)
        return ["$(edges[i])-$(edges[i+1])" for i in 1:(length(edges)-1)]
    end
    
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
