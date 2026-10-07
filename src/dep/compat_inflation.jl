#==========================================================================
    HANDLING INFLATION: EconFrame methods - Helper functions
==========================================================================#

"""
    match_variable_to_cpi(ef::EconFrame, var::Symbol, cpi_dict::Dict, anygood_cpi)

Find the matching CPI for a given variable based on its good_type metadata.
"""
function match_variable_to_cpi(ef::EconFrame, var::String, cpi_dict::Dict, anygood_cpi)
    # Get good type for this variable
    var_good_type = if "good_type" in colmetadatakeys(ef.data, var)
        colmetadata(ef.data, var, "good_type")
    else
        AnyGood()
    end
    
    # Find matching CPI
    if haskey(cpi_dict, var_good_type)
        return cpi_dict[var_good_type]
    elseif !isnothing(anygood_cpi)
        return anygood_cpi
    else
        return nothing
    end
end

"""
    variable_currency(ef::EconFrame, var::String)

Return the currency associated with a monetary variable. Falls back to frame currency
when per-column currency metadata is not available.
"""
function variable_currency(ef::EconFrame, var::String)
    return if "currency" in colmetadatakeys(ef.data, var)
        colmetadata(ef.data, var, "currency")
    else
        currency(ef)
    end
end

"""
    price_conversion!(ef::EconFrame, cpis::AbstractVector{<:CPI}, 
                      conversion_fn::Function, args...; 
                      check_currency::Function, 
                      update_currency::Function,
                      operation_name::String)

Generic function to apply inflation conversions to all monetary variables in an EconFrame.

# Arguments
- `ef`: EconFrame to modify
- `cpis`: Vector of CPIs for different good types
- `conversion_vars`: Vector of monetary variables to convert
- `conversion_fn`: Function to apply to each variable (e.g., to_real, to_nominal, rebase)
- `args...`: Additional arguments to pass to conversion_fn
- `operation_name`: Name of operation for warning messages
- `kwargs...`: Additional keyword arguments to pass to `conversion_fn`
"""
function price_conversion!(
    ef::EconFrame, cpis::AbstractVector{<:CPI},
    conversion_vars::AbstractVector, conversion_fn::Function, args...;
    operation_name::String, kwargs...
)
    
    # Validate CPIs
    validate_cpis_unique(cpis)
    
    # Build CPI dictionary
    cpi_dict, anygood_cpi = build_cpi_dict(cpis)
    
    # Preliminaries
    all_mon_vars = list_monetary_variables(ef)
    unconverted_vars = String[]
    
    # Save column metadata (can be lost during broadcast assignment)
    saved_meta = df_save_metadata(ef)
    
    # Convert each monetary variable
    for var in conversion_vars
        matching_cpi = match_variable_to_cpi(ef, var, cpi_dict, anygood_cpi)
        
        if !isnothing(matching_cpi)
            converted = conversion_fn(getproperty(ef, Symbol(var)), matching_cpi, args...; kwargs...)
            setproperty!(ef, Symbol(var), converted)
        else
            push!(unconverted_vars, var)
        end
    end
    
    # Warnings and update currency
    if length(unconverted_vars) == length(conversion_vars)
        @warn("No monetary variables were converted in $operation_name.")
    else
        !isempty(unconverted_vars) && @warn("The following variables were not converted in $operation_name (no matching CPI found): $(unconverted_vars)")
    end
    
    # Restore column metadata (may have been lost during broadcast assignment)
    df_restore_metadata!(ef, saved_meta)
    
    return nothing
end



#==========================================================================
    HELPER FUNCTIONS: type of monetary column
==========================================================================#

is_nominal_col(ef::EconFrame, col::Union{Symbol, String}) = colmetadata(ef, col)["currency"] isa NominalCurrency
is_real_col(ef::EconFrame, col::Union{Symbol, String}) = colmetadata(ef, col)["currency"] isa RealCurrency



#==========================================================================
    HANDLING INFLATION: EconFrame methods
==========================================================================#

"""
    to_real!(ef::EconFrame, cpi::CPI, new_base_date; do_warn::Bool=true)
    to_real!(ef::EconFrame, cpis::AbstractVector{<:CPI}, new_base_date; do_warn::Bool=true)

Convert nominal monetary variables in an EconFrame to real values.

# Arguments
- `ef`: EconFrame with monetary variables
- `cpi` or `cpis`: Single CPI or vector of CPIs for different good types
- `new_base_date`: Base date for real values (e.g., 2007)
- `do_warn`: Whether to display warnings when the type of good does not match with the available CPIs

# Behavior with multiple CPIs
When providing multiple CPIs:
1. Each CPI must have a unique good type (no duplicates allowed)
2. Monetary variables are matched to CPIs by good type:
   - Variables with good type Tg are converted with CPI of type Tg
   - Variables without matching CPI are converted with AnyGood CPI (if available)
   - Variables without any matching CPI remain unconverted (warning issued)
3. Frame currency is updated to real currency with new base date

# Examples
```julia
# Single CPI for all variables
to_real!(psid, cpi_general, 2007)

# Multiple CPIs for different goods
to_real!(psid, [cpi_consumption, cpi_housing], 2007)
```
"""
to_real!(ef::EconFrame, cpi::CPI, new_base_date; do_warn::Bool=true)::Nothing = to_real!(ef, [cpi], new_base_date; do_warn)

