@testset "Testing TimeStepRow" begin
    vars1 = Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65)
    vars2 = Atmosphere(T=21.0, Wind=3.0, P=101.3, Rh=0.63)
    ts = TimeStepTable([vars1, vars2])

    @test typeof(ts[1]) <: PlantMeteo.TimeStepRow{T} where {T<:Atmosphere}

    row1 = ts[1]
    row2 = ts[2]

    @test row1.T == 20.0
    @test row2.T == 21.0

    @test parent(row1) == ts
    @test parent(row2) == ts
    @test PlantMeteo.rownumber(row1) == 1
    @test PlantMeteo.rownumber(row2) == 2
    @test PlantMeteo.row_from_parent(row1, 1) == row1
    @test PlantMeteo.row_from_parent(row1, 2) == row2
    @test PlantMeteo.next_row(row1) == row2
    @test PlantMeteo.prev_row(row2) == row1

    @test_throws BoundsError PlantMeteo.next_row(row2)
    @test_throws BoundsError PlantMeteo.prev_row(row1)

    @test PlantMeteo.row_struct(row1) == vars1
    @test PlantMeteo.row_struct(row2) == vars2
    @test Tables.getcolumn(row1, :T) == 20.0
    @test Tables.getcolumn(row1, 3) == 20.0
    @test Tables.columnnames(row1) == keys(vars1)
end