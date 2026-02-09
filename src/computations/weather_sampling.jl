"""
    AbstractTimeReducer

Abstract supertype for reducers used by [`MeteoTransform`](@ref).

Reducer implementations are expected to be callable with either:
- `(vals)`
- `(vals, durations)`

See [`MeanWeighted`](@ref), [`SumReducer`](@ref), and [`RadiationEnergy`](@ref).
"""
abstract type AbstractTimeReducer end

"""
    MeanWeighted()

Duration-weighted mean reducer. When durations are not provided, falls back to a plain mean.
"""
struct MeanWeighted <: AbstractTimeReducer end

"""
    MeanReducer()

Arithmetic mean reducer.
"""
struct MeanReducer <: AbstractTimeReducer end

"""
    SumReducer()

Sum reducer.
"""
struct SumReducer <: AbstractTimeReducer end

"""
    MinReducer()

Minimum reducer.
"""
struct MinReducer <: AbstractTimeReducer end

"""
    MaxReducer()

Maximum reducer.
"""
struct MaxReducer <: AbstractTimeReducer end

"""
    FirstReducer()

Reducer returning first value in the window.
"""
struct FirstReducer <: AbstractTimeReducer end

"""
    LastReducer()

Reducer returning last value in the window.
"""
struct LastReducer <: AbstractTimeReducer end

"""
    RadiationEnergy()

Integrate flux values (W m-2) over durations (seconds) into MJ m-2.
"""
struct RadiationEnergy <: AbstractTimeReducer end

(::MeanWeighted)(vals::AbstractVector{<:Real}) = Statistics.mean(vals)
"""
    (MeanWeighted())(vals, durations)

Compute duration-weighted mean.

# Arguments

- `vals::AbstractVector{<:Real}`: values to reduce.
- `durations::AbstractVector{<:Real}`: per-value durations.

# Returns

Weighted mean, or `nothing` when the total duration is zero.
"""
function (::MeanWeighted)(vals::AbstractVector{<:Real}, durations::AbstractVector{<:Real})
    num = 0.0
    den = 0.0
    for (v, d) in zip(vals, durations)
        num += v * d
        den += d
    end
    den == 0.0 && return nothing
    return num / den
end

(::MeanReducer)(vals::AbstractVector{<:Real}) = Statistics.mean(vals)
"""
    (MeanReducer())(vals)
    (MeanReducer())(vals, durations)

Compute arithmetic mean of sampled values.

# Arguments

- `vals::AbstractVector{<:Real}`: values to reduce.
- `durations::AbstractVector{<:Real}`: optional durations (ignored).
"""
(::MeanReducer)(vals::AbstractVector{<:Real}, durations::AbstractVector{<:Real}) = Statistics.mean(vals)

"""
    (SumReducer())(vals)
    (SumReducer())(vals, durations)

Compute sum of sampled values.

# Arguments

- `vals::AbstractVector{<:Real}`: values to reduce.
- `durations::AbstractVector{<:Real}`: optional durations (ignored).
"""
(::SumReducer)(vals::AbstractVector{<:Real}) = sum(vals)
(::SumReducer)(vals::AbstractVector{<:Real}, durations::AbstractVector{<:Real}) = sum(vals)

"""
    (MinReducer())(vals)
    (MinReducer())(vals, durations)

Compute minimum of sampled values.

# Arguments

- `vals::AbstractVector{<:Real}`: values to reduce.
- `durations::AbstractVector{<:Real}`: optional durations (ignored).
"""
(::MinReducer)(vals::AbstractVector{<:Real}) = minimum(vals)
(::MinReducer)(vals::AbstractVector{<:Real}, durations::AbstractVector{<:Real}) = minimum(vals)

"""
    (MaxReducer())(vals)
    (MaxReducer())(vals, durations)

Compute maximum of sampled values.

# Arguments

- `vals::AbstractVector{<:Real}`: values to reduce.
- `durations::AbstractVector{<:Real}`: optional durations (ignored).
"""
(::MaxReducer)(vals::AbstractVector{<:Real}) = maximum(vals)
(::MaxReducer)(vals::AbstractVector{<:Real}, durations::AbstractVector{<:Real}) = maximum(vals)

