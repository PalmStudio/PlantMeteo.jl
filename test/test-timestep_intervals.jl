@testset "timestep interval helpers" begin
    row1 = (date="2016/06/12", hour_start="08:30:00", hour_end="09:00:00")
    row2 = (date="2016/06/12", hour_start="09:00:00", hour_end="09:30:00")
    row_overlap = (date="2016/06/12", hour_start="08:45:00", hour_end="09:15:00")

    s1, e1 = row_datetime_interval(row1)
    @test s1 == DateTime(2016, 6, 12, 8, 30, 0)
    @test e1 == DateTime(2016, 6, 12, 9, 0, 0)

    s2, e2 = row_datetime_interval((date="2016/06/12", hour_start="09:00:00", step_duration="00:30:00"))
    @test s2 == DateTime(2016, 6, 12, 9, 0, 0)
    @test e2 == DateTime(2016, 6, 12, 9, 30, 0)

    @test duration_seconds("00:30:00") == 1800.0
    @test positive_duration_seconds(900.0) == 900.0
    @test_throws ErrorException positive_duration_seconds("0")

    check_non_overlapping_timesteps([row1, row2])
    @test_throws ErrorException check_non_overlapping_timesteps([row1, row_overlap])

    selected = select_overlapping_timesteps(
        [row1, row2],
        DateTime(2016, 6, 12, 9, 0, 0),
        DateTime(2016, 6, 12, 9, 0, 0);
        closed=true,
    )
    @test length(selected) == 2
end
