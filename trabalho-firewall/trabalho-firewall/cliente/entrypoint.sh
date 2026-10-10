#!/bin/sh
# Tudo que não é da própria rede (DMZ, dados) passa pelo firewall
ip route add 172.30.0.0/16 via "$FW_IP"
exec sleep infinity
