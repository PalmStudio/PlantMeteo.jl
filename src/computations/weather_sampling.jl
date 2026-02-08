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
function (::MeanWeighted)(vals::AbstractVector{<:Real}, durations::AbstractVector{<:Real})
    num = 0.0
    den = 0.0
    for (v, d) in zip(vals, durations)
        num += float(v) * float(d)
        den += float(d)
    end
    den == 0.0 && return nothing
    return num / den
end

(::MeanReducer)(vals::AbstractVector{<:Real}) = Statistics.mean(vals)
(::MeanReducer)(vals::AbstractVector{<:Real}, durations::AbstractVector{<:Real}) = Statistics.mean(vals)

(::SumReducer)(vals::AbstractVector{<:Real}) = sum(vals)
(::SumReducer)(vals::AbstractVector{<:Real}, durations::AbstractVector{<:Real}) = sum(vals)

(::MinReducer)(vals::AbstractVector{<:Real}) = minimum(vals)
(::MinReducer)(vals::AbstractVector{<:Real}, durations::AbstractVector{<:Real}) = minimum(vals)

(::MaxReducer)(vals::AbstractVector{<:Real}) = maximum(vals)
(::MaxReducer)(vals::AbstractVector{<:Real}, durations::AbstractVector{<:Real}) = maximum(vals)

(::FirstReducer)(vals::AbstractVector) = first(vals)
(::FirstReducer)(vals::AbstractVector, durations::AbstractVector{<:Real}) = first(vals)

(::LastReducer)(vals::AbstractVector) = last(vals)
(::LastReducer)(vals::AbstractVector, durations::AbstractVector{<:Real}) = last(vals)

function (::RadiationEnergy)(vals::AbstractVector{<:Real}, durations::AbstractVector{<:Real})
    # W m-2 integrated over seconds -> MJ m-2
    return sum(float(v) * float(d) for (v, d) in zip(vals, durations)) * 1.0e-6
end

function (::RadiationEnergy)(vals::AbstractVector{<:Real})
    error("`RadiationEnergy` requires durations. Use it only in weather sampling contexts.")
end

"""
    RollingWindow()
    CalendarWindow(period, anchor=:current_period, week_start=1, completeness=:allow_partial)

Window selection for weather sampling.
`RollingWindow` uses a trailing rolling window driven by `dt`.
`CalendarWindow` groups rows by civil period (`:day`, `:week`, `:month`).
"""
abstract type AbstractSamplingWindow end

struct RollingWindow <: AbstractSamplingWindow end

struct CalendarWindow <: AbstractSamplingWindow
    period::Symbol
    anchor::Symbol
    week_start::Int
    completeness::Symbol
end

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

function MeteoSamplingSpec(dt::Real, phase::Real; window::AbstractSamplingWindow=RollingWindow())
    T = promote_type(typeof(float(dt)), typeof(float(phase)))
    return MeteoSamplingSpec{T,typeof(window)}(T(dt), T(phase), window)
end

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

MeteoTransform(target::Symbol; source::Symbol=target, reducer=MeanWeighted()) = MeteoTransform(target, source, reducer)

"""
    PreparedWeather(weather; transforms=default_sampling_transforms(), lazy=true)
    prepare_weather_sampler(weather; transforms=default_sampling_transforms(), lazy=true)

Container holding a fine-step weather table and lazy sampling cache.
"""
mutable struct PreparedWeather{W,T,C,WC}
    weather::W
    transforms::T
    cache::C
    window_cache::WC
    lazy::Bool
end

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

prepare_weather_sampler(weather; transforms=default_sampling_transforms(), lazy::Bool=true) =
    PreparedWeather(weather; transforms=transforms, lazy=lazy)

function _duration_seconds(d)
    if d isa Dates.Period
        return float(Dates.toms(d)) * 1.0e-3
    elseif d isa Real
        return float(d)
    end
    return 1.0
end

function _duration_period_from_seconds(sec::Float64)
    ms = round(Int, sec * 1000.0)
    return Dates.Millisecond(ms)
end

function _window_bounds(step::Int, spec::MeteoSamplingSpec)
    dt = float(spec.dt)
    dt <= 1.0 && return step, step
    start = Int(floor(step - dt + 1.0 + 1.0e-8))
    return max(1, start), step
end

function _week_start_date(d::Dates.Date, week_start::Int)
    offset = mod(Dates.dayofweek(d) - week_start, 7)
    return d - Dates.Day(offset)
end

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

function _expected_period_seconds(period_key::Dates.Date, window::CalendarWindow)
    if window.period == :day
        return 86400.0
    elseif window.period == :week
        return 7.0 * 86400.0
    elseif window.period == :month
        return float(Dates.daysinmonth(period_key)) * 86400.0
    end
    error("Unsupported calendar period `$(window.period)`.")
end

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

function _transform_signature(transforms::AbstractVector{MeteoTransform})
    h = hash(length(transforms))
    for t in transforms
        h = hash((h, t.target, t.source, t.reducer))
    end
    return UInt64(h)
end

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

function _normalize_single_transform(target::Symbol, rule)
    if rule isa NamedTuple
        src = haskey(rule, :source) ? Symbol(rule.source) : target
        reducer = haskey(rule, :reducer) ? _normalize_reducer(rule.reducer) : MeanWeighted()
        return MeteoTransform(target; source=src, reducer=reducer)
    end

    return MeteoTransform(target; source=target, reducer=_normalize_reducer(rule))
end

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
    spec_sig = UInt64(hash((float(spec.dt), float(spec.phase), spec.window)))
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
