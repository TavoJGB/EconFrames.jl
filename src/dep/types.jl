#==========================================================================
    AUXILIARY TYPES
==========================================================================#

# Data frequency
abstract type DataFrequency end
struct Annual <: DataFrequency end
struct Quarterly <: DataFrequency end
struct Monthly <: DataFrequency end
struct MultiYearly{N} <: DataFrequency end
struct NAFrequency <: DataFrequency end         # not a frequency

# Subject of analysis
abstract type DataSubject end
struct Household <: DataSubject end
struct Individual <: DataSubject end
struct Quantile <: DataSubject end

# Source of the data
abstract type DataSource end
struct PSID <: DataSource end
struct SCF <: DataSource end
struct EFF <: DataSource end

# Good type (for sector-specific inflation adjustments)
abstract type GoodType end
abstract type SomeGood <: GoodType end
struct AnyGood <: GoodType end
struct ConsumptionGood <: SomeGood end
struct Housing <: SomeGood end

# Housing tenure status
@enum TenureStatus begin
    Owner = 1
    Renter = 5
    NoTenure = 9
    NoHead = 10
end



#==========================================================================
    CURRENCIES
==========================================================================#

# Currency type (for tracking nominal vs real values)
abstract type Currency end
abstract type NominalCurrency <: Currency end
abstract type RealCurrency{D} <: Currency end   # D = base date for real values
struct NominalEUR <: NominalCurrency end
struct RealEUR{D} <: RealCurrency{D} end        # D = base date for real values
struct NominalUSD <: NominalCurrency end
struct RealUSD{D} <: RealCurrency{D} end        # D = base date for real values
struct NACurrency <: Currency end        # not a currency

# Currency mapping helpers
# - Nominal to real
real_currency(::NominalEUR, d) = RealEUR{d}()
real_currency(::NominalUSD, d) = RealUSD{d}()
# - Real to nominal
nominal_currency(::RealEUR{D}) where {D} = NominalEUR()
nominal_currency(::RealUSD{D}) where {D} = NominalUSD()
# - Real to real
real_currency(::RealEUR{D1}, d2::Union{Int,Date}) where {D1} = RealEUR{d2}()
real_currency(::RealUSD{D1}, d2::Union{Int,Date}) where {D1} = RealUSD{d2}()
# - Get base date
base_date(::RealCurrency{D}) where {D} = D

# Fallbacks (extend later if more currencies are added)
function real_currency(::NominalCurrency, d)
    throw(ArgumentError("No real-currency mapping defined for this NominalCurrency"))
end
function nominal_currency(::RealCurrency)
    throw(ArgumentError("No nominal-currency mapping defined for this RealCurrency"))
end

# Helper function to display currency type
currency_string(::NominalCurrency) = "Nominal currency"
currency_string(::NominalEUR) = "Nominal EUR"
currency_string(::NominalUSD) = "Nominal USD"
currency_string(::RealCurrency{Y}) where Y = "Real currency {$Y}"
currency_string(::RealEUR{D}) where D = "Real EUR (base=$D)"
currency_string(::RealUSD{D}) where D = "Real USD (base=$D)"



#==========================================================================
    ECONSCALAR
    Scalar economic values (means, variances, etc.)
==========================================================================#

abstract type AbstractEconScalar{T<:Real, Tf<:DataFrequency, Ts<:DataSubject} end

struct EconScalar{T<:Real, Tf<:DataFrequency, Ts<:DataSubject} <: AbstractEconScalar{T, Tf, Ts}
    value::T
    # Constructor
    EconScalar(value::T, freq::F, DataSubject::S) where {T<:Real, F<:DataFrequency, S<:DataSubject} = new{T, F, S}(value)
end

# Accessor functions for EconScalar
frequency(s::AbstractEconScalar{T, Tf, Ts}) where {T, Tf<:DataFrequency, Ts} = Tf()
subject(s::AbstractEconScalar{T, Tf, Ts}) where {T, Tf, Ts<:DataSubject} = Ts()

