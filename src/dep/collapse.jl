#==========================================================================
    COLLAPSE
    Aggregate from fine to coarse level (e.g., individual → household)
==========================================================================#

"""
    collapse(es::EconSet, target::Symbol, source::Symbol, ops...; 
             by::Union{Symbol,Nothing}=nothing)

Collapse data from a finer level (source) to a coarser level (target) by aggregating variables.

Uses standard DataFrames.jl `combine` syntax for aggregation operations, with automatic weight 
injection for weighted functions.

# Arguments
- `es`: EconSet containing both source and target EconFrames
- `target`: Key for the target (coarser) EconFrame in the EconSet
- `source`: Key for the source (finer) EconFrame in the EconSet  
- `ops`: Aggregation operations in DataFrames.jl syntax (see examples)
- `by`: Linking variable (default: uses `es.cross_id[target, source]`)

# Simplified syntax for common aggregations
You can specify common aggregations using simple `Symbol => Function` pairs:
- `:var => sum` : Sum of `var`
- `:var => only_head` → Takes value from reference person (requires `:head` column)
- weighted functions (see below)

# Automatic Weight Injection
These functions automatically receive weights from the source EconFrame:
- `weighted_mean` → `(x, w) -> weighted_mean(x, w)`
- `weighted_sum` → `(x, w) -> weighted_sum(x, w)`

# Examples
```julia
# Create EconSet with individual and household data
es = EconSet(
    Dict(:ii => ef_individual, :hh => ef_household),
    (:ii, :hh) => :household_id
)

# Simple aggregations
collapse(es, :hh, :ii,
    :age => first,                          # First value (head)
    :income => sum,                         # Total
    :education => maximum                   # Max
)

# Automatic weight injection
collapse(es, :hh, :ii,
    :income => weighted_mean,               # Automatically uses weights
    :wealth => weighted_sum                 # Automatically uses weights
)

# Multi-column operations (manual)
collapse(es, :hh, :ii,
    [:wealth, :weight] => ((w, wgt) -> sum(w .* wgt) / sum(wgt)) => :mean_wealth,
    [:income, :weight] => ((inc, wgt) -> weighted_mean(inc, wgt; skipmissing=true)) => :mean_income
)

# Using only_head helper (requires :head column in source)
collapse(es, :hh, :ii,
    :age => only_head,
    :income => sum
)
```
"""
function collapse(
    es::EconSet, target::Symbol, source::Symbol, ops...;
    by::Union{Symbol,Vector{Symbol},Nothing}=es.cross_id[target, source]
)::EconFrame    
    # Get source and target frames
    ef_source = es.efs[source]
    ef_target = deepcopy(es.efs[target])
    
    # Get weight column name
    @unpack weight_var = ef_source;
    
    # Functions that need automatic weight injection
    weighted_funcs = Dict(
        weighted_mean => (var) -> [var, weight_var] => ((x, w) -> weighted_mean(x, w)) => var,
        weighted_sum => (var) -> [var, weight_var] => ((x, w) -> weighted_sum(x, w)) => var,
    )
    
    # Process operations
    processed_ops = []
    for op in ops
        if op isa Pair{Symbol, <:Function}
            var, func = op.first, op.second
            
            if func == only_head
                # Special: only_head
                push!(processed_ops, [var, :head] => ((x,h) -> only(x[h])) => var)
            elseif haskey(weighted_funcs, func)
                # Automatic weight injection
                push!(processed_ops, weighted_funcs[func](var))
            else
                # Pass through as-is
                push!(processed_ops, op)
            end
        else
            # Pass through complex operations as-is
            push!(processed_ops, op)
        end
    end
    
    # Group by linking variable and aggregate
    gdf = groupby(ef_source, by)
    df_collapsed = DataFrames.combine(gdf, processed_ops...)
    
    # Merge collapsed data into target frame    
    return leftjoin(ef_target, df_collapsed; on=by, makeunique=true)
end



#==========================================================================
    COMBINE FUNCTIONS
    Helper functions for common aggregations
==========================================================================#

"""
    only_head

Special marker function for collapse(). Takes the value from the reference person (head).
Requires the source EconFrame to have a boolean `:head` column.

# Example
```julia
collapse(es, :hh, :ii,
    :age => only_head,      # Head's age
    :education => only_head # Head's education
)
```
"""
only_head(x) = error("only_head is a marker function - use it only within collapse()")