"""
    write_weather(
        file, w; 
        select=setdiff(propertynames(w), ATMOSPHERE_COMPUTED),
        duration=Dates.Minute
    )

Write the weather data to a file. 

# Arguments

- `file`: a `String` representing the path to the file to write
- `w`: a `TimeStepTable{Atmosphere}`
- `select`: a vector of variables to write (as symbols). By default, all variables are written except the ones that 
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
    file::String, w::T;
    select=setdiff(propertynames(w), ATMOSPHERE_COMPUTED),
    duration=Dates.Minute
) where {T<:TimeStepTable{<:Atmosphere}}

    if select !== nothing
        select_ = [select...]
        for var in select
            # var = :date
            # check if the variables are in the table, if not remove them from the selection:
            if !hasproperty(w, var)
                popat!(select_, findfirst(select_ .== var))
            else
                # Remove variables with all values at != Inf (default value, we don't need to write it)
                if all(w[var] .== Inf)
                    popat!(select_, findfirst(select_ .== var))
                end
            end
        end
    end

    # select the variables:
    df = DataFrames.DataFrame(w)[:, select_] #! do we really need the conversion to df here ? 

    # add the duration format:
    DataFrames.metadata!(df, "duration", duration, style=:note)

    if hasproperty(df, :duration)
        df.duration = Dates.value.(duration.(Dates.Millisecond.(Dates.toms.(w.duration))))
    end

    write_weather_(file, df)
end

"""
    ATMOSPHERE_SELECT

List of variables that are by default removed from the table when using `write_weather` on a TimeStepTable{Atmosphere}.
"""
const ATMOSPHERE_COMPUTED = [
    (:e, :eₛ, :VPD, :ρ, :λ, :γ, :ε, :Δ)
]

"""
    write_weather_(file, w)

Write the weather data to a file with a special-commented yaml header for the metadata.
"""
function write_weather_(file::String, w)

    if length(metadata(w)) > 0
        append = true
        # write the metadata as a (special-commented #') yaml header:
        metadata_ = "#'"
        for i in pairs(metadata(w))
            i.first == :file && continue # don't write the source file name as it is added at reading
            yaml_line = YAML.write(i)
            # NB: cannot simply use YAML.write(i, "#'") as it only puts the prefix on the first line (can make several lines out of one)

            # Add "#'" at the beginning of each line:
            metadata_ *= replace(yaml_line, r"\n" => "\n#'")
        end
        metadata_ *= "\n"

        open(file, "w") do io
            write(io, metadata_)
        end
    else
        append = false
    end
    # write the data:
    CSV.write(file, w; append=append, writeheader=true)
end