# Compatibility check
function assert_compatible(s::AbstractEconScalar, t::AbstractEconScalar)::Nothing
    for (Ts, Tt) in zip(characteristics(s), characteristics(t))
        @assert Ts == Tt "Scalars are not comparable ($Ts vs $Tt)"
    end
    return nothing
end

# Base functions for EconScalar
characteristics(s::AbstractEconScalar) = (frequency(s), subject(s))
Base.show(io::IO, s::AbstractEconScalar) = show(io, s.value)
Base.:(==)(s::AbstractEconScalar, t::AbstractEconScalar) = (s.value == t.value) && (typeof(s) == typeof(t))
Base.:(==)(s::AbstractEconScalar, x::Number) = (s.value == x)
Base.:(==)(x::Number, s::AbstractEconScalar) = (s.value == x)
Base.isequal(s::AbstractEconScalar, t::AbstractEconScalar) = isequal(s.value, t.value) && (typeof(s) == typeof(t))
Base.isequal(s::AbstractEconScalar, x::Number) = isequal(s.value, x)
Base.isequal(x::Number, s::AbstractEconScalar) = isequal(s.value, x)
function Base.isless(s::AbstractEconScalar, t::AbstractEconScalar)
    assert_compatible(s, t)
    return (s.value < t.value)
end
Base.isless(s::Real, t::AbstractEconScalar) = (s < t.value)
Base.isless(s::AbstractEconScalar, t::Real) = (s.value < t)
Base.real(s::AbstractEconScalar) = s.value
Base.abs(s::AbstractEconScalar) = abs(s.value)

# Arithmetic operations for EconScalar
function Base.:+(s::Tes, t::Tes) where {Tes<:AbstractEconScalar}
    assert_compatible(s, t)
    return Tes.name.wrapper(s.value + t.value, characteristics(s)...)
end
Base.:+(s::Tes, x::Real) where {Tes<:AbstractEconScalar} = Tes.name.wrapper(s.value + x, characteristics(s)...)
Base.:+(x::Real, s::Tes) where {Tes<:AbstractEconScalar} = Tes.name.wrapper(x + s.value, characteristics(s)...)

function Base.:-(s::Tes, t::Tes) where {Tes<:AbstractEconScalar}
    assert_compatible(s, t)
    return Tes.name.wrapper(s.value - t.value, characteristics(s)...)
end
Base.:-(s::Tes) where {Tes<:AbstractEconScalar} = Tes.name.wrapper(-s.value, characteristics(s)...)
Base.:-(s::Tes, x::Real) where {Tes<:AbstractEconScalar} = Tes.name.wrapper(s.value - x, characteristics(s)...)
Base.:-(x::Real, s::Tes) where {Tes<:AbstractEconScalar} = Tes.name.wrapper(x - s.value, characteristics(s)...)
function Base.:*(s::Tes, t::Tes) where {Tes<:AbstractEconScalar}
    assert_compatible(s, t)
    return Tes.name.wrapper(s.value * t.value, characteristics(s)...)
end
Base.:*(s::Tes, x::Real) where {Tes<:AbstractEconScalar} = Tes.name.wrapper(s.value * x, characteristics(s)...)
Base.:*(x::Real, s::Tes) where {Tes<:AbstractEconScalar} = Tes.name.wrapper(x * s.value, characteristics(s)...)

function Base.:/(s::Tes, t::Tes) where {Tes<:AbstractEconScalar}
    assert_compatible(s, t)
    return Tes.name.wrapper(s.value / t.value, characteristics(s)...)
end
Base.:/(s::Tes, x::Real) where {Tes<:AbstractEconScalar} = Tes.name.wrapper(s.value / x, characteristics(s)...)
Base.:/(x::Real, s::Tes) where {Tes<:AbstractEconScalar} = Tes.name.wrapper(x / s.value, characteristics(s)...)

