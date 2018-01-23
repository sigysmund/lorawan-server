%
% Copyright (c) 2016-2018 Petr Gotthard <petr.gotthard@centrum.cz>
% All rights reserved.
% Distributed under the terms of the MIT License. See the LICENSE file.
%
-module(lorawan_admin_graph_server).

-export([init/2]).
-export([is_authorized/2]).
-export([allowed_methods/2]).
-export([content_types_provided/2]).
-export([resource_exists/2]).

-export([get_server/2]).

-include("lorawan.hrl").
-record(state, {key}).

init(Req, _Opts) ->
    Key = cowboy_req:binding(name, Req),
    {cowboy_rest, Req, #state{key=Key}}.

is_authorized(Req, State) ->
    lorawan_admin:handle_authorization(Req, State).

allowed_methods(Req, State) ->
    {[<<"OPTIONS">>, <<"GET">>], Req, State}.

content_types_provided(Req, State) ->
    {[
        {{<<"application">>, <<"json">>, []}, get_server}
    ], Req, State}.

get_server(Req, #state{key=Key}=State) ->
    Server = mnesia:dirty_read(servers, node()),
    {jsx:encode([{name, Key}, {array, get_array(Server)}]), Req, State}.

get_array([#server{router_perf=Perf}]) when is_list(Perf) ->
    [{cols, [
        [{id, <<"timestamp">>}, {label, <<"Timestamp">>}, {type, <<"datetime">>}],
        [{id, <<"requests">>}, {label, <<"Requests per min">>}, {type, <<"number">>}],
        [{id, <<"errors">>}, {label, <<"Errors per min">>}, {type, <<"number">>}]
    ]},
    {rows, lists:map(
        fun ({Date, {ReqCnt, ErrCnt}}) ->
            [{c, [
                [{v, lorawan_admin:timestamp_to_json_date(Date)}],
                [{v, ReqCnt}],
                [{v, ErrCnt}]
            ]}]
        end, Perf)
    }];
get_array(_Else) ->
    [].

resource_exists(Req, #state{key=Key}=State) ->
    case atom_to_binary(node(), latin1) of
        Key ->
            {true, Req, State};
        _Else ->
            {false, Req, State}
    end.

% end of file
