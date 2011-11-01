%%%-------------------------------------------------------------------
%%% @copyright
%%% COPYRIGHT
%%% @end
%%%-------------------------------------------------------------------
%%% @doc player_orders
%%%
%%% A module for recognizing play move orders in email body
%%%
%%% @TODO modify the code in a concurrent a way, so that results of some
%%% expensive initiations can be stored in other processes.
%%% @end
%%%
%%%-------------------------------------------------------------------
-module(player_orders).

%% Exports for API
-export([parse_orders/1]).

%% Exports for eunit
-export([init_valid_region/0,translate_location/1,interpret_str_orders/1,
         translate_fullname_to_abbv_atom/1,interpret_order_line/1]).

-include("test_utils.hrl").
-include("player_orders.hrl").

%%------------------------------------------------------------------------------
%% @doc parse player's orders to a list of order terms.
%%  Return {ok, {OrderList, ErrorList}}
%%
%%  Example:
%%  Input:  "F boh -> nwy         \n
%%           A vie H              \n
%%           A mun S A bor -> swe "
%%
%%  Output: {ok, {[#move{...},
%%                 #hold{...},
%%                 #support_move{...}],
%%                [{error, ...},
%%                 {error, ...}]}}
%% @end
%%------------------------------------------------------------------------------
parse_orders (EmailBody) when is_binary(EmailBody) ->
    parse_orders (binary_to_list(EmailBody));
parse_orders (EmailBody) ->
    init_valid_region(),
    LowerCasedEmailBody = string:to_lower(EmailBody),
    MailLines = string:tokens(LowerCasedEmailBody, "\n"),
    OrderList = interpret_str_orders(MailLines),
    ResultOrders = lists:partition(fun(X)->
                                        element(1, X) /= error end, OrderList),
    {ok, ResultOrders}.


%%------------------------------------------------------------------------------
%% @doc interpret each mail line to erlang terms
%%  Example:
%%  Input :["F boh -> nwy         \r",
%%          "A vie H              ",
%%          "A mun S A bor -> swe "]
%%
%%  Output: [#move{...},
%%           #hold{...},
%%           #support_move{...}]
%% @end
%%------------------------------------------------------------------------------
interpret_str_orders (MailLines) ->
    {ok, OrderParser} = re:compile(?ORD_PARSER, [{newline, anycrlf}]),
    interpret_str_orders(MailLines, OrderParser, []).

interpret_str_orders ([], _, StrOrderList) -> StrOrderList;
interpret_str_orders ([CurrentLine|Rest], OrderParser, StrOrderList) ->
    ExtractResult = re:run(CurrentLine, OrderParser, ?ORD_PARSER_SETTING),
    case ExtractResult of
        {match, ExtractedStrOrderLine} ->
            InterpretedLine = (catch interpret_order_line(ExtractedStrOrderLine)),
            case InterpretedLine of
                {'EXIT', _} ->
                    interpret_str_orders (Rest, OrderParser, StrOrderList);
                _ ->
                    interpret_str_orders (Rest, OrderParser, [InterpretedLine|StrOrderList])
            end;
        nomatch ->
            interpret_str_orders (Rest, OrderParser, StrOrderList)
    end.

%%------------------------------------------------------------------------------
%% @doc interpret a single player order string line to erlang terms
%%  Example:
%%  Input :"F boh -> nwy         \r"
%%
%%  Output: #move{subj_unit=fleet, subj_loc=boh, subj_dst=nwy}
%% @end
%%------------------------------------------------------------------------------
interpret_order_line (OrderLine) ->
    [SubjUnitStr, SubjLocStr, SubjActStr, ObjUnitStr, ObjSrcStr, ObjDstStr,
     CoastStr] = OrderLine,
    SubjAct = translate_action(SubjActStr),
    SubjUnit = translate_unit(SubjUnitStr),
    SubjLoc = translate_location(SubjLocStr),
    ObjUnit = translate_unit(ObjUnitStr),
    ObjSrc = translate_location(ObjSrcStr),
    ObjDst = translate_location(ObjDstStr),
    Coast = translate_coast(CoastStr),

    case SubjAct of
        move when SubjLoc /=nil, ObjSrc/=nil ->
            #move{subj_unit = SubjUnit, subj_src_loc = SubjLoc,
                  subj_dst_loc = ObjSrc, coast = Coast};
        support when ObjDst == nil, SubjLoc /=nil, ObjSrc /=nil ->
            #support_hold{subj_unit = SubjUnit, subj_loc = SubjLoc,
                          obj_unit = ObjUnit, obj_loc = ObjSrc};
        support when SubjLoc /=nil, ObjSrc /=nil, ObjDst /=nil ->
            #support_move{subj_unit = SubjUnit, subj_loc = SubjLoc,
                          obj_unit = ObjUnit, obj_src_loc = ObjSrc,
                          obj_dst_loc = ObjDst, coast = Coast};
        hold when SubjLoc /=nil->
            #hold{subj_unit = SubjUnit, subj_loc = SubjLoc};
        convoy when SubjLoc /=nil, ObjSrc /=nil, ObjDst /=nil ->
            #convoy{subj_unit = SubjUnit, subj_loc = SubjLoc, obj_unit = ObjUnit,
                    obj_src_loc = ObjSrc, obj_dst_loc = ObjDst};
        build when ObjUnit /=nil, ObjSrc /=nil ->
            % @TODO default coast for special coastal province
            #build{obj_unit = ObjUnit, obj_loc = ObjSrc, coast = Coast};
        remove when ObjSrc /= nil ->
            #remove{obj_unit = ObjUnit, obj_loc = ObjSrc};
        disband when SubjLoc /= nil ->
            #disband{subj_unit = SubjUnit, subj_loc = SubjLoc};
        waive ->
            #waive{};
        _ ->
            throw({error, {"invalid action#",OrderLine}})
    end.

% functions prefix with translate_
% should only be called by interpret_order_line/1----------------------------
translate_location([]) -> nil;
translate_location(Loc) when length(Loc) >3 ->
    translate_fullname_to_abbv_atom(Loc);
translate_location(Loc) ->
    ExistingAtom = (catch list_to_existing_atom(Loc)),
    case ExistingAtom of
        {'EXIT', _} ->
            throw({error, Loc ++ "#invalid location name, not in atom table"});
        MatchedAtom ->
            case get(MatchedAtom) of
                true -> MatchedAtom;
                undefined ->
                    throw({error, Loc ++ "#invalid location name, not in procdict"})
            end
    end.


translate_coast(Key) ->
    get_translation(Key, ?TRANS_COAST, "coast name").


translate_unit(Key) ->
    get_translation(Key, ?TRANS_UNIT, "unit name").


translate_action(Key) ->
    get_translation(Key, ?TRANS_ACTION, "action name").


translate_fullname_to_abbv_atom(Key) ->
    get_translation(Key, ?TRANS_LOC_FULLNAME, "full name").


get_translation(Key, PropList, ErrorMsg) ->
    Value = proplists:get_value(Key, PropList),
    case Value of
        undefined ->
            throw({error, Key ++ "#invalid " ++ ErrorMsg});
        _ ->
            Value
    end.


% Make sure the procdict won't be rewritten some where else
% @TODO check if there's some way better than procdict
init_valid_region () ->
    lists:foreach(fun(X) -> put(X, true) end, ?LOCATIONS).