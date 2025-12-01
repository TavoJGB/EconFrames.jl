#==========================================================================
    CONSUMER PRICE INDEX
    Stores parallel vectors of dates and CPI values and provides helpers to
    look up indices/values by date.
==========================================================================#

struct CPI{Tg<:GoodType}
    dates::Vector{<:Date}
    values::Vector{Float64}
    # Constructors
    function CPI(dates::AbstractVector{<:Date}, vals::AbstractVector{<:Real}, ::Tg=AnyGood()) where {Tg<:GoodType}
        length(dates) == length(vals) || throw(ArgumentError("`dates` and `values` must have same length"))
        return new{Tg}(dates, vals)
    end
    CPI(dates::AbstractVector{<:Int}, args...) = CPI(Date.(dates), args...)
end

# Accesors
get_good_type(::CPI{Tg}) where {Tg<:GoodType} = Tg
get_good(cpi::CPI) = (get_good_type(cpi))()

"""cpi_index(cpi::CPI, date)

Return the 1-based index in `cpi.dates` corresponding to `date`, or `nothing`
if the date is not present.
"""
function cpi_index(cpi::CPI, date::Date)
    idx = findfirst(==(date), cpi.dates)
    @assert !isnothing(idx) "Base date $base_date not found in CPI"
    return cpi.values[idx]
end
cpi_index(cpi::CPI, date::AbstractVector{<:Date}) = [cpi_index(cpi, d) for d in date]
cpi_index(cpi::CPI, date) = cpi_index(cpi, Date.(date))

# Base methods
Base.getindex(cpi::CPI, i::Int) = cpi.values[i]
Base.length(cpi::CPI) = length(cpi.values)
Base.firstindex(cpi::CPI) = 1
Base.lastindex(cpi::CPI) = length(cpi.values)

# Compatibility methods
list_compatible_monetary_variables(ef, cpi::CPI{<:Tg}; kwargs...) where {Tg} = list_compatible_monetary_variables(ef, Tg(); kwargs...)
function assert_compatible(cpi::CPI, tg_ms::Tg_ms) where {Tg_ms<:GoodType}
    tg_cpi = get_good_type(cpi)
    tg_cpi isa AnyGood && return nothing    # AnyGood CPI is compatible with all
    if tg_ms isa AnyGood
        @warn("You are applying a CPI of type $(tg_cpi) to a good of type AnyGood, compatibility should be double-checked.")
    else
        @assert tg_cpi == Tg_ms "CPI is for goods of type $(tg_cpi), it cannot be applied on goods of type $(tg_ms)."
    end
    return nothing
end
assert_compatible(cpi::CPI, ms::MonetaryScalar) = assert_compatible(cpi, ms.good)
assert_compatible(ms::MonetaryScalar, cpi::CPI) = assert_compatible(cpi, ms.good)
assert_compatible(cpi::CPI, mv::MonetaryVariable) = assert_compatible(cpi, mv.good)
assert_compatible(mv::MonetaryVariable, cpi::CPI) = assert_compatible(cpi, mv.good)



#==========================================================================
    HANDLING INFLATION: basic methods
==========================================================================#

function to_real(v::AbstractVector{<:Real}, cpi::CPI, data_date, new_base_date::Date)
    # Preparation
    ref_cpi = cpi_index(cpi, new_base_date)
    current_cpi = cpi_index(cpi, data_date)
    # Deflate
    return @. v * current_cpi / ref_cpi
end
to_real(v::AbstractVector{<:Real}, cpi::CPI, data_date, new_base_date) = to_real(v, cpi, data_date, Date(new_base_date))

function to_nominal(v::AbstractVector{<:Real}, cpi::CPI, base_date::Date, data_dates::AbstractVector{Date})
    # Preparation
    current_cpi = cpi_index(cpi, base_date)
    nominal_cpi = cpi_index(cpi, data_dates)
    # Inflate
    return @. v * current_cpi / nominal_cpi
end
to_nominal(v::AbstractVector{<:Real}, cpi::CPI, base_date, data_dates::AbstractVector{Date}) = to_nominal(v, cpi, Date(base_date), data_dates)
to_nominal(v::AbstractVector{<:Real}, cpi::CPI, current_curr::RealCurrency, data_dates::AbstractVector{Date})=to_nominal(v, cpi, base_date(current_curr), data_dates)
function rebase(v::AbstractVector{<:Real}, cpi::CPI, current_base_date::Date, new_base_date::Date)
    # Preparation
    current_base_date==new_base_date && return v  # No change needed
    current_cpi = cpi_index(cpi, current_base_date)
    new_cpi = cpi_index(cpi, new_base_date)
    # Build nominal currency from real currency
    return @. v * new_cpi / current_cpi
