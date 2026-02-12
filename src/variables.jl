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
const ATMOSPHERE_STANDARD_TO_INTERNAL = (; (v => k for (k, v) in pairs(ATMOSPHERE_NONSTANDARD_NAMES))...)

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
    rename_columns(df, var -> begin
        haskey(ATMOSPHERE_NONSTANDARD_NAMES, var) ? ATMOSPHERE_NONSTANDARD_NAMES[var] : var
    end)
end

function standardize_columns!(::ToPlantMeteoColumns, df)
    rename_columns(df, var -> begin
        haskey(ATMOSPHERE_STANDARD_TO_INTERNAL, var) ? ATMOSPHERE_STANDARD_TO_INTERNAL[var] : var
    end)
end
