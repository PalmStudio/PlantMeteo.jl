"""
    read_weather(
        file[,args...];
        date_format = DateFormat("yyyy-mm-ddTHH:MM:SS.s"),
        date_formats = nothing,
        hour_format = DateFormat("HH:MM:SS"),
        duration = nothing,
        forward_fill_date = false,
    )

Read a meteo file. The meteo file is a CSV, and optionnaly with metadata in a header formatted
as a commented YAML. The column names **and units** should match exactly the fields of
[`Atmosphere`](https://palmstudio.github.io/PlantMeteo.jl/stable/#PlantMeteo.Atmosphere), or 
the user should provide their transformation as arguments (`args`) with the `DataFrames.jl` form, *i.e.*: 
- `:var_name => (x -> x .+ 1) => :new_name`: the variable `:var_name` is transformed by the function 
    `x -> x .+ 1` and renamed to `:new_name`
- `:var_name => :new_name`: the variable `:var_name` is renamed to `:new_name`
- `:var_name`: the variable `:var_name` is kept as is

# Note

The variables found in the file will be used *as is* if not transformed, and not recomputed
from the other variables. Please check that all variables have the same units as in the
[`Atmosphere`](https://palmstudio.github.io/PlantMeteo.jl/stable/#PlantMeteo.Atmosphere) structure.

# Arguments

- `file::String`: path to a meteo file
- `args...`: A list of arguments to transform the table. See above to see the possible forms.
- `date_format = DateFormat("yyyy-mm-ddTHH:MM:SS.s")`: the format for the `DateTime` columns
- `date_formats = nothing`: optional fallback date formats tried after `date_format`
- `hour_format = DateFormat("HH:MM:SS")`: the format for the `Time` columns (*e.g.* `hour_start`)
- `duration`: a function to parse the `duration` column if present in the file. Usually `Dates.Day` or `Dates.Minute`.
If the column is absent, the duration will be computed using the `hour_format` and the `hour_start` and `hour_end` columns
along with the `date` column.
- `forward_fill_date = false`: if `true`, missing dates are replaced by the previous parsed date.

# Examples

```julia
using PlantMeteo, Dates

file = joinpath(dirname(dirname(pathof(PlantMeteo))),"test","data","meteo.csv")

meteo = read_weather(
    file,
    :temperature => :T,
    :relativeHumidity => (x -> x ./100) => :Rh,
    :wind => :Wind,
    :atmosphereCO2_ppm => :Cₐ,
    date_format = DateFormat("yyyy/mm/dd")
)
```
"""
function read_weather(
    file, args...;
    date_format=Dates.DateFormat("yyyy-mm-ddTHH:MM:SS.s"),
    date_formats=nothing,
    hour_format=Dates.DateFormat("HH:MM:SS"),
    duration=nothing,
    forward_fill_date::Bool=false,
)

    arguments = (args...,)
    data, metadata_ = read_weather_(file)

    # Apply the transformations eventually given by the user:
    data = transform_columns(data, arguments...)

    date = _compute_date_with_fallback(data, date_format, date_formats, hour_format; forward_fill_date=forward_fill_date)
    data = set_column(data, :date, date)
    data = set_column(data, :duration, compute_duration(data, hour_format, duration))

    # Rename the columns to the PlantMeteo convention (if any):
    data = standardize_columns!(ToPlantMeteoColumns(), data)

    # If there's a "use" field in the YAML, parse it and rename it:
    if haskey(metadata_, "use")
        # Old format (deprecated, but used by ARCHIMED) uses "use" => "clearness, test"
        # instead of a proper YAML list. So we have to parse it:
        if isa(metadata_["use"], String)
            splitted_use = split(metadata_["use"], r"[,\s]")
            metadata_["use"] = Symbol.(splitted_use[findall(x -> length(x) > 0, splitted_use)])
        end

        replacements = Pair{Symbol,Symbol}[]
        for i in arguments
            i isa Pair || continue
            new_name =
                if i.second isa Pair
                    i.second.second
                elseif i.second isa Symbol
                    i.second
                else
                    i.first
                end
            push!(replacements, i.first => new_name)
        end
        length(replacements) > 0 && replace!(metadata_["use"], replacements...)
    end
    # NB: the "use" field is not used in PlantMeteo, but it is still correctly parsed.

    return Weather(data, (; zip(Symbol.(keys(metadata_)), values(metadata_))...))
