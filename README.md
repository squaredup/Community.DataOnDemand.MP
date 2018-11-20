# Community.DataOnDemand.MP

## What is the Data On Demand MP

The Data on Demand Management Packs contains several useful Microsoft System Center Operations Manager (SCOM) agent tasks, including the Netstat task required by Squared Up Visual Application Discovery & Analysis.

To make use of these Management packs, you will need SCOM installed and configured, monitoring your environment. No other dependencies are required.

## Getting started

This GitHub repository contains the source files. The sealed downloadable management packs can be found here:

<https://download.squaredup.com/#managementpacks>

To install the Data On Demand MPs you will need:

* SCOM 2012 R2 (earlier versions may be supported but are untested)
* SCOM Admin rights (only Administrators can import management packs)
* If you plan to import the Data On Demand Unix MP, you will need to import and configure the relevant Microsoft Unix management packs first.
* If you plan to import the Data On Demand SQL MPs, you will need to import and configure the relevant Microsoft SQL management packs first.
* If you plan to import the Data On Demand IIS MP, you will need to import and configure the relevant Microsoft IIS management packs first.

### Install the SCOM Management Pack

Import the management packs into SCOM using the standard process.

The MPs will show up as `Data on Demand - Community Management Pack`.

The MPs adds a number of agent tasks to various computer classes, with the suffix `(Data On Demand)`. This can be viewed in the SCOM console under `Authoring > Management Pack Objects > Tasks`.

## Management Pack Contents

### Tasks

Display Name                                    | Target           | Description
----------------------------------------------- | ---------------- | ----------------------
Get DNS Cache (Data On Demand)                  | Windows Computer | Lists all entries in the server's DNS cache.
Get IIS Worker Processes Data (Data On Demand)  | IIS Webserver    | Displays worker process information about IIS on the target computer.
Get Netstat CSV (Data On Demand)                | Unix Computer    | Displays established TCP connections using netstat.
Get Netstat CSV (Data On Demand)                | Windows Computer | Displays established TCP connections using netstat.
Get SQL Server Connections (Data On Demand)     | SQL DB Engine    | Lists all open connections to the SQL instance, and the databases that are in use by those connections.
List Event Logs (Data On Demand)                | Windows Computer | Displays the last 4 entries in the system event log.
List Processes (Data On Demand)                 | Windows Computer | Lists the top 10 processes sorted by CPU usage.
List Services (Data On Demand)                  | Windows Computer | Lists the name and status of services.
Resolve Addresses (Data On Demand)              | Unix Computer    | Looks up the specified IP Addresses or names using configured DNS settings on the target computer.
Resolve Addresses (Data On Demand)              | Windows Computer | Looks up the specified IP Addresses or names using configured DNS settings on the target computer.

**Note:** Windows tasks support returning data in JSON, however this is only supported if PowerShell v3 or later are available on the target agent.

## Releases

While anyone is free to download and import these management pack projects, sealed and signed releases of these management packs will only be available via <https://download.squaredup.com/#managementpacks>.

Releases of these management packs will use semantic versioning, and will occur as and when warranted.

## Help and Assistance

These management packs are community packs originally developed by Squared Up (<http://www.squaredup.com>).

For help and advice, post questions on <http://community.squaredup.com/answers>.

If you have found a specific bug or issue with the tasks in one of the management packs, please raise an [issue](https://github.com/squaredup/Community.DataOnDemand.MP/issues) on GitHub.

## Contributions

If you want to suggest some fixes or improvements to the scripts or management packs, raise an issue on [the GitHub Issues page](https://github.com/squaredup/Community.DataOnDemand.MP/issues) or better, submit the suggested change as a [Pull Request](https://github.com/squaredup/Community.DataOnDemand.MP/pulls).

If you have an awesome command/script that you would like to share but lack the MP authoring knowledge to embed this in a task, feel free to raise an issue and include the content you want in the task.

### Guidelines

* Please target pull requests at the **develop** branch.
* If your change would bring in a non-standard MP reference (i.e a management pack not imported into SCOM by default) then please create a new management pack in the solution.
* Target the minimum version of a management pack reference that you can, and avoid versions that were introduced in particular cumulative updates.
* Ensure that there are no outstanding Management Pack Best Practices Analyser issues reported by your change.
* If you introduce a custom Probe or Write Action module, please use appropriate types for your configuration elements (i.e do not use **string** for values that clearly are boolean).
* Do not update the version numbers of the MP in your pull request.
* Task DisplayStrings should be suffixed with `(Data On Demand)`.
