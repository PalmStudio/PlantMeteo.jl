@testset "Testing TimeStepTable{Atmosphere}" begin
    vars = Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65)
    ts = TimeStepTable([vars, vars])

    @test Tables.istable(typeof(ts))

    ts_rows = Tables.rows(ts)
    @test length(ts_rows) == length(ts)

    @test Tables.rowaccess(typeof(ts))
    # test that it defines column access
    ts_first = first(ts)
    @test eltype(ts) == typeof(ts_first)
    # now we can test our `Tables.AbstractRow` interface methods on our MatrixRow
    @test ts_first.T == 20.00
    @test Tables.getcolumn(ts_first, :Wind) == 1.0
    @test Tables.getcolumn(ts_first, 1) == ts_first[:date]
    @test keys(ts) == propertynames(ts_first) == (
              :date, :duration, :T, :Wind, :P, :Rh, :Precipitations,
              :Cₐ, :e, :eₛ, :VPD, :ρ, :λ, :γ, :ε, :Δ, :clearness,
              :Ri_SW_f, :Ri_PAR_f, :Ri_NIR_f, :Ri_TIR_f, :Ri_custom_f
          )

    # Get column value using getcolumn:
    @test Tables.getcolumn(ts_rows[1], 1) == vars[1]
    @test Tables.getcolumn(ts_rows[1], :Rh) == vars.Rh

    # Get column value using indexing and/or the dot syntax:
    @test ts_rows[1].P == vars.P
    @test ts_rows[1][2] == vars[2]
    @test ts_rows[1][:date] == vars[1]

    # Get column values for all rows at once:
    cols = Tables.columns(ts)
    @test ts.T == cols.T
    @test ts[1, 1] == cols.date[1]

    # Indexing as a Matrix:
    @test ts[1, :] == ts_first
    @test ts[:, 1] == cols.date

    # Get column names:
    @test Tables.columnnames(ts) == keys(vars)

    # Get column names for a single row:
    @test Tables.columnnames(ts_rows[1]) == keys(vars)

    # Testing transforming into a DataFrame:
    df = DataFrame(ts)

    @test size(df) == (2, 22)
    @test df.T == [20.0, 20.0]
    @test df.VPD == [0.8214484239448965, 0.8214484239448965]
    @test names(df) == [string.(keys(vars))...]
end