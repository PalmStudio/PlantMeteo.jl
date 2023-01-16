"""
    ATMOSPHERE_SELECT

List of variables that are by default removed from the table when using `write_weather` on a TimeStepTable{Atmosphere}.
"""
const ATMOSPHERE_COMPUTED = [:e, :eₛ, :VPD, :ρ, :λ, :γ, :ε, :Δ]

"""
    ATMOSPHERE_NONSTANDARD_NAMES

List of variables that are by default renamed when using [`write_weather`](@ref) on a 
`TimeStepTable{Atmosphere}`, to be compatible with standard file systems (CSV, databases...).

- `Cₐ` => `Ca`
- `eₛ` => `es`
- `ρ` => `rho`
- `λ` => `lambda`
- `γ` => `gamma`
- `ε` => `epsilon`
- `Δ` => `Delta`

The reverse procedure is done when reading a file with [`read_weather`](@ref).

# See also

[`standardize_columns!`](@ref)

"""
const ATMOSPHERE_NONSTANDARD_NAMES = (
    Cₐ=:Ca, eₛ=:es, ρ=:rho, λ=:lambda, γ=:gamma, ε=:epsilon, Δ=:Delta
)

struct ToFileColumns end
struct ToPlantMeteoColumns end

"""
    standardize_columns!(::ToFileColumns, df)
    standardize_columns!(::ToPlantMeteoColumns, df)

Standardize the column names of a `DataFrame` built upon `Atmosphere`s to be compatible with standard
file systems (CSV, databases...).

# Arguments

- `df`: a `DataFrame` built upon `Atmosphere`s

# Examples

```julia
using PlantMeteo, Dates, DataFrames

file = joinpath(dirname(dirname(pathof(PlantMeteo))),"test","data","meteo.csv")

df = read_weather(
    file,
    :temperature => :T,
    :relativeHumidity => (x -> x ./100) => :Rh,
    :wind => :Wind,
    :atmosphereCO2_ppm => :Cₐ,
    date_format = DateFormat("yyyy/mm/dd")
) |> DataFrame

df = standardize_columns!(ToFileColumns(), df)
```
"""
function standardize_columns!(::ToFileColumns, df)
    to_rename = Pair{Symbol,Symbol}[]

    # if the variable is in the list of non-standard names, add it to the renaming vector of pairs:
    for var in propertynames(df)
        if var in keys(ATMOSPHERE_NONSTANDARD_NAMES)
            push!(to_rename, var => ATMOSPHERE_NONSTANDARD_NAMES[var])
        end
    end

    # rename the variables:
    length(to_rename) > 0 && DataFrames.rename!(df, to_rename)
end

function standardize_columns!(::ToPlantMeteoColumns, df)
    to_rename = Pair{Symbol,Symbol}[]

    # if the variable is in the list of PlantMeteo variables, add it to the renaming vector of pairs:
    for var in propertynames(df)
        if var in ATMOSPHERE_NONSTANDARD_NAMES
            push!(to_rename, var => findfirst(x -> x == var, ATMOSPHERE_NONSTANDARD_NAMES))
        end
    end

    # rename the variables:
    length(to_rename) > 0 && DataFrames.rename!(df, to_rename)
end