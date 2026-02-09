```@meta
CurrentModule = PlantMeteo
```

# Weather Sampling

This guide explains how to align raw weather time steps with model requirements.

## Why Sampling?

A model often needs weather at a different temporal scale than the source data.
Examples:

- source meteo is hourly, model step is 3 hours
- source meteo is sub-hourly, model step is daily
- a simulation needs both rolling and calendar-based aggregates

The sampling API makes these choices explicit and testable.

## Sampling Workflow

1. define the source weather table
2. prepare a sampler object (with optional caching)
3. choose a window specification
4. sample one step or materialize full sampled tables

## 1. Create a Small, Predictable Weather Series

For this example we'll use simple values so aggregation effects are easy to verify.
We make 48 hourly rows (two days) with monotonic `T`:

```@example sampling
using PlantMeteo
using Dates

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

meteo
```

## 2. Prepare Sampler State

We can normalize transforms and enable query-level memoization with `prepare_weather_sampler`. This is optional but can speed up repeated calls with the same specs.
This is done so that repeated identical calls can return cached objects (`lazy=true`).

```@example sampling
prepared = prepare_weather_sampler(meteo)  # lazy cache enabled by default
typeof(prepared)
```

## 3. Rolling Window Sampling

We can then aggregate over a trailing window in source-step units using `sample_weather`, which returns one aggregated `Atmosphere`.

```@example sampling
spec2 = MeteoSamplingSpec(2.0, 1.0)
row3 = sample_weather(prepared, 3; spec = spec2)
row3_cached = sample_weather(prepared, 3; spec = spec2)

(row3.T, row3.Tmin, row3.Tmax, row3_cached === row3)
```

`sample_weather` provides default transforms for common variables (*i.e.* the ones in `Atmosphere`), but you can override them with custom rules (see next section).

## 4. Override Variable-wise Aggregation Rules

We can match aggregation logic to model semantics by overriding variable-wise aggregation rules. Custom transforms are normalized and applied for this call.

```@example sampling
custom = (
    T = MeanWeighted(),
    Tmax = (source = :T, reducer = MaxReducer()),
    Tsum = (source = :T, reducer = SumReducer())
)

row_custom = sample_weather(prepared, 3; spec = spec2, transforms = custom)
(row_custom.T, row_custom.Tmax, row_custom.Tsum)
```

## 5. Calendar Window Sampling

Sometimes model logic is tied to civil periods (day/week/month) rather than fixed trailing windows. In this case, we can use `CalendarWindow` to aggregate all source steps that fall within the same period.
This is useful for *e.g.* daily models that need to aggregate all hourly steps that fall within the same day, regardless of how many there are or where they fall in the source data. For example if you need the average temperature for the day, you can use a `CalendarWindow` anchored to the current period:

```@example sampling
spec_day = MeteoSamplingSpec(
    1.0;
    window = CalendarWindow(
        :day;
        anchor = :current_period,
        week_start = 1,
        completeness = :allow_partial
    )
)

day_sample = sample_weather(prepared, 5; spec = spec_day)
(day_sample.T, day_sample.Tmin, day_sample.Tmax, day_sample.duration)
```

We sample the fifth hour of the series, which falls on the first day. The sampled `T` is the average of the 24 hourly steps that fall within that day, which matches our expectation for a daily aggregation:

```@example sampling
mean(meteo[i].T for i in 1:24)
```

The result would be the same for any hour from 1 to 24, since they all fall in the same day:

```@example sampling
day_sample2 = sample_weather(prepared, 20; spec = spec_day)
day_sample2.T == day_sample.T
```

The aggregated results are cached, so repeated calls with the same spec and query step will return the same values, and it means that performance will be ensured for long simulation loops with repeated calls:

```@example sampling
day_sample_cached = sample_weather(prepared, 6; spec = spec_day)
day_sample_cached.T === day_sample.T
```

The returned `Atmosphere` is different though, since the date (and sometimes duration) are different for each query step, even if the aggregated values are the same:

```@example sampling
day_sample.date, day_sample_cached.date, day_sample2.date
```

Note that `CalendarWindow` expects a `date::DateTime` column in the weather. And with `completeness = :strict`, incomplete periods raise an error.

## 6. Precompute for Simulation Loops

When running long simulations, you can precompute all sampled weather tables upfront rather than sampling on-demand at each step. This trades a one-time preprocessing cost for faster lookups during the simulation loop. The `materialize_weather` function returns one sampled table per requested sampling spec, allowing efficient access throughout your simulation.

```@example sampling
specs = [spec2, spec_day]
tables = materialize_weather(prepared; specs = specs)

(length(tables), length(tables[spec2]), tables[spec2][3].T ≈ row3.T)
```

This is typically the best approach when you perform many simulations with the same weather, *e.g.* for model calibration, sensitivity analysis, or system optimization.