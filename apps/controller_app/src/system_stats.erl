%%%-------------------------------------------------------------------
%%% @copyright
%%% Copyright (C) 2011 by Bermuda Triangle
%%%
%%% Permission is hereby granted, free of charge, to any person obtaining a copy
%%% of this software and associated documentation files (the "Software"), to deal
%%% in the Software without restriction, including without limitation the rights
%%% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%%% copies of the Software, and to permit persons to whom the Software is
%%% furnished to do so, subject to the following conditions:
%%%
%%% The above copyright notice and this permission notice shall be included in
%%% all copies or substantial portions of the Software.
%%%
%%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
%%% THE SOFTWARE.
%%% @end
%%%-------------------------------------------------------------------

-module(system_stats).

-export([get_system_stats/1, max_mem_proc/0, get_db_stats/0]).
-include_lib("utils/include/debug.hrl").

%%---------------------------------------------------------------------
%% Data Type: application stats
%% where:
%%    app: The name of the application
%%    node_count: An integer, how many nodes are running that app
%%    node_worker_stats: a list of tuples
%%      {Node :: node(), NumOfWorkers :: integer(),
%%       {Max :: integer(), Min :: integer(), Avg :: float()}}
%%      where node is the nodename, NumOfWorkers is the number of workers
%%      and Max/Min/Avg is the max/min/avg message queue length on that node.
%%----------------------------------------------------------------------
-record(system_stats, {app,
                       node_count,
                       node_worker_stats}).

% creates a dotted line 60 characters long
-define(BREAKLINE, io_lib:format("~60c~n", [$-])).

%% ------------------------------------------------------------------
%% API
%% ------------------------------------------------------------------
%%-------------------------------------------------------------------
%% @doc
%% Gets some system statistics
%% @end
%% @spec get_system_stats(OutputType::atom()) -> string | {ok, string()}
%% @end
%%-------------------------------------------------------------------
get_system_stats(OutputType) ->
    AppStats = get_all_app_stats(),
    FrontendStats = get_frontend_stats(),
    MachineStats = get_machine_stats(),
    AllStats = lists:flatten(MachineStats ++ FrontendStats ++ AppStats),
    case OutputType of
        io_format ->
            io:format("~s", [AllStats]);
        string ->
            {ok, AllStats}
    end.

%% ------------------------------------------------------------------
%% Machine Statistics - text output
%% ------------------------------------------------------------------
%% ------------------------------------------------------------------
%% @doc
%% Converts each element of the list, that <code>get_machines_states()</code>
%% returns, to the character list, then combines the converted value with
%% other string values, and returns the result.
%%
%% @spec
%% get_machine_stats() -> string()
%% @end
%%--------------------------------------------------------------------
get_machine_stats() ->
    MachineHeadline = break_line("machine state"),
    MachineStats = lists:map(fun(Element) ->
                                 {Node,
                                  SystemLoad,
                                  CpuUsage,
                                  MemoryUsage,
                                  Reductions} = Element,
                                 io_lib:format("Node:\t\t~s~n"
                                               "System load:\t~p~n"
                                               "CPU usage:\t~p~n"
                                               "Memory usage:\t~p~n"
                                               "Reductions:\t~p~n",
                                               [Node,
                                                SystemLoad,
                                                CpuUsage,
                                                MemoryUsage,
                                                Reductions])
                             end, get_machines_states()),
    MachineHeadline ++ MachineStats ++ ?BREAKLINE.

%% ------------------------------------------------------------------
%% Machine Statistics - data
%% ------------------------------------------------------------------
%% ------------------------------------------------------------------
%% @doc
%% Returns state of the machines which are in the nodes list
%%
%% @spec
%% get_machines_states() -> List
%% where
%%     List = [{Node::node(),
%%              SysLoad,
%%              CpuUsg::float(),
%%              MemUsg}]
%%     SysLoad = {Avg1::integer(), Avg5::integer(), Avg15::integer()}
%%     MemUsg = [Tuples]
%%     Tuples = tuple()
%% @end
%%--------------------------------------------------------------------
get_machines_states() ->
    lists:map(fun(Pid) ->
                  Node = node(Pid),
                  {SysLoad,
                   CpuUsg,
                   MemUsg,
                   Red} = controller_app_config:machine_state(Pid),
                  {Node, SysLoad, CpuUsg, MemUsg, Red}
              end, controller_app_config:node_pids()).

%% ------------------------------------------------------------------
%% Frontend Statistics - text output
%% ------------------------------------------------------------------
get_frontend_stats() ->
    FrontendHeadline = break_line("online users"),
    IM = session_presence:count_all_by_type(im),
    Mail = session_presence:count_all_by_type(mail),
    Web = session_presence:count_all_by_type(web),
    Total = session_presence:count_all(),
    UserStats = io_lib:format("Total users:\t~p~nIM users:\t~p~n"
                              "Mail users:\t~p~nWeb users:\t~p~n",
                              [Total, IM, Mail, Web]),
    FrontendHeadline ++ UserStats ++ ?BREAKLINE.

%% ------------------------------------------------------------------
%% Frontend Statistics - text output
%% ------------------------------------------------------------------
get_db_stats() ->
    AllDbNodeStats = lists:map(fun(Pid) ->
                 controller_app_config:db_state(Pid)
              end, controller_app_config:node_pids()),
    {ok, AllDbNodeStats}.

%% ------------------------------------------------------------------
%% Cross-Node Application Statistics - text output
%% ------------------------------------------------------------------
get_all_app_stats() ->
    % get data for each app (system stats record)
    DbStats = get_app_stats(db_config, db),
    ControllerStats = get_app_stats(controller_app_config, controller_app),
    GameStats = get_app_stats(game_config, game),
    MessageStats = get_app_stats(message_config, message),
    AppHeadline = break_line("applications"),
    % build the output
    Appstats = appstats_text_output([DbStats, ControllerStats,
                                     GameStats, MessageStats]),
    AppHeadline ++ Appstats ++ ?BREAKLINE.


