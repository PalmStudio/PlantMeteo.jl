```@meta
CurrentModule = PlantMeteo
```

# Daily Aggregation

Use [`to_daily`](@ref) when you want one row per civil day with standard daily weather summaries. This is the right tool when the model expects daily weather inputs and the source data is sub-daily.

## Build A Small Hourly Series

```@example daily
using PlantMeteo
using Dates
using Statistics

base = DateTime(2025, 7, 1)
hourly = Weather(map(base:Hour(1):(base + Hour(47))) do t
    h = Dates.hour(t)
    Atmosphere(
        date = t,
        duration = Hour(1),
        T = 18.0 + 6.0 * sin(2pi * h / 24) + (Dates.day(t) - 1),
        Wind = 1.5,
        Rh = 0.60 - 0.10 * sin(2pi * h / 24),
        P = 101.3,
        Precipitations = h in (5, 6) ? 0.6 : 0.0,
        Ri_SW_f = h in 6:18 ? 700.0 * sin(pi * (h - 6) / 12) : 0.0
    )
end)
hourly[1:6]
```

## Aggregate To One Row Per Day

```@example daily
daily = to_daily(hourly)
```

```@example daily
daily
```

The output has one row per day and includes standard daily summaries such as mean temperature, minimum temperature, maximum temperature, summed precipitation, and integrated radiation.

```@example daily
daily[1].Tmin
```

```@example daily
daily[1].Tmax
```

```@example daily
daily[1].T
```

```@example daily
daily[1].Precipitations
```

```@example daily
daily[1].Ri_SW_f
```

## Add Or Override Daily Transformations

You can request additional daily variables or override a default aggregation:

```@example daily
daily_custom = to_daily(
    hourly,
    :T => mean => :Tmean,
    :T => maximum => :Tpeak
)
```

```@example daily
daily_custom[1].Tmean
```

```@example daily
daily_custom[1].Tpeak
```

## When `to_daily` Is The Right Tool

Use [`to_daily`](@ref) when:

- the source data is sub-daily
- the model wants one row per day
- standard daily summaries are enough

Use [Weather Sampling](weather-sampling.md) instead when you need rolling windows, calendar windows other than simple daily reduction, custom reducers, or cached repeated queries during simulation.
