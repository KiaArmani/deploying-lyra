# deploying-lyra
A repository containing various useful resources around deploying Lyra to players.

> Note: This is work-in-progress!

# Goals

The goal of this project was to deploy a version of [Lyra](https://docs.unrealengine.com/5.0/en-US/lyra-sample-game-in-unreal-engine/) that is easy and cheap to replicate by a small team, and fulfilled the following requirements:

* Gameservers are available, and only available, as [dedicated servers](https://docs.unrealengine.com/5.2/en-US/setting-up-dedicated-servers-in-unreal-engine/).
* Said gameservers are running as a [docker container](https://www.docker.com/resources/what-container/#:~:text=A%20Docker%20container%20image%20is,tools%2C%20system%20libraries%20and%20settings.).
* Said containers are running in [K3S](https://k3s.io/) cluster, across multiple machines (optionally across datacenters), with Agones and an AutoScaler in place that ensures that new gameservers are spawned should existing servers become occupied.
* The cluster would **not** be hosted with one of the big cloud providers. (i.e. Amazon AWS, Microsoft Azure, Google Cloud Platform)
* The session browser in Lyra would find and display sessions of dedicated servers that are currently available. (GamePhase != Phase_Playing || Phase_PostGame)
* The "Quickplay" selection in W_ExperienceSelectionScreen searches for other players also in search of a match, groups them together, reserves a game server for them and then sends them to the gameserver for play. (with optional skill-based matchmaking support). This replaces the existing Quickplay functionality that would host a listen server instead of no match could be found.
* Once the match ends, the gameserver terminates instead of continue to run matches.

# Prerequisites & Assumptions

The following assumptions are made about you and your project when following any of the instructions or tips here:

* You have intermediate to advanced knowledge about Unreal Engine and programming.
* You have basic knowledge about Linux servers (SSHing into them, determining network interfaces and basic commandline usage skills)
* You already set up a product at [Epic's developer portal](https://dev.epicgames.com/portal/).
* Your project is based on [Redpoint's fork of Lyra](https://docs.redpoint.games/eos-online-subsystem/docs/example_project/#lyra-example-project).
* You are using the following plugins by Redpoint Games
    * https://www.unrealengine.com/marketplace/en-US/product/eos-online-subsystem
    * https://www.unrealengine.com/marketplace/en-US/product/online-subsystem-blueprints
    * https://www.unrealengine.com/marketplace/en-US/product/matchmaking
* You are using EOS SDK version 1.15.5.
* You are using a source-built version of Unreal Engine.

# Why Redpoint's fork of Lyra and their plugins?

Simply put, because it saves time. (in this specific project as well outside of Lyra)

There are a lot of benefits using their plugins including:

* Authentication being handled automatically.
* Everything is being exposed to blueprints. (which can make it easier to first understand the flows of EOS)
* Implementing support for dedicated servers is mostly handled for you. (especially handling Agones)
* **There is professional support via Discord included.**

# Getting Started

Redpoint Games provides excellent documentation on how to get started with your project setup, so instead of repeating what is already available, I will simply link to their [documentation](https://docs.redpoint.games/eos-online-subsystem/docs/core_getting_started).

You will also want to read their getting started guide for [dedicated servers](https://docs.redpoint.games/eos-online-subsystem/docs/dedis_overview).

## Implementing the Matchmaker in Quickplay

Implementing the matchmaking using Redpoint's plugin was fairly straight forward. I suggest reading their [documentation](https://docs.redpoint.games/matchmaking/docs/) on it.

In the case of Lyra, all that really needed to be done was to edit ``W_ExperienceSelectionScreen`` to get a reference to the matchmaking actor in your menu scene and call ``Set Ready State`` on it.

Note: This only implements matchmaking for a single player party. The matchmaking plugin supports matchmaking parties, but you will need to implement parties (Invites etc.) yourself.

## Implementing session search for dedicated servers in server browser

To implement that I have replaced the session finding logic that is present in ``W_SessionBrowserScreen``. Mostly to ensure that session finding and creation are consistent using the same APIs.

Create a ``OnlineSessionSearch`` object, update the max. search results to however many results you'd like to display in your browser (i.e. 200), then call ``Find Sessions`` via the ``Online Session Subsystem``.

The problem with those results are that the ``LyraListView`` that displays all our search results requires an array of **Objects** whereas ``Get Search Results`` returns an array of **Structs**.

You could either modify the ``LyraListView`` to support the objects or create an array of a custom object and feed the struct into it. I went for the custom route and create a blueprint named ``BP_RedpointSessionResult`` which simply holds the struct in a variable.

That array then gets fed into ``SetListItems``. 

You can find the blueprint code for that [here](https://blueprintue.com/render/rsi1l6ll/) or, if no longer available, as text [here](/blueprints/W_SessionBrowserScreen.blueprint).

## Launching the Dedicated Server and register a session

Given that there is a matchmaker in between the dedicated server starting and the players finding a match, I have altered the flow of sessions a little bit to better accomodate that.

![Session Flow](images/diagrams/Session%20Flow.drawio.png)

This is all being handled inside a blueprint component that you can just assign any actor in the level the dedicated servers loads (i.e. L_Expanse).

You can find the code for it [here](https://blueprintue.com/blueprint/tde09g8u/), or, if no longer available, as text [here](/blueprints/BPC_DedicatedServerInit.blueprint)

The blueprint also handles the ``OnMatchReadyToStart`` event in this example. It is called once all players of that match (determined by being a member of the lobby that was created in the matchmaking) have connected to the match.

I have noticed though that this gets called a bit too early, as in, that atleast the last player connecting, might still be in the loading screen once this is triggered. I would suggest working with an alternative solution to determine all players being ready (i.e. PostLogin on the PlayerController) or adding a delay.

## Existing logic for session creation in Lyra

By default, ``LyraGameMode`` implements a lot of session creation stuff already. In my case, I removed it as I wanted to control the session creation with the Matchmaker in mind.

I would recommend looking into ``HandleMatchAssignmentIfNotExpectingOne`` inside ``LyraGameMode.cpp`` and decide how you want to do it. You could either:

* Remove any dedicated server logic there (see calls for ``TryDedicatedServerLogin``)
* Implement what I made in blueprints (see "Launching the Dedicated Server and register a session") in there instead.

If you plan to use Lyra as a base for your project, instead of using as a reference and copy parts from it, I would advise implementing it in C++, and refactor ``LyraGameMode`` to better fit your needs.

Also, if you go the C++ route, check ``CreateHostingRequest`` in ``ULyraUserFacingExperienceDefinition`` as it is configured to not use lobbies by default.

## Ending the session

I implemented two ways to end the session:

* When Phase_PostGame gets started.
* When the dedicated server shuts down (via ``Event Shutdown`` in the GameInstance)

The reason I added a call to ``Destroy Session`` in the shutdown event is that when I manually terminate a gameserver (e.g. when testing locally and giving the application a signal to quit via CTRL + C), the session would immediately be removed from the list of all sessions within EOS. This way you prevent a newly started client to accidentally trying to connect to it.

## Phase Management with matchmaking in mind

> Note: This will focus on the ``B_ShooterGame_Elimination`` gamemode used in ``L_Expanse``.

Lyra's Game State creates an ability system component (ASC) that contains data about the game phases which are implemented as ``Lyra Game Phase Abilities`` which are in turn just ``LyraGameplayAbilities`` or ``GameplayAbilities``.

The ShooterCore plugin ships with three of these phases:

* Warmup - During this phase, a damage immunity Gameplay Effect is applied to all players, then starts a replicated countdown, removes the immunity, and transitions to Playing state.
* Playing - In this phase, the Game has begun and is currently in play. Scoring and time limits are tracked, and will transition to PostGame when appropriate.
* PostGame - This phase reapplies damage immunity and disables controls on all players, then transitions to the next match round.

By default, it will automatically start the warmup phase once the server is started, and once it is done waiting for players, will switch to the Playing phase which ends by a team getting to the target score and it switching to PostGame.

**The scoring base being used (i.e. ``B_TeamDeathMatchScoring``) will usually start the warmup phase. But, since we already do that when ``OnMatchReadyToStart`` is called, you'd ideally replace that call with a call to ``WhenPhaseEnds`` instead and connect the delegate to the ``OnWarmupEnded`` event.**

This way we can keep all of the logic intact thats present.

## Configuring the matchmaking beacon with Kubernetes 

At the time of writing, an important piece of information is not available in the matckmaker documentation. When building & deploying the gameserver as docker image in a Kubernetes cluster, make sure to update the ``Beacon Port`` field to say "Beacon". 

![Kubernetes Beacon Configuration](/images/unreal/matchmaking-beacon-port-kubernetes.png)

This is required as it won't read the EOS ``PORT_BEACON_s`` attribute otherwise and fill in the correct port.

&nbsp;

# Building Lyra

For your convenience I have included a couple scripts to this repository which you can find in the "scripts" folder.
It is strongly recommended to read and adjust those scripts to your needs before running them!

Here a quick overview of what some of them do:
* build_gameclient.ps1: (Optional -platform Win64 / Linux argument) Builds the game client of your project to ``$PROJECT_ROOT\Binaries\GameClient``.
* build_gameserver.ps1: (Optional -platform Win64 / Linux argument) Builds the game server of your project to ``$PROJECT_ROOT\Binaries\GameServer``.
* deploy_gameserver.ps1: Builds a docker image from your game server.
    * Expects a ``Dockerfile`` to be present at ``$PROJECT_ROOT\Binaries\GameServer``.
    * Expects a docker registry to be accessible under the hostname ``registry``.
* run_devauthtool.ps1: Runs ``$PROJECT_ROOT\Plugins\EOS\OnlineSubsystemRedpointEOS\Source\ThirdParty\Tools\DevAuthTool\EOS_DevAuthTool.exe``.
* run_gameclient.ps1: (Optional -context argument) Runs ``LyraGame.exe -AUTH_LOGIN="localhost:6300" -AUTH_PASSWORD="$context" -AUTH_TYPE="Developer"``. (Currently not supported by Redpoint EOS)
* run_gameserver.ps1: Runs ``LyraServer.exe -server -log L_Expanse -Experience=B_ShooterGame_Elimination``

Some of these commands can instead also just be called from the editor (Building Client / Server) if you prefer that. 

Feel free to edit them to your needs!

&nbsp;

# Deploying Lyra

This section only covers the setup of the infrastructure needed to run a Kubernetes cluster with Agones and your Lyra image.

To learn more about setting up the cluster and running it, please check out Redpoint Games' excellent documentation [here](https://docs.redpoint.games/eos-online-subsystem/docs/dedis_overview). 

Some notes I made, at the time of writing:

* The documentation calls to install version 1.21.0 of Agones in the "Installing Agones" section. I would recommend installing the latest, or a specific, newer version instead, as updates were done for better compability with Unreal Engine 5.3.
The command for that would look like this:

``helm install agones --namespace agones-system --create-namespace agones/agones --set agones.ping.http.port=8001 --set agones.allocator.service.http.port=8002 --set agones.allocator.service.grpc.port=8003``

## Virtual machines via Hetzner

From https://github.com/vitobotta/hetzner-k3s: 

> Hetzner Cloud is an awesome cloud provider which offers a truly great service with the best performance/cost ratio in the market and locations in both Europe and USA.

I have been personally using them for many years now and will use them for my research. If you do not have an account yet, you can make one using this link and get 20€ credit for free: https://hetzner.cloud/?ref=Bt8CbhKVbAFX

This credit can be used to deploy the dev cluster.

You can also use [hetzner-k3s](https://github.com/vitobotta/hetzner-k3s) to quickly deploy a kubernetes cluster and to skip Redpoint's documentation to the [Creating your cluster section](https://docs.redpoint.games/eos-online-subsystem/docs/dedis_creating_your_cluster) (though you want to skip the "Installing Kubernetes" section as that was already done for you)

Your Hetzner should look kinda like this after using ``hetzner-k3s``:

![Hetzner Setup](/images/hetzner/cloud-servers.png)

## Private Network

A set of machines and clients will need to be able to talk to each other. Specifically:

* K3S agents that will run the game server image. They need to be able to talk to one or more control nodes that are responsible for managing the cluster.
* Pipeline runners need to be able to push docker images to a registry.
* Said registry need to be accessible by agents, runners & possibly workstations that want to manually push images. (though it would probably be better if they had a local cluster running)

For this I used [Tailscale](https://tailscale.com/). It is free to use for up to 3 users and 100 devices which should be enough to get you started.

Once you created your account, head to the [admin console](https://login.tailscale.com/admin/machines) and start installing Tailscale to your machines so they communicate *with each other*.

Do **not** expose Tailscale to your entire sub-net unless you know what you are doing!

## Docker Registry

For that you have two easy options:

* Use [dockerhub](https://hub.docker.com/) to store your images.
* Create another VM on Hetzner using your existing private network that hosts the registry and store your images there.

For a simple dev environment I found the VM solution to be sufficient. For a more robust solution I would either use dockerhub or a GitLab-provided registry.

You can find a really nice setup guide for that [here](https://technotablet.com/tutorials/setting-up-docker-registry/) once your machine is ready.

## Launching your gameservers

Once you have set up everything, you can use the yaml files in the ``templates`` folder to quickly spin up a deployment.

``agones-dev-fleet.yaml`` will be the initial deployment of your gameservers and ``agones-dev-fleet-autoscaler.yaml`` provides a simple autoscaler to automatically create new servers once players occupy a gameserver via the matchmaker. (Credits and special thanks to June from Redpoint Games for these)

Here a few useful commands to use while SSH'd into your master VM:

### Delete all gameservers and scalers

```
kubectl delete fleetautoscaler --all
kubectl delete fleet --all
kubectl delete gameserver --all
```


### Get status of all gameservers

``kubectl get gs``

### Get pod status of a specific gameserver

``kubectl describe <podname>``

### Get logs of a specific gameserver

``kubectl logs <podname> lyra``

### Continously watch logs of a gameserver

``kubectl logs -f <podname> lyra``

# Troubleshooting

If you run into an issues or know about specific common issues that occur and know the fix for them, please open an [issue](https://github.com/KiaArmani/deploying-lyra/issues/new/choose) so it can be discussed and this repo updated.

Special thanks again to June from Redpoint Games for their fantastic work on their EOS plugins and documentation on Agones.

# Important Links

* [Lyra & Unreal Overview Board](https://miro.com/app/board/uXjVPvPBawA=/): A Miro board that shows the infrastructure of Lyra in a more visual way.
* [Epic Games' documentation on Lyra](https://docs.unrealengine.com/5.0/en-US/lyra-sample-game-in-unreal-engine)