function to_real!(ef::EconFrame, cpis::AbstractVector{<:CPI}, new_base_date; do_warn::Bool=true)::Nothing    
    dates = get_dates(ef)
    
    # Get nominal variables
    mon_vars = ef |> list_monetary_variables
    conversion_vars = mon_vars[[is_nominal_col(ef, col) for col in mon_vars]]

    # Warn about skipped variables
    skipped_vars = setdiff(mon_vars, conversion_vars)
    if !isempty(skipped_vars)
        @warn "The following monetary variables were skipped because they are not real: " * join(skipped_vars, ", ")
    end

    # Returns
    return price_conversion!(ef, cpis, conversion_vars, to_real, dates, new_base_date; operation_name = "to_real", do_warn)
end
"""
    to_nominal!(ef::EconFrame, cpi::CPI)
    to_nominal!(ef::EconFrame, cpis::AbstractVector{<:CPI})

Convert real monetary variables in an EconFrame back to nominal values.

# Arguments
- `ef`: EconFrame with monetary variables in real terms
- `cpi` or `cpis`: Single CPI or vector of CPIs for different good types
- `do_warn`: Whether to display warnings when the type of good does not match with the available CPIs (default: `true`)


# Behavior with multiple CPIs
When providing multiple CPIs:
1. Each CPI must have a unique good type (no duplicates allowed)
2. Monetary variables are matched to CPIs by good type
3. Variables without matching CPI use their stored pre-conversion currency (if available)
4. Frame currency is updated to nominal currency

# Examples
```julia
# Single CPI for all variables
to_nominal!(psid, cpi_general)

# Multiple CPIs for different goods
to_nominal!(psid, [cpi_consumption, cpi_housing])
```
"""
to_nominal!(ef::EconFrame, cpi::CPI; do_warn::Bool=true)::Nothing = to_nominal!(ef, [cpi]; do_warn)

function to_nominal!(ef::EconFrame, cpis::AbstractVector{<:CPI}; do_warn::Bool=true)::Nothing
    
    dates = get_dates(ef)

    # Get real variables
    mon_vars = ef |> list_monetary_variables
    conversion_vars = mon_vars[[is_real_col(ef, col) for col in mon_vars]]

    # Warn about skipped variables
    skipped_vars = setdiff(mon_vars, conversion_vars)
    if !isempty(skipped_vars)
        @warn "The following monetary variables were skipped because they are not real: " * join(skipped_vars, ", ")
    end
    
    return price_conversion!(ef, cpis, conversion_vars, to_nominal, dates; operation_name = "to_nominal", do_warn)
end
"""
    rebase!(ef::EconFrame, cpi::CPI, new_base_date)
    rebase!(ef::EconFrame, cpis::AbstractVector{<:CPI}, new_base_date)

Change the base date of real monetary variables in an EconFrame.

# Arguments
- `ef`: EconFrame with monetary variables in real terms
- `cpi` or `cpis`: Single CPI or vector of CPIs for different good types
- `new_base_date`: New base date for real values (e.g., 1992)
- `do_warn`: Whether to display warnings when the type of good does not match with the available CPIs (default: `true`)

# Behavior with multiple CPIs
When providing multiple CPIs:
1. Each CPI must have a unique good type (no duplicates allowed)
2. Monetary variables are matched to CPIs by good type
3. Variables without matching CPI remain unconverted (warning issued)
4. Frame currency is updated to real currency with new base date

# Examples
```julia
# Single CPI for all variables
rebase!(psid, cpi_general, 1992)

# Multiple CPIs for different goods
rebase!(psid, [cpi_consumption, cpi_housing], 1992)
```
"""
rebase!(ef::EconFrame, cpi::CPI, new_base_date; do_warn::Bool=true)::Nothing = rebase!(ef, [cpi], new_base_date; do_warn)

function rebase!(ef::EconFrame, cpis::AbstractVector{<:CPI}, new_base_date; do_warn::Bool=true)::Nothing
    
    # Get real variables
    mon_vars = ef |> list_monetary_variables
    conversion_vars = mon_vars[[is_real_col(ef, col) for col in mon_vars]]

    # Warn about skipped variables
    skipped_vars = setdiff(mon_vars, conversion_vars)
    if !isempty(skipped_vars)
        @warn "The following monetary variables were skipped because they are not real: " * join(skipped_vars, ", ")
    end

    return price_conversion!(ef, cpis, conversion_vars, rebase, new_base_date; operation_name = "rebase", do_warn)
end