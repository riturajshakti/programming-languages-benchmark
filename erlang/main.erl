-module(main).
-export([main/0]).

-define(CSV_PATH, "../users-big.csv").
-define(BUF_SIZE, 8 * 1024 * 1024).

-record(user, {id, name, email, country, age, profession, salary}).

main() ->
    CsvPath = ?CSV_PATH,

    io:format("==================================================~n"),
    io:format("Cross-Language Benchmark~n"),
    io:format("Language : Erlang~n"),
    io:format("==================================================~n~n"),
    io:format("Input File : ~s~n~n", [CsvPath]),

    %% Open file
    case file:open(CsvPath, [read, raw, binary]) of
        {ok, Fd} -> ok;
        {error, _} ->
            io:format(standard_error, "Error:~nUnable to open ~s~n", [CsvPath]),
            halt(1),
            Fd = undefined
    end,

    %% Get file size
    {ok, FileInfo} = file:read_file_info(CsvPath),
    CsvSizeBytes = element(2, FileInfo),

    %% Start timing
    StartTime = erlang:monotonic_time(nanosecond),

    %% Process file
    {RowsProcessed, InvalidRows, TotalSalary, MinSalary, MaxSalary, TotalAge,
     Countries, Professions} =
        process_file(Fd, CsvSizeBytes, StartTime),

    file:close(Fd),

    %% Final progress
    print_progress(CsvSizeBytes, CsvSizeBytes, RowsProcessed, StartTime),
    io:format("~n~n"),

    ValidRows = RowsProcessed - InvalidRows,
    AvgSalary = case ValidRows > 0 of true -> TotalSalary / ValidRows; false -> 0.0 end,
    AvgAge = case ValidRows > 0 of true -> TotalAge / ValidRows; false -> 0.0 end,
    MinSal = case MinSalary >= 1.0e308 of true -> 0.0; false -> MinSalary end,
    MaxSal = case MaxSalary =< -1.0e308 of true -> 0.0; false -> MaxSalary end,

    %% Find highest/lowest paid profession
    {HighestProf, LowestProf} = find_extreme_professions(Professions),

    %% Write JSON
    OutputPath = "result.json",
    write_json(OutputPath, RowsProcessed, ValidRows, InvalidRows,
               AvgSalary, MinSal, MaxSal, AvgAge,
               HighestProf, LowestProf, Countries, Professions),

    {ok, JsonInfo} = file:read_file_info(OutputPath),
    JsonSizeBytes = element(2, JsonInfo),

    EndTime = erlang:monotonic_time(nanosecond),
    Elapsed = (EndTime - StartTime) / 1.0e9,
    RowsPerSec = case Elapsed > 0 of true -> trunc(RowsProcessed / Elapsed); false -> 0 end,

    %% Peak memory
    PeakMemory = erlang:memory(total),

    io:format("==================================================~n"),
    io:format("Benchmark Complete~n"),
    io:format("==================================================~n~n"),
    io:format("Language           : Erlang~n~n"),
    io:format("Rows Processed     : ~B~n", [RowsProcessed]),
    io:format("Invalid Rows       : ~B~n~n", [InvalidRows]),
    io:format("CSV Size           : ~s~n", [format_size(CsvSizeBytes)]),
    io:format("JSON Size          : ~s~n~n", [format_size(JsonSizeBytes)]),
    io:format("Execution Time     : ~.3f seconds~n~n", [Elapsed]),
    io:format("Rows / Second      : ~B~n~n", [RowsPerSec]),
    io:format("Peak Memory        : ~s~n~n", [format_size(PeakMemory)]),
    io:format("Output File        : ~s~n~n", [OutputPath]),
    io:format("==================================================~n"),
    halt(0).

format_size(Bytes) ->
    B = float(Bytes),
    if
        B >= 1073741824 -> io_lib:format("~.2f GB", [B / 1073741824]);
        B >= 1048576 -> io_lib:format("~.2f MB", [B / 1048576]);
        B >= 1024 -> io_lib:format("~.2f KB", [B / 1024]);
        true -> io_lib:format("~B B", [Bytes])
    end.

