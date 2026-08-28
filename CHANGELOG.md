# Changelog

This file records the notable user-facing changes in PlantMeteo.

## [0.9.0] - Unreleased

PlantMeteo 0.9.0 makes weather-data boundaries explicit. Imported values are
normalized from declared units, invalid atmospheric inputs are reported instead
of silently changed, and optional forcing variables now have a clear missing-data
contract.

This is a minor release because some existing workflows may need small changes,
especially code that relied on automatic unit guessing, clamping, `Inf` sentinels,
or interpreted metadata.

### Explicit weather import units

**What changed**

- Added the public `normalize_weather_import` function.
- Added the `input_units` keyword to `read_weather` for relative humidity (`Rh`)
  and pressure (`P`). Supported declarations are `:fraction` or `:percent` for
  `Rh`, and `:kPa`, `:hPa`, or `:Pa` for `P`.
- `read_weather` applies unit normalization after source columns have been renamed
  to PlantMeteo's canonical names.
- Every import appends a YAML-safe `import_normalization` record to the weather
  metadata. Earlier normalization records are preserved.

**Why**

PlantMeteo previously allowed unit conversion to be hidden inside arbitrary
column transformations or inferred from suspicious values. That made it difficult
to tell whether a value had already been converted and made accidental double
conversion possible. The new boundary records the declared source units and every
conversion applied.

**What this means for users**

Canonical input remains the default: `Rh` is assumed to be a fraction and `P` is
assumed to be in kPa. Declare non-canonical input explicitly:

```julia
weather = read_weather(
    file,
    :relativeHumidity => :Rh,
    :surfacePressure => :P,
    input_units=(Rh=:percent, P=:hPa),
)
```

Existing explicit transformations can still be used, but `input_units` is the
recommended path for humidity and pressure because it also records provenance.

### Strict `Atmosphere` construction

**What changed**

- `Atmosphere(...; check=true)` now applies one centralized validation step
  before computing derived variables.
- Under this contract, negative wind, humidity outside `[0, 1]`, non-finite
  core values, invalid pressure, negative radiation, and invalid clearness raise
  an error.
- Physical zero is preserved for calm wind, dry air, darkness, and zero incoming
  radiation.
- `check=false` skips validation but never clamps, rescales, or otherwise changes
  the supplied values.

**Why**

Silently replacing calm wind with an epsilon or interpreting humidity as a
percentage inside the row constructor changed scientific inputs without leaving a
trace. Validation and unit conversion now have separate responsibilities:
normalization happens at the import boundary, while `Atmosphere` checks canonical
values.

**What this means for users**

Code that relied on automatic humidity conversion or wind clamping must normalize
its inputs before constructing `Atmosphere` rows. Use `check=false` only when the
caller intentionally owns validation; it no longer requests automatic correction.

### Optional forcing and stable weather schemas

**What changed**

- Omitted `clearness` and `Ri_*_f` keywords are now structurally absent instead of
  being stored as `Inf`.
- Passing `missing` keeps an optional forcing column present with an explicitly
  missing value.
- When `Atmosphere` rows expose different optional forcing fields,
  `TimeStepTable` builds their stable union schema and inserts `missing` where a
  field was absent.
- Non-`Atmosphere` rows must expose the same ordered keys.
- `push!` and `append!` reject rows that would introduce a new schema. `append!`
  validates and converts all incoming rows before mutating the table.

**Why**

`Inf` mixed two different meanings: an unavailable value and a real numeric value.
An explicit schema with `missing` makes absence visible to Tables.jl, CSV writers,
data-frame conversions, and downstream models without inventing a physical value.

**What this means for users**

- Check `hasproperty(row, :Ri_SW_f)` when a forcing may be structurally absent.
- Use `missing`, not `Inf`, when the variable exists but its value is unavailable.
- Rebuild a `TimeStepTable` when adding a new column; `push!` and `append!` only add
  rows that match the existing schema.
- Code that filtered optional columns by testing for all-`Inf` values should use
  schema presence and `missing` instead.

### Open-Meteo unit normalization and provenance

**What changed**

- Open-Meteo values are normalized according to the requested `OpenMeteoUnits`.
  Supported conversions include Fahrenheit to degrees Celsius, km/h, mph, or
  knots to m/s, inches to mm, percent humidity to a fraction, and hPa to kPa.
- PlantMeteo validates the unit labels returned by Open-Meteo before consuming the
  payload.
- Returned metadata now distinguishes canonical `units` from `source_units` and
  includes the `import_normalization` history.
- Formatting leaves the source payload unchanged.
- Missing or invalid core forcing is reported instead of being replaced with a
  default pressure or an epsilon wind speed.

**Why**

The former formatter always converted humidity and pressure but did not normalize
all configurable Open-Meteo units. This could attach canonical field names to
values that were still expressed in Fahrenheit, mph, knots, or inches. Explicit
normalization keeps values, unit labels, and provenance consistent.

**What this means for users**

Custom `OpenMeteoUnits` configurations now produce canonical PlantMeteo values.
Workflows that previously tolerated incomplete Open-Meteo forcing should handle
the reported error rather than expecting PlantMeteo to invent replacement data.

### Metadata and read/write round trips

**What changed**

- YAML metadata values are preserved as read. Column transformations no longer
  parse or rename values in the legacy `use` metadata field.
- YAML indentation is preserved so nested metadata survives write/read round
  trips.
- Normalization provenance survives `write_weather` followed by `read_weather`;
  the new import record is appended rather than replacing earlier history.

**Why**

Metadata is source provenance, not weather data. Changing metadata as a side
effect of column mapping made round trips lossy and gave undocumented meaning to
arbitrary source fields.

**What this means for users**

Code that expects `metadata(weather, :use)` to be parsed into symbols or renamed
must now interpret that source-specific value explicitly. Other metadata is
preserved for inspection and export.

### Removed internal compatibility code

- Removed the unused `transform_and_select.jl` implementation and its disabled
  test file. These files were not part of the loaded or exported PlantMeteo API.
- Internal Open-Meteo formatting is now non-mutating and returns the formatted
  rows together with canonical units and normalization provenance.

Most users do not need to change anything for these internal removals. Code that
directly included package source files or called unexported formatter functions
must migrate to the public `read_weather`, `get_weather`, and
`normalize_weather_import` APIs.

[0.9.0]: https://github.com/PalmStudio/PlantMeteo.jl/compare/v0.8.5...v0.9.0
