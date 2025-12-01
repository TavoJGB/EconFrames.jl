function weighted_mean_nomissing(v::AbstractVector, weights::AbstractVector)
    keep = @. !(ismissing(v) | ismissing(weights) | isnan(v) | isnan(weights))
    dot(v[keep], weights[keep]) / sum(weights[keep])
end
weighted_mean(v::AbstractVector, weights::AbstractVector; skipmissing::Bool=false) = skipmissing ? weighted_mean_nomissing(v, weights) : dot(v, weights) / sum(weights)
get_share(v::AbstractVector, condition::Function, weights::AbstractVector; kwargs...) = weighted_mean(condition.(v), weights; kwargs...)
get_share(v::AbstractVector, condition, weights::AbstractVector; kwargs...) = get_share(v, x -> x == condition, weights; kwargs...)