using Pkg
Pkg.activate(dirname(@__FILE__))
Pkg.instantiate()

using BenchmarkTools
using Dates
using PlantMeteo

const BASE_DATE = Dates.DateTime(2025, 1, 1, 0, 0, 0)

@inline function _hourly_row(i::Int)
    hour = (i - 1) % 24
    cycle_day = 2π * hour / 24
    cycle_solar = π * hour / 24

    return (
        date=BASE_DATE + Dates.Hour(i - 1),
        duration=Dates.Hour(1),
        T=18.0 + 9.0 * sin(cycle_day),
        Wind=1.0 + 2.0 * abs(sin(cycle_day / 2)),
        P=101.3 - 0.3 * cos(cycle_day),
        Rh=0.55 + 0.35 * cos(cycle_day),
        Precipitations=hour == 3 ? 0.2 : 0.0,
        Ri_SW_f=max(0.0, 650.0 * sin(cycle_solar))
    )
end

make_named_rows(nsteps::Int) = [_hourly_row(i) for i in 1:nsteps]

const NAMED_ROWS_30D = make_named_rows(24 * 30)
const NAMED_ROWS_180D = make_named_rows(24 * 180)

const WEATHER_30D = Weather(NAMED_ROWS_30D)
const WEATHER_180D = Weather(NAMED_ROWS_180D)

const ROLLING_24H = RollingWindow(24.0)
const CALENDAR_DAY = CalendarWindow(:day; anchor=:current_period, completeness=:allow_partial)

function bench_sample_all(weather, window)
    prepared = prepare_weather_sampler(weather; lazy=false)
    for i in 1:length(weather)
        sample_weather(prepared, i; window=window)
    end
    return nothing
end

function bench_materialize_windows(weather)
    prepared = prepare_weather_sampler(weather; lazy=false)
    materialize_weather(prepared; windows=(ROLLING_24H, CALENDAR_DAY))
    return nothing
end

suite_name = "bench_"
if Sys.iswindows()
    suite_name *= "windows"
elseif Sys.isapple()
    suite_name *= "mac"
elseif Sys.islinux()
    suite_name *= "linux"
end

const SUITE = BenchmarkGroup()
SUITE[suite_name] = BenchmarkGroup(["PlantMeteo"])

SUITE[suite_name]["Weather_construct_30d"] = @benchmarkable Weather($NAMED_ROWS_30D)
SUITE[suite_name]["sample_weather_rolling_24h"] = @benchmarkable bench_sample_all($WEATHER_30D, $ROLLING_24H)
SUITE[suite_name]["sample_weather_calendar_day"] = @benchmarkable bench_sample_all($WEATHER_30D, $CALENDAR_DAY)
SUITE[suite_name]["materialize_weather_windows"] = @benchmarkable bench_materialize_windows($WEATHER_30D)
SUITE[suite_name]["to_daily_180d"] = @benchmarkable to_daily($WEATHER_180D)
