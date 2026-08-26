const WEATHER_CANONICAL_INPUT_UNITS = (Rh=:fraction, P=:kPa)

"""
    normalize_weather_import(data; input_units=(Rh=:fraction, P=:kPa))

Normalize explicitly declared import units into PlantMeteo's canonical units.

This boundary never guesses units from values. Relative humidity accepts
`:fraction` or `:percent`; pressure accepts `:kPa`, `:hPa`, or `:Pa`. Missing
values remain `missing`. The returned named tuple contains the normalized table
as `data` and a deterministic `provenance` record describing every conversion
that was applied.

# Example

```julia
raw = (Rh=[60.0, missing], P=[1013.0, 1012.0])
normalized = normalize_weather_import(
    raw;
    input_units=(Rh=:percent, P=:hPa),
)

normalized.data.Rh
normalized.provenance.conversions
```
"""
function normalize_weather_import(
    data;
    input_units=(Rh=:fraction, P=:kPa),
)
    input_units isa NamedTuple || throw(ArgumentError(
        "`input_units` must be a named tuple with optional `Rh` and `P` entries",
    ))

    unknown = setdiff(propertynames(input_units), propertynames(WEATHER_CANONICAL_INPUT_UNITS))
    isempty(unknown) || throw(ArgumentError(
        "Unsupported weather input unit key(s): $(join(string.(unknown), ", "))",
    ))

    units = merge(WEATHER_CANONICAL_INPUT_UNITS, input_units)
    _validate_weather_import_unit(:Rh, units.Rh, (:fraction, :percent))
    _validate_weather_import_unit(:P, units.P, (:kPa, :hPa, :Pa))

    normalized = Tables.columntable(data)
    conversions = NamedTuple[]

    normalized, conversion = _normalize_weather_import_column(
        normalized,
        :Rh,
        units.Rh,
        :fraction,
        units.Rh === :percent ? 0.01 : 1.0,
    )
    conversion === nothing || push!(conversions, conversion)

    pressure_scale = units.P === :hPa ? 0.1 : units.P === :Pa ? 0.001 : 1.0
    normalized, conversion = _normalize_weather_import_column(
        normalized,
        :P,
        units.P,
        :kPa,
        pressure_scale,
    )
    conversion === nothing || push!(conversions, conversion)

    provenance = (
        input_units=units,
        output_units=WEATHER_CANONICAL_INPUT_UNITS,
        conversions=Tuple(conversions),
    )
    return (data=normalized, provenance=provenance)
end

function _validate_weather_import_unit(variable::Symbol, unit::Symbol, allowed)
    unit in allowed || throw(ArgumentError(
        "Unsupported unit `$unit` for `$variable`; expected one of $(join(("`$u`" for u in allowed), ", "))",
    ))
    return nothing
end

function _validate_weather_import_unit(variable::Symbol, unit, allowed)
    throw(ArgumentError(
        "Unit for `$variable` must be a Symbol, got $(repr(unit)); expected one of $(join(("`$u`" for u in allowed), ", "))",
    ))
end

function _normalize_weather_import_column(data, variable, input_unit, output_unit, scale)
    hasproperty(data, variable) || return data, nothing
    input_unit === output_unit && return data, nothing

    values_ = map(Tables.getcolumn(data, variable)) do value
        ismissing(value) ? missing : value * scale
    end
    normalized = set_column(data, variable, values_)
    conversion = (
        variable=variable,
        input_unit=input_unit,
        output_unit=output_unit,
        scale=scale,
    )
    return normalized, conversion
end

function _weather_import_provenance_metadata(provenance)
    conversions = Dict{String,Any}[]
    for conversion in provenance.conversions
        record = Dict{String,Any}()
        for (key, value) in pairs(conversion)
            record[string(key)] = value isa Symbol ? string(value) : value
        end
        push!(conversions, record)
    end

    return Dict{String,Any}(
        "schema" => "PlantMeteo.import-normalization.v1",
        "input_units" => _weather_import_units_metadata(provenance.input_units),
        "output_units" => _weather_import_units_metadata(provenance.output_units),
        "conversions" => conversions,
    )
end

function _weather_import_units_metadata(units)
    metadata = Dict{String,Any}()
    for (variable, unit) in pairs(units)
        metadata[string(variable)] = unit isa Symbol ? string(unit) : unit
    end
    return metadata
end

function _weather_import_provenance_history(provenance)
    return Dict{String,Any}[_weather_import_provenance_metadata(provenance)]
end

function _append_weather_import_provenance(metadata::NamedTuple, provenance)
    history = Dict{String,Any}[]
    if hasproperty(metadata, :import_normalization)
        existing = getproperty(metadata, :import_normalization)
        records = existing isa AbstractVector ? existing : (existing,)
        for record in records
            push!(history, _coerce_weather_import_provenance_record(record))
        end
    end
    push!(history, _weather_import_provenance_metadata(provenance))
    return merge(metadata, (import_normalization=history,))
end

function _coerce_weather_import_provenance_record(record::AbstractDict)
    return Dict{String,Any}(string(key) => value for (key, value) in pairs(record))
end

function _coerce_weather_import_provenance_record(record)
    return Dict{String,Any}(
        "schema" => "PlantMeteo.import-normalization.legacy-source.v1",
        "source_value" => record,
    )
end