"""
    (FirstReducer())(vals)
    (FirstReducer())(vals, durations)

Return first sampled value.

# Arguments

- `vals::AbstractVector`: values to reduce.
- `durations::AbstractVector{<:Real}`: optional durations (ignored).
"""
(::FirstReducer)(vals::AbstractVector) = first(vals)
(::FirstReducer)(vals::AbstractVector, durations::AbstractVector{<:Real}) = first(vals)

"""
    (LastReducer())(vals)
    (LastReducer())(vals, durations)

Return last sampled value.

# Arguments

- `vals::AbstractVector`: values to reduce.
- `durations::AbstractVector{<:Real}`: optional durations (ignored).
"""
(::LastReducer)(vals::AbstractVector) = last(vals)
(::LastReducer)(vals::AbstractVector, durations::AbstractVector{<:Real}) = last(vals)

"""
    RadiationEnergy()(vals, durations)

Integrate flux values over durations into energy in MJ m-2.

# Arguments

- `vals::AbstractVector{<:Real}`: flux values in W m-2.
- `durations::AbstractVector{<:Real}`: durations in seconds or in `Dates.TimePeriod` (*e.g.* `Dates.Day`, `Dates.Minute`...).
"""
function (::RadiationEnergy)(vals::AbstractVector{<:Real}, durations::AbstractVector{<:Real})
    # W m-2 integrated over seconds -> MJ m-2
    return sum(v * d for (v, d) in zip(vals, durations)) * 1.0e-6
end

function (::RadiationEnergy)(vals::AbstractVector{<:Real}, durations::AbstractVector{<:Dates.TimePeriod})
    return sum(v * Dates.toms(d) * 1e3 for (v, d) in zip(vals, durations)) * 1.0e-6
end

"""
    (RadiationEnergy())(vals)

Erroring fallback for duration-free reductions.

Use `(RadiationEnergy())(vals, durations)` in weather sampling contexts.
"""
function (::RadiationEnergy)(vals::AbstractVector{<:Real})
    error("`RadiationEnergy` requires durations. Use it only in weather sampling contexts.")
end

"""
    AbstractSamplingWindow

Abstract supertype for weather window selectors used by [`MeteoSamplingSpec`](@ref).
"""
abstract type AbstractSamplingWindow end

"""
    RollingWindow()

Trailing window selector for [`sample_weather`](@ref).
The selected indices are driven by `spec.dt` and `spec.phase` from [`MeteoSamplingSpec`](@ref).
"""
struct RollingWindow <: AbstractSamplingWindow end

"""
    CalendarWindow

Calendar-based window selector used by [`MeteoSamplingSpec`](@ref).

# Fields

- `period::Symbol`: calendar period (`:day`, `:week`, or `:month`).
- `anchor::Symbol`: period anchor (`:current_period` or `:previous_complete_period`).
- `week_start::Int`: first day of week in `1:7` (`1=Monday`, `7=Sunday`).
- `completeness::Symbol`: handling of partial periods (`:allow_partial` or `:strict`).
"""
struct CalendarWindow <: AbstractSamplingWindow
    period::Symbol
    anchor::Symbol
    week_start::Int
    completeness::Symbol
end

"""
    CalendarWindow(period; anchor=:current_period, week_start=1, completeness=:allow_partial)

Build a [`CalendarWindow`](@ref) with validation.

# Arguments

- `period::Symbol`: one of `:day`, `:week`, `:month`.
- `anchor::Symbol`: one of `:current_period`, `:previous_complete_period`.
- `week_start::Int`: integer in `1:7` (`1=Monday`, `7=Sunday`).
- `completeness::Symbol`: one of `:allow_partial`, `:strict`.

# Errors

Throws if any argument is outside the allowed set.
"""
function CalendarWindow(
    period::Symbol;
    anchor::Symbol=:current_period,
    week_start::Int=1,
    completeness::Symbol=:allow_partial
)
    period in (:day, :week, :month) || error(
        "Unsupported calendar period `$(period)`. Allowed values are :day, :week, :month."
    )
    anchor in (:current_period, :previous_complete_period) || error(
        "Unsupported calendar anchor `$(anchor)`. Allowed values are :current_period, :previous_complete_period."
    )
    1 <= week_start <= 7 || error(
        "Invalid `week_start=$(week_start)`. Allowed values are integers in 1:7 (1=Monday, 7=Sunday)."
    )
    completeness in (:allow_partial, :strict) || error(
        "Unsupported completeness mode `$(completeness)`. Allowed values are :allow_partial, :strict."
    )
    return CalendarWindow(period, anchor, Int(week_start), completeness)