function Base.:^(s::Tes, t::Tes) where {Tes<:AbstractEconScalar}
    assert_compatible(s, t)
    return Tes.name.wrapper(s.value ^ t.value, characteristics(s)...)
end
Base.:^(s::Tes, x::Real) where {Tes<:AbstractEconScalar} = Tes.name.wrapper(s.value ^ x, characteristics(s)...)
Base.:^(x::Real, s::Tes) where {Tes<:AbstractEconScalar} = Tes.name.wrapper(x ^ s.value, characteristics(s)...)



#==========================================================================
    MONETARYSCALAR
==========================================================================#

struct MonetaryScalar{T<:Real, Tf<:DataFrequency, Ts<:DataSubject} <: AbstractEconScalar{T, Tf, Ts}
    value::T
    currency::Currency
    good::GoodType
    # Constructors
    MonetaryScalar(value::T, ::F, ::S, currency::Currency, good::GoodType=AnyGood()) where {T<:Real, F<:DataFrequency, S<:DataSubject} = new{T, F, S}(value, currency, good)
    EconScalar(value::T, freq::F, DataSubject::S, currency::Currency, good::GoodType=AnyGood()) where {T<:Real, F<:DataFrequency, S<:DataSubject} = new{T, F, S}(value, currency, good)
end

# Methods
currency(s::MonetaryScalar) = s.currency
get_good_type(s::MonetaryScalar) = typeof(s.good)
characteristics(s::MonetaryScalar) = (frequency(s), subject(s), currency(s))



#==========================================================================
    ECONVARIABLE
    Vector wrapper with economic metadata
==========================================================================#

abstract type AbstractEconVariable{T<:Real, Tf<:DataFrequency, Ts<:DataSubject} <: AbstractVector{T} end

struct EconVariable{T<:Real, Tf<:DataFrequency, Ts<:DataSubject} <: AbstractEconVariable{T, Tf, Ts}
    data::Vector{T}
    # Constructors
    function EconVariable(data::Vector{T}, freq::F, subject::S) where {T<:Real, F<:DataFrequency, S<:DataSubject}
        return new{T, F, S}(data)
    end
end

# Accessor functions
frequency(v::AbstractEconVariable{T, Tf, Ts}) where {T, Tf<:DataFrequency, Ts} = Tf()
subject(v::AbstractEconVariable{T, Tf, Ts}) where {T, Tf, Ts<:DataSubject} = Ts()
characteristics(v::AbstractEconVariable) = (frequency(v), subject(v))

# Show methods for EconVariable
list_characteristics(v::AbstractEconVariable) = list_characteristics(characteristics(v)...)
list_characteristics(::Tf, ::Ts) where {Tf<:DataFrequency, Ts<:DataSubject} = string(Tf.name.name), string(Ts.name.name)
function Base.show(io::IO, v::EconVariable{T, Tf, Ts}) where {T, Tf, Ts}
    freq_str, subj_str = list_characteristics(v)
    println(io, "EconVariable{$T, $freq_str, $subj_str}($(length(v)) elements)")
    Base.print_array(io, v.data)
end
function Base.show(io::IO, ::MIME"text/plain", v::EconVariable{T, Tf, Ts}) where {T, Tf, Ts}
    freq_str, subj_str = list_characteristics(v)
    println(io, "$(length(v))-element EconVariable{$T, $freq_str, $subj_str}:")
    Base.print_array(io, v.data)
end

# AbstractArray interface implementation
Base.size(v::AbstractEconVariable) = size(v.data)
Base.getindex(v::AbstractEconVariable, i::Int) = getindex(v.data, i)
Base.getindex(v::AbstractEconVariable, I...) = getindex(v.data, I...)
Base.setindex!(v::AbstractEconVariable, val, i::Int) = setindex!(v.data, val, i)
Base.setindex!(v::AbstractEconVariable, val, I...) = setindex!(v.data, val, I...)
Base.IndexStyle(::Type{<:AbstractEconVariable}) = IndexLinear()
Base.length(v::AbstractEconVariable) = length(v.data)