print_progress(BytesRead, TotalBytes, Rows, StartTime) ->
    Now = erlang:monotonic_time(nanosecond),
    Elapsed = (Now - StartTime) / 1.0e9,
    RowsPerSec = case Elapsed > 0 of true -> trunc(Rows / Elapsed); false -> 0 end,
    MbPerSec = case Elapsed > 0 of true -> BytesRead / 1048576 / Elapsed; false -> 0.0 end,
    Percent = case TotalBytes > 0 of true -> BytesRead / TotalBytes * 100; false -> 0.0 end,

    BarWidth = 30,
    Filled = case TotalBytes > 0 of
        true -> min(trunc(BarWidth * BytesRead / TotalBytes), BarWidth);
        false -> 0
    end,

    %% Build UTF-8 bar as raw bytes
    F = <<16#e2, 16#96, 16#88>>,  %% █
    E = <<16#e2, 16#96, 16#91>>,  %% ░
    FilledBin = list_to_binary(lists:duplicate(Filled, binary_to_list(F))),
    EmptyBin = list_to_binary(lists:duplicate(BarWidth - Filled, binary_to_list(E))),

    %% Write raw bytes to fd 1 (stdout) to bypass Erlang's unicode handling
    Msg = io_lib:format("[~s] ~.2f% | ~B rows | ~B rows/sec | ~.2f MB/s    ",
              [<<FilledBin/binary, EmptyBin/binary>>, Percent, Rows, RowsPerSec, MbPerSec]),
    file:write(standard_io, [<<"\r">>, iolist_to_binary(Msg)]).

process_file(Fd, CsvSizeBytes, StartTime) ->
    process_loop(Fd, CsvSizeBytes, StartTime,
                 <<>>,  %% leftover
                 false, %% header_skipped
                 0,     %% bytes_read
                 0,     %% rows_processed
                 0,     %% invalid_rows
                 0.0,   %% total_salary
                 1.0e308,   %% min_salary
                 -1.0e308,  %% max_salary
                 0,     %% total_age
                 #{},   %% countries
                 #{},   %% professions
                 StartTime  %% last_progress
                ).

process_loop(Fd, CsvSizeBytes, StartTime,
             Leftover, HeaderSkipped, BytesRead,
             RowsProcessed, InvalidRows,
             TotalSalary, MinSalary, MaxSalary, TotalAge,
             Countries, Professions, LastProgress) ->
    case file:read(Fd, ?BUF_SIZE) of
        {ok, Data} ->
            NewBytesRead = BytesRead + byte_size(Data),
            Combined = <<Leftover/binary, Data/binary>>,

            {NewLeftover, NewHeaderSkipped, NRP, NIR, NTS, NMinS, NMaxS, NTA, NC, NP} =
                process_lines(Combined, HeaderSkipped,
                              RowsProcessed, InvalidRows,
                              TotalSalary, MinSalary, MaxSalary, TotalAge,
                              Countries, Professions),

            %% Progress every 50ms
            Now = erlang:monotonic_time(nanosecond),
            NewLastProgress = case (Now - LastProgress) >= 50000000 of
                true ->
                    print_progress(NewBytesRead, CsvSizeBytes, NRP, StartTime),
                    Now;
                false ->
                    LastProgress
            end,

            process_loop(Fd, CsvSizeBytes, StartTime,
                         NewLeftover, NewHeaderSkipped, NewBytesRead,
                         NRP, NIR, NTS, NMinS, NMaxS, NTA, NC, NP, NewLastProgress);
        eof ->
            %% Process remaining leftover
            {FRP, FIR, FTS, FMinS, FMaxS, FTA, FC, FP} =
                case Leftover of
                    <<>> ->
                        {RowsProcessed, InvalidRows, TotalSalary, MinSalary, MaxSalary,
                         TotalAge, Countries, Professions};
                    _ when HeaderSkipped ->
                        Line = string:trim(binary_to_list(Leftover), trailing, "\r\n"),
                        case Line of
                            [] ->
                                {RowsProcessed, InvalidRows, TotalSalary, MinSalary,
                                 MaxSalary, TotalAge, Countries, Professions};
                            _ ->
                                process_single_line(Line,
                                    RowsProcessed, InvalidRows,
                                    TotalSalary, MinSalary, MaxSalary, TotalAge,
                                    Countries, Professions)
                        end;
                    _ ->
                        {RowsProcessed, InvalidRows, TotalSalary, MinSalary, MaxSalary,
                         TotalAge, Countries, Professions}
                end,
            {FRP, FIR, FTS, FMinS, FMaxS, FTA, FC, FP}
    end.