end

"""
    MeteoSamplingSpec(dt, phase=0.0; window=RollingWindow())

Sampling specification used to aggregate fine-step weather into a model clock window.
`dt` and `phase` are expressed in base weather timesteps.
`window` selects how weather rows are selected before reducers are applied.
"""
struct MeteoSamplingSpec{T<:Real,W<:AbstractSamplingWindow}
    dt::T
    phase::T
    window::W
end

"""
    MeteoSamplingSpec(dt, phase; window=RollingWindow())

Build a typed sampling spec for [`sample_weather`](@ref).

# Arguments

- `dt::Real`: window size in source weather timesteps.
- `phase::Real`: model phase offset in source weather timesteps.
- `window::AbstractSamplingWindow`: window selector, usually [`RollingWindow`](@ref)
  or [`CalendarWindow`](@ref).
"""
function MeteoSamplingSpec(dt::Real, phase::Real; window::AbstractSamplingWindow=RollingWindow())
    T = promote_type(typeof(dt), typeof(phase))
    return MeteoSamplingSpec{T,typeof(window)}(T(dt), T(phase), window)
end

"""
    MeteoSamplingSpec(dt; window=RollingWindow())

Convenience constructor equivalent to `MeteoSamplingSpec(dt, 0.0; window=window)`.
"""
MeteoSamplingSpec(dt::Real; window::AbstractSamplingWindow=RollingWindow()) = MeteoSamplingSpec(dt, zero(dt); window=window)

"""
    MeteoTransform(target; source=target, reducer=MeanWeighted())

One weather transformation rule used by [`PlantMeteo.sample_weather`](@ref).
"""
struct MeteoTransform{R}
    target::Symbol
    source::Symbol
    reducer::R
end

"""
    MeteoTransform(target; source=target, reducer=MeanWeighted())

Build a transform rule consumed by [`sample_weather`](@ref).

# Arguments

- `target::Symbol`: output variable name in sampled weather.
- `source::Symbol`: input variable name read from source rows.
- `reducer`: reducer instance used on windowed values.
"""
MeteoTransform(target::Symbol; source::Symbol=target, reducer=MeanWeighted()) = MeteoTransform(target, source, reducer)

"""
    PreparedWeather(weather; transforms=default_sampling_transforms(), lazy=true)

Container holding a fine-step weather table and lazy sampling cache.
"""
mutable struct PreparedWeather{W,T,C,WC}
    weather::W
    transforms::T
    cache::C
    window_cache::WC
    lazy::Bool
end

"""
    PreparedWeather(weather; transforms=default_sampling_transforms(), lazy=true)

Build a sampler container used by [`sample_weather`](@ref).

# Arguments

- `weather`: source weather table (`TimeStepTable{Atmosphere}` or compatible rows).
- `transforms`: transform specification accepted by [`normalize_sampling_transforms`](@ref).
- `lazy::Bool`: enable memoization cache for repeated sampling queries.
"""
function PreparedWeather(weather; transforms=default_sampling_transforms(), lazy::Bool=true)
    normalized = normalize_sampling_transforms(transforms)
    PreparedWeather(
        weather,
        normalized,
        Dict{Tuple{Int,UInt64,UInt64},Any}(),
        Dict{UInt64,Any}(),
        lazy
    )
end

