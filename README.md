# IPSEC Server
This repository contains a bare strongswan capsulated in a Docker container.

It should expose the vici socket, located at /var/run, to other repositories, like ipsec_server or ipsec_exporter
You can customize it via environment variables. These are printed by the start script.
