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
%%%
%%% @doc
%%%  Utilities to read an app.config as a term, update it, and write it in
%%%  the correct form again.
%%% @end
%%%
%%% @since : 23 Nov 2011 by Bermuda Triangle
%%% @end
%%%-------------------------------------------------------------------
-module(manage_config).

%% ------------------------------------------------------------------
%% API Function Exports
%% ------------------------------------------------------------------
-export([read_config/1, update_config/2, write_config/2]).

%% ------------------------------------------------------------------
%% @doc
%% Read an app.config as an erlang term.
%% @end
%% ------------------------------------------------------------------
-spec read_config(string()) -> {ok, term()}.
read_config(Path) ->
    {ok, [Config]} = file:consult(Path),
    {ok, Config}.

%% ------------------------------------------------------------------
%% @doc
%% Update the first level list of an app.config term with the given list.
%% Terms that don't exist will be added.
%% The OldConfig [{a, before}] with ConfigChanges [{a, after}, {b, new}]
%% will be returned as [{a, after}, {b, new}].
%% @end
%% ------------------------------------------------------------------
-spec update_config([tuple()], [tuple()]) -> [tuple()].
update_config(OldConfig, ConfigChanges) ->
    Fun = fun(Change, Config) ->
                  Key = element(1, Change),
                  lists:keystore(Key, 1, Config, Change)
          end,
    lists:foldl(Fun, OldConfig, ConfigChanges).

%% ------------------------------------------------------------------
%% @doc Write an app.config term to the given path with a trailing period (.) 
%% @end
%% ------------------------------------------------------------------
-spec write_config(string(), term()) -> ok | {error, term()}.
write_config(Path, Config) ->
    ConfigString = io_lib:format("~p.", [Config]),
    file:write_file(Path, ConfigString).