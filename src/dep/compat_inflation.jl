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
    price_conversion!(ef::EconFrame, cpis::AbstractVector{<:CPI}, 
                      conversion_fn::Function, args...; 
                      check_currency::Function, 
                      update_currency::Function,
                      operation_name::String)

Generic function to apply inflation conversions to all monetary variables in an EconFrame.

# Arguments
- `ef`: EconFrame to modify
- `cpis`: Vector of CPIs for different good types
- `conversion_fn`: Function to apply to each variable (e.g., to_real, to_nominal, rebase)
- `args...`: Additional arguments to pass to conversion_fn
- `new_currency`: The new currency to set after conversion
- `operation_name`: Name of operation for warning messages
"""
function price_conversion!(
    ef::EconFrame, cpis::AbstractVector{<:CPI}, conversion_fn::Function, args...;
    new_currency::Currency,
    operation_name::String
)
    
    # Validate CPIs
    validate_cpis_unique(cpis)
    
    # Build CPI dictionary
    cpi_dict, anygood_cpi = build_cpi_dict(cpis)
    
    # Get all monetary variables
    all_mon_vars = list_monetary_variables(ef)
    unconverted_vars = String[]
    
    # Convert each monetary variable
    for var in all_mon_vars
        matching_cpi = match_variable_to_cpi(ef, var, cpi_dict, anygood_cpi)
        
        if !isnothing(matching_cpi)
            ef[!, var] .= conversion_fn(ef[!, var], matching_cpi, args...)
        else
            push!(unconverted_vars, var)
            # Store pre-conversion currency in metadata (only for to_real)
            if operation_name == "to_real"
                colmetadata!(ef.data, var, "currency", currency(ef))
            end
        end
    end
    
    # Warnings and update currency
    if length(unconverted_vars) == length(all_mon_vars)
        @warn("No monetary variables were converted in $operation_name.")
    else
        !isempty(unconverted_vars) && @warn("The following variables were not converted in $operation_name (no matching CPI found): $(unconverted_vars)")
        ef.currency = new_currency
    end
    
    return nothing
end

#==========================================================================
    HANDLING INFLATION: EconFrame methods
==========================================================================#

"""
    to_real!(ef::EconFrame, cpi::CPI, new_base_date)
    to_real!(ef::EconFrame, cpis::AbstractVector{<:CPI}, new_base_date)

Convert nominal monetary variables in an EconFrame to real values.

# Arguments
- `ef`: EconFrame with monetary variables
- `cpi` or `cpis`: Single CPI or vector of CPIs for different good types
- `new_base_date`: Base date for real values (e.g., 2007)

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
to_real!(ef::EconFrame, cpi::CPI, new_base_date)::Nothing = to_real!(ef, [cpi], new_base_date)

function to_real!(ef::EconFrame, cpis::AbstractVector{<:CPI}, new_base_date)::Nothing
    # Check currency validity
    curr = currency(ef)
    if curr isa RealCurrency
        @warn("EconFrame is already in real terms. No conversion applied.")
        return nothing
    end
    
    # Calculate new currency
    new_currency = real_currency(curr, new_base_date)
    dates = get_dates(ef)
    
    return price_conversion!(
        ef, cpis, to_real, dates, new_base_date;
        new_currency, operation_name = "to_real"
    )
end
"""
    to_nominal!(ef::EconFrame, cpi::CPI)
    to_nominal!(ef::EconFrame, cpis::AbstractVector{<:CPI})

Convert real monetary variables in an EconFrame back to nominal values.

# Arguments
- `ef`: EconFrame with monetary variables in real terms
- `cpi` or `cpis`: Single CPI or vector of CPIs for different good types

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
to_nominal!(ef::EconFrame, cpi::CPI)::Nothing = to_nominal!(ef, [cpi])

function to_nominal!(ef::EconFrame, cpis::AbstractVector{<:CPI})::Nothing
    # Check currency validity
    curr = currency(ef)
    if !(curr isa RealCurrency)
        @warn("EconFrame is not in real terms. No conversion applied.")
        return nothing
    end
    
    # Calculate new currency
    new_currency = nominal_currency(curr)
    dates = get_dates(ef)
    base = base_date(curr)
    
    return price_conversion!(
        ef, cpis,
        (var, cpi, dates) -> to_nominal(var, cpi, base, dates),
        dates;
        new_currency, operation_name = "to_nominal"
    )
end
"""
    rebase!(ef::EconFrame, cpi::CPI, new_base_date)
    rebase!(ef::EconFrame, cpis::AbstractVector{<:CPI}, new_base_date)

Change the base date of real monetary variables in an EconFrame.

# Arguments
- `ef`: EconFrame with monetary variables in real terms
- `cpi` or `cpis`: Single CPI or vector of CPIs for different good types
- `new_base_date`: New base date for real values (e.g., 1992)

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
rebase!(ef::EconFrame, cpi::CPI, new_base_date)::Nothing = rebase!(ef, [cpi], new_base_date)

function rebase!(ef::EconFrame, cpis::AbstractVector{<:CPI}, new_base_date)::Nothing
    # Check currency validity
    curr = currency(ef)
    if !(curr isa RealCurrency)
        @warn("EconFrame is not in real terms. Cannot rebase nominal values.")
        return nothing
    end
    
    # Calculate new currency
    current_base_date = base_date(curr)
    new_currency = real_currency(curr, new_base_date)
    
    return price_conversion!(
        ef, cpis, rebase, current_base_date, new_base_date;
        new_currency, operation_name = "rebase"
    )
end