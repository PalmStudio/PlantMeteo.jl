"""
    rh_from_vpd(VPD,eₛ)

Conversion between VPD and rh.

# Examples

```julia
eₛ = e_sat(Tₐ)
rh_from_vpd(1.5,eₛ)
```
"""
function rh_from_vpd(VPD, eₛ)
    one(VPD) - VPD / eₛ
end

"""
    rh_from_e(VPD,eₛ)

Conversion between e (kPa) and rh (0-1).

# Examples

```julia
rh_from_e(1.5,25.0)
```
"""
function rh_from_e(e, Tₐ)
    eₛ = e_sat(Tₐ)
    min(one(e), e / eₛ)
end

"""
    vpd(Rh,Tₐ)

Compute vapor pressure deficit (kPa) from the air relative humidity (0-1) and temperature (°C).

The computation simply uses vpd = eₛ - e.

# Examples

```julia
vpd(0.4,25.0)
```
"""
function vpd(Rh, Tₐ)
    return vpd_from_e(vapor_pressure(Tₐ, Rh), Tₐ)
end

"""
    vpd_from_e(e,Tₐ)

Compute vapor pressure deficit (kPa) from the air vapor pressure (kPa) and temperature (°C).

The computation simply uses vpd = eₛ - e.

# Examples

```julia
vpd_from_e(1.5,25.0)
```
"""
function vpd_from_e(e, Tₐ)
    return e_sat(Tₐ) - e
end