```@meta
CurrentModule = PlantMeteo
```

# Weather Sampling

Use weather sampling when your model needs more than simple one-row-per-day aggregation. Sampling lets you define rolling or calendar windows, control reducers per variable, and cache repeated queries for long simulation loops.

## When To Use Sampling Instead Of `to_daily`

Use [`to_daily`](@ref) when you want standard daily weather summaries and one row per civil day.

Use sampling when:

- the model timestep is not just daily
- you need a trailing window such as "the last 24 hourly steps"
- you need calendar windows such as current day, previous week, or current month
- different variables require different reducers
- repeated simulation queries should be cached

## Sampling Workflow

1. define the source weather table
2. prepare a sampler object
3. choose a window specification
4. sample one step or materialize full sampled tables

## 1. Create a Small, Predictable Weather Series

For this example we'll use simple values so aggregation effects are easy to verify.
We make 48 hourly rows (two days) with monotonic `T`:

```@example sampling
using PlantMeteo
using Dates
using Statistics

base = DateTime(2025, 1, 1)
meteo = Weather([
    Atmosphere(
        date = base + Hour(i),
        duration = Hour(1),
        T = 10.0 + i,
        Wind = 1.0,
        Rh = 0.50 + 0.005 * i,
        P = 100.0,
        Ri_SW_f = 100.0 + 10.0 * i
    )
    for i in 0:47
])

meteo[1:6]
```

## 2. Prepare Sampler State

We can normalize transforms and enable query-level memoization with [`prepare_weather_sampler`](@ref). This is optional but useful when the same weather is sampled many times during a simulation.

```@example sampling
prepared = prepare_weather_sampler(meteo)  # lazy cache enabled by default
typeof(prepared)
```

## 3. Rolling Window Sampling

We can then aggregate over a trailing window in source-step units using [`sample_weather`](@ref), which returns one aggregated [`Atmosphere`](@ref).

```@example sampling
window2 = RollingWindow(2.0)
row3 = sample_weather(prepared, 3; window = window2)
row3_cached = sample_weather(prepared, 3; window = window2)
```

```@example sampling
row3.T
```

```@example sampling
row3.Tmin
```

```@example sampling
row3.Tmax
```

```@example sampling
row3_cached === row3
```

`sample_weather` provides default transforms for common atmospheric variables, but you can override them when your model semantics differ.

## 4. Override Variable-wise Aggregation Rules

We can match aggregation logic to model semantics by overriding variable-wise aggregation rules.

```@example sampling
custom = (
    T = MeanWeighted(),
    Tmax = (source = :T, reducer = MaxReducer()),
    Tsum = (source = :T, reducer = SumReducer())
)

row_custom = sample_weather(prepared, 3; window = window2, transforms = custom)
```

```@example sampling
row_custom.T
```

```@example sampling
row_custom.Tmax
```

```@example sampling
row_custom.Tsum
```

## 5. Calendar Window Sampling

Sometimes model logic is tied to civil periods (day/week/month) rather than fixed trailing windows. In that case, use [`CalendarWindow`](@ref) to aggregate all source timesteps that fall within the same period.

```@example sampling
window_day = CalendarWindow(:day)
day_sample = sample_weather(prepared, 5; window = window_day)
```

```@example sampling
day_sample.T
```

```@example sampling
day_sample.Tmin
```

```@example sampling
day_sample.Tmax
```

```@example sampling
day_sample.duration
```

We sample the fifth hour of the series, which falls on the first day. The sampled `T` is the average of the 24 hourly steps that fall within that day, which matches our expectation for a daily aggregation:

```@example sampling
mean(meteo[i].T for i in 1:24)
```

The result would be the same for any hour from 1 to 24, since they all fall in the same day:

```@example sampling
day_sample2 = sample_weather(prepared, 20; window = window_day)
day_sample2.T == day_sample.T
```

The aggregated results are cached, so repeated calls with the same window and query step will return the same values, and it means that performance will be ensured for long simulation loops with repeated calls:

```@example sampling
day_sample_cached = sample_weather(prepared, 6; window = window_day)
day_sample_cached.T === day_sample.T
```

The returned `Atmosphere` is different though, since the date (and sometimes duration) are different for each query step, even if the aggregated values are the same:

```@example sampling
day_sample.date
```

```@example sampling
day_sample_cached.date
```

```@example sampling
day_sample2.date
```

Note that `CalendarWindow` expects a `date::DateTime` column in the weather. By default, it checks for completeness of the period, but you can use `completeness = :allow_partial` to authorize incomplete periods. This is also faster since it doesn't have to perform checks.

## 6. Precompute for Simulation Loops

When running long simulations, you can precompute all sampled weather tables upfront rather than sampling on-demand at each step. This trades a one-time preprocessing cost for faster lookups during the simulation loop. The `materialize_weather` function returns one sampled table per requested sampling window, allowing efficient access throughout your simulation.

```@example sampling
windows = [window2, window_day]
tables = materialize_weather(prepared; windows = windows)
```

```@example sampling
length(tables)
```

```@example sampling
length(tables[window2])
```

```@example sampling
tables[window2][3].T ≈ row3.T
```

This is typically the best approach when you perform many simulations with the same weather, for example model calibration, sensitivity analysis, or repeated scenario runs.
