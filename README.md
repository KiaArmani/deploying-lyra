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
* Implementing support for dedicated servers is mostly handled for you.
* **There is professional support via Discord included.**

# Getting Started

Redpoint Games provides excellent documentation on how to get started with your project setup, so instead of repeating what is already available, I will simply link to their [documentation](https://docs.redpoint.games/eos-online-subsystem/docs/core_getting_started).

You will also want to read their getting started guide for [dedicated servers](https://docs.redpoint.games/eos-online-subsystem/docs/dedis_overview).

# Implementing session search for dedicated servers in server browser

To implement that I have replaced the session finding logic that is present in ``W_SessionBrowserScreen``. Mostly to ensure that session finding and creation are consistent using the same APIs.

Create a ``OnlineSessionSearch`` object, update the max. search results to however many results you'd like to display in your browser (i.e. 200), then call ``Find Sessions`` via the ``Online Session Subsystem``.

The problem with those results are that the ``LyraListView`` that displays all our search results requires an array of **Objects** whereas ``Get Search Results`` returns an array of **Structs**.

You could either modify the ``LyraListView`` to support the objects or create an array of a custom object and feed the struct into it. I went for the custom route and create a blueprint named ``BP_RedpointSessionResult`` which simply holds the struct in a variable.

That array then gets fed into ``SetListItems``. 

You can find the blueprint code for that [here](https://blueprintue.com/render/rsi1l6ll/) or, if no longer available, as text [here](/blueprints/W_SessionBrowserScreen.blueprint).

# Launching the Dedicated Server and register a session

Given that there is a matchmaker in between the dedicated server starting and the players finding a match, I have altered the flow of sessions a little bit to better accomodate that.

![Session Flow](images/diagrams/Session%20Flow.drawio.png)

This is all being handled inside a blueprint component that you can just assign any actor in the level the dedicated servers loads (i.e. L_Expanse).

You can find the code for it [here](https://blueprintue.com/blueprint/tde09g8u/), or, if no longer available, as text [here](/blueprints/BPC_DedicatedServerInit.blueprint)

The blueprint also handles the ``OnMatchReadyToStart`` event in this example. It is called once all players of that match (determined by being a member of the lobby that was created in the matchmaking) have connected to the match.

I have noticed though that this gets called a bit too early, as in, that atleast the last player connecting, might still be in the loading screen once this is triggered. I would suggest working with an alternative solution to determine all players being ready (i.e. PostLogin on the PlayerController) or adding a delay.

&nbsp;

# Infrastructure

## Hetzner

From https://github.com/vitobotta/hetzner-k3s: 

> Hetzner Cloud is an awesome cloud provider which offers a truly great service with the best performance/cost ratio in the market and locations in both Europe and USA.

I have been personally using them for many years now and will use them for my research. If you do not have an account yet, you can make one using this link and get 20€ credit for free: https://hetzner.cloud/?ref=Bt8CbhKVbAFX

This credit can be used to deploy the dev cluster.

## Private Network

A set of machines and clients will need to be able to talk to each other. Specifically:

* K3S agents that will run the game server image. They need to be able to talk to one or more control nodes that are responsible for managing the cluster.
* Pipeline runners need to be able to push docker images to a registry.
* Said registry need to be accessible by agents, runners & possibly workstations that want to manually push images. (though it would probably be better if they had a local cluster running)

# Game Repository Structure
    ├── Lyra
    │   ├── Binaries
    │   │   ├── GameServer
    │   │   │   ├── Dockerfile
    │   │   │   ├── LinuxServer
    │   │   │   ├── WindowsServer
    │   │   ├── GameClient
    │   │   │   ├── Windows
    │   │   │   ├── Linux
    │   ├── Plugins
    │   │   ├── OnlineSubsystemRedpointEOS
    │   │   ├── OnlineSubsystemBlueprints
    │   │   ├── Matchmaking
    │   │   ├── GameManagementFramework