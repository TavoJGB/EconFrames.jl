#==========================================================================
    SYMMETRICDICT
==========================================================================#

struct SymmetricDict{K,V}
    data::Dict{Tuple{K,K}, V}
    # Main constructor
    function SymmetricDict(d::Dict{Tuple{K,K}, V}) where {K,V}
        normalized = Dict{Tuple{K,K}, V}()
        for ((a, b), v) in d
            normalized[_normalize_key(a, b)] = v
        end
        return new{K,V}(normalized)
    end
    # Other constructors
    SymmetricDict{K,V}() where {K,V} = new{K,V}(Dict{Tuple{K,K}, V}())
    SymmetricDict(pairs::Pair{Tuple{K,K}, <:Any}...) where {K} = SymmetricDict(Dict(pairs))
end

# Normalising the key: always alphabetic order
_normalize_key(a::Symbol, b::Symbol) = a <= b ? (a, b) : (b, a)

# Dict methods
Base.getindex(d::SymmetricDict, a::Symbol, b::Symbol) = d.data[_normalize_key(a, b)]
Base.getindex(d::SymmetricDict, key::Tuple{Symbol,Symbol}) = d.data[_normalize_key(key...)]
Base.setindex!(d::SymmetricDict, v, a::Symbol, b::Symbol) = (d.data[_normalize_key(a, b)] = v)
Base.setindex!(d::SymmetricDict, v, key::Tuple{Symbol,Symbol}) = (d.data[_normalize_key(key...)] = v)
Base.get(d::SymmetricDict, key::Tuple{Symbol,Symbol}, default) = get(d.data, _normalize_key(key...), default)
Base.haskey(d::SymmetricDict, a::Symbol, b::Symbol) = haskey(d.data, _normalize_key(a, b))
Base.haskey(d::SymmetricDict, key::Tuple{Symbol,Symbol}) = haskey(d.data, _normalize_key(key...))
Base.keys(d::SymmetricDict) = keys(d.data)
Base.values(d::SymmetricDict) = values(d.data)
Base.pairs(d::SymmetricDict) = pairs(d.data)
Base.length(d::SymmetricDict) = length(d.data)
Base.isempty(d::SymmetricDict) = isempty(d.data)

# Show method
Base.show(io::IO, d::SymmetricDict{K,V}) where {K,V} = print(io, "SymmetricDict{$K, $V}(", d.data, ")")