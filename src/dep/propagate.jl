#==========================================================================
    PROPAGATE
    Distribute from coarse to fine level (e.g., household → individual)
==========================================================================#

"""
    propagate(es::EconSet, target::Symbol, source::Symbol, vars::Union{Symbol, Pair{Symbol,Symbol}}...;
              by::Union{Symbol,Vector{Symbol}}=nothing)

Propagate variables from a coarser level (source) to a finer level (target).

# Arguments
- `es`: EconSet containing both source and target EconFrames
- `target`: Key for the target (finer) EconFrame in the EconSet
- `source`: Key for the source (coarser) EconFrame in the EconSet
- `vars`: Variables to propagate. Can be:
  - Symbol: propagate with same name
  - Pair{Symbol,Symbol}: propagate with rename (source_var => target_var)
- `by`: Linking variable (default: uses `es.cross_id[target, source]`)

# Examples
```julia
# Create EconSet
es = EconSet(
    Dict(:ii => ef_individual, :hh => ef_household),
    (:ii, :hh) => :household_id
)

# Propagate household variables to individuals
propagate(es, :ii, :hh,
    :wealth,              # Same name
    :house_value,         # Same name
    :income => :hh_income # Rename
)
```
"""
function propagate(
    es::EconSet, target::Symbol, source::Symbol, vars::Union{Symbol, Pair{Symbol,Symbol}}...;
    by::Union{Symbol,Vector{Symbol}}=es.cross_id[target, source]
)
    
    # Get source and target frames  
    ef_source = es.efs[source]
    ef_target = deepcopy(es.efs[target])
    
    # Process variable specifications
    source_vars = Symbol[]
    rename_map = Dict{Symbol,Symbol}()
    
    for var_spec in vars
        if var_spec isa Symbol
            push!(source_vars, var_spec)
            rename_map[var_spec] = var_spec
        else  # Pair
            source_var, target_var = var_spec
            push!(source_vars, source_var)
            rename_map[source_var] = target_var
        end
    end
    
    # Select relevant columns from source
    cols_to_join = [link_var; source_vars]
    df_to_propagate = ef_source.data[!, cols_to_join]
    
    # Rename if needed
    if any(k != v for (k, v) in rename_map)
        df_to_propagate = rename(df_to_propagate, rename_map...)
    end
    
    # Join to target frame
    ef_target = leftjoin(ef_target, df_to_propagate; on=link_var, makeunique=true)
    
    return nothing
end