# Iteration
Base.iterate(v::AbstractEconVariable) = iterate(v.data)
Base.iterate(v::AbstractEconVariable, state) = iterate(v.data, state)
# Equality
Base.:(==)(v::AbstractEconVariable, w::AbstractEconVariable) = (v.data == w.data) && (typeof(v) == typeof(w))
Base.isequal(v::AbstractEconVariable, w::AbstractEconVariable) = isequal(v.data, w.data) && (typeof(v) == typeof(w))

# Helper functions to check compatibility
function assert_compatible(v::AbstractEconVariable, w::AbstractEconVariable)::Nothing
    for (Tv, Tw) in zip(characteristics(v), characteristics(w))
        @assert Tv == Tw "Variables are not comparable ($Tv vs $Tw)"
    end
    @assert length(v) == length(w) "Variables have different lengths"
    return nothing
end
function assert_compatible(v::AbstractEconVariable, w::AbstractEconScalar)::Nothing
    for (Tv, Tw) in zip(characteristics(v), characteristics(w))
        @assert Tv == Tw "Variables are not comparable ($Tv vs $Tw)"
    end
    @assert length(v) == length(w) "Variables have different lengths"
    return nothing
end
assert_compatible(w::AbstractEconScalar, v::AbstractEconVariable) = assert_compatible(v, w)

# Arithmetic operations
# - Addition
function Base.:+(v::Tev, w::Tev) where {Tev<:AbstractEconVariable}
    assert_compatible(v, w)
    T = typeof(v).name.wrapper
    return T(v.data .+ w.data, characteristics(v)...)
end
Base.:+(v::Tev, x::Real) where {Tev<:AbstractEconVariable} = typeof(v).name.wrapper(v.data .+ x, characteristics(v)...)
Base.:+(x::Real, v::Tev) where {Tev<:AbstractEconVariable} = typeof(v).name.wrapper(x .+ v.data, characteristics(v)...)
Base.:+(v::Tev, x::AbstractVector{<:Real}) where {Tev<:AbstractEconVariable} = typeof(v).name.wrapper(v.data .+ x, characteristics(v)...)
Base.:+(x::AbstractVector{<:Real}, v::Tev) where {Tev<:AbstractEconVariable} = typeof(v).name.wrapper(x .+ v.data, characteristics(v)...)

# Allow adding EconScalar to EconVariable
function Base.:+(v::Tev, s::Tes) where {Tev<:AbstractEconVariable, Tes<:AbstractEconScalar}
    assert_compatible(v, s)
    T = typeof(v).name.wrapper
    return T(v.data .+ s.value, characteristics(v)...)
end
Base.:+(s::AbstractEconScalar, v::AbstractEconVariable) = v + s
# - Subtraction
function Base.:-(v::Tev, w::Tev) where {Tev<:AbstractEconVariable}
    assert_compatible(v, w)
    return Tev.name.wrapper(v.data .- w.data, characteristics(v)...)
end
Base.:-(v::Tev) where {Tev<:AbstractEconVariable} = Tev.name.wrapper(-v.data, characteristics(v)...)
Base.:-(v::Tev, x::Real) where {Tev<:AbstractEconVariable} = Tev.name.wrapper(v.data .- x, characteristics(v)...)
Base.:-(x::Real, v::Tev) where {Tev<:AbstractEconVariable} = Tev.name.wrapper(x .- v.data, characteristics(v)...)
Base.:-(v::Tev, x::AbstractVector{<:Real}) where {Tev<:AbstractEconVariable} = Tev.name.wrapper(v.data .- x, characteristics(v)...)
Base.:-(x::AbstractVector{<:Real}, v::Tev) where {Tev<:AbstractEconVariable} = Tev.name.wrapper(x .- v.data, characteristics(v)...)

function Base.:-(v::Tev, s::Tes) where {Tev<:AbstractEconVariable, Tes<:AbstractEconScalar}
    assert_compatible(v, s)
    T = typeof(v).name.wrapper
    return T(v.data .- s.value, characteristics(v)...)