end
rebase(v::AbstractVector{<:Real}, cpi::CPI, current_base_date, new_base_date) = rebase(v, cpi, Date(current_base_date), Date(new_base_date))



#==========================================================================
    HANDLING INFLATION: MonetaryScalar methods
==========================================================================#

"""
    to_real(s::MonetaryScalar{T,Tf,Ts}, cpi::CPI, data_date, new_base_date::Union{Int, Date}) where {T,Tf,Ts}

Convert nominal scalar to real value using a CPI index.

# Arguments
- `s`: MonetaryScalar with nominal value
- `cpi`: CPI object
- `data_date`: Date of the data
- `new_base_date`: The base date for real values (e.g., 1990)

# Returns
- MonetaryScalar with real value (base date = new_base_date)
"""
function to_real(
    s::MonetaryScalar{T,Tf,Ts}, cpi::CPI, data_date, new_base_date::Union{Int, Date}
) where {T,Tf,Ts}
    # Checks
    # - current currency is nominal
    current_curr = currency(s)
    current_curr isa NominalCurrency || throw(ArgumentError("MonetaryScalar must have NominalCurrency to convert to real"))
    # - compatibility
    assert_compatible(cpi, s)
    # Preparation
    rc = real_currency(current_curr, new_base_date)
    ref_cpi = cpi_index(cpi, new_base_date)
    current_cpi = cpi_index(cpi, data_date)
    # Deflate
    deflated = s.value * current_cpi / ref_cpi
    return MonetaryScalar(deflated, Tf(), Ts(), rc)
end

"""
    to_nominal(s::MonetaryScalar{T,Tf,Ts}, cpi::CPI, data_date::Union{Int,Date}) where {T,Tf,Ts}

Convert real scalar back to nominal value using a CPI index.

# Arguments
- `s`: MonetaryScalar with real value
- `cpi`: CPI object
- `data_date`: Date for which to compute the nominal value

# Returns
- MonetaryScalar with nominal value
"""
function to_nominal(s::MonetaryScalar{T,Tf,Ts}, cpi::CPI, data_date::Union{Int,Date}) where {T,Tf,Ts}
    # Checks
    # - current currency is real
    current_curr = currency(s)
    current_curr isa RealCurrency || throw(ArgumentError("MonetaryScalar must have RealCurrency to convert to nominal"))
    # - compatibility
    assert_compatible(cpi, s)
    # Preparation
    nc = nominal_currency(current_curr)
    base_cpi = cpi_index(cpi, base_date(current_curr))
    nominal_cpi = cpi_index(cpi, data_date)
    # Inflate
    inflated = s.value * base_cpi / nominal_cpi
    return MonetaryScalar(inflated, Tf(), Ts(), nc)
end

"""
    rebase(s::MonetaryScalar{T,Tf,Ts}, cpi::CPI, new_base_date::Union{Int, Date}) where {T,Tf,Ts}

Change the base date of a real scalar.

# Arguments
- `s`: MonetaryScalar with real value
- `cpi`: CPI object
- `new_base_date`: The new base date (e.g., 1992)

# Returns
- MonetaryScalar with real value in new base date
"""
function rebase(s::MonetaryScalar{T,Tf,Ts}, cpi::CPI, new_base_date::Union{Int, Date}) where {T,Tf,Ts}
    # Checks
    # - current currency is real
    current_curr = currency(s)
    current_curr isa RealCurrency || throw(ArgumentError("MonetaryScalar must have RealCurrency to rebase"))
    # - compatibility
    assert_compatible(cpi, s)
    # Preparation
    current_base = base_date(current_curr)
    current_base==new_base_date && return s  # No change needed
    # Build real currency with new base date
    rc = real_currency(current_curr, new_base_date)
    current_cpi = cpi_index(cpi, current_base)
    new_cpi = cpi_index(cpi, new_base_date)
    # Rebase
    rebased = s.value * new_cpi / current_cpi
    return MonetaryScalar(rebased, Tf(), Ts(), rc)
end



#==========================================================================
    HANDLING INFLATION: MonetaryVariable methods
==========================================================================#

