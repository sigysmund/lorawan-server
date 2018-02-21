%
% Copyright (c) 2016-2018 Petr Gotthard <petr.gotthard@centrum.cz>
% All rights reserved.
% Distributed under the terms of the MIT License. See the LICENSE file.
%
-module(lorawan_connector_ws).

-export([start_connector/1, stop_connector/1]).
-export([init/2]).
-export([websocket_init/1, websocket_handle/2, websocket_info/2, terminate/3]).

-include("lorawan_db.hrl").

-record(state, {connector, type, bindings}).

start_connector(#connector{connid=Id, publish_uplinks=PubUp, publish_events=PubEv}=Connector) ->
    lorawan_http_registry:update_routes({ws, Id},
        case lorawan_connector:pattern_for_cowboy(PubUp) of
            undefined ->
                [];
            error ->
                lorawan_connector:raise_failed(Id, {badarg, PubUp}),
                [];
            Pattern1 ->
                [{Pattern1, ?MODULE, [Connector, uplink]}]
        end ++
        case lorawan_connector:pattern_for_cowboy(PubEv) of
            undefined ->
                [];
            error ->
                lorawan_connector:raise_failed(Id, {badarg, PubEv}),
                [];
            Pattern2 ->
                [{Pattern2, ?MODULE, [Connector, event]}]
        end).

stop_connector(Id) ->
    lorawan_http_registry:delete_routes({ws, Id}).

init(Req, [#connector{connid=Id}=Connector, Type]) ->
    Bindings = lorawan_admin:parse(cowboy_req:bindings(Req)),
    case validate(maps:to_list(Bindings)) of
        ok ->
            {ok, Timeout} = application:get_env(lorawan_server, websocket_timeout),
            {cowboy_websocket, Req, #state{connector=Connector, type=Type, bindings=Bindings}, #{idle_timeout => Timeout}};
        {error, Error} ->
            lorawan_utils:throw_error({connector, Id}, Error),
            Req2 = cowboy_req:reply(404, Req),
            {ok, Req2, undefined}
    end.

validate([{Key, Value} | Other]) ->
    case validate0(Key, Value) of
        ok ->
            validate(Other);
        Else ->
            Else
    end;
validate([])->
    ok.

validate0(deveui, DevEUI) ->
    case mnesia:dirty_read(devices, DevEUI) of
        [#device{}] ->
            ok;
        _Else ->
            {error, {unknown_deveui, lorawan_utils:binary_to_hex(DevEUI)}}
    end;
validate0(devaddr, DevAddr) ->
    case mnesia:dirty_read(nodes, DevAddr) of
        [#node{}] ->
            ok;
        _Else ->
            {error, {unknown_devaddr, lorawan_utils:binary_to_hex(DevAddr)}}
    end.

websocket_init(#state{connector=#connector{connid=Id, app=App}, bindings=Bindings} = State) ->
    lager:debug("WebSocket connector ~p with ~p", [Id, Bindings]),
    ok = pg2:join({backend, App}, self()),
    {ok, State}.

websocket_handle({text, Msg}, State) ->
    handle_downlink(Msg, State);
websocket_handle({binary, Msg}, State) ->
    handle_downlink(Msg, State);
websocket_handle({ping, _}, State) ->
    % no action needed as server handles pings automatically
    {ok, State};
websocket_handle(Data, State) ->
    lager:warning("Unknown handle ~w", [Data]),
    {ok, State}.

handle_downlink(Msg, #state{connector=Connector, bindings=Bindings}=State) ->
    case lorawan_connector:decode_and_downlink(Connector, Msg, Bindings) of
        ok ->
            ok;
        {error, {Object, Error}} ->
            lorawan_utils:throw_error(Object, Error);
        {error, Error} ->
            lorawan_utils:throw_error({connector, Connector#connector.connid}, Error)
    end,
    {ok, State}.

websocket_info(nodes_changed, State) ->
    % nothing to do here
    {ok, State};
websocket_info({uplink, _Node, Vars0},
        #state{connector=#connector{format=Format}, type=uplink, bindings=Bindings} = State) ->
    case lorawan_connector:same_common_vars(Vars0, Bindings) of
        true ->
            {reply, encode_uplink(Format, Vars0), State};
        false ->
            {ok, State}
    end;
websocket_info({uplink, _Node, _Vars}, #state{type=event}=State) ->
    % this is not for me
    {ok, State};
websocket_info({event, _Node, Vars0},
        #state{type=event, bindings=Bindings} = State) ->
    case lorawan_connector:same_common_vars(Vars0, Bindings) of
        true ->
            {reply, {text,
                jsx:encode(lorawan_admin:build(Vars0))}, State};
        false ->
            {ok, State}
    end;
websocket_info({event, _Node, _Vars0}, #state{type=uplink}=State) ->
    % this is not for me
    {ok, State};
websocket_info(Info, State) ->
    lager:warning("Unknown info ~p", [Info]),
    {ok, State}.

encode_uplink(<<"raw">>, Vars) ->
    {binary, maps:get(data, Vars, <<>>)};
encode_uplink(<<"json">>, Vars) ->
    {text, jsx:encode(lorawan_admin:build(Vars))};
encode_uplink(<<"www-form">>, Vars) ->
    {text, lorawan_connector:form_encode(Vars)}.

terminate(Reason, _Req, _State) ->
    lager:debug("WebSocket terminated: ~p", [Reason]),
    ok.

% end of file
