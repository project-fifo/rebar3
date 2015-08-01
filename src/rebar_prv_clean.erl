%% -*- erlang-indent-level: 4;indent-tabs-mode: nil -*-
%% ex: ts=4 sw=4 et

-module(rebar_prv_clean).

-behaviour(provider).

-export([init/1,
         do/1,
         format_error/1]).

-include("rebar.hrl").

-define(PROVIDER, clean).
-define(DEPS, [app_discovery]).

%% ===================================================================
%% Public API
%% ===================================================================

-spec init(rebar_state:t()) -> {ok, rebar_state:t()}.
init(State) ->
    State1 = rebar_state:add_provider(State, providers:create([{name, ?PROVIDER},
                                                               {module, ?MODULE},
                                                               {bare, true},
                                                               {deps, ?DEPS},
                                                               {example, "rebar3 clean"},
                                                               {short_desc, "Remove compiled beam files from apps."},
                                                               {desc, "Remove compiled beam files from apps."},
                                                               {opts, [{all, $a, "all", undefined, "Clean all apps include deps"}]}])),
    {ok, State1}.

-spec do(rebar_state:t()) -> {ok, rebar_state:t()} | {error, string()}.
do(State) ->
    Providers = rebar_state:providers(State),
    ProjectApps = rebar_state:project_apps(State),
    {all, All} = handle_args(State),

    case All of
        true ->
            DepsDir = rebar_dir:deps_dir(State),
            DepApps = rebar_app_discover:find_apps([filename:join(DepsDir, "*")], all);
        false ->
            DepApps = []
    end,

    %% Need to allow global config vars used on deps
    %% Right now no way to differeniate and just give deps a new state
    EmptyState = rebar_state:new(),
    clean_apps(EmptyState, Providers, DepApps),

    Cwd = rebar_dir:get_cwd(),
    {ok, State1} = rebar_hooks:run_all_hooks(Cwd, pre, ?PROVIDER, Providers, State),
    clean_apps(State1, Providers, ProjectApps),
    rebar_hooks:run_all_hooks(Cwd, post, ?PROVIDER, Providers, State1).

-spec format_error(any()) -> iolist().
format_error(Reason) ->
    io_lib:format("~p", [Reason]).

%% ===================================================================
%% Internal functions
%% ===================================================================

clean_apps(State, Providers, Apps) ->
    lists:foreach(fun(AppInfo) ->
                          AppDir = rebar_app_info:dir(AppInfo),
                          S = rebar_app_info:state_or_new(State, AppInfo),

                          ?INFO("Cleaning out ~s...", [rebar_app_info:name(AppInfo)]),
                          {ok, S1} = rebar_hooks:run_all_hooks(AppDir, pre, ?PROVIDER, Providers, S),
                          rebar_erlc_compiler:clean(S1, rebar_app_info:out_dir(AppInfo)),
                          rebar_hooks:run_all_hooks(AppDir, post, ?PROVIDER, Providers, S1),
                          ok
                  end, Apps).

handle_args(State) ->
    {Args, _} = rebar_state:command_parsed_args(State),
    All = proplists:get_value(all, Args, false),
    {all, All}.