"""
    to_real(v::MonetaryVariable{T,Tf,Ts}, cpi::CPI, data_date, new_base_date::Union{Int, Date}) where {T,Tf,Ts}

Convert nominal values to real values using a CPI index.

# Arguments
- `v`: MonetaryVariable with nominal values
- `cpi`: CPI object
- `data_date`: Date(s) of the data
- `new_base_date`: The base date for real values (e.g., 1990)

# Returns
- MonetaryVariable with real values (base date = new_base_date)

# Example
```julia
income_nominal = MonetaryVariable(rand(5), Annual(), Household(), NominalUSD())
cpi = CPI([1990, 1991, 1992, 1993, 1994], [100, 102, 105, 108, 110], ConsumptionGood())
income_real = to_real(income_nominal, cpi, [1990, 1991, 1992, 1993, 1994], 1990)
```
"""
function to_real(
    v::MonetaryVariable{T,Tf,Ts}, cpi::CPI, data_date, new_base_date::Union{Int, Date}
) where {T,Tf,Ts}
    # Checks
    # - current currency is nominal
    current_curr = currency(v)
    current_curr isa NominalCurrency || throw(ArgumentError("MonetaryVariable must have NominalCurrency to convert to real"))
    # - compatibility
    assert_compatible(cpi, v)
    # Preparation
    rc = real_currency(current_curr, new_base_date)
    # Deflate
    deflated = to_real(v.data, cpi, data_date, new_base_date)
    return MonetaryVariable(deflated, Tf(), Ts(), rc)
end

"""
    to_nominal(v::MonetaryVariable{T,Tf,Ts}, cpi::CPI, data_dates::AbstractVector) where {T,Tf,Ts}

Convert real values back to nominal values using a CPI index.

# Arguments
- `v`: MonetaryVariable with real values
- `cpi`: CPI object
- `data_dates`: Vector of dates for each observation (can be Int years or Date objects)

# Returns
- MonetaryVariable with nominal values
"""
function to_nominal(v::MonetaryVariable{T,Tf,Ts}, cpi::CPI, data_dates::AbstractVector) where {T,Tf,Ts}
    # Checks
    # - current currency is real
    current_curr = currency(v)
    current_curr isa RealCurrency || throw(ArgumentError("MonetaryVariable must have RealCurrency to convert to nominal"))
    # - compatibility
    assert_compatible(cpi, v)
    # Preparation
    nc = nominal_currency(current_curr)
    bd = base_date(current_curr)
    # Convert to Date if needed
    base_date_date = bd isa Date ? bd : Date(bd)
    dates_vector = data_dates isa AbstractVector{Date} ? data_dates : Date.(data_dates)
    # Build nominal currency from real currency
    inflated = to_nominal(v.data, cpi, base_date_date, dates_vector)
    return MonetaryVariable(inflated, Tf(), Ts(), nc)
end

"""
    rebase(v::MonetaryVariable{T,Tf,Ts}, cpi::CPI, new_base_date::Union{Int, Date}) where {T,Tf,Ts}

Change the base date of real values.

# Arguments
- `v`: MonetaryVariable with real values
- `cpi`: CPI object
- `new_base_date`: The new base date (e.g., 1992)

# Returns
- MonetaryVariable with real values in new base date
"""
function rebase(v::MonetaryVariable{T,Tf,Ts}, cpi::CPI, new_base_date::Union{Int, Date}) where {T,Tf,Ts}
    # Checks
    # - current currency is real
    current_curr = currency(v)
    current_curr isa RealCurrency || throw(ArgumentError("MonetaryVariable must have RealCurrency to rebase"))
    # - compatibility
    assert_compatible(cpi, v)
    # Preparation
    current_base = base_date(current_curr)
    current_base==new_base_date && return v  # No change needed
    # Build real currency with new base date
    rc = real_currency(current_curr, new_base_date)
    rebased = rebase(v.data, cpi, current_base, new_base_date)
    return MonetaryVariable(rebased, Tf(), Ts(), rc)
end



#==========================================================================
    HANDLING INFLATION: EconFrame methods - Helper functions
==========================================================================#

"""
    validate_cpis_unique(cpis::AbstractVector{<:CPI})

Validate that all CPIs have unique good types.
"""
function validate_cpis_unique(cpis::AbstractVector{<:CPI})
    cpi_good_types = [get_good(cpi) for cpi in cpis]
    if length(cpi_good_types) != length(unique(cpi_good_types))
        throw(ArgumentError("Cannot have multiple CPIs with the same good type"))
    end
end

"""
    build_cpi_dict(cpis::AbstractVector{<:CPI})

Create dictionary mapping GoodType => CPI and return the dict and AnyGood CPI (if exists).
"""
function build_cpi_dict(cpis::AbstractVector{<:CPI})
    cpi_dict = Dict(get_good(cpi) => cpi for cpi in cpis)
    anygood_cpi = haskey(cpi_dict, AnyGood()) ? cpi_dict[AnyGood()] : nothing
    return cpi_dict, anygood_cpi
end

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