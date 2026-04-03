```@meta
CurrentModule = PlantMeteo
```

# Reference

## Weather Tables

```@docs
Atmosphere
Weather
TimeStepTable
Constants
get_index_raw
```

## Data Ingestion And Export

```@docs
read_weather
write_weather
row_datetime_interval
check_non_overlapping_timesteps
select_overlapping_timesteps
```

## API Retrieval

```@docs
AbstractAPI
DemoAPI
get_weather
OpenMeteoUnits
OpenMeteo
get_forecast
```

## Daily Aggregation

```@docs
to_daily
```

## Sampling

```@docs
AbstractTimeReducer
MeanWeighted
MeanReducer
SumReducer
MinReducer
MaxReducer
FirstReducer
LastReducer
DurationSumReducer
RadiationEnergy
AbstractSamplingWindow
RollingWindow
CalendarWindow
MeteoTransform
PreparedWeather
prepare_weather_sampler
sample_weather
materialize_weather
default_sampling_transforms
normalize_sampling_transforms
```

## Atmosphere Computations

```@docs
atmosphere_emissivity
vapor_pressure
e_sat
air_density
latent_heat_vaporization
psychrometer_constant
rh_from_vpd
rh_from_e
vpd
vpd_from_e
duration_seconds
positive_duration_seconds
```

## Index

```@index
```
