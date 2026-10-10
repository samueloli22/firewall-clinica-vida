#!/bin/sh
set -e

RECEPCAO=172.30.1.10
WIFI=172.30.2.10
PRONTUARIO=172.30.3.10
SITE=172.30.3.20
BANCO=172.30.4.10
DADOS=172.30.4.0/24

# Limpa regras antigas
iptables -F; iptables -X
iptables -t nat -F

# Política padrão: bloqueia tudo
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# INPUT (tráfego para o próprio firewall)
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# FORWARD: respostas de conexões já autorizadas
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# R2: Recepção -> Prontuário web (HTTP/HTTPS)
iptables -A FORWARD -s $RECEPCAO -d $PRONTUARIO -p tcp -m multiport --dports 80,443 -j ACCEPT

# R3: Recepção -> Banco: bloqueio explícito com log
iptables -A FORWARD -s $RECEPCAO -d $BANCO -p tcp --dport 5432 -j LOG --log-prefix "FW-RECEPCAO-BANCO: "
iptables -A FORWARD -s $RECEPCAO -d $BANCO -p tcp --dport 5432 -j DROP

# R4: Prontuário web -> Banco (único caminho autorizado até o banco)
iptables -A FORWARD -s $PRONTUARIO -d $BANCO -p tcp --dport 5432 -j ACCEPT

# R5: Wi-Fi pacientes -> site público (HTTP)
iptables -A FORWARD -s $WIFI -d $SITE -p tcp --dport 80 -j ACCEPT

# R6: Wi-Fi pacientes -> prontuário e rede de dados: log e bloqueio
iptables -A FORWARD -s $WIFI -d $PRONTUARIO -m limit --limit 10/min -j LOG --log-prefix "FW-WIFI-PRONTUARIO: "
iptables -A FORWARD -s $WIFI -d $PRONTUARIO -j DROP
iptables -A FORWARD -s $WIFI -d $DADOS -m limit --limit 10/min -j LOG --log-prefix "FW-WIFI-DADOS: "
iptables -A FORWARD -s $WIFI -d $DADOS -j DROP

# R7: todo o resto, log limitado e DROP pela política padrão
iptables -A FORWARD -m limit --limit 5/min -j LOG --log-prefix "FW-DROP: "

# NAT: os destinos respondem ao firewall
iptables -t nat -A POSTROUTING -s 172.30.0.0/16 -d 172.30.0.0/16 -j MASQUERADE

echo "[firewall] regras carregadas:"
iptables -L -n -v --line-numbers

exec tail -f /dev/null