"""
    prepare_weather_sampler(weather; transforms=default_sampling_transforms(), lazy=true)

Build the [`PreparedWeather`](@ref) container holding a fine-step weather table and lazy sampling cache.

# Arguments

- `weather`: source weather table.
- `transforms`: transform specification accepted by [`normalize_sampling_transforms`](@ref).
- `lazy::Bool`: enable/disable sampling cache.
"""
prepare_weather_sampler(weather; transforms=default_sampling_transforms(), lazy::Bool=true) =
    PreparedWeather(weather; transforms=transforms, lazy=lazy)

"""
    _duration_seconds(d)

Convert a duration-like value to seconds.

# Arguments

- `d`: a `Dates.Period`, a real value already in seconds, or another value.

# Returns

`Float64` seconds. Unknown types fall back to `1.0`.
"""
function _duration_seconds(d)
    if d isa Dates.Period
        return Dates.toms(d) * 1.0e-3
    elseif d isa Real
        return d
    end
    return 1.0
end

"""
    _duration_period_from_seconds(sec)

Convert seconds to a `Dates.Millisecond` period used in sampled outputs.

# Arguments

- `sec::Float64`: duration in seconds.
"""
function _duration_period_from_seconds(sec::Float64)
    ms = round(Int, sec * 1000.0)
    return Dates.Millisecond(ms)
end

"""
    _window_bounds(step, spec)

Compute inclusive trailing bounds `(start, stop)` for a [`RollingWindow`](@ref).

# Arguments

- `step::Int`: current weather index.
- `spec::MeteoSamplingSpec`: sampling spec containing `dt`.
"""
function _window_bounds(step::Int, spec::MeteoSamplingSpec)
    dt = spec.dt
    dt <= 1.0 && return step, step
    start = Int(floor(step - dt + 1.0 + 1.0e-8))
    return max(1, start), step
end

"""
    _week_start_date(d, week_start)

Return the civil week start date containing `d`.

# Arguments

- `d::Dates.Date`: date to classify.
- `week_start::Int`: week start day in `1:7` (`1=Monday`, `7=Sunday`).
"""
function _week_start_date(d::Dates.Date, week_start::Int)
    offset = mod(Dates.dayofweek(d) - week_start, 7)
    return d - Dates.Day(offset)
end

"""
    _period_key(dt, window)

Map a `DateTime` to the canonical period key used by [`CalendarWindow`](@ref).

# Arguments

- `dt::Dates.DateTime`: timestamp to classify.
- `window::CalendarWindow`: window configuration (day/week/month).
"""
function _period_key(dt::Dates.DateTime, window::CalendarWindow)
    d = Dates.Date(dt)
    if window.period == :day
        return d
    elseif window.period == :week
        return _week_start_date(d, window.week_start)
    elseif window.period == :month
        return Dates.Date(Dates.year(d), Dates.month(d), 1)
    end
    error("Unsupported calendar period `$(window.period)`.")
end

"""
    _expected_period_seconds(period_key, window)

Return expected duration in seconds for a complete calendar period.

# Arguments

- `period_key::Dates.Date`: canonical period key from `_period_key`.
- `window::CalendarWindow`: window configuration.
"""
function _expected_period_seconds(period_key::Dates.Date, window::CalendarWindow)
    if window.period == :day
        return 86400.0
    elseif window.period == :week
        return 7.0 * 86400.0
    elseif window.period == :month
        return Dates.daysinmonth(period_key) * 86400.0
    end
    error("Unsupported calendar period `$(window.period)`.")
end