process_lines(Data, HeaderSkipped, RP, IR, TS, MinS, MaxS, TA, C, P) ->
    case binary:split(Data, <<"\n">>) of
        [Line, Rest] ->
            TrimmedLine = string:trim(binary_to_list(Line), trailing, "\r"),
            case HeaderSkipped of
                false ->
                    process_lines(Rest, true, RP, IR, TS, MinS, MaxS, TA, C, P);
                true when TrimmedLine =:= [] ->
                    process_lines(Rest, true, RP, IR, TS, MinS, MaxS, TA, C, P);
                true ->
                    {NRP, NIR, NTS, NMinS, NMaxS, NTA, NC, NP} =
                        process_single_line(TrimmedLine, RP, IR, TS, MinS, MaxS, TA, C, P),
                    process_lines(Rest, true, NRP, NIR, NTS, NMinS, NMaxS, NTA, NC, NP)
            end;
        [Leftover] ->
            {Leftover, HeaderSkipped, RP, IR, TS, MinS, MaxS, TA, C, P}
    end.

process_single_line(Line, RP, IR, TS, MinS, MaxS, TA, Countries, Professions) ->
    case string:split(Line, ",", all) of
        [Id, _Name, Email, Country, AgeStr, Profession, SalaryStr | _] when length(Id) > 0 ->
            case string:find(Email, "@") of
                nomatch ->
                    {RP + 1, IR + 1, TS, MinS, MaxS, TA, Countries, Professions};
                _ ->
                    case catch list_to_integer(AgeStr) of
                        Age when is_integer(Age) ->
                            CleanSalary = string:trim(SalaryStr, trailing, "\r"),
                            case catch list_to_float(CleanSalary) of
                                Salary when is_float(Salary) ->
                                    do_process(Id, _Name, Email, Country, Age, Profession, Salary,
                                              RP, IR, TS, MinS, MaxS, TA, Countries, Professions);
                                _ ->
                                    %% Try integer salary
                                    case catch list_to_integer(CleanSalary) of
                                        SalInt when is_integer(SalInt) ->
                                            Salary2 = float(SalInt),
                                            do_process(Id, _Name, Email, Country, Age, Profession, Salary2,
                                                      RP, IR, TS, MinS, MaxS, TA, Countries, Professions);
                                        _ ->
                                            {RP + 1, IR + 1, TS, MinS, MaxS, TA, Countries, Professions}
                                    end
                            end;
                        _ ->
                            {RP + 1, IR + 1, TS, MinS, MaxS, TA, Countries, Professions}
                    end
            end;
        [[] | _] ->
            {RP + 1, IR + 1, TS, MinS, MaxS, TA, Countries, Professions};
        _ ->
            {RP + 1, IR + 1, TS, MinS, MaxS, TA, Countries, Professions}
    end.

do_process(_Id, _Name, _Email, Country, Age, Profession, Salary,
           RP, IR, TS, MinS, MaxS, TA, Countries, Professions) ->
    %% Create user record
    _User = #user{id=_Id, name=_Name, email=_Email, country=Country,
                  age=Age, profession=Profession, salary=Salary},

    NewTS = TS + Salary,
    NewMinS = case Salary < MinS of true -> Salary; false -> MinS end,
    NewMaxS = case Salary > MaxS of true -> Salary; false -> MaxS end,
    NewTA = TA + Age,

    %% Country grouping
    NewCountries = case maps:find(Country, Countries) of
        {ok, {CC, CTS, CTA}} ->
            maps:put(Country, {CC + 1, CTS + Salary, CTA + Age}, Countries);
        error ->
            maps:put(Country, {1, Salary, Age}, Countries)
    end,

    %% Profession grouping
    NewProfessions = case maps:find(Profession, Professions) of
        {ok, {PC, PTS}} ->
            maps:put(Profession, {PC + 1, PTS + Salary}, Professions);
        error ->
            maps:put(Profession, {1, Salary}, Professions)
    end,

    {RP + 1, IR, NewTS, NewMinS, NewMaxS, NewTA, NewCountries, NewProfessions}.

