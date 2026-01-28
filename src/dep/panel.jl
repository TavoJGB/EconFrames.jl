#==========================================================================
    PANEL-SPECIFIC METHODS
==========================================================================#

"""
    is_balanced(ef::EconPanel)

Check if the panel is balanced by verifying that all individuals have positive weight 
in all time periods (or in none of them).

# Arguments
- `ef`: EconPanel to check

# Returns
- `Bool`: true if balanced, false otherwise

# Examples
```julia
is_balanced(panel)  # true if all individuals have positive weight in all periods
```
"""
function is_balanced(ef::EconPanel)::Bool
    unique_dates = unique(ef.data[!, ef.date_var])
    unique_ids = unique(ef.data[!, ef.id_var])
    n_periods = length(unique_dates)
    
    # For each id, count how many periods have positive weight
    for id in unique_ids
        id_data = ef.data[ef.data[!, ef.id_var] .== id, :]
        n_positive_weight = sum(id_data[!, ef.weight_var] .> 0)
        
        # Individual must have positive weight in all periods or none
        if (n_positive_weight != 0) && (n_positive_weight != n_periods)
            return false
        end
    end
    
    return true
end

"""
    lag(ef::EconPanel, col::Symbol; n::Int=1)

Create a lagged variable by individual. The lagged values are computed within each 
individual (id_var), respecting the temporal order given by date_var.

# Arguments
- `ef`: EconPanel
- `col`: Column name to lag
- `n`: Number of periods to lag (default: 1)

# Returns
- `Vector`: Lagged values with missing for first n observations per individual

# Examples
```julia
ef.data[!, :income_lag] = lag(ef, :income)
ef.data[!, :income_lag2] = lag(ef, :income; n=2)
```
"""
function lag(ef::EconPanel, col::Symbol; n::Int=1)
    # Add row index to track original order
    data_with_index = copy(ef.data)
    data_with_index[!, :_original_row] = 1:nrow(data_with_index)
    
    # Sort by id and date
    sort!(data_with_index, [ef.id_var, ef.date_var])
    
    # Create lagged variable by group
    result = DataFrames.transform(
        groupby(data_with_index, ef.id_var),
        col => (x -> [fill(missing, n); x[1:end-n]]) => :_lagged
    )
    
    # Sort back to original order and extract lagged column
    sort!(result, :_original_row)
    return result[!, :_lagged]
end

"""
    lead(ef::EconPanel, col::Symbol; n::Int=1)

Create a leading (forward) variable by individual. The leading values are computed 
within each individual (id_var), respecting the temporal order given by date_var.

# Arguments
- `ef`: EconPanel
- `col`: Column name to lead
- `n`: Number of periods to lead forward (default: 1)

# Returns
- `Vector`: Leading values with missing for last n observations per individual

# Examples
```julia
ef.data[!, :income_lead] = lead(ef, :income)
ef.data[!, :income_lead2] = lead(ef, :income; n=2)
```
"""
function lead(ef::EconPanel, col::Symbol; n::Int=1)
    # Add row index to track original order
    data_with_index = copy(ef.data)
    data_with_index[!, :_original_row] = 1:nrow(data_with_index)
    
    # Sort by id and date
    sort!(data_with_index, [ef.id_var, ef.date_var])
    
    # Create leading variable by group
    result = DataFrames.transform(
        groupby(data_with_index, ef.id_var),
        col => (x -> [x[n+1:end]; fill(missing, n)]) => :_lead
    )
    
    # Sort back to original order and extract lead column
    sort!(result, :_original_row)
    return result[!, :_lead]
end