"""
    _build_calendar_window_cache(prepared, window)

Precompute per-step indices and completeness flags for [`CalendarWindow`](@ref) sampling.

# Arguments

- `prepared::PreparedWeather`: source weather container.
- `window::CalendarWindow`: calendar window settings.

# Returns

Named tuple with:
- `indices_by_step::Vector{Vector{Int}}`
- `complete_by_step::Vector{Bool}`
"""
function _build_calendar_window_cache(prepared::PreparedWeather, window::CalendarWindow)
    weather = prepared.weather
    n = length(weather)
    period_keys = Vector{Dates.Date}(undef, n)
    groups = Dict{Dates.Date,Vector{Int}}()
    duration_sums = Dict{Dates.Date,Float64}()

    for i in 1:n
        row = weather[i]
        hasproperty(row, :date) || error(
            "CalendarWindow sampling requires `date` in weather rows. Missing at index $(i)."
        )
        dt = getproperty(row, :date)
        dt isa Dates.DateTime || error(
            "CalendarWindow sampling requires `date::DateTime`. Got `$(typeof(dt))` at index $(i)."
        )
        key = _period_key(dt, window)
        period_keys[i] = key
        push!(get!(groups, key, Int[]), i)
        dur = hasproperty(row, :duration) ? _duration_seconds(getproperty(row, :duration)) : 1.0
        duration_sums[key] = get(duration_sums, key, 0.0) + dur
    end

    ordered_keys = sort!(collect(keys(groups)))
    prev_key = Dict{Dates.Date,Union{Dates.Date,Nothing}}()
    last_key = nothing
    for k in ordered_keys
        prev_key[k] = last_key
        last_key = k
    end

    indices_by_step = Vector{Vector{Int}}(undef, n)
    complete_by_step = Vector{Bool}(undef, n)
    for i in 1:n
        current_key = period_keys[i]
        selected_key = if window.anchor == :current_period
            current_key
        else
            prev_key[current_key]
        end

        if isnothing(selected_key)
            indices_by_step[i] = Int[]
            complete_by_step[i] = false
            continue
        end

        idxs = groups[selected_key]
        indices_by_step[i] = idxs
        expected = _expected_period_seconds(selected_key, window)
        actual = duration_sums[selected_key]
        complete_by_step[i] = isapprox(actual, expected; atol=1.0e-6, rtol=0.0)
    end

    return (; indices_by_step, complete_by_step)
end

"""
    _window_indices(prepared, step, spec)

Return source weather indices selected for one sampling query.

# Arguments

- `prepared::PreparedWeather`: source weather container.
- `step::Int`: current weather index.
- `spec::MeteoSamplingSpec`: sampling specification.
"""
function _window_indices(prepared::PreparedWeather, step::Int, spec::MeteoSamplingSpec)
    window = spec.window
    if window isa RollingWindow
        start, stop = _window_bounds(step, spec)
        return collect(start:stop)
    elseif window isa CalendarWindow
        key = UInt64(hash(window))
        if !haskey(prepared.window_cache, key)
            prepared.window_cache[key] = _build_calendar_window_cache(prepared, window)
        end
        info = prepared.window_cache[key]
        idxs = info.indices_by_step[step]
        complete = info.complete_by_step[step]

        if isempty(idxs)
            if window.completeness == :strict
                error(
                    "No period available for CalendarWindow(period=$(window.period), anchor=$(window.anchor)) at weather step $(step)."
                )
            end
            return [step]
        end

        if window.completeness == :strict && !complete
            error(
                "Incomplete $(window.period) period for CalendarWindow(period=$(window.period), anchor=$(window.anchor)) at weather step $(step)."
            )
        end

        return idxs
    end

    error("Unsupported sampling window type `$(typeof(window))`.")
end

"""
    _transform_signature(transforms)

Compute a deterministic hash signature for transform rules used in cache keys.

# Arguments

- `transforms::AbstractVector{MeteoTransform}`: normalized transform rules.
"""
function _transform_signature(transforms::AbstractVector{MeteoTransform})
    h = hash(length(transforms))
    for t in transforms
        h = hash((h, t.target, t.source, t.reducer))
    end
    return UInt64(h)
end

"""
    _default_radiation_flux_vars()

Return default radiation source variable names used by [`default_sampling_transforms`](@ref).
"""
function _default_radiation_flux_vars()
    (
        :Ri_SW_f,
        :Ri_PAR_f,
        :Ri_NIR_f,
        :Ri_TIR_f,
        :Ri_custom_f,
    )
end

