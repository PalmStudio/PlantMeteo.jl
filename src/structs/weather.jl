"""
    Weather(data[, metadata])

Defines the weather, *i.e.* the local conditions of the Atmosphere for one or more time-steps.
Each time-step is described using the [`Atmosphere`](@ref) structure, and the resulting structure
is a `TimeStepTable`.

The simplest way to instantiate a `Weather` is to use a `DataFrame` as input.

The `DataFrame` should be formated such as each row is an observation for a given time-step
and each column is a variable. The column names should match exactly the variables names of the
[`Atmosphere`](@ref) structure:

## See also

- the [`Atmosphere`](@ref) structure
- the [`read_weather`](@ref) function to read Archimed-formatted meteorology data.

## Examples

Example of weather data defined by hand (cumbersome):

```julia
w = Weather(
    [
        Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65),
        Atmosphere(T = 23.0, Wind = 1.5, P = 101.3, Rh = 0.60),
        Atmosphere(T = 25.0, Wind = 3.0, P = 101.3, Rh = 0.55)
    ],
    (
        site = "Test site",
        important_metadata = "this is important and will be attached to our weather data"
    )
)
```

`Weather` is a `TimeStepTable{Atmosphere}`, so we can convert it into a `DataFrame`:

```julia
using DataFrames
df = DataFrame(w)
```

And then back into `Weather` to make a `TimeStepTable{Atmosphere}`:

```julia
Weather(df, (site = "My site",))
```

Of course it works with any `DataFrame` that has at least the required
variables listed in `Atmosphere`.
"""
function Weather(data, metadata::S=NamedTuple()) where {S<:NamedTuple}
    TimeStepTable{Atmosphere}(data, metadata)
end

# This method directly calls TimeStepTable(ts::V, metadata=NamedTuple()) where {V<:Vector}:
function Weather(data::V, metadata::S=NamedTuple()) where {V<:Vector{A} where {A<:Atmosphere},S<:NamedTuple}
    TimeStepTable(data, metadata)
end