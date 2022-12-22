"""
    timesteps_durations(datetime::Dates.DateTime; verbose=true)

Duration in sensible units (e.g. 1 hour, or 1 day), computed as the 
duration between a step and the previous step. The first one is unknown,
so we force it as the same as all (if unique), or the second one (if not)
with a warning.

The function returns a `Dates.CompoundPeriod` because it helps finding a sensible
default from a milliseconds period (*e.g.* 1 Hour or 1 Day).

# Arguments
- `datetime::Vector{Dates.DateTime}`: Vector of dates
- `verbose::Bool=true`: If `true`, print a warning if the duration is not 
constant between the time steps.

# Examples

```jldocs
julia> timesteps_durations([Dates.DateTime(2019, 1, 1, 0), Dates.DateTime(2019, 1, 1, 1)])
2-element Vector{Dates.CompoundPeriod}:
 1 hour
 1 hour
```
"""
function timesteps_durations(datetime::Vector{Dates.DateTime}; verbose=true)
    # Duration in sensible units (e.g. 1 hour, or 1 day)
    duration = [i == 1 ? Dates.canonicalize(Dates.Hour(1)) : Dates.canonicalize(datetime[i] - datetime[i-1]) for i in eachindex(datetime)]

    if verbose && length(unique(duration[2:end])) != 1
        @warn string(
            "Duration is not constant in the forecast data.",
            " Using the duration value of the second time step for the first."
        )
    end

    # The duration is computed as the duration between a step and 
    # the previous step, so the first one is unknown. We compute it 
    # as the same as all (if unique), or the second one (if not).
    # In all cases, we use the second one because if all are the same,
    # we can take any time step.
    duration[1] = duration[2]

    return duration
end