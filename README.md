# Nokia SR Linux Streaming Telemetry Lab

This lab represents a small Clos fabric with [Nokia SR Linux](https://learn.srlinux.dev/) switches running as containers. The lab topology consists of a Clos topology, plus a Streaming Telemetry stack comprised of [gnmic](https://gnmic.openconfig.net), prometheus and grafana applications.

---

![pic1](https://gitlab.com/rdodin/pics/-/wikis/uploads/0784c31d48ec18fd24111ad8d73478b0/image.png)

In addition to the telemetry stack, the lab also includes a modern logging stack comprised of [promtail](https://grafana.com/docs/loki/latest/clients/promtail/) and [loki](https://grafana.com/oss/loki/).

## Deploying the lab

The lab is deployed with the [containerlab](https://containerlab.dev) project, where [`st.clab.yml`](st.clab.yml) file declaratively describes the lab topology.

```bash
# change into the cloned directory
# and execute
containerlab deploy --reconfigure
```

To remove the lab:

```bash
containerlab destroy --cleanup
```

## Accessing the network elements

Once the lab has been deployed, the different SR Linux nodes can be accessed via SSH through their management IP address, given in the summary displayed after the execution of the deploy command. It is also possible to reach those nodes directly via their hostname, defined in the topology file. Linux clients cannot be reached via SSH, as it is not enabled, but it is possible to connect to them with a docker exec command.

```bash
# reach a SR Linux leaf or a spine via SSH
ssh admin@leaf1
ssh admin@spine1

# reach a Linux client via Docker
docker exec -it client1 bash
```

## Fabric configuration

The DC fabric used in this lab consists of three leaves and two spines interconnected as shown in the diagram.

![pic](https://gitlab.com/rdodin/pics/-/wikis/uploads/14c768a04fc30e09b0bf5cf0b57b5b63/image.png)

Leaves and spines use Nokia SR Linux IXR-D2 and IXR-D3L chassis respectively. Each network element of this topology is equipped with a [startup configuration file](configs/fabric/) that is applied at the node's startup.

Once booted, network nodes will come up with interfaces and underlay protocols. 

### Verifying the underlay status

By connecting via SSH to one of the leaves, we can verify the status of those BGP sessions.

```
A:leaf1# show network-instance default protocols bgp neighbor
------------------------------------------------------------------------------------------------------------------
BGP neighbor summary for network-instance "default"
Flags: S static, D dynamic, L discovered by LLDP, B BFD enabled, - disabled, * slow

+-----------+---------------+---------------+-------+----------+-------------+--------------+--------------+---------------+
| Net-Inst  |     Peer      |     Group     | Flags | Peer-AS  |   State     |    Uptime    |   AFI/SAFI   | Rx/Active/Tx] |
+===========+===============+===============+=======+==========+=============+==============+==============+===============+
| default   | 10.0.2.1      | iBGP-overlay  | S     | 100      | established | 0d:0h:0m:27s | evpn         | [4/4/2]       |
| default   | 10.0.2.2      | iBGP-overlay  | S     | 100      | established | 0d:0h:0m:28s | evpn         | [4/0/2]       |
| default   | 192.168.11.1  | eBGP          | S     | 201      | established | 0d:0h:0m:34s | ipv4-unicast | [3/3/2]       |
| default   | 192.168.12.1  | eBGP          | S     | 202      | established | 0d:0h:0m:33s | ipv4-unicast | [3/3/4]       |
+-----------+---------------+---------------+-------+----------+-------------+--------------+--------------+---------------+
```

### Configure L2 Service
Configuration to be implemented on leaf's
##### Downlink Interface with VLAN 10
```
set / interface ethernet-1/1 subinterface 10 type bridged
set / interface ethernet-1/1 subinterface 10 description towards_client
set / interface ethernet-1/1 subinterface 10 admin-state enable
set / interface ethernet-1/1 subinterface 10 vlan encap single-tagged vlan-id 10
```
##### Tunnel interface [VxLAN VNI]
```
set / tunnel-interface vxlan0 vxlan-interface 1 type bridged
set / tunnel-interface vxlan0 vxlan-interface 1 ingress vni 1
set / tunnel-interface vxlan0 vxlan-interface 1 egress source-ip use-system-ipv4-address
```
##### Mac vrf 
```
set / network-instance mac-vrf-1
set / network-instance mac-vrf-1 type mac-vrf
set / network-instance mac-vrf-1 admin-state enable
set / network-instance mac-vrf-1 interface ethernet-1/1.0
set / network-instance mac-vrf-1 vxlan-interface vxlan0.1
set / network-instance mac-vrf-1 protocols
set / network-instance mac-vrf-1 protocols bgp-evpn
set / network-instance mac-vrf-1 protocols bgp-evpn bgp-instance 1
set / network-instance mac-vrf-1 protocols bgp-evpn bgp-instance 1 vxlan-interface vxlan0.1
set / network-instance mac-vrf-1 protocols bgp-evpn bgp-instance 1 evi 1
set / network-instance mac-vrf-1 protocols bgp-evpn bgp-instance 1 ecmp 8
set / network-instance mac-vrf-1 protocols bgp-vpn
set / network-instance mac-vrf-1 protocols bgp-vpn bgp-instance 1
set / network-instance mac-vrf-1 protocols bgp-vpn bgp-instance 1 route-target
set / network-instance mac-vrf-1 protocols bgp-vpn bgp-instance 1 route-target export-rt target:100:1
set / network-instance mac-vrf-1 protocols bgp-vpn bgp-instance 1 route-target import-rt target:100:1
```

## Telemetry stack

As the lab name suggests, telemetry is at its core. The following telemetry stack is used in this lab:

| Role                | Software                              |
| ------------------- | ------------------------------------- |
| Telemetry collector | [gnmic](https://gnmic.openconfig.net) |
| Time-Series DB      | [prometheus](https://prometheus.io)   |
| Visualization       | [grafana](https://grafana.com)        |

### gnmic

[gnmic](https://gnmic.openconfig.net) is an Openconfig project that allows to subscribe to streaming telemetry data from network devices and export it to a variety of destinations. In this lab, gnmic is used to subscribe to the telemetry data from the fabric nodes and export it to the prometheus time-series database.

The gnmic configuration file - [configs/gnmic/gnmic-config.yml](./configs/gnmic/gnmic-config.yml) - is applied to the gnmic container at the startup and instructs it to subscribe to the telemetry data and export it to the prometheus time-series database.

### Prometheus

[Prometheus](https://prometheus.io) is a popular open-source time-series database. It is used in this lab to store the telemetry data exported by gnmic. The prometheus configuration file - [configs/prometheus/prometheus.yml](configs/prometheus/prometheus.yml) - has a minimal configuration and instructs prometheus to scrape the data from the gnmic collector with a 5s interval.

### Grafana

Grafana is another key component of this lab as it provides the visualisation for the collected telemetry data. Lab's topology file includes grafana node and configuration parameters such as dashboards, datasources and required plugins.

Grafana dashboard provided by this repository provides multiple views on the collected real-time data. Powered by [flow plugin](https://grafana.com/grafana/plugins/andrewbmchugh-flow-panel/) it overlays telemetry sourced data over graphics such as topology and front panel views:

![pic3](https://gitlab.com/rdodin/pics/-/wikis/uploads/919092da83782779b960eeb4b893fb4a/image.png)

Using the flow plugin and real telemetry data users can create interactive topology maps (aka weathermap) with a visual indication of link rate/utilization.

![pic2](https://gitlab.com/rdodin/pics/-/wikis/uploads/12f154dafca1270f7a1628c1ed3ab77a/image.png)

The panels for the flow plugin has been autocreated by the [clab-io-draw](https://github.com/srl-labs/clab-io-draw) tool

### Access details

Using containerlab's ability to expose ports of the containers to the host, the following services are available on the host machine:

* Grafana: <http://localhost:3000>. Anonymous access is enabled; no credentials are required. If you want to act as an admin, use `admin/admin` credentials.
* Prometheus: <http://localhost:9090/graph>

## Traffic generation

When the lab is started, there is not traffic running between the nodes as the clients are sending any data. To run traffic between the nodes, leverage `traffic.sh` control script.

To start the traffic:

* `bash traffic.sh start all` - start traffic between all nodes
* `bash traffic.sh start 1-2` - start traffic between client1 and client2
* `bash traffic.sh start 1-3` - start traffic between client1 and client3

To stop the traffic:

* `bash traffic.sh stop` - stop traffic generation between all nodes
* `bash traffic.sh stop 1-2` - stop traffic generation between client1 and client2
* `bash traffic.sh stop 1-3` - stop traffic generation between client1 and client3

As a result, the traffic will be generated between the clients and the traffic rate will be reflected on the grafana dashboard.

## Logging stack

The logging stack leverages the promtail->Loki pipeline, where promtail is a log agent that extracts, transforms and ships logs to Loki, a log aggregation system.

The logging infrastructure logs every message from SR Linux that is above Info level. This includes all the BGP messages, all the system messages, all the interface state changes, etc. The dashboard provides a view on the collected logs and allows filtering on a per-application level.

