ref_values = (T=20.0, Wind=1.0, P=101.3, Rh=0.65)
row_types = [
    Atmosphere(; ref_values...),
    Dict(zip(keys(ref_values), values(ref_values))),
    ref_values
]

for row_type in row_types
    @testset "Testing TimeStepTable{$(nameof(typeof(row_type)))}}" begin
        # row_type = row_types[2]
        ts = TimeStepTable([row_type, row_type])

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
        @test Tables.getcolumn(ts_rows[1], :Rh) == getindex(row_type, :Rh)

        if isa(row_type, Atmosphere)
            @test Tables.getcolumn(ts_first, 1) == ts_first[:date]
            @test Tables.getcolumn(ts_rows[1], 1) == row_type[1]
        end

        @test keys(ts) == propertynames(ts_first) == names(ts)

        # Get column value using indexing and/or the dot syntax:
        @test ts_rows[1].P == ref_values.P

        @test ts_rows[1][2] == getindex(row_type, names(ts)[2])
        @test ts_rows[1][:P] == ref_values[:P]

        # Get column values for all rows at once:
        cols = Tables.columns(ts)
        @test ts.T == cols.T
        @test ts[1, 1] == getindex(cols, names(ts)[1])[1]

        # Indexing as a Matrix:
        @test ts[1, :] == ts_first
        @test ts[:, 1] == getindex(cols, names(ts)[1])
        @test ts[1:2] isa TimeStepTable
        @test ts[1:2] == ts
        @test ts[1:2, :] isa TimeStepTable
        @test ts[1:2, :] == ts
        @test ts[1, :T] == ref_values.T
        @test ts[1, "T"] == ref_values.T
        @test ts[1:2, :T] == [ref_values.T, ref_values.T]
        @test ts[1:2, "T"] == [ref_values.T, ref_values.T]
        @test ts[:, :T] == ts.T
        @test ts[:, "T"] == ts.T
        @test PlantMeteo.row_struct(ts[[2, 1]][1, :]) == PlantMeteo.row_struct(ts[2, :])
        @test PlantMeteo.row_struct(ts[[2, 1]][2, :]) == PlantMeteo.row_struct(ts[1, :])
        @test length(ts[1:0]) == 0
        @test length(ts[1:0, :]) == 0
        @test_throws BoundsError ts[1:3]
        @test_throws BoundsError ts[1:3, :]
        @test_throws ArgumentError ts[1, :DOES_NOT_EXIST]

        # Get column names:
        @test Tables.columnnames(ts) == (keys(row_type)...,)

        # Get column names for a single row:
        @test Tables.columnnames(ts_rows[1]) == (keys(row_type)...,)

        # Testing transforming into a DataFrame:
        df = DataFrame(ts)

        @test size(df) == (nrow(ts), ncol(ts))
        @test df.T == [20.0, 20.0]
        @test df.Rh == [0.65, 0.65]
        @test names(df) == [string.(keys(row_type))...]
    end
end

@testset "TimeStepTable schema inference" begin
    ts_mixed = TimeStepTable([(A=nothing, B=1), (A=1.0, B=2)])
    sch_mixed = Tables.schema(ts_mixed)
    @test sch_mixed.names == (:A, :B)
    @test sch_mixed.types == (Union{Nothing,Float64}, Int64)

    ts_num = TimeStepTable([(A=1,), (A=2.0,)])
    sch_num = Tables.schema(ts_num)
    @test sch_num.names == (:A,)
    @test sch_num.types == (Union{Int64,Float64},)

    df_mixed = DataFrame(ts_mixed)
    @test eltype(df_mixed.A) == Union{Nothing,Float64}
end
