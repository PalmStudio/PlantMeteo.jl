"""
    write_weather(
        file, w; 
        vars=setdiff(propertynames(w), ATMOSPHERE_COMPUTED),
        duration=Dates.Minute
    )

Write the weather data to a file. 

# Arguments

- `file`: a `String` representing the path to the file to write
- `w`: a `TimeStepTable{Atmosphere}`
- `vars`: a vector of variables to write (as symbols). By default, all variables are written except the ones that 
can be recomputed (see [`ATMOSPHERE_COMPUTED`](@ref)). If `nothing` is given, all variables are written.
- `duration`: the unit for formating the duration of the time steps. By default, it is `Dates.Minute`.

# Examples

```julia
using PlantMeteo, Dates

file = joinpath(dirname(dirname(pathof(PlantMeteo))),"test","data","meteo.csv")
w = read_weather(
    file,
    :temperature => :T,
    :relativeHumidity => (x -> x ./100) => :Rh,
    :wind => :Wind,
    :atmosphereCO2_ppm => :Cₐ,
    date_format = DateFormat("yyyy/mm/dd")
)

write_weather("meteo.csv", w)
```
"""
function write_weather(
    file::String, w;
    vars=setdiff(propertynames(w), ATMOSPHERE_COMPUTED),
    duration=Dates.Minute
)
    df = prepare_weather(w; vars=vars, duration=duration)
    df = standardize_columns!(ToFileColumns(), df)

    md = Dict{Symbol,Any}(pairs(table_metadata(w)))
    md[:duration] = duration

    write_weather_(file, df; metadata_=(; md...))
end

"""
    prepare_weather(
        w;
        vars=setdiff(propertynames(w), ATMOSPHERE_COMPUTED),
        duration=Dates.Minute
    )

Prepare the weather data for writing to a file. The function returns a 
`DataFrame` with the selected variables and the duration formated.

# Arguments

- `w`: a `Tables.jl` interfaced table, such as a `TimeStepTable{Atmosphere}` or a `DataFrame`
- `vars`: a vector of variables to write (as symbols). By default, all variables are written except the ones that
can be recomputed (see [`ATMOSPHERE_COMPUTED`](@ref)). If `nothing` is given, all variables are written.
- `duration`: the unit for formating the duration of the time steps. By default, it is `Dates.Minute`

# Examples

```julia
using PlantMeteo, Dates

file = joinpath(dirname(dirname(pathof(PlantMeteo))),"test","data","meteo.csv")
w = read_weather(
    file,
    :temperature => :T,
    :relativeHumidity => (x -> x ./100) => :Rh,
    :wind => :Wind,
    :atmosphereCO2_ppm => :Cₐ,
    date_format = DateFormat("yyyy/mm/dd")
)

df = prepare_weather(w)
```
"""
function prepare_weather(
    w;
    vars=setdiff(propertynames(w), ATMOSPHERE_COMPUTED),
    duration=Dates.Minute
)
    Tables.istable(w) || throw(ArgumentError("The weather data must be interfaced with `Tables.jl`."))

    df = select_weather(w, vars)

    if hasproperty(df, :duration)
        df = set_column(df, :duration, Dates.value.(duration.(Dates.Millisecond.(Dates.toms.(df.duration)))))
    end

    df
end


"""
    select_weather(w, vars=setdiff(propertynames(w), ATMOSPHERE_COMPUTED))

Select the variables to write in the weather data. The function returns a `DataFrame` with the selected variables.

# Arguments

- `w`: a `Tables.jl` interfaced table, such as a `TimeStepTable{Atmosphere}` or a `DataFrame`
- `vars`: a vector of variables to write (as symbols). By default, all variables are written except the ones that
can be recomputed (see [`ATMOSPHERE_COMPUTED`](@ref)). If `nothing` is given, all variables are written.

# Examples

```julia
using PlantMeteo, Dates

file = joinpath(dirname(dirname(pathof(PlantMeteo))),"test","data","meteo.csv")
w = read_weather(
    file,
    :temperature => :T,
    :relativeHumidity => (x -> x ./100) => :Rh,
    :wind => :Wind,
    :atmosphereCO2_ppm => :Cₐ,
    date_format = DateFormat("yyyy/mm/dd")
)

df = select_weather(w)
```
"""
function select_weather(w, vars=setdiff(propertynames(w), ATMOSPHERE_COMPUTED))

    Tables.istable(w) || throw(ArgumentError("The weather data must be interfaced with `Tables.jl`."))

    requested_vars = if vars === nothing
        collect(propertynames(w))
    else
        collect(vars)
    end

    selected_vars = Symbol[]
    selected_cols = Any[]

    for var in requested_vars
        hasproperty(w, var) || continue

        col = Tables.getcolumn(w, var)
        if vars !== nothing && all(==(Inf), col)
            continue
        end

        push!(selected_vars, var)
        push!(selected_cols, col)
    end

    # Build the table from selected columns only to avoid materializing all columns first.
    return NamedTuple{Tuple(selected_vars)}(Tuple(selected_cols))
end


"""
    write_weather_(file, w)

Write the weather data to a file with a special-commented yaml header for the metadata.
"""
function write_weather_(file::String, w; metadata_=NamedTuple())

    if length(metadata_) > 0
        append = true
        # write the metadata as a (special-commented #') yaml header:
        metadata_string = "#'"
        for i in pairs(metadata_)
            i.first == :file && continue # don't write the source file name as it is added at reading
            yaml_line = YAML.write(i)
            # NB: cannot simply use YAML.write(i, "#'") as it only puts the prefix on the first line (can make several lines out of one)

            # Add "#'" at the beginning of each line:
            metadata_string *= replace(yaml_line, r"\n" => "\n#'")
        end
        metadata_string *= "\n"

        open(file, "w") do io
            write(io, metadata_string)
        end
    else
        append = false
    end
    # write the data:
    CSV.write(file, w; append=append, header=true)
end