"""
    default_sampling_transforms(; radiation_mode=:both)

Default weather sampling rules.

`radiation_mode` controls how radiation targets are emitted:
- `:flux_mean`: duration-weighted mean flux (same units as source)
- `:energy_sum`: integrated quantity in MJ m-2 over the sampling window
- `:both`: keep `Ri_*_f` as weighted-mean flux and also emit `Ri_*_q` quantities

# Arguments

- `radiation_mode::Symbol`: one of `:flux_mean`, `:energy_sum`, `:both`.

# Returns

`Vector{MeteoTransform}` used by [`PreparedWeather`](@ref) and [`sample_weather`](@ref).
"""
function default_sampling_transforms(; radiation_mode::Symbol=:both)
    radiation_mode in (:flux_mean, :energy_sum, :both) || error(
        "Unsupported radiation_mode `$(radiation_mode)`. Allowed values are :flux_mean, :energy_sum, :both."
    )

    transforms = MeteoTransform[
        MeteoTransform(:T; reducer=MeanWeighted()),
        MeteoTransform(:Tmin; source=:T, reducer=MinReducer()),
        MeteoTransform(:Tmax; source=:T, reducer=MaxReducer()),
        MeteoTransform(:Wind; reducer=MeanWeighted()),
        MeteoTransform(:P; reducer=MeanWeighted()),
        MeteoTransform(:Rh; reducer=MeanWeighted()),
        MeteoTransform(:Rhmin; source=:Rh, reducer=MinReducer()),
        MeteoTransform(:Rhmax; source=:Rh, reducer=MaxReducer()),
        MeteoTransform(:Precipitations; reducer=SumReducer()),
        MeteoTransform(:Cₐ; reducer=MeanWeighted()),
        MeteoTransform(:e; reducer=MeanWeighted()),
        MeteoTransform(:eₛ; reducer=MeanWeighted()),
        MeteoTransform(:VPD; reducer=MeanWeighted()),
        MeteoTransform(:ρ; reducer=MeanWeighted()),
        MeteoTransform(:λ; reducer=MeanWeighted()),
        MeteoTransform(:γ; reducer=MeanWeighted()),
        MeteoTransform(:ε; reducer=MeanWeighted()),
        MeteoTransform(:Δ; reducer=MeanWeighted()),
        MeteoTransform(:clearness; reducer=MeanWeighted()),
    ]

    for var in _default_radiation_flux_vars()
        if radiation_mode == :energy_sum
            push!(transforms, MeteoTransform(var; source=var, reducer=RadiationEnergy()))
        else
            push!(transforms, MeteoTransform(var; source=var, reducer=MeanWeighted()))
        end
    end

    if radiation_mode == :both
        for var in _default_radiation_flux_vars()
            q = Symbol(replace(String(var), "_f" => "_q"))
            push!(transforms, MeteoTransform(q; source=var, reducer=RadiationEnergy()))
        end
    end

    return transforms
end

"""
    _normalize_reducer(reducer)

Normalize user reducer definitions into a callable reducer object.

# Arguments

- `reducer`: reducer instance/type or callable.

# Returns

- Reducer instance when input is a reducer type.
- Reducer/callable unchanged when already instantiated.
"""
function _normalize_reducer(reducer)
    if reducer isa DataType
        reducer <: AbstractTimeReducer || error(
            "Unsupported reducer type `$(reducer)`. ",
            "Expected a subtype of `AbstractTimeReducer` or a callable."
        )
        return reducer()
    elseif reducer isa AbstractTimeReducer
        return reducer
    elseif reducer isa Function
        return reducer
    end

    error(
        "Unsupported reducer value `$(reducer)` of type `$(typeof(reducer))`. ",
        "Use a reducer instance/type (subtype of `AbstractTimeReducer`) or a callable."
    )
end

"""
    _normalize_single_transform(target, rule)

Normalize one transform specification entry into a [`MeteoTransform`](@ref).

# Arguments

- `target::Symbol`: output variable name.
- `rule`: reducer-like value or named tuple with optional `source` and `reducer`.
"""
function _normalize_single_transform(target::Symbol, rule)
    if rule isa NamedTuple
        src = haskey(rule, :source) ? Symbol(rule.source) : target
        reducer = haskey(rule, :reducer) ? _normalize_reducer(rule.reducer) : MeanWeighted()
        return MeteoTransform(target; source=src, reducer=reducer)
    end

    return MeteoTransform(target; source=target, reducer=_normalize_reducer(rule))
