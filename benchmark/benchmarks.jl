using BenchmarkTools
using Dates
using PlantMeteo

const BASE_DATE = Dates.DateTime(2025, 1, 1, 0, 0, 0)
const DATA_KEYS = (:date, :duration, :T, :Wind, :P, :Rh, :Precipitations, :Ri_SW_f)

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
const INDEX_RANGE = 100:300
const INDEX_VECTOR = collect(1:3:length(WEATHER_30D))

mutable struct MutableMeteoRow
    date::Dates.DateTime
    duration::Dates.Hour
    T::Float64
    Wind::Float64
    P::Float64
    Rh::Float64
    Precipitations::Float64
    Ri_SW_f::Float64
end

Base.keys(::MutableMeteoRow) = DATA_KEYS
Base.getindex(row::MutableMeteoRow, i::Int) = getfield(row, DATA_KEYS[i])
Base.getindex(row::MutableMeteoRow, s::Symbol) = getfield(row, s)
Base.values(row::MutableMeteoRow) = (getfield(row, k) for k in DATA_KEYS)

function _mutable_row(i::Int)
    nt = _hourly_row(i)
    return MutableMeteoRow(
        nt.date,
        nt.duration,
        nt.T,
        nt.Wind,
        nt.P,
        nt.Rh,
        nt.Precipitations,
        nt.Ri_SW_f
    )
end

make_mutable_weather(nsteps::Int) = TimeStepTable([_mutable_row(i) for i in 1:nsteps])

bench_index_row(ts, i) = ts[i]
bench_index_cell(ts, i, j) = ts[i, j]
bench_index_column(ts, j) = ts[:, j]
bench_index_range(ts, r) = ts[r]
bench_index_range_matrix(ts, r) = ts[r, :]
bench_index_vector_rows(ts, idxs) = ts[idxs]

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

function bench_update_column!(ts, values)
    ts.T = values
    return nothing
end

function bench_update_each_row!(ts)
    for i in 1:length(ts)
        row = ts[i, :]
        row.T = row.T + 0.1
    end
    return nothing
end

function bench_update_range_rows!(ts, row_range)
    for i in row_range
        row = ts[i, :]
        row.T = row.T + 0.1
    end
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

SUITE[suite_name]["data_manip"] = BenchmarkGroup(["PlantMeteo", "data_manip"])
SUITE[suite_name]["data_manip"]["index_row"] = @benchmarkable bench_index_row($WEATHER_30D, 240)
SUITE[suite_name]["data_manip"]["index_cell"] = @benchmarkable bench_index_cell($WEATHER_30D, 240, 3)
SUITE[suite_name]["data_manip"]["index_column"] = @benchmarkable bench_index_column($WEATHER_30D, 3)
SUITE[suite_name]["data_manip"]["index_range"] = @benchmarkable bench_index_range($WEATHER_30D, $INDEX_RANGE)
SUITE[suite_name]["data_manip"]["index_range_matrix"] = @benchmarkable bench_index_range_matrix($WEATHER_30D, $INDEX_RANGE)
SUITE[suite_name]["data_manip"]["index_vector_rows"] = @benchmarkable bench_index_vector_rows($WEATHER_30D, $INDEX_VECTOR)
SUITE[suite_name]["data_manip"]["update_column"] = @benchmarkable bench_update_column!(ts, vals) setup = (ts = make_mutable_weather(24 * 30); vals = fill(19.5, length(ts)))
SUITE[suite_name]["data_manip"]["update_each_row"] = @benchmarkable bench_update_each_row!(ts) setup = (ts = make_mutable_weather(24 * 30))
SUITE[suite_name]["data_manip"]["update_range_rows"] = @benchmarkable bench_update_range_rows!(ts, r) setup = (ts = make_mutable_weather(24 * 30); r = 200:400)
