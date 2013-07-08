%%
%% %CopyrightBegin%
%%
%% Copyright Ericsson AB 2004-2012. All Rights Reserved.
%%
%% The contents of this file are subject to the Erlang Public License,
%% Version 1.1, (the "License"); you may not use this file except in
%% compliance with the License. You should have received a copy of the
%% Erlang Public License along with this software. If not, it can be
%% retrieved online at http://www.erlang.org/.
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and limitations
%% under the License.
%%
%% %CopyrightEnd%
%%
-module(otp_mibs_SUITE).

%%-----------------------------------------------------------------
%% This suite can no longer be executed standalone, i.e. it must be
%% executed with common test. The reason is that ct_snmp is used
%% instead of the snmp application directly. The suite requires a
%% config file, otp_mibs_SUITE.cfg, found in the same directory as
%% the suite.
%%
%% Execute with:
%% > ct_run -suite otp_mibs_SUITE -config otp_mibs_SUITE.cfg
%%-----------------------------------------------------------------

-include_lib("test_server/include/test_server.hrl").
-include_lib("otp_mibs/include/OTP-MIB.hrl").
-include_lib("snmp/include/snmp_types.hrl").

% Test server specific exports
-export([all/0, suite/0,groups/0,init_per_group/2,end_per_group/2,
	 init_per_suite/1, end_per_suite/1,
	 init_per_testcase/2, end_per_testcase/2]).

% Test cases must be exported.
-export([nt_basic_types/1, nt_high_reduction_count/1]).

-define(TRAP_UDP, 5000).
-define(AGENT_UDP, 4000).
-define(CONF_FILE_VER, [v2]).
-define(SYS_NAME, "Test otp_mibs").
-define(MAX_MSG_SIZE, 484).
-define(ENGINE_ID, "mgrEngine").
-define(MGR_PORT, 5001).

%% Since some cases are only interested in single entries of the OTP-MIB's
%% node table, one row must be chosen. The first row should be sufficient
%% for this.
-define(NODE_ENTRY, 1).

%%---------------------------------------------------------------------
%% CT setup
%%---------------------------------------------------------------------

init_per_testcase(_Case, Config) when is_list(Config) ->
    Dog = test_server:timetrap(test_server:minutes(6)),
    [{watchdog, Dog}|Config].

end_per_testcase(_Case, Config) when is_list(Config) ->
    Dog = ?config(watchdog, Config),
    test_server:timetrap_cancel(Dog),
    Config.

suite() -> [{ct_hooks,[ts_install_cth]}, {require, snmp_mgr_agent, snmp}].

all() -> [{group, node_table}].

groups() -> [{node_table, [], [nt_basic_types, nt_high_reduction_count]}].

init_per_group(_GroupName, Config) -> Config.

end_per_group(_GroupName, Config) -> Config.

init_per_suite(Config) ->
    ?line application:start(sasl),
    ?line application:start(mnesia),
    ?line application:start(otp_mibs),

    ok = ct_snmp:start(Config,snmp_mgr_agent),

    %% Load the mibs that should be tested
    otp_mib:load(snmp_master_agent),

    Config.

end_per_suite(Config) ->
    PrivDir = ?config(priv_dir, Config),
    ConfDir = filename:join(PrivDir,"conf"),
    DbDir = filename:join(PrivDir,"db"),
    MgrDir = filename:join(PrivDir, "mgr"),

    %% Uload mibs
    otp_mib:unload(snmp_master_agent),

    %% Clean up
    application:stop(snmp),
    application:stop(mnesia),
    application:stop(otp_mibs),

    del_dir(ConfDir),
    del_dir(DbDir),
    (catch del_dir(MgrDir)),
    ok.

%%---------------------------------------------------------------------
%% Test cases
%%---------------------------------------------------------------------

nt_basic_types(suite) ->
    [];
nt_basic_types(doc) ->
    ["Query every item of the node table and check its variable "
     "type and content for sensible values."];