end
function Base.:-(s::Tes, v::Tev) where {Tev<:AbstractEconVariable, Tes<:AbstractEconScalar}
    assert_compatible(v, s)
    T = typeof(v).name.wrapper
    return T(s.value .- v.data, characteristics(v)...)
end

# - Multiplication
function Base.:*(v::Tev, w::Tev) where {Tev<:AbstractEconVariable}
    assert_compatible(v, w)
    T = typeof(v).name.wrapper
    return T(v.data .* w.data, characteristics(v)...)
end
Base.:*(v::Tev, x::Real) where {Tev<:AbstractEconVariable} = typeof(v).name.wrapper(v.data .* x, characteristics(v)...)
Base.:*(x::Real, v::Tev) where {Tev<:AbstractEconVariable} = typeof(v).name.wrapper(x .* v.data, characteristics(v)...)
Base.:*(v::Tev, x::AbstractVector{<:Real}) where {Tev<:AbstractEconVariable} = typeof(v).name.wrapper(v.data .* x, characteristics(v)...)
Base.:*(x::AbstractVector{<:Real}, v::Tev) where {Tev<:AbstractEconVariable} = typeof(v).name.wrapper(x .* v.data, characteristics(v)...)
function Base.:*(v::Tev, s::Tes) where {Tev<:AbstractEconVariable, Tes<:AbstractEconScalar}
    assert_compatible(v, s)
    T = typeof(v).name.wrapper
    return T(v.data .* s.value, characteristics(v)...)
end
Base.:*(s::AbstractEconScalar, v::AbstractEconVariable) = v * s

# - Division
function Base.:/(v::Tev, w::Tev) where {Tev<:AbstractEconVariable}
    assert_compatible(v, w)
    return Tev.name.wrapper(v.data ./ w.data, characteristics(v)...)
end
Base.:/(v::Tev, x::Real) where {Tev<:AbstractEconVariable} = Tev.name.wrapper(v.data ./ x, characteristics(v)...)
Base.:/(x::Real, v::Tev) where {Tev<:AbstractEconVariable} = Tev.name.wrapper(x ./ v.data, characteristics(v)...)
Base.:/(v::Tev, x::AbstractVector{<:Real}) where {Tev<:AbstractEconVariable} = Tev.name.wrapper(v.data ./ x, characteristics(v)...)
Base.:/(x::AbstractVector{<:Real}, v::Tev) where {Tev<:AbstractEconVariable} = Tev.name.wrapper(x ./ v.data, characteristics(v)...)
function Base.:/(v::Tev, s::Tes) where {Tev<:AbstractEconVariable, Tes<:AbstractEconScalar}
    assert_compatible(v, s)
    return Tev.name.wrapper(v.data ./ s.value, characteristics(v)...)
end
function Base.:/(s::Tes, v::Tev) where {Tev<:AbstractEconVariable, Tes<:AbstractEconScalar}
    assert_compatible(v, s)
    return Tev.name.wrapper(s.value ./ v.data, characteristics(v)...)
end

# - Power
function Base.:^(v::Tev, w::Tev) where {Tev<:AbstractEconVariable}
    assert_compatible(v, w)
    return Tev.name.wrapper(v.data .^ w.data, characteristics(v)...)
end
Base.:^(v::Tev, x::Real) where {Tev<:AbstractEconVariable} = Tev.name.wrapper(v.data .^ x, characteristics(v)...)
Base.:^(x::Real, v::Tev) where {Tev<:AbstractEconVariable} = Tev.name.wrapper(x .^ v.data, characteristics(v)...)
Base.:^(v::Tev, x::AbstractVector{<:Real}) where {Tev<:AbstractEconVariable} = Tev.name.wrapper(v.data .^ x, characteristics(v)...)
Base.:^(x::AbstractVector{<:Real}, v::Tev) where {Tev<:AbstractEconVariable} = Tev.name.wrapper(x .^ v.data, characteristics(v)...)