end

"""
    normalize_sampling_transforms(transforms)

Normalize user-provided weather transform definitions into `Vector{MeteoTransform}`.

Accepted inputs are:
- `Vector{MeteoTransform}` (copied as-is)
- `NamedTuple` where each key is the target variable and each value is either:
  - a reducer (`AbstractTimeReducer` instance/type, or callable), or
  - a named tuple with optional `source` and `reducer` fields
- `AbstractVector` containing only `MeteoTransform` entries

This is the canonical parser used by [`PreparedWeather`](@ref) and
[`sample_weather`](@ref) to validate and materialize transform rules.

# Arguments

- `transforms`: user transform specification (named tuple or vector forms).

# Returns

`Vector{MeteoTransform}`.
"""
function normalize_sampling_transforms(transforms::AbstractVector{MeteoTransform})
    return collect(transforms)
end

function normalize_sampling_transforms(transforms::NamedTuple)
    out = MeteoTransform[]
    for (target, rule) in pairs(transforms)
        push!(out, _normalize_single_transform(Symbol(target), rule))
    end
    return out
end

function normalize_sampling_transforms(transforms::AbstractVector)
    out = MeteoTransform[]
    for t in transforms
        if t isa MeteoTransform
            push!(out, t)
        else
            error("Unsupported transform element type `$(typeof(t))`.")
        end
    end
    return out
end

"""
    _reduce_values(vals, durations, reducer)

Apply one reducer to sampled values and optional durations.

# Arguments

- `vals::AbstractVector`: sampled source values for one transform.
- `durations::AbstractVector{<:Real}`: per-value durations in seconds.
- `reducer`: normalized reducer instance or callable.

# Returns

Reduced value, or `nothing` when reduction is not possible (for example non-real values
with real-only reducers).
"""
function _reduce_values(vals::AbstractVector, durations::AbstractVector{<:Real}, reducer)
    isempty(vals) && return nothing
    if reducer isa AbstractTimeReducer
        if reducer isa Union{FirstReducer,LastReducer}
            return reducer(vals, durations)
        end
        all(v -> v isa Real, vals) || return nothing
        vals_real = float.(vals)
        if applicable(reducer, vals_real, durations)
            return reducer(vals_real, durations)
        elseif applicable(reducer, vals_real)
            return reducer(vals_real)
        end
    else
        if applicable(reducer, vals, durations)
            return reducer(vals, durations)
        elseif applicable(reducer, vals)
            return reducer(vals)
        end
    end

    error("Reducer `$(reducer)` is not callable on sampled weather values.")
end

