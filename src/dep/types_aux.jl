#==========================================================================
    SYMMETRICDICT
==========================================================================#

struct SymmetricDict{K,V}
    data::Dict{Tuple{K,K}, V}
    # Constructors
    # - Empty constructor
    SymmetricDict{K,V}() where {K,V} = new{K,V}(Dict{Tuple{K,K}, V}())
    # - Constructor from Dict
    SymmetricDict(d::Dict{Tuple{K,K}, V}) where {K,V} = new{K,V}(d)
end

# Normalising the key: alwats alphabetic order
_normalize_key(a::Symbol, b::Symbol) = a <= b ? (a, b) : (b, a)

# Dict methods
Base.getindex(d::SymmetricDict, a::Symbol, b::Symbol) = d.data[_normalize_key(a, b)]
Base.setindex!(d::SymmetricDict, v, a::Symbol, b::Symbol) = (d.data[_normalize_key(a, b)] = v)
Base.get(d::SymmetricDict, key::Tuple{Symbol,Symbol}, default) = get(d.data, _normalize_key(key...), default)
Base.haskey(d::SymmetricDict, a::Symbol, b::Symbol) = haskey(d.data, _normalize_key(a, b))
Base.keys(d::SymmetricDict) = keys(d.data)
Base.values(d::SymmetricDict) = values(d.data)
Base.pairs(d::SymmetricDict) = pairs(d.data)