# Broadcasting support
Base.BroadcastStyle(::Type{Tev}) where {Tev<:AbstractEconVariable} = Broadcast.ArrayStyle{Tev}()

# similar
function Base.similar(bc::Broadcast.Broadcasted{<:Broadcast.ArrayStyle{<:Tev}}, ::Type{ElType}, axes) where {ElType, Tev<:AbstractEconVariable}
    v = find_econvar(bc)
    return Tev.name.wrapper(similar(Array{ElType}, axes), characteristics(v)...)
end
Base.similar(bc::Broadcast.Broadcasted{<:Broadcast.ArrayStyle{<:AbstractEconVariable}}, ::Type{ElType}) where {ElType} = similar(bc, ElType, axes(bc))

# Helper function to find an EconVariable in Broadcasted args
function find_econvar(bc::Base.Broadcast.Broadcasted)
    for arg in bc.args
        if arg isa AbstractEconVariable
            return arg
        elseif arg isa Base.Broadcast.Broadcasted
            v = find_econvar(arg)
            if !isnothing(v)
                return v
            end
        end
    end
    return nothing
end

# Statistical functions that preserve metadata and return EconScalar
Base.sum(v::AbstractEconVariable) = EconScalar(sum(v.data), characteristics(v)...)
Base.minimum(v::AbstractEconVariable) = EconScalar(minimum(v.data), characteristics(v)...)
Base.maximum(v::AbstractEconVariable) = EconScalar(maximum(v.data), characteristics(v)...)
# Import StatsBase for mean and other stats
using StatsBase: mean, var, std, median, quantile
StatsBase.mean(v::AbstractEconVariable) = EconScalar(mean(v.data), characteristics(v)...)
StatsBase.var(v::AbstractEconVariable) = EconScalar(var(v.data), characteristics(v)...)
StatsBase.std(v::AbstractEconVariable) =  EconScalar(std(v.data), characteristics(v)...)
StatsBase.median(v::AbstractEconVariable) = EconScalar(median(v.data), characteristics(v)...)
StatsBase.quantile(v::AbstractEconVariable, p) = EconScalar(quantile(v.data, p), characteristics(v)...)

# Allow conversion to regular Vector
Base.Vector(v::AbstractEconVariable) = v.data
Base.convert(::Type{Vector{T}}, v::AbstractEconVariable) where T = convert(Vector{T}, v.data)



#==========================================================================
    MONETARYVARIABLE
    Vector wrapper with monetary metadata
==========================================================================#

struct MonetaryVariable{T<:Real, Tf<:DataFrequency, Ts<:DataSubject} <: AbstractEconVariable{T, Tf, Ts}
    data::Vector{T}
    currency::Currency
    good::GoodType
    # Constructors
    MonetaryVariable(data::Vector{T}, ::F, ::S, curr::Currency, good::GoodType=AnyGood()) where {T<:Real, F<:DataFrequency, S<:DataSubject} = new{T, F, S}(data, curr, good)
end

currency(v::MonetaryVariable) = v.currency
get_good_type(v::MonetaryVariable) = typeof(v.good)
characteristics(v::MonetaryVariable) = (frequency(v), subject(v), currency(v))
list_characteristics(::Tf, ::Ts, ::Tc) where {Tf<:DataFrequency, Ts<:DataSubject, Tc<:Currency} = string(Tf.name.name), string(Ts.name.name), currency_string(Tc())

# Show methods for MonetaryVariable (with currency)
function Base.show(io::IO, v::MonetaryVariable{T, Tf, Ts}) where {T, Tf, Ts}
    freq_str, subj_str, curr_str = list_characteristics(v)
    println(io, "MonetaryVariable{$T, $freq_str, $subj_str, $curr_str}($(length(v)) elements)")
    Base.print_array(io, v.data)