nt_basic_types(Config) when is_list(Config) ->
    ok = otp_mib:update_erl_node_table(),

    NodeName = ?erlNodeEntry ++ [?erlNodeName, ?NODE_ENTRY],
    {noError, 0, [NodeNameVal]} = snmp_get([NodeName]),
    #varbind{variabletype = 'OCTET STRING'} = NodeNameVal,
    true = is_list(NodeNameVal#varbind.value),

    NodeMachine = ?erlNodeEntry ++ [?erlNodeMachine, ?NODE_ENTRY],
    {noError, 0, [NodeMachineVal]} = snmp_get([NodeMachine]),
    #varbind{variabletype = 'OCTET STRING'} = NodeMachineVal,
    true = is_list(NodeMachineVal#varbind.value),

    NodeVersion = ?erlNodeEntry ++ [?erlNodeVersion, ?NODE_ENTRY],
    {noError, 0, [NodeVersionVal]} = snmp_get([NodeVersion]),
    #varbind{variabletype = 'OCTET STRING'} = NodeVersionVal,
    true = is_list(NodeVersionVal#varbind.value),

    NodeRunQueue = ?erlNodeEntry ++ [?erlNodeRunQueue, ?NODE_ENTRY],
    {noError, 0, [NodeRunQueueVal]} = snmp_get([NodeRunQueue]),
    #varbind{variabletype = 'Unsigned32'} = NodeRunQueueVal,
    true = is_integer(NodeRunQueueVal#varbind.value),

    NodeRunTime = ?erlNodeEntry ++ [?erlNodeRunTime, ?NODE_ENTRY],
    {noError, 0, [NodeRunTimeVal]} = snmp_get([NodeRunTime]),
    #varbind{variabletype = 'Counter32'} = NodeRunTimeVal,
    true = is_integer(NodeRunTimeVal#varbind.value),

    NodeWallClock = ?erlNodeEntry ++ [?erlNodeWallClock, ?NODE_ENTRY],
    {noError, 0, [NodeWallClockVal]} = snmp_get([NodeWallClock]),
    #varbind{variabletype = 'Counter32'} = NodeWallClockVal,
    true = is_integer(NodeWallClockVal#varbind.value),

    NodeReductions = ?erlNodeEntry ++ [?erlNodeReductions, ?NODE_ENTRY],
    {noError, 0, [NodeReductionsVal]} = snmp_get([NodeReductions]),
    #varbind{variabletype = 'Counter64'} = NodeReductionsVal,
    true = is_integer(NodeReductionsVal#varbind.value),

    NodeProcesses = ?erlNodeEntry ++ [?erlNodeProcesses, ?NODE_ENTRY],
    {noError, 0, [NodeProcessesVal]} = snmp_get([NodeProcesses]),
    #varbind{variabletype = 'Unsigned32'} = NodeProcessesVal,
    true = is_integer(NodeProcessesVal#varbind.value),

    NodeInBytes = ?erlNodeEntry ++ [?erlNodeInBytes, ?NODE_ENTRY],
    {noError, 0, [NodeInBytesVal]} = snmp_get([NodeInBytes]),
    #varbind{variabletype = 'Counter32'} = NodeInBytesVal,
    true = is_integer(NodeInBytesVal#varbind.value),

    NodeOutBytes = ?erlNodeEntry ++ [?erlNodeOutBytes, ?NODE_ENTRY],
    {noError, 0, [NodeOutBytesVal]} = snmp_get([NodeOutBytes]),
    #varbind{variabletype = 'Counter32'} = NodeOutBytesVal,
    true = is_integer(NodeOutBytesVal#varbind.value),

    ok.

nt_high_reduction_count(suite) ->
    [];
nt_high_reduction_count(doc) ->
    ["Check that no error occurs when the erlNodeReductions field"
     "exceeds the 32bit boundary."];
nt_high_reduction_count(Config) when is_list(Config) ->
    NodeReductions = ?erlNodeEntry ++ [?erlNodeReductions, ?NODE_ENTRY],

    ok = otp_mib:update_erl_node_table(),

    {noError, 0, [Val1]} = snmp_get([NodeReductions]),
    #varbind{variabletype = 'Counter64'} = Val1,
    true = is_integer(Val1#varbind.value),

    {noError, 0, [Val2]} = snmp_get([NodeReductions]),
    #varbind{variabletype = 'Counter64'} = Val2,
    true = is_integer(Val2#varbind.value),

    Val2 >= Val1,

    Data = otp_mib:get_erl_node(1),
    ReductionCount = 1024 * 1024 * 1024 * 1024 * 500,
    NewData = setelement(?erlNodeReductions + 1, Data, ReductionCount),
    mnesia:dirty_write(NewData),

    {noError, 0, [Val3]} = snmp_get([NodeReductions]),
    #varbind{variabletype = 'Counter64'} = Val3,
    true = is_integer(Val3#varbind.value),
    ReductionCount = Val3#varbind.value,

    ok.

%%---------------------------------------------------------------------
%% Internal functions
%%---------------------------------------------------------------------

snmp_get(OIdList) ->
    ct_snmp:get_values(otp_mibs_test, OIdList, snmp_mgr_agent).

del_dir(Dir) ->
    io:format("Deleting: ~s~n",[Dir]),
    {ok, Files} = file:list_dir(Dir),
    FullPathFiles = lists:map(fun(File) -> filename:join(Dir, File) end, Files),
    lists:foreach(fun file:delete/1, FullPathFiles),
    file:del_dir(Dir).