end

function _compute_date_with_fallback(data, date_format, date_formats, hour_format; forward_fill_date::Bool=false)
    formats = Dates.DateFormat[date_format]
    if date_formats !== nothing
        if date_formats isa Dates.DateFormat
            push!(formats, date_formats)
        else
            append!(formats, collect(date_formats))
        end
    end

    # Keep first occurrence order while removing duplicates.
    uniq_formats = Dates.DateFormat[]
    seen = Set{String}()
    for fmt in formats
        k = string(fmt)
        k in seen && continue
        push!(seen, k)
        push!(uniq_formats, fmt)
    end

    last_err = nothing
    for fmt in uniq_formats
        try
            return compute_date(data, fmt, hour_format; forward_fill_date=forward_fill_date)
        catch err
            last_err = err
        end
    end

    last_err === nothing && error("No date format provided.")
    throw(last_err)
end

function _parse_date_cell(v, date_format)
    v === missing && return missing
    if v isa Dates.DateTime
        return Dates.Date(v)
    elseif v isa Dates.Date
        return v
    end
    s = strip(string(v))
    (isempty(s) || lowercase(s) == "missing") && return missing
    return Dates.Date(s, date_format)
end

function _parse_date_column(date_col, date_format)
    out = Vector{Union{Missing,Dates.Date}}(undef, length(date_col))
    for i in eachindex(date_col)
        out[i] = _parse_date_cell(date_col[i], date_format)
    end
    return out
end

function _combine_date_and_hour(date_col, hour_col, hour_format)
    out = Vector{Union{Missing,Dates.DateTime}}(undef, length(date_col))
    for i in eachindex(date_col)
        d = date_col[i]
        if d === missing
            out[i] = missing
        else
            out[i] = d + parse_hour(hour_col[i], hour_format)
        end
    end
    return out
end

function _forward_fill_dates(date_col)
    out = collect(date_col)
    last_seen = nothing
    for i in eachindex(out)
        if out[i] === missing
            last_seen === nothing || (out[i] = last_seen)
        else
            last_seen = out[i]
        end
    end
    return out
end

function read_weather_(file)
    yaml_data = open(file, "r") do io
        yaml_data = ""
        is_yaml = true
        while is_yaml
            line = readline(io, keep=true)
            if line[1:2] == "#'"
                yaml_data *= lstrip(line[3:end])
            else
                is_yaml = false
            end
        end
        return yaml_data
    end

    metadata_ = length(yaml_data) > 0 ? YAML.load(yaml_data) : Dict()
    push!(metadata_, "file" => file)

    met_data = Tables.columntable(CSV.File(file; comment="#"))

    (data=met_data, metadata_=metadata_)
end

"""
    compute_date(data, date_format, hour_format; forward_fill_date=false)

Compute the `date` column depending on several cases:

- If it is already in data and is a `DateTime`, does nothing.
- If it is a `String`, tries and parse it using a user-input `DateFormat`
- If it is a `Date`, return it as is, or try to make it a `DateTime` if there's a column named
`hour_start`

# Arguments

- `data`: any `Tables.jl` compatible table, such as a `DataFrame`
- `date_format`: a `DateFormat` to parse the `date` column if it is a `String`
- `hour_format`: a `DateFormat` to parse the `hour_start` column if it is a `String`
- `forward_fill_date`: when `true`, missing dates are filled with the previous non-missing date
"""
function compute_date(
    data,
    date_format=Dates.DateFormat("yyyy-mm-ddTHH:MM:SS.s"),
    hour_format=Dates.DateFormat("HH:MM:SS"),
    ;
    forward_fill_date::Bool=false,
)
    hasproperty(data, :date) || error("The `date` column is missing from the weather data.")

    date = data.date
    if !(typeof(date[1]) == Dates.DateTime || typeof(date[1]) == Dates.Date)
        # There's a "date" column but it is not a DateTime or a Date.
        date = try
            _parse_date_column(date, date_format)
        catch e
            error(
                "The values in the `date` column cannot be parsed.",
                " Please check the format of the dates or provide the format as argument.\n",
                e
            )
        end
    end

    forward_fill_date && (date = _forward_fill_dates(date))

    first_idx = findfirst(x -> x !== missing, date)
    if first_idx !== nothing && hasproperty(data, :hour_start)
        first_val = date[first_idx]
        if first_val isa Dates.Date
            date = try
                _combine_date_and_hour(date, data.hour_start, hour_format)
            catch e
                error(
                    "The values in the `hour_start` column cannot be parsed.",
                    " Please check the format of the hours or provide the format as argument.",
                    e
                )
            end
        end
    end

    return date