end
function Base.show(io::IO, ::MIME"text/plain", v::MonetaryVariable{T, Tf, Ts}) where {T, Tf, Ts}
    freq_str, subj_str, curr_str = list_characteristics(v)
    println(io, "$(length(v))-element MonetaryVariable{$T, $freq_str, $subj_str, $curr_str}:")
    Base.print_array(io, v.data)
end

# Statistical functions for MonetaryVariable return MonetaryScalar
Base.sum(v::MonetaryVariable) = MonetaryScalar(sum(v.data), characteristics(v)...)
Base.minimum(v::MonetaryVariable) = MonetaryScalar(minimum(v.data), characteristics(v)...)
Base.maximum(v::MonetaryVariable) = MonetaryScalar(maximum(v.data), characteristics(v)...)
StatsBase.mean(v::MonetaryVariable) = MonetaryScalar(mean(v.data), characteristics(v)...)
StatsBase.var(v::MonetaryVariable) = MonetaryScalar(var(v.data), characteristics(v)...)
StatsBase.std(v::MonetaryVariable) = MonetaryScalar(std(v.data), characteristics(v)...)
StatsBase.median(v::MonetaryVariable) = MonetaryScalar(median(v.data), characteristics(v)...)
StatsBase.quantile(v::MonetaryVariable, p) = MonetaryScalar(quantile(v.data, p), characteristics(v)...)



#==========================================================================
    ECONFRAME
    Main type. DataFrames with economic metadata.
==========================================================================#

abstract type EconFrame end

mutable struct EconRepeatedCrossSection{Ds<:DataSource, Dj<:DataSubject, Df<:DataFrequency} <: EconFrame
    # Data
    data::DataFrame
    # Data characteristics
    source::Ds
    subject::Dj
    frequency::Df
    currency::Currency    # Currency for monetary variables (not parametric to allow mutation)
    N::Int          # Number of observations
    # Key columns
    date_var::Union{Symbol,String}
    weight_var::Union{Symbol,String}
    # Constructors
    function EconRepeatedCrossSection(
        data::DataFrame, source::Ds, subject::Dj, frequency::Df, date_var::Union{Symbol,String};
        currency::Currency=NACurrency(), weight_var::Union{Symbol,String}=:weight
    ) where {Ds<:DataSource, Dj<:DataSubject, Df<:DataFrequency}
        N = nrow(data)
        data[!, date_var] = Date.(data[!, date_var])  # Ensure date variable is of Date type
        return new{Ds, Dj, Df}(data, source, subject, frequency, currency, N, date_var, weight_var)
    end
end
mutable struct EconCrossSection{Ds<:DataSource, Dj<:DataSubject} <: EconFrame
    # Data
    data::DataFrame
    # Data characteristics
    source::Ds
    subject::Dj
    currency::Currency    # Currency for monetary variables (not parametric to allow mutation)
    N::Int          # Number of observations
    date::Date
    # Key columns
    weight_var::Union{Symbol,String}
    # Constructor
    function EconCrossSection(
        data::DataFrame, source::Ds, subject::Dj, date::Date;
        currency::Currency=NACurrency(), weight_var::Union{Symbol,String}=:weight
    ) where {Ds<:DataSource, Dj<:DataSubject}
        N = nrow(data)
        data[!, date_var] = Date.(data[!, date_var])  # Ensure date variable is of Date type
        return new{Ds, Dj}(data, source, subject, currency, N, date, weight_var)
    end
    EconCrossSection(data::DataFrame, source::DataSource, subject::DataSubject, date; kwargs...) = EconCrossSection(data, source, subject, Date(date); kwargs...)
end

# Methods
# Mark columns as monetary variables (they will use the EconFrame's currency)
function monetary_variable!(ef::EconFrame, col::Symbol, good_type::GoodType=AnyGood())::Nothing
    # Ensure column contains Real numbers
    if !(eltype(ef.data[!, col]) <: Real)
        ef.data[!, col] = parse.(Float64, string.(ef.data[!, col]))
    end
    # Set metadata
    colmetadata!(ef.data, col, "is_monetary", true)
    colmetadata!(ef.data, col, "good_type", good_type)
    return nothing
