```@meta
CurrentModule = PlantMeteo
```

# Read/Write Round Trip

Use [`write_weather`](@ref) when you want to export a cleaned PlantMeteo table back to disk. This is useful after standardizing raw files, checking variables, or building a weather table from an API and saving the result for reuse.

## Read A Local File

```@example roundtrip
using PlantMeteo
using Dates

file = joinpath(dirname(dirname(pathof(PlantMeteo))), "test", "data", "meteo.csv")

weather = read_weather(
    file,
    :temperature => :T,
    :relativeHumidity => (x -> x ./ 100) => :Rh,
    :wind => :Wind,
    :atmosphereCO2_ppm => :Cₐ,
    date_format = DateFormat("yyyy/mm/dd")
)

weather[1:3]
```

## Write It Back To Disk

```@example roundtrip
roundtrip = mktempdir() do tmp
    out = joinpath(tmp, "weather_out.csv")
    write_weather(out, weather)
    reread = read_weather(out; duration = Dates.Minute)

    (
        out,
        length(reread) == length(weather),
        reread[1].T == weather[1].T,
        metadatakeys(reread),
    )
end
```

```@example roundtrip
roundtrip[1]
```

```@example roundtrip
roundtrip[2]
```

```@example roundtrip
roundtrip[3]
```

```@example roundtrip
roundtrip[4]
```

By default, `write_weather` avoids writing variables that can be recomputed from core atmospheric inputs. That keeps exported files focused on the variables that need to be persisted.

## When To Use This Guide

Use this workflow when you want to:

- keep a cleaned file for later simulations
- normalize metadata and variable names once, then reuse the result
- export weather built from a PlantMeteo workflow rather than rebuilding it every time