end


"""
    compute_duration(data, hour_format, duration)

Compute the `duration` column depending on several cases:

- If it is already in the data, use the `duration` function to parse it into a `Date.Period`.
- If it is not, but there's a column named `hour_end` and another one either called `hour_start`
or `date`, compute the duration from the period between `hour_start` (or `date`) and `hour_end`.

# Arguments

- `data`: any `Tables.jl` compatible table, such as a `DataFrame`
- `hour_format`: a `DateFormat` to parse the `hour_start` and `hour_end` columns if they are `String`s.
- `duration`: a function to parse the `duration` column. Usually `Dates.Day` or `Dates.Minute`.
"""
function compute_duration(data, hour_format=Dates.DateFormat("HH:MM:SS"), duration=nothing)

    if hasproperty(data, :duration)
        duration === nothing && error("The `duration` column is already in the data, please provide the `duration` argument")

        # If the duration is a String, we try to parse it as a Period with the user-defined format:
        # time period unit
        duration = try
            duration.(data.duration)
        catch e
            error(
                "The values in the `duration` column cannot be parsed.",
                " Please check the format of the durations or provide the period unit as argument (e.g. Dates.Minute).",
                e
            )
        end
    elseif hasproperty(data, :hour_end) && !hasproperty(data, :duration)
        hour_end = parse_hour.(data.hour_end, hour_format)

        if hasproperty(data, :hour_start)
            hour_start = parse_hour.(data.hour_start, hour_format)
            duration = Dates.canonicalize.(hour_end .- hour_start)
        elseif hasproperty(data, :date)
            duration = Dates.canonicalize.(hour_end .- Dates.Time.(data.date))
        end
    else
        # No `hour_end` in the data, we compute the duration as the difference between two consecutive
        # time steps:
        if hasproperty(data, :DateTime)
            duration = timesteps_durations(data.DateTime)
        elseif hasproperty(data, :date) && isa(data.date[1], Dates.DateTime)
            duration = timesteps_durations(data.date)
        elseif hasproperty(data, :date) && data.date[1] == Dates.Date && hasproperty(data, :hour_start)
            hour_start = parse_hour.(data.hour_start, hour_format)
            duration = timesteps_durations(data.date .+ hour_start)
        else
            error(
                "The `duration` column cannot be computed because of a lack of information.",
                " Please provide `date` as a DateTime or `hour_end` or `hour_start` columns."
            )
        end
    end

    return duration
end

"""
    parse_hour(h, hour_format=Dates.DateFormat("HH:MM:SS"))

Parse an hour that can be of several formats:
- `Time`: return it as is
- `String`: try to parse it using the user-input `DateFormat`
- `DateTime`: transform it into a `Time`

# Arguments
- `h`: hour to parse
- `hour_format::DateFormat`: user-input format to parse the hours

# Examples

```jldoctest 1
julia> using PlantMeteo, Dates;
```

As a string:

```jldoctest 1
julia> PlantMeteo.parse_hour("12:00:00")
12:00:00
```

As a `Time`:

```jldoctest 1
julia> PlantMeteo.parse_hour(Dates.Time(12, 0, 0))
12:00:00
```

As a `DateTime`:

```jldoctest 1
julia> PlantMeteo.parse_hour(Dates.DateTime(2020, 1, 1, 12, 0, 0))
12:00:00
```
"""
function parse_hour(h, hour_format=Dates.DateFormat("HH:MM:SS"))
    typeof(h) == Dates.Time && return h

    if typeof(h) == String
        try
            h = Dates.Time(h, hour_format)
        catch e
            error(
                "Hour $h cannot be parsed into a Dates.Time with format $hour_format.",
                " Please check the format of the hours or provide the format as argument.",
                e
            )
        end
    end

    # If it is of DateTime type, transform it into a Time:
    if typeof(h) == Dates.DateTime
        h = Dates.Time(h)
    end

    return h
end
