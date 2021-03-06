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
%%% @doc Unit tests for the session interface.
%%% @end
%%%
%%% @since : 17 Oct 2011 by Bermuda Triangle
%%% @end
%%%-------------------------------------------------------------------
-module(session_test).

-define(TIMEOUT, 3000).

-include_lib("eunit/include/eunit.hrl").
-include_lib("datatypes/include/push_receiver.hrl").
-include_lib("datatypes/include/push_event.hrl").
-include_lib("datatypes/include/user.hrl").


%% startup
apps() ->
    [message, protobuffs, riakc, db].

app_start() ->
    [ ?assertEqual(ok, application:start(App)) || App <- apps()],
    error_logger:tty(false).

%% teardown
app_stop(_) ->
    [ ?assertEqual(ok, application:stop(App)) || App <- lists:reverse(apps())],
    error_logger:tty(true).


%% testing the session interface
session_test_() ->
    {setup,
     fun app_start/0,
     fun app_stop/1,
     [
      ?_test(alive_t()),
      ?_test(start_stop_t()),
      ?_test(push_t())
     ]
    }.

alive_t() ->
    OwnId = session_id:from_pid(self()),
    FakeId = session_id:from_pid(list_to_pid("<0.9999.0>")),

    OwnAlive = session:alive(OwnId),
    ?assertEqual(true, OwnAlive),

    FakeAlive = session:alive(FakeId),
    ?assertEqual(false, FakeAlive).

start_stop_t() ->
    User = create_user(),
    Id = User#user.id,
    PushReceiver = #push_receiver{},
    SessionId = session:start(User, session_history:create(Id), PushReceiver),

    Alive = session:alive(SessionId),
    ?assertEqual(true, Alive),

    session:stop(SessionId),
    % wait for it to stop
    MonitorRef = monitor(process, session_id:to_pid(SessionId)),
    receive {'DOWN', MonitorRef, _Type, _Object, _Info} -> ok end,
    StopAlive = session:alive(SessionId),
    ?assertEqual(false, StopAlive).


%% helper functions
push_t() ->
    User = create_user(),
    Id = User#user.id,
    PushReceiver = #push_receiver{pid = self(), args = no_args,
                                  type = default
                                 },
    SessionId = session:start(User, session_history:create(Id), PushReceiver),

    Event = #push_event{type = test_type, data = {some, data, to, test, this}},
    session:push_event(SessionId, Event),
    Received = receive
                   Any -> Any
               after ?TIMEOUT -> {error, timeout}
               end,
    session:stop(SessionId),

    ?assertEqual({push, no_args, Event}, Received).


%% helper functions
create_user() ->
    #user{id = db_c:get_unique_id(),
          nick = "testuser" ++ integer_to_list(db_c:get_unique_id()),
          email = "test@user.com",
          password = "test_passw0rd",
          name = "Test User",
          role = user,
          channel = mail,
          last_ip = {127, 0, 0, 0},
          last_login = never,
          score = 0,
          date_created = {{2011, 10, 18}, {10, 42, 15}},
          date_updated = {{2011, 10, 18}, {10, 42, 16}}}.