appstats_text_output(StatsList) ->
    appstats_text_output(StatsList, "").
appstats_text_output([], AppStatistics) ->
    AppStatistics;
appstats_text_output([AppStats | StatsList], Stats) ->
    AppName = AppStats#system_stats.app,
    NodeCount = integer_to_list(AppStats#system_stats.node_count),
    NodeWorkerList = AppStats#system_stats.node_worker_stats,
    StatText = Stats ++ io_lib:format("Application\t~s\t~s node(s)~n",
                                      [AppName, NodeCount]),
    % format data for each node
    AppData =
        lists:foldl(fun({Node, WorkerCount, {Max, Min, AvgQueue}}, Acc) ->
                            MaxQueue = integer_to_list(Max),
                            MinQueue = integer_to_list(Min),
                            Count = integer_to_list(WorkerCount),
                            Acc ++
                                io_lib:format("\tNode:\t~s\tWorkers:\t~s~n\t\t"
                                              "\tMax queue:\t~s~n\t\t"
                                              "\tMin queue:\t~s~n\t\t"
                                              "\tAvg. queue:\t~.1f~n",
                                              [Node, Count,MaxQueue,
                                               MinQueue, AvgQueue])
                    end, "", NodeWorkerList),
    appstats_text_output(StatsList, StatText ++ AppData).

%% ------------------------------------------------------------------
%% Cross-Node Application Statistics - data
%% ------------------------------------------------------------------
%% ------------------------------------------------------------------
%% @doc
%% Gets statistics about number of workers and max/min/avg message queue
%% from all nodes on which the application is running on.
%% @end
%% @spec
%% get_app_stats(ConfigModName :: atom(),
%%               AppName :: atom()) ->
%%     #system_stats{}
%% @end
%%--------------------------------------------------------------------
get_app_stats(ConfigMod, AppName) ->
    Nodes = ConfigMod:node_count(),
    Pids = ConfigMod:node_pids(),
    NodeWorkerStats = get_worker_data(ConfigMod, Pids),
    #system_stats{app = AppName,
                  node_count = Nodes,
                  node_worker_stats = NodeWorkerStats}.


get_worker_data(ConfigMod, Pids) ->
    get_worker_data(ConfigMod, Pids, []).
get_worker_data(_Mod, [], Data) ->
    Data;
get_worker_data(ConfigMod, [Pid | Pids], Data) ->
    QueueInfo = queue_max_min_avg(ConfigMod:queue_info(Pid)),
    get_worker_data(ConfigMod, Pids,
                    [{node(Pid),
                      ConfigMod:worker_count(Pid),
                      QueueInfo} | Data]).


queue_max_min_avg({Key, WorkerData}) ->
    max_min_avg(Key, WorkerData, 0, undefined, 0, 0).
max_min_avg(_Key, [], Max, Min, Tot, Num) ->
    {Max, Min, Tot/Num};
max_min_avg(Key, [{_Tag, QLen}| Workers], Max, Min, Tot, Num) ->
    if QLen > Max ->
            NewMax = QLen;
       true ->
            NewMax = Max
    end,
    case Min of
        undefined ->
            NewMin = QLen;
        _ when QLen < Min ->
            NewMin = QLen;
        _ ->
            NewMin = Min
    end,
    max_min_avg(Key, Workers, NewMax, NewMin, Tot+QLen, Num+1).



%%-------------------------------------------------------------------
%% @doc
%% Finds the module which uses the most memory in total
%% (all processes that spawned from that module)
%% @end
%%-------------------------------------------------------------------
max_mem_proc() ->
    ProcList = proc_mem_list(),
    MemDict = mod_mem_sum(ProcList),
    dict:fold(fun(Key, Val, {I, Max}) ->
                      case Val > Max of
                          true -> {Key, Val};
                          false -> {I, Max}
                      end
              end, {no_mod, 0}, MemDict).


%% ------------------------------------------------------------------
%% Other stuff
%% ------------------------------------------------------------------
break_line(HeadText) ->
    Headline = string:to_upper(HeadText) ++ ?BREAKLINE,
    io_lib:format("~60s~n", [Headline]).
%%-------------------------------------------------------------------
%% @doc Returns a list like:
%% [{pid(), Mod, Memory}]
%% where for every process there is a tuple like that.
%% @end
%%-------------------------------------------------------------------
proc_mem_list() ->
    ProcModFun = fun(Pid) ->
                         {memory, Val} = erlang:process_info(Pid, memory),
                         {dictionary, Dict} = erlang:process_info(Pid, dictionary),
                         case lists:keyfind('$initial_call', 1, Dict) of
                             false -> ignore;
                             {_, Mod} ->
                                 {Pid, Mod, Val}
                         end
                 end,
    ProcMods = lists:map(ProcModFun, processes()),
    FilterFun = fun(ignore) ->
                        false;
                   (_) -> true
                end,
    lists:filter(FilterFun, ProcMods).


%%-------------------------------------------------------------------
%% @doc
%% Sums for every module in ProcMemList up how much memory usage
%% originates from that module.
%% @end
%%-------------------------------------------------------------------
mod_mem_sum(ProcMemList) ->
    lists:foldl(fun({_P, I, M}, Dict) ->
                        case dict:find(I, Dict) of
                            {ok, Val} ->
                                dict:store(I, Val+M, Dict);
                            _ -> dict:store(I, M, Dict)
                        end
                end, dict:new(), ProcMemList).
