-module(spot_check).
-export([start/0, std_dev/1, avg/1]).

%% Main loop
-spec start() -> ok.
start() ->
    Line = io:get_line(""),
    case Line of
        eof ->
            ok;
        Line ->
            Line2 = string:strip(Line, both, $\n),
            Tokens = string:tokens(Line2, " "),
            parse(Tokens),
            start()
    end.

%%============================================================================
%% Internal Functions
%%============================================================================

%% Assume we start with a reference (and only one for whole session)
parse(["reference", TempStr, HumidStr]) ->
    {Temp, _} = string:to_integer(TempStr),
    {Humid, _} = string:to_integer(HumidStr),
    parse2(Temp, Humid, none, "", 0, []).

%% Read devices and device readings until we can read no more, evaluating each
%% device once a new device is encounted
parse2(AvgTemp, AvgHum, PrevType, PrevName, PrevAvg, PrevVals)
  when is_integer(AvgTemp) andalso
       is_integer(AvgHum) ->
    case io:get_line("") of
        eof ->
            eval_sensor(PrevType, PrevName, PrevAvg, PrevVals),
            ok;
        Line ->
            Line2 = string:strip(Line, both, $\n),
            Tokens = string:tokens(Line2, " "),
            case Tokens of
                ["thermometer", ThermName]  ->
                    eval_sensor(PrevType, PrevName, PrevAvg, PrevVals),
                    parse2(AvgTemp, AvgHum, therm, ThermName, AvgTemp, []);
                ["humidity", HumName] ->
                    eval_sensor(PrevType, PrevName, PrevAvg, PrevVals),
                    parse2(AvgTemp, AvgHum, hum, HumName, AvgHum, []);
                [_Time, PrevName, Val] ->
                    {FloatVal, _Rest} = string:to_float(Val),
                     parse2(AvgTemp, AvgHum, PrevType, PrevName,
                           PrevAvg, [FloatVal|PrevVals]);
                _ ->
                    io:format("Bad input, ignoring: ~s~n", [Line2]),
                    parse2(AvgTemp, AvgHum, PrevType, PrevName, PrevAvg, PrevVals)
            end
    end.

%% Evavluate sensor values and determine acceptance
eval_sensor(_Type, _Name, _Avg, []) ->
    ignore;
eval_sensor(therm, Name, Avg, Vals) ->
    ValsAvg = avg(Vals),
    StdDev = std_dev(Vals),
    if
        erlang:abs(ValsAvg-Avg) =< 0.5 andalso StdDev < 3 ->
            io:format("~s: ultra precise~n", [Name]),
            therm_ultra_precise;
        erlang:abs(ValsAvg-Avg) =< 0.5 andalso StdDev < 5 ->
            io:format("~s: very precise~n", [Name]),
            therm_very_precise;
        true ->
            io:format("~s: precise~n", [Name]),
            therm_precise
    end;
eval_sensor(hum, Name, Avg, Vals) ->
    case erlang:length([X || X <- Vals, erlang:abs(X-Avg)/Avg > 0.01]) of
        0 ->
            io:format("~s: OK~n", [Name]),
            hum_ok;
        _ ->
            io:format("~s: discard~n", [Name]),
            hum_discard
    end.

%% Calculate average value from list of numbers
-spec avg(list(float())) -> float().
avg(L) ->
    Sum = lists:foldl(fun(X, Sum) -> X + Sum end, 0, L),
    Total = erlang:length(L),
    Sum/Total.

%% Calculate the standard deviation from list of numbers
-spec std_dev(list(float())) -> float().
std_dev(L) ->
    Avg = avg(L),
    Var = lists:foldl(fun(X, Sum) -> math:pow(erlang:abs(X-Avg), 2) + Sum end, 0, L)/5,
    math:sqrt(Var).

%%============================================================================
%% Tests
%%============================================================================
-include_lib("eunit/include/eunit.hrl").

avg_test() ->
    ?assertEqual(avg([4.0,5.0,6.0]), 5.0).

std_dev_test() ->
    ?assertEqual(std_dev([23.5,57.43,44.3,22.1,40.2]), 13.295824306901771).
