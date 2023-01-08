"""
    check_day_complete(df)

Check that the weather table `df` has full days (24h) of data by 
summing their durations.

`df` must be a `Tables.jl` compatible table with a `date` and `duration` column.
The `date` column must be a `Dates.DateTime` column, and the `duration` column 
must be a `Dates.Period` or `Dates.CompoundPeriod` column.
"""
function check_day_complete(df)
    !hasproperty(df, :date) && throw(ArgumentError("`df` should have a `date` column."))
    !hasproperty(df, :duration) && throw(ArgumentError("`df` should have a `duration` column."))

    if hasproperty(df, :dayofyear)
        dayofyear = df.dayofyear
    else
        dayofyear = Dates.dayofyear.(df.date)
    end

    # Compute the cumulated duration of each day
    duration_s = df.duration[1]
    prev_day = dayofyear[1]
    for (i, day) in enumerate(dayofyear)
        i == 1 && continue

        if day == prev_day
            # We are in the same day than the iteration before, so we cumulate
            duration_s += df.duration[i]
        else
            # We change day, so we check that the duration of the day before is one full day:
            if duration_s != Dates.Day(1)
                error("Day $(df.date[i]) is not complete: sum of all durations is not 24h, but $duration_s.")
            end
            prev_day = day

            # we restart duration to the first value of the day
            duration_s = df.duration[i]
        end
    end
end
