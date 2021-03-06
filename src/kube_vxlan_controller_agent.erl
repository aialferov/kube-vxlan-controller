-module(kube_vxlan_controller_agent).

-export([
    terminate/2,
    exec/3
]).

-define(Pod, kube_vxlan_controller_pod).

terminate(Pod, Config) ->
    %%% TODO: provided for BC, remove once not needed
    exec(Pod, "touch /run/terminate", Config),
    %%%
    exec(Pod, "kill -TERM 1", Config).

exec(#{namespace := Namespace, name := PodName}, Command, Config) ->
    ContainerName = maps:get(agent_container_name, Config),
    ?Pod:exec(Namespace, PodName, ContainerName, Command, Config).

%-define(AgentContainerName, <<"vxlan-controller-agent">>).
%-define(AgentImage, <<"aialferov/kube-vxlan-controller-agent">>).

%-define(AgentSpec, #{
%  spec => #{
%    template => #{
%      spec => #{
%        containers => [
%          #{name => ?AgentContainerName,
%            image => ?AgentImage}
%        ]}}}
%}).
%
%embed(Namespace, DeploymentName, Config) ->
%    ?Log:info("Embedding agent into \"~s\" deployment", [DeploymentName]),
%
%    Resource = "/apis/apps/v1beta2/namespaces/" ++ Namespace ++
%               "/deployments/" ++ binary_to_list(DeploymentName),
%    Headers = [
%        {"Content-Type", <<"application/strategic-merge-patch+json">>}
%    ],
%    Body = jsx:encode(?AgentSpec),
%
%    {ok, Data} = ?K8s:http_request(patch, Resource, [], Headers, Body, Config),
%    ?Log:info(Data),
%    ok.
%
%get_deployment_name(Namespace, ReplicaSetName) ->
%   ResourceReplicaSet = "/apis/extensions/v1beta1/namespaces/" ++ Namespace ++
%                        "/replicasets/" ++ binary_to_list(ReplicaSetName),
%   {ok, [#{
%     metadata := #{
%       ownerReferences := [#{
%         kind := <<"Deployment">>,
%         name := DeploymentName
%       }|_]
%     }
%   }]} = ?K8s:http_request(ResourceReplicaSet, [], Config),
%   DeploymentName.