"""
    _sample_weather_uncached(prepared, step, spec, transforms)

Compute one sampled weather row without using/setting cache.

# Arguments

- `prepared::PreparedWeather`: source weather container.
- `step::Int`: index of the current source weather row.
- `spec::MeteoSamplingSpec`: sampling specification.
- `transforms::AbstractVector{MeteoTransform}`: normalized transform rules.

# Returns

`Atmosphere` sampled at `step`.
"""
function _sample_weather_uncached(
    prepared::PreparedWeather,
    step::Int,
    spec::MeteoSamplingSpec,
    transforms::AbstractVector{MeteoTransform}
)
    weather = prepared.weather
    1 <= step <= length(weather) || error("Invalid weather step $(step), expected 1 <= step <= $(length(weather)).")
    indices = _window_indices(prepared, step, spec)
    rows = [weather[i] for i in indices]
    current = weather[step]
    durations = [
        hasproperty(r, :duration) ? _duration_seconds(getproperty(r, :duration)) : 1.0
        for r in rows
    ]

    sampled = Dict{Symbol,Any}()
    for tr in transforms
        vals = Any[]
        durs = Float64[]
        for (r, d) in zip(rows, durations)
            hasproperty(r, tr.source) || continue
            push!(vals, getproperty(r, tr.source))
            push!(durs, d)
        end
        isempty(vals) && continue
        v = _reduce_values(vals, durs, tr.reducer)
        isnothing(v) && continue
        sampled[tr.target] = v
    end

    sampled[:date] = hasproperty(current, :date) ? getproperty(current, :date) : Dates.now()
    sampled[:duration] = _duration_period_from_seconds(sum(durations))

    # Required core variables for Atmosphere
    sampled[:T] = get(sampled, :T, hasproperty(current, :T) ? getproperty(current, :T) : error("Missing required meteo variable :T"))
    sampled[:Wind] = get(sampled, :Wind, hasproperty(current, :Wind) ? getproperty(current, :Wind) : error("Missing required meteo variable :Wind"))
    sampled[:Rh] = get(sampled, :Rh, hasproperty(current, :Rh) ? getproperty(current, :Rh) : error("Missing required meteo variable :Rh"))
    sampled[:P] = get(sampled, :P, hasproperty(current, :P) ? getproperty(current, :P) : DEFAULTS.P)

    keys_sorted = sort!(collect(keys(sampled)))
    kwargs = (; (k => sampled[k] for k in keys_sorted)...)
    return Atmosphere(; check=false, kwargs...)
end

"""
    sample_weather(prepared, step; spec=MeteoSamplingSpec(1.0, 0.0), transforms=nothing)

Sample one aggregated weather row at `step` from a [`PreparedWeather`](@ref) sampler.

# Arguments

- `prepared::PreparedWeather`: output of [`prepare_weather_sampler`](@ref), holding source weather and optional cache.
- `step::Int`: 1-based index in the original fine-step weather table.

# Keyword arguments

- `spec::MeteoSamplingSpec`: window definition and phase used to select rows before reduction.
  The default `MeteoSamplingSpec(1.0, 0.0)` behaves as an identity window.
- `transforms`: optional transform override for this call.
  If `nothing`, uses `prepared.transforms`; otherwise accepted by
  [`normalize_sampling_transforms`](@ref) (e.g. `NamedTuple` or `Vector{MeteoTransform}`).

# Returns

An `Atmosphere` instance built from reduced variables over the selected window.
When `prepared.lazy == true`, results are memoized by `(step, spec, transforms)` and reused on repeated calls.
"""
function sample_weather(
    prepared::PreparedWeather,
    step::Int;
    spec::MeteoSamplingSpec=MeteoSamplingSpec(1.0, 0.0),
    transforms=nothing
)
    rules = isnothing(transforms) ? prepared.transforms : normalize_sampling_transforms(transforms)
    spec_sig = UInt64(hash((spec.dt, spec.phase, spec.window)))
    tr_sig = _transform_signature(rules)
    key = (step, spec_sig, tr_sig)

    if prepared.lazy && haskey(prepared.cache, key)
        return prepared.cache[key]
    end

    sampled = _sample_weather_uncached(prepared, step, spec, rules)
    if prepared.lazy
        prepared.cache[key] = sampled
    end
    return sampled
end

"""
    materialize_weather(prepared; specs, transforms=nothing)

Precompute sampled weather tables for a set of sampling specs.
Returns `Dict{MeteoSamplingSpec,TimeStepTable{Atmosphere}}`.

# Arguments

- `prepared::PreparedWeather`: sampler state containing source weather.
- `specs`: iterable collection of [`MeteoSamplingSpec`](@ref).
- `transforms`: optional transform override applied to all specs.
"""
function materialize_weather(prepared::PreparedWeather; specs, transforms=nothing)
    tables = Dict{MeteoSamplingSpec,TimeStepTable{Atmosphere}}()
    for spec in specs
        rows = Atmosphere[
            sample_weather(prepared, i; spec=spec, transforms=transforms)
            for i in 1:length(prepared.weather)
        ]
        tables[spec] = TimeStepTable(rows, metadata(prepared.weather))
    end
    return tables
end
