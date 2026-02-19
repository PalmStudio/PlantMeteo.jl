"""
    duration_seconds(x; field_name="duration", allow_nan=true)

Convert a duration-like value into seconds.

Accepted values are:
- numeric values (already in seconds),
- `Dates.Period`,
- `Dates.Time`,
- `Dates.DateTime`,
- strings formatted as `HH:MM[:SS]`,
- strings parseable as numbers.

When parsing fails, the function returns `NaN` if `allow_nan=true`, otherwise it throws.
"""
function duration_seconds(x; field_name::AbstractString="duration", allow_nan::Bool=true)
    x === missing && return allow_nan ? NaN : error("Invalid $(field_name) value: missing")

    if x isa Number
        return Float64(x)
    elseif x isa Dates.Time
        return Float64(Dates.hour(x) * 3600 + Dates.minute(x) * 60 + Dates.second(x))
    elseif x isa Dates.DateTime
        t = Dates.Time(x)
        return Float64(Dates.hour(t) * 3600 + Dates.minute(t) * 60 + Dates.second(t))
    elseif x isa Dates.Period
        return Dates.toms(x) * 1.0e-3
    end

    s = strip(string(x))
    if isempty(s) || lowercase(s) in ("na", "nan", "missing")
        return allow_nan ? NaN : error("Invalid $(field_name) value: $(repr(x))")
    end

    for fmt in (Dates.DateFormat("HH:MM:SS"), Dates.DateFormat("HH:MM"))
        try
            t = Dates.Time(s, fmt)
            return Float64(Dates.hour(t) * 3600 + Dates.minute(t) * 60 + Dates.second(t))
        catch
        end
    end

    n = tryparse(Float64, s)
    if n === nothing
        return allow_nan ? NaN : error("Invalid $(field_name) value: $(repr(x))")
    end
    return n
end

"""
    positive_duration_seconds(x; field_name="duration")

Convert a duration-like value to seconds and ensure it is finite and strictly positive.
"""
function positive_duration_seconds(x; field_name::AbstractString="duration")
    seconds = duration_seconds(x; field_name=field_name, allow_nan=false)
    if !(isfinite(seconds) && seconds > 0.0)
        error("Invalid $(field_name) value: expected a positive duration, got $(repr(x))")
    end
    return seconds
end

function _parse_time_strict(v, field_name::String)
    v === missing && error("invalid value: missing $(field_name)")
    if v isa Dates.Time
        return v
    elseif v isa Dates.DateTime
        return Dates.Time(v)
    end
    s = strip(string(v))
    isempty(s) && error("invalid value: empty $(field_name)")
    for fmt in (Dates.DateFormat("HH:MM:SS"), Dates.DateFormat("HH:MM"), Dates.DateFormat("H:MM:SS"), Dates.DateFormat("H:MM"))
        try
            return Dates.Time(s, fmt)
        catch
        end
    end
    error("invalid value: cannot parse $(field_name)=$(repr(v))")
end

function _parse_date_or_default(v, default::Dates.Date)
    v === missing && return default
    if v isa Dates.Date
        return v
    elseif v isa Dates.DateTime
        return Dates.Date(v)
    end
    s = strip(string(v))
    (isempty(s) || lowercase(s) == "missing") && return default
    for fmt in (
        Dates.DateFormat("yyyy/mm/dd"),
        Dates.DateFormat("yyyy-mm-dd"),
        Dates.DateFormat("yyyy/mm/ddTHH:MM:SS"),
        Dates.DateFormat("yyyy-mm-ddTHH:MM:SS"),
    )
        try
            return Dates.Date(s, fmt)
        catch
        end
    end
    return default
end

function _first_present_column(row, cols::Tuple{Vararg{Symbol}})
    names = propertynames(row)
    for c in cols
        c in names && return c
    end
    return nothing
end

"""
    row_datetime_interval(
        row;
        index=0,
        date_cols=(:date,),
        start_cols=(:hour_start, :hour),
        end_cols=(:hour_end,),
        duration_cols=(:step_duration, :duration),
        default_date=Date(2000, 1, 1),
        default_duration_seconds=1.0,
        allow_end_rollover=false,
    )

Return `(start_dt, end_dt)` for one timestep row.

`start_dt` is built from `date_cols` + `start_cols`. `end_dt` is taken from `end_cols`,
or derived from `duration_cols`, or from `default_duration_seconds` when no explicit end
is available.
"""
function row_datetime_interval(
    row;
    index::Int=0,
    date_cols::Tuple{Vararg{Symbol}}=(:date,),
    start_cols::Tuple{Vararg{Symbol}}=(:hour_start, :hour),
    end_cols::Tuple{Vararg{Symbol}}=(:hour_end,),
    duration_cols::Tuple{Vararg{Symbol}}=(:step_duration, :duration),
    default_date::Dates.Date=Dates.Date(2000, 1, 1),
    default_duration_seconds::Float64=1.0,
    allow_end_rollover::Bool=false,
)
    start_col = _first_present_column(row, start_cols)
    start_col === nothing && error("invalid value: missing start column at row $(index)")

    date_col = _first_present_column(row, date_cols)
    date = date_col === nothing ? default_date : _parse_date_or_default(getproperty(row, date_col), default_date)

    start_time = _parse_time_strict(getproperty(row, start_col), String(start_col))
    start_dt = Dates.DateTime(date, start_time)

    end_col = _first_present_column(row, end_cols)
    duration_col = _first_present_column(row, duration_cols)

    end_dt =
        if end_col !== nothing
            end_time = _parse_time_strict(getproperty(row, end_col), String(end_col))
            dt = Dates.DateTime(date, end_time)
            if dt < start_dt
                if allow_end_rollover
                    dt += Dates.Day(1)
                else
                    error("end is before start at row $(index)")
                end
            end
            dt
        elseif duration_col !== nothing
            secs = positive_duration_seconds(getproperty(row, duration_col); field_name=String(duration_col))
            start_dt + Dates.Millisecond(round(Int, secs * 1000.0))
        else
            start_dt + Dates.Millisecond(round(Int, default_duration_seconds * 1000.0))
        end

    end_dt > start_dt || error("end is before start at row $(index)")
    return start_dt, end_dt
end

"""
    check_non_overlapping_timesteps(rows; kwargs...)

Validate that each timestep starts at or after the previous timestep end.
Throws an error on the first overlap.
"""
function check_non_overlapping_timesteps(rows; kwargs...)
    prev_end = nothing
    for (i, row) in enumerate(rows)
        start_dt, end_dt = row_datetime_interval(row; index=i, kwargs...)
        if prev_end !== nothing && start_dt < prev_end
            error("overlapping timesteps at row $(i)")
        end
        prev_end = end_dt
    end
    return nothing
end

"""
    select_overlapping_timesteps(rows, start_dt, end_dt; closed=true, kwargs...)

Return rows whose timestep interval overlaps `[start_dt, end_dt]` (`closed=true`)
or `(start_dt, end_dt)` (`closed=false`).
"""
function select_overlapping_timesteps(
    rows,
    start_dt::Dates.DateTime,
    end_dt::Dates.DateTime;
    closed::Bool=true,
    kwargs...,
)
    end_dt >= start_dt || error("invalid range: end datetime is before start datetime")
    out = Vector{eltype(rows)}()
    for (i, row) in enumerate(rows)
        s, e = row_datetime_interval(row; index=i, kwargs...)
        overlaps = closed ? (s <= end_dt && e >= start_dt) : (s < end_dt && e > start_dt)
        overlaps && push!(out, row)
    end
    return out
end