end
function monetary_variable!(ef::EconFrame, cols::AbstractVector{Symbol}, good_type::GoodType=AnyGood())::Nothing
    for col in cols
        monetary_variable!(ef, col, good_type)
    end
    return nothing
end
function monetary_variable!(ef::EconFrame, cols::AbstractVector{<:Symbol}, good_types::Vector{<:GoodType})::Nothing
    for (col, good_type) in zip(cols, good_types)
        monetary_variable!(ef, Symbol(col), good_type)
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
get_dates(ef::EconCrossSection) = ef.date
get_weights(ef::EconFrame) = ef.data[!, ef.weight_var]

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

# Base methods
Base.size(ef::EconFrame) = size(ef.data)
Base.getindex(ef::EconFrame, args...) = getindex(ef.data, args...)
Base.setindex!(ef::EconFrame, val, args...) = setindex!(ef.data, val, args...)
Base.view(ef::EconFrame, args...) = view(ef.data, args...)
Base.propertynames(ef::EconFrame) = propertynames(ef.data)
Base.getproperty(ef::EconFrame, s::Symbol) = s in fieldnames(typeof(ef)) ? getfield(ef, s) : getproperty(ef.data, s)
Base.setproperty!(ef::EconFrame, s::Symbol, val) = s in fieldnames(typeof(ef)) ? setfield!(ef, s, val) : setproperty!(ef.data, s, val)
Base.sort!(ef::EconFrame, args...; kwargs...) = df_function_keeping_metadata!(ef, Base.sort!, args...; kwargs...)

# DataFrame methods
DataFrames.names(ef::EconFrame) = names(ef.data)
DataFrames.nrow(ef::EconFrame) = nrow(ef.data)
DataFrames.ncol(ef::EconFrame) = ncol(ef.data)
DataFrames.colmetadata(ef::EconFrame, args...) = DataFrames.colmetadata(ef.data, args...)
DataFrames.colmetadatakeys(ef::EconFrame, args...) = DataFrames.colmetadatakeys(ef.data, args...)
DataFrames.insertcols!(ef::EconFrame, args...) = DataFrames.insertcols!(ef.data, args...)
DataFrames.select(ef::EconFrame, args...; kwargs...) = reconstruct(ef;data=DataFrames.select(ef.data, args...; kwargs...), kwargs...)
DataFrames.select!(ef::EconFrame, args...) = df_function_keeping_metadata!(ef, DataFrames.select!, args...)
DataFrames.subset(ef::EconFrame, args...; kwargs...) = reconstruct(ef;data=DataFrames.subset(ef.data, args...), kwargs...)
DataFrames.subset!(ef::EconFrame, args...) = df_function_keeping_metadata!(ef, DataFrames.subset!, args...)

# Auxiliary
function df_function_keeping_metadata!(ef::EconFrame, df_func::Function, args...; kwargs...)
    # Save all column metadata
    saved_meta = df_save_metadata(ef)
    # Perform function
    df_func(ef.data, args...; kwargs...)
    ef.N = nrow(ef.data)
    # Restore metadata for remaining columns
    df_restore_metadata!(ef, saved_meta)
    return nothing
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
function Base.show(io::IO, ef::EconRepeatedCrossSection{Ds,Dj,Df}) where {Ds,Dj,Df}
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
    print(io, "EconRepeatedCrossSection{$(Ds.name.name), $(Dj.name.name), $(Df.name.name), $curr_str}(")
    print(io, "$(ef.source), $(ef.subject), $(ef.frequency), ")
    print(io, "dates: $date_range, ")
    print(io, "currency: $curr_str, ")
    print(io, "$(ef.N) observations, ")
    print(io, "$(ncol(ef.data))×$(nrow(ef.data)) DataFrame\n")
    show(io, ef.data)
end