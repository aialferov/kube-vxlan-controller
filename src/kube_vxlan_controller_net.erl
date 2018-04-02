-module(kube_vxlan_controller_net).

-export([
    pod_setup/2,
    pod_join/3,
    pod_leave/3,

    links/3, links/4, link/4,
    bridges/4, bridges/5, bridge/5,

    bridge_macs/4,
    vxlan_id/3,

    common_pod_net_names/2,
    pod_net_names/1,

    cmd/4
]).

-define(Agent, kube_vxlan_controller_agent).

pod_setup(Pod, Config) ->
    links(add, Pod, Config),
    links(up, Pod, Config).

pod_join(Pod, NetPods, Config) ->
    lists:foreach(fun(NetPod) ->
        NetNames = common_pod_net_names(Pod, NetPod),
        bridges(append, NetPod, NetNames, maps:get(ip, Pod), Config),
        bridges(append, Pod, NetNames, maps:get(ip, NetPod), Config)
    end, NetPods).

pod_leave(Pod, NetPods, Config) ->
    lists:foreach(fun(NetPod) ->
        NetNames = common_pod_net_names(Pod, NetPod),
        bridges(delete, Pod, NetNames, maps:get(ip, NetPod), Config),
        bridges(delete, NetPod, NetNames, maps:get(ip, Pod), Config)
    end, NetPods).

links(Action, Pod, Config) ->
    links(Action, Pod, pod_net_names(Pod), Config).

links(Action, Pod, NetNames, Config) ->
    lists:foreach(fun(NetName) ->
        link(Action, Pod, NetName, Config)
    end, NetNames).

link(add, Pod, NetName, Config) ->
    Command = cmd("ip link add ~s type ~s id ~s dev ~s dstport 0",
                  [name, type, id, dev], Pod, NetName),
    ?Agent:exec(Pod, Command, Config);

link(delete, Pod, NetName, Config) ->
    Command = cmd("ip link delete ~s", [name], Pod, NetName),
    ?Agent:exec(Pod, Command, Config);

link(up, Pod, NetName, Config) ->
    Command = cmd("ip link set ~s up", [name], Pod, NetName),
    ?Agent:exec(Pod, Command, Config);

link(down, Pod, NetName, Config) ->
    Command = cmd("ip link set ~s down", [name], Pod, NetName),
    ?Agent:exec(Pod, Command, Config).

bridges(Action, Pod, TargetIp, Config) ->
    bridges(Action, Pod, pod_net_names(Pod), TargetIp, Config).

bridges(Action, Pod, NetNames, TargetIp, Config) ->
    lists:foreach(fun(NetName) ->
        bridge(Action, Pod, NetName, TargetIp, Config)
    end, NetNames).

bridge(append, Pod, NetName, TargetIp, Config) ->
    BridgeExists = bridge_macs(Pod, NetName, TargetIp, Config) /= [],
    BridgeExists orelse begin
        Command = cmd("bridge fdb append to 00:00:00:00:00:00 dst ~s dev ~s",
                      [TargetIp, name], Pod, NetName),
        ?Agent:exec(Pod, Command, Config)
    end;

bridge(delete, Pod, NetName, TargetIp, Config) ->
    lists:foreach(fun(Mac) ->
        Command = cmd("bridge fdb delete ~s dst ~s dev ~s",
                      [Mac, TargetIp, name], Pod, NetName),
        ?Agent:exec(Pod, Command, Config)
    end, bridge_macs(Pod, NetName, TargetIp, Config)).

bridge_macs(Pod, NetName, TargetIp, Config) ->
    Command = cmd("bridge fdb show dev ~s", [name], Pod, NetName),
    Result = ?Agent:exec(Pod, Command, Config),
    [Mac || FdbRecord <- string:lexemes(Result, "\n"),
            [Mac, "dst", Ip|_ ] <- [string:lexemes(FdbRecord, " ")],
            Ip == TargetIp].

vxlan_id(Pod, NetName, Config) ->
    Command = cmd("ip -d link show ~s", [name], Pod, NetName),
    Result = ?Agent:exec(Pod, Command, Config),

    case string:lexemes(hd(lists:reverse(string:lexemes(Result, "\n"))), " ") of
        ["vxlan", "id", Id|_] -> {ok, Id};
        _Other -> {error, not_found}
    end.

common_pod_net_names(Pod1, Pod2) ->
    Pod2Nets = maps:get(nets, Pod2),
    [Name || {Name, _Options} <- maps:get(nets, Pod1),
     proplists:is_defined(Name, Pod2Nets)].

pod_net_names(Pod) ->
    [Name || {Name, _Options} <- maps:get(nets, Pod)].

cmd(Format, Args, Pod, NetName) ->
    Net = proplists:get_value(NetName, maps:get(nets, Pod)),
    lists:flatten(io_lib:format(Format, [cmd_arg(Arg, Net) || Arg <- Args])).

cmd_arg(Arg, Net) when is_atom(Arg) -> maps:get(Arg, Net);
cmd_arg(Arg, _Net) -> Arg.
