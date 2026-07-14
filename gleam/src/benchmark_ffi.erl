-module(benchmark_ffi).
-export([
    file_open/1,
    file_close/1,
    file_read/2,
    file_size/1,
    monotonic_time_ns/0,
    erlang_memory_total/0,
    write_stderr/1,
    write_stdout_raw/1,
    write_file/2,
    halt/1,
    erlang_float_to_list/2
]).

file_open(Path) ->
    case file:open(binary_to_list(Path), [read, raw, binary]) of
        {ok, Fd} -> {ok, Fd};
        {error, Reason} -> {error, list_to_binary(atom_to_list(Reason))}
    end.

file_close(Fd) ->
    file:close(Fd),
    nil.

file_read(Fd, Size) ->
    case file:read(Fd, Size) of
        {ok, Data} -> {ok, Data};
        eof -> {error, <<"eof">>};
        {error, Reason} -> {error, list_to_binary(atom_to_list(Reason))}
    end.

file_size(Path) ->
    case file:read_file_info(binary_to_list(Path)) of
        {ok, Info} -> {ok, element(2, Info)};
        {error, Reason} -> {error, list_to_binary(atom_to_list(Reason))}
    end.

monotonic_time_ns() ->
    erlang:monotonic_time(nanosecond).

erlang_memory_total() ->
    erlang:memory(total).

write_stderr(Msg) ->
    io:put_chars(standard_error, Msg),
    nil.

write_stdout_raw(Msg) ->
    Bin = unicode:characters_to_binary(Msg, utf8),
    Port = open_port({fd, 0, 1}, [out, binary]),
    port_command(Port, Bin),
    port_close(Port),
    nil.

write_file(Path, Content) ->
    file:write_file(binary_to_list(Path), Content),
    nil.

halt(Code) ->
    erlang:halt(Code).

erlang_float_to_list(F, Decimals) ->
    list_to_binary(io_lib:format("~.*f", [Decimals, F])).
