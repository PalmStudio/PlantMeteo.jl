"""
    Weather(data[, metadata])

Convenience constructor for a weather table made of [`Atmosphere`](@ref) rows.

`Weather` returns a `TimeStepTable{Atmosphere}` and is the easiest way to say "this table is
weather". It accepts either a vector of `Atmosphere` rows or any table whose columns match the
canonical PlantMeteo variable names.

Use `Weather` when building a small synthetic weather series by hand, converting already-clean
tabular data into PlantMeteo's table type, or returning weather from a custom API backend.

# Example

```julia
using PlantMeteo, Dates

weather = Weather(
    [
        Atmosphere(date=DateTime(2025, 7, 1, 12), duration=Hour(1), T=24.0, Wind=1.8, Rh=0.58, P=101.3),
        Atmosphere(date=DateTime(2025, 7, 1, 13), duration=Hour(1), T=25.0, Wind=2.0, Rh=0.55, P=101.3),
    ],
    (site = "demo",)
)
```
"""
function Weather(data, metadata::S=NamedTuple()) where {S<:NamedTuple}
    TimeStepTable{Atmosphere}(data, metadata)
end

# This method directly calls TimeStepTable(ts::V, metadata=NamedTuple()) where {V<:Vector}:
function Weather(data::V, metadata::S=NamedTuple()) where {V<:Vector{A} where {A<:Atmosphere},S<:NamedTuple}
    TimeStepTable(data, metadata)
end
