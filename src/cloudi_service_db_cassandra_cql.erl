%-*-Mode:erlang;coding:utf-8;tab-width:4;c-basic-offset:4;indent-tabs-mode:()-*-
% ex: set ft=erlang fenc=utf-8 sts=4 ts=4 sw=4 et:
%%%
%%%------------------------------------------------------------------------
%%% @doc
%%% ==CloudI DB Cassandra CQL Module==
%%%
%%%     CloudI layer on top of erlcql from
%%%         https://github.com/rpt/erlcql.git
%%%
%%%     NOTE: set service config count_process to desired pool size
%%%
%%%     erlcql_client results will be wrapped in cloudi:send_sync result:
%%%     {ok, ErlcqlClientResult}
%%%
%%%     As a result all successful responses from erlcql_client will be of the form
%%%         {ok, {ok, Response}}
%%%     All failures from erlcql_client will be of the form
%%%         {ok, {error, Reason}}
%%%
%%%     send_sync errors will be standard 'CloudI' errors
%%%
%%%
%%% @end
%%%
%%% BSD LICENSE
%%%
%%% Copyright (c) 2014, Irina Guberman <irina.guberman@gmail.com>
%%% All rights reserved.
%%%
%%% Redistribution and use in source and binary forms, with or without
%%% modification, are permitted provided that the following conditions are met:
%%%
%%%     * Redistributions of source code must retain the above copyright
%%%       notice, this list of conditions and the following disclaimer.
%%%     * Redistributions in binary form must reproduce the above copyright
%%%       notice, this list of conditions and the following disclaimer in
%%%       the documentation and/or other materials provided with the
%%%       distribution.
%%%     * All advertising materials mentioning features or use of this
%%%       software must display the following acknowledgment:
%%%         This product includes
%%%         software developed by Irina Guberman
%%%     * The name of the author may not be used to endorse or promote
%%%       products derived from this software without specific prior
%%%       written permission
%%%
%%% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
%%% CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
%%% INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
%%% OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
%%% DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
%%% CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
%%% SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
%%% BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
%%% SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
%%% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
%%% WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
%%% NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
%%% OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
%%% DAMAGE.
%%%
%%% @author Irina Guberman <irina.guberman@gmail.com>
%%% @copyright 2014 Irina Guberman
%%% @version 1.0.0 06/12/2014
%%%------------------------------------------------------------------------
-module(cloudi_service_db_cassandra_cql).
-author("irinaguberman").

-behaviour(cloudi_service).

%% cloudi_service callbacks
-export([cloudi_service_init/3,
  cloudi_service_handle_request/11,
  cloudi_service_handle_info/3,
  cloudi_service_terminate/2]).

-include_lib("cloudi_core/include/cloudi_logger.hrl").
-include_lib("erlcql/include/erlcql.hrl").

-type dispatcher()      :: cloudi_service:dispatcher() | cloudi:context().

-record(state, {
  client              :: pid(),
  consistency         :: atom()
}).


-type cql_name()       :: atom().
-type cql_params()     :: [binary() | integer() | none()].


-type executeRequest() :: { QueryName :: cql_name(),
                            Params :: cql_params(),
                            Consistency :: consistency() | none()}.

-type queryRequest() ::   { QueryString :: string(),
                            Consistency :: consistency() | none()}.


-type service_request() :: executeRequest() | queryRequest().

-type query()           :: {Name :: cql_name(), Query :: binary()}.

-type service_name() :: { service_name, ServiceName :: string() }.
-type connection_options() :: { connection_options, [ {host, Host :: string()} |
                                                      {port, Port :: integer()} |
                                                      {username, Username :: binary()} |
                                                      {password, Password :: binary()} |
                                                      {use, Keyspace :: binary()} |
                                                      {prepare, [query()]} |
                                                      {keepalive, Value :: boolean()} |
                                                      {auto_reconnect, Value :: boolean()} |
                                                      {reconnect_start, Value :: integer()} |
                                                      {reconnect_max, Value :: integer()} |
                                                      {cql_version, CqlVersion :: binary()} |
                                                      {event_fun, EventFun :: pid() | fun() } |
                                                      {events, Events :: [event()]} |
                                                      {compression, Compression :: compression()} |
                                                      {tracing, Tracing :: boolean()} |
                                                      {parent, Parent :: pid()}
]}.

-type consistency_option()        :: { consistency, Consistency :: consistency()}.
-type args()  :: [ service_name() | connection_options() | consistency_option()].


%%%------------------------------------------------------------------------
%%% Callback functions from cloudi_service
%%%------------------------------------------------------------------------
-spec cloudi_service_init(args(), string(), dispatcher()) ->
  response().
cloudi_service_init(Args, _Prefix, Dispatcher) ->

  [ {service_name, ServiceName},
    {connection_options, ConnectionOptions},
    {consistency, Consistency}] = Args,

  {ok, ClientPid} = erlcql_client:start_link(ConnectionOptions),

  cloudi_service:subscribe(Dispatcher,ServiceName),
      {ok, #state{client = ClientPid, consistency = Consistency}}.

-spec cloudi_service_handle_request(atom(), string(), string(), any(), service_request(), int, int, int, pid(), tuple(), dispatcher())->
  {reply, any()}.
cloudi_service_handle_request(_Type, _Name, _Pattern, _RequestInfo, Request,
    _Timeout, _Priority, _TransId, _Pid,
    #state{client = ClientPid,
    consistency = Consistency
    } = State,
    _Dispatcher) ->

  Res =
  case Request of
    {QueryName, Values} when (is_atom(QueryName) and is_list(Values)) ->
    erlcql_client:async_execute(ClientPid, QueryName, Values, Consistency);
    {QueryName, Values, RequestConsistency}
          when (is_atom(QueryName) and is_list(Values) and is_atom(RequestConsistency))->
    erlcql_client:async_execute(ClientPid, QueryName, Values, RequestConsistency);

    {Query} when is_list(Query)->
      erlcql_client:async_query(ClientPid, Query, Consistency);
    {Query, RequestConsistency} when (is_list(Query) and is_atom(RequestConsistency))->
      erlcql_client:async_query(ClientPid, Query, RequestConsistency);
    _-> {error, "Invalid Request"}
  end,

  case Res of
    {ok, QueryRef} ->
      {reply, erlcql_client:await(QueryRef), State};
    {error, _Reason} = Error ->
      {reply, Error, State}
  end.

cloudi_service_handle_info(Request, State, _) ->
  ?LOG_INFO("Unknown info ~p", [Request]),
  {noreply, State}.

cloudi_service_terminate(_, _State) ->
  ok.