find_extreme_professions(Professions) ->
    maps:fold(fun(Name, {Count, TotalSal}, {High, HAvg, Low, LAvg}) ->
        Avg = TotalSal / Count,
        {NH, NHA} = case Avg > HAvg of true -> {Name, Avg}; false -> {High, HAvg} end,
        {NL, NLA} = case Avg < LAvg of true -> {Name, Avg}; false -> {Low, LAvg} end,
        {NH, NHA, NL, NLA}
    end, {"", -1.0e308, "", 1.0e308}, Professions),
    receive after 0 -> ok end,
    %% Extract just the names
    {H, _, L, _} = maps:fold(fun(Name, {Count, TotalSal}, {High, HAvg, Low, LAvg}) ->
        Avg = TotalSal / Count,
        {NH, NHA} = case Avg > HAvg of true -> {Name, Avg}; false -> {High, HAvg} end,
        {NL, NLA} = case Avg < LAvg of true -> {Name, Avg}; false -> {Low, LAvg} end,
        {NH, NHA, NL, NLA}
    end, {"", -1.0e308, "", 1.0e308}, Professions),
    {H, L}.

write_json(Path, RowsProcessed, ValidRows, InvalidRows,
           AvgSalary, MinSalary, MaxSalary, AvgAge,
           HighestProf, LowestProf, Countries, Professions) ->
    {ok, F} = file:open(Path, [write]),
    W = fun(Str) -> file:write(F, Str) end,
    Wf = fun(Fmt, Args) -> file:write(F, io_lib:format(Fmt, Args)) end,

    W("{\n"),
    W("  \"summary\": {\n"),
    Wf("    \"total_records\": ~B,~n", [RowsProcessed]),
    Wf("    \"valid_records\": ~B,~n", [ValidRows]),
    Wf("    \"invalid_records\": ~B,~n", [InvalidRows]),
    Wf("    \"average_salary\": ~.2f,~n", [AvgSalary]),
    Wf("    \"min_salary\": ~.2f,~n", [MinSalary]),
    Wf("    \"max_salary\": ~.2f,~n", [MaxSalary]),
    Wf("    \"average_age\": ~.2f,~n", [AvgAge]),
    Wf("    \"highest_paid_profession\": \"~s\",~n", [HighestProf]),
    Wf("    \"lowest_paid_profession\": \"~s\"~n", [LowestProf]),
    W("  },\n"),

    W("  \"countries\": {\n"),
    CountryList = maps:to_list(Countries),
    CountryTotal = length(CountryList),
    lists:foldl(fun({Name, {Count, TotalSal, TotalA}}, Idx) ->
        CA = TotalSal / Count,
        AA = TotalA / Count,
        Wf("    \"~s\": {~n", [Name]),
        Wf("      \"total_users\": ~B,~n", [Count]),
        Wf("      \"average_salary\": ~.2f,~n", [CA]),
        Wf("      \"average_age\": ~.2f~n", [float(AA)]),
        case Idx < CountryTotal of
            true -> W("    },\n");
            false -> W("    }\n")
        end,
        Idx + 1
    end, 1, CountryList),
    W("  },\n"),

    W("  \"professions\": {\n"),
    ProfList = maps:to_list(Professions),
    ProfTotal = length(ProfList),
    lists:foldl(fun({Name, {Count, TotalSal}}, Idx) ->
        PA = TotalSal / Count,
        Wf("    \"~s\": {~n", [Name]),
        Wf("      \"count\": ~B,~n", [Count]),
        Wf("      \"average_salary\": ~.2f~n", [PA]),
        case Idx < ProfTotal of
            true -> W("    },\n");
            false -> W("    }\n")
        end,
        Idx + 1
    end, 1, ProfList),
    W("  }\n"),
    W("}\n"),
    file:close(F).

float(X) when is_integer(X) -> X * 1.0;
float(X) when is_float(X) -> X.
