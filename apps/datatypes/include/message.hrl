-ifndef(MSG_DATAMODEL).
-define(MSG_DATAMODEL, true).

-include_lib("datatypes/include/date.hrl").
-include_lib("datatypes/include/game.hrl").

-record (message, {id :: integer(),
                   from_id :: integer(),
                   from_nick :: string (),
                   to_id :: integer(),
                   to_nick :: string(),
                   content :: nonempty_string(),
                   date_created :: date (),
                   status = unread :: read | unread
                  }).

-record (game_message, {id :: integer(),
                        game_id :: integer(),
                        from_id :: integer(),
                        from_country :: country()| unknown,
                        to_id :: integer(),
                        to_country :: country(),
                        content :: nonempty_string(),
                        date_created :: date (),
                        status = unread :: read | unread
                       }).

%% The "to" field in record frontend_msg:
%% * For off-game communication it's a string()
%% * For in-game communication it's a list(), so that we can send to
%%   several players  e.g. [england, russia, french]
-record (frontend_msg, {to :: list(atom()) | string(),
                        content :: nonempty_string(),
                        game_id = undefined :: undefined | integer()
                       }).

-endif.