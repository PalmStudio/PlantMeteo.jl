"""
    read_weather(file[,args...];
        date_format = DateFormat("yyyy-mm-ddTHH:MM:SS.s"),
        hour_format = DateFormat("HH:MM:SS")
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
- `hour_format = DateFormat("HH:MM:SS")`: the format for the `Time` columns (*e.g.* `hour_start`)

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
    hour_format=Dates.DateFormat("HH:MM:SS")
)

    arguments = (args...,)
    data, metadata_ = read_weather_(file)

    data.date = compute_date(data, date_format, hour_format)
    data.duration = compute_duration(data, hour_format)

    # Apply the transformations eventually given by the user:
    data = DataFrames.transform(
        data,
        arguments...
    )

    # If there's a "use" field in the YAML, parse it and rename it:
    if haskey(metadata_, "use")
        splitted_use = split(metadata_["use"], r"[,\s]")
        metadata_["use"] = Symbol.(splitted_use[findall(x -> length(x) > 0, splitted_use)])

        orig_names = [i.first for i in arguments]
        new_names = [isa(i.second, Pair) ? i.second.second : i.second for i in arguments]
        length(arguments) > 0 && replace!(metadata_["use"], Pair.(orig_names, new_names)...)
    end
    # NB: the "use" field is not used in PlantMeteo, but it is still correctly parsed.

    return Weather(data, (; zip(Symbol.(keys(metadata_)), values(metadata_))...))
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

    met_data = CSV.read(file, DataFrames.DataFrame; comment="#")

    (data=met_data, metadata_=metadata_)
end

"""
    compute_date(data, date_format, hour_format)

Compute the `date` column depending on several cases:

- If it is already in data and is a `DateTime`, does nothing.
- If it is a `String`, tries and parse it using a user-input `DateFormat`
- If it is a `Date`, return it as is, or try to make it a `DateTime` if there's a column named
`hour_start`

# Arguments

- `data`: any `Tables.jl` compatible table, such as a `DataFrame`
- `date_format`: a `DateFormat` to parse the `date` column if it is a `String`
- `hour_format`: a `DateFormat` to parse the `hour_start` column if it is a `String`
"""
function compute_date(
    data,
    date_format=Dates.DateFormat("yyyy-mm-ddTHH:MM:SS.s"),
    hour_format=Dates.DateFormat("HH:MM:SS"),
)

    if hasproperty(data, :date) && typeof(data.date[1]) != Dates.DateTime
        # There's a "date" column but it is not a DateTime
        # Trying to parse it with the user-defined format:
        date = try
            Dates.Date.(data.date, date_format)
        catch
            error(
                "The values in the `date` column cannot be parsed.",
                " Please check the format of the dates or provide the format as argument."
            )
        end

        if typeof(date[1]) == Dates.Date && hasproperty(data, :hour_start)
            # The `date` column is of Date type, we have to add the Time if there's a column named
            # `hour_start`:
            if typeof(data.hour_start[1]) != Dates.Time
                # There's a "hour_start" column but it is not of Time type
                # If it is a String, it did not parse at reading with CSV, so trying to use
                # the user-defined format:
                date = try
                    # Adding the Time to the Date to make a DateTime:
                    date .+ Dates.Time.(data.hour_start, hour_format)
                catch
                    error(
                        "The values in the `hour_start` column cannot be parsed.",
                        " Please check the format of the hours or provide the format as argument."
                    )
                end
            else
                date = date .+ data.hour_start
            end
        end
    else
        return data.date
    end

    return date
end


"""
    compute_duration(data, hour_format)

Compute the `duration` column depending on several cases:

- If it is already in the data, does nothing.
- If it is not, but there's a column named `hour_end` and another one either called `hour_start`
or `date`, compute the duration from the period between `hour_start` (or `date`) and `hour_end`.

# Arguments
- `data`: any `Tables.jl` compatible table, such as a `DataFrame`
- `hour_format`: a `DateFormat` to parse the `hour_start` and `hour_end` columns if they are `String`s.
"""
function compute_duration(data, hour_format=Dates.DateFormat("HH:MM:SS"))
    if hasproperty(data, :hour_end) && !hasproperty(data, :duration)
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
        elseif hasproperty(data, :date) && data.date[1] == Dates.DateTime
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
        catch
            error(
                "Hour $h cannot be parsed into a Dates.Time with format $hour_format.",
                " Please check the format of the hours or provide the format as argument."
            )
        end
    end

    # If it is of DateTime type, transform it into a Time:
    if typeof(h) == Dates.DateTime
        h = Dates.Time(h)
    end

    return h
end
