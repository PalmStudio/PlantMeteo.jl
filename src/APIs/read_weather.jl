"""
    read_weather(file[,args...];
        date_format = DateFormat("yyyy-mm-ddTHH:MM:SS.s"),
        hour_format = DateFormat("HH:MM:SS")
    )

Read a meteo file. The meteo file is a CSV, and optionnaly with metadata in a header formatted
as a commented YAML. The column names **and units** should match exactly the fields of
[`Atmosphere`](https://palmstudio.github.io/PlantMeteo.jl/stable/#PlantMeteo.Atmosphere), or the user should provide their transformation as arguments (`args`)
to help mapping the two. The transformations are given as for `DataFrames`.

# Note

The variables found in the file will be used as is if not transformed, and not recomputed
from the other variables. Please check that all variables have the same units as in the
[`Atmosphere`](https://palmstudio.github.io/PlantMeteo.jl/stable/#PlantMeteo.Atmosphere) structure.

# Arguments

- `file::String`: path to a meteo file
- `var_names = Dict()`: A Dict to map the file variable names to the Atmosphere variable names
- `date_format = DateFormat("yyyy-mm-ddTHH:MM:SS.s")`: the format for the `DateTime` columns
- `hour_format = DateFormat("HH:MM:SS")`: the format for the `Time` columns (*e.g.* `hour_start`)

# Examples

```julia
using Dates

file = joinpath(dirname(dirname(pathof(PlantBiophysics))),"test","inputs","meteo.csv")

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
    data, metadata_ = read_weather(file, DataFrames.DataFrame)

    # Clean-up the variable names:
    length(arguments) > 0 && DataFrames.transform!(data, arguments...)

    # If there's a "use" field in the YAML, parse it and rename it:
    if haskey(metadata_, "use")
        splitted_use = split(metadata_["use"], r"[,\s]")
        metadata_["use"] = Symbol.(splitted_use[findall(x -> length(x) > 0, splitted_use)])

        orig_names = [i.first for i in arguments]
        new_names = [isa(i.second, Pair) ? i.second.second : i.second for i in arguments]
        length(arguments) > 0 && replace!(metadata_["use"], Pair.(orig_names, new_names)...)
    end
    # NB: the "use" field is not used in PlantMeteo, but it is still correctly parsed.

    compute_date!(data, date_format, hour_format)
    compute_duration!(data, hour_format)

    # cols = fieldnames(PlantMeteo.Atmosphere)
    # DataFrames.select!(data, DataFrames.names(data, x -> Symbol(x) in cols))
    # NB: we don't select anymore so the user can have the extra columns if needed.

    Weather(data, (; zip(Symbol.(keys(metadata_)), values(metadata_))...))
end

function read_weather(file, ::Type{DataFrames.DataFrame})
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
    compute_date!(df, date_format, hour_format)

Compute the `date` column depending on several cases:

- If it is already in the DataFrame and is a `DateTime`, does nothing.
- If it is a `String`, tries and parse it using a user-input `DateFormat`
- If it is a `Date`, return it as is, or try to make it a `DateTime` if there's a column named
`hour_start`
"""
function compute_date!(df, date_format, hour_format)
    if hasproperty(df, :date) && typeof(df.date[1]) != Dates.DateTime
        # There's a "date" column but it is not a DateTime
        # Trying to parse it with the user-defined format:
        try
            df.date = Dates.Date.(df.date, date_format)
        catch
            error(
                "The values in the `date` column cannot be parsed.",
                " Please check the format of the dates or provide the format as argument."
            )
        end

        if typeof(df.date[1]) == Dates.Date && hasproperty(df, :hour_start)
            # The `date` column is of Date type, we have to add the Time if there's a column named
            # `hour_start`:
            if typeof(df.hour_start[1]) != Dates.Time
                # There's a "hour_start" column but it is not of Time type
                # If it is a String, it did not parse at reading with CSV, so trying to use
                # the user-defined format:
                try
                    df.hour_start = Dates.Time.(df.hour_start, hour_format)
                catch
                    error(
                        "The values in the `hour_start` column cannot be parsed.",
                        " Please check the format of the hours or provide the format as argument."
                    )
                end
            end
            # Adding the Time to the Date to make a DateTime:
            df.date = df.date .+ df.hour_start
        end
    end
end


"""
    compute_duration!(df, hour_format)

Compute the `duration` column depending on several cases:

- If it is already in the DataFrame, does nothing.
- If it is not, but there's a column named `hour_end` and another one either called `hour_start`
or `date`, compute the duration from the period between `hour_start` (or `date`) and `hour_end`.
"""
function compute_duration!(df, hour_format)
    # `duration` is not in the df but there is an `hour_end` column:
    if hasproperty(df, :hour_end) && !hasproperty(df, :duration)
        if typeof(df.hour_end[1]) != Dates.Time
            # There's a `hour_end` column but it is not of Time type
            # If it is a String, it did not parse at reading with CSV, so trying to use
            # the user-defined format:
            if typeof(df.hour_end[1]) != String
                try
                    df.hour_end = Dates.Time.(df.hour_end, hour_format)
                catch
                    error(
                        "The values in the `hour_end` column cannot be parsed.",
                        " Please check the format of the hours or provide the format as argument."
                    )
                end
            end

            # If it is of Time type, transform it into a DateTime:
            if typeof(df.hour_end[1]) == Dates.DateTime
                df.hour_end = Dates.Time(df.hour_end)
            end
        end

        if hasproperty(df, :hour_start)
            df.duration = Dates.Minute.(df.hour_end .- df.hour_start)
        elseif hasproperty(df, :date)
            df.duration = Dates.Minute.(df.hour_end .- Dates.Time.(df.date))
        end
    end
end
