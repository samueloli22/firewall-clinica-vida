# Firewall Linux em uma Clínica: Prontuário Protegido e Wi-Fi de Pacientes Isolado

**Instituto Federal Goiano – Campus Ceres**
Bacharelado em Sistemas de Informação
Disciplina: Segurança da Informação
Docente: Prof. Roitier Campos Gonçalves
Aluno: **Samuel Antunes de Oliveira Gomes**

---

## 1. Sobre o projeto

Este projeto apresenta uma solução de segurança de redes para uma clínica médica fictícia chamada **Clínica Vida**, localizada no interior de Goiás.

A clínica possui uma recepção, quatro consultórios e aproximadamente 15 funcionários. Para realizar os atendimentos, utiliza um sistema de prontuário eletrônico que armazena informações como histórico de consultas, exames e receitas médicas.

O ambiente também conta com um site público, utilizado para divulgar informações e contatos da clínica, além de uma rede Wi-Fi gratuita para os pacientes.

O objetivo do projeto é implementar um firewall Linux com `iptables`, separando as redes e controlando a comunicação entre os dispositivos. Dessa forma, buscamos reduzir os riscos de acessos indevidos e proteger as informações dos pacientes.

### Serviços envolvidos

| Serviço                     | Função                               | Quem pode acessar          |
| --------------------------- | ------------------------------------ | -------------------------- |
| Prontuário web (Nginx)      | Sistema utilizado pela equipe        | Computadores da recepção   |
| Banco de dados (PostgreSQL) | Armazenamento dos prontuários        | Somente o prontuário web   |
| Site público (Nginx)        | Divulgação de informações da clínica | Pacientes e público        |
| Wi-Fi dos pacientes         | Acesso à internet na sala de espera  | Dispositivos dos pacientes |

Os dados médicos são considerados dados pessoais sensíveis pela LGPD. Por isso, precisam de medidas de proteção adequadas para evitar acessos não autorizados.

## 2. Problema identificado e solução proposta

### Cenário inicial

Antes da implementação, a clínica apresenta alguns problemas de segurança:

* **Rede sem separação:** computadores da recepção, servidores, banco de dados e celulares dos pacientes utilizam a mesma rede.
* **Wi-Fi sem isolamento:** os pacientes podem tentar acessar serviços internos da clínica.
* **Banco de dados exposto:** a porta 5432 do PostgreSQL pode ser acessada por outros dispositivos da rede.
* **Risco de ransomware:** um computador infectado pode representar uma ameaça aos prontuários e à continuidade dos atendimentos.
* **Falta de monitoramento:** as tentativas de acesso indevido não são devidamente controladas ou registradas.

### Solução implementada

A proposta consiste em dividir a infraestrutura em quatro redes separadas, utilizando um firewall Linux com `iptables` para controlar o tráfego entre elas.

A política adotada é bloquear as conexões por padrão e liberar somente aquelas necessárias para o funcionamento dos serviços.

| Zona     | Rede            | Finalidade                          |
| -------- | --------------- | ----------------------------------- |
| Recepção | `172.30.1.0/24` | Computadores utilizados pela equipe |
| Wi-Fi    | `172.30.2.0/24` | Dispositivos dos pacientes          |
| DMZ      | `172.30.3.0/24` | Prontuário web e site público       |
| Dados    | `172.30.4.0/24` | Banco de dados PostgreSQL           |

### Por que essa arquitetura foi escolhida?

* **Separação do Wi-Fi:** os pacientes não precisam acessar os sistemas internos da clínica.
* **Utilização de uma DMZ:** os serviços web ficam separados das redes dos usuários.
* **Proteção do banco de dados:** somente o prontuário web pode acessar o PostgreSQL pela porta 5432.
* **Bloqueio por padrão:** conexões não autorizadas são bloqueadas pelo firewall.
* **Registro de tentativas:** as regras de log ajudam a identificar e analisar acessos indevidos.

## 3. Arquitetura da rede

A estrutura abaixo representa a comunicação entre as redes da clínica e o firewall responsável pelo controle do tráfego.

```text
 Recepção 172.30.1.0/24       Wi-Fi 172.30.2.0/24
 +-------------------+        +-------------------+
 | recepcao     .10  |        | wifi_paciente .10 |
 +---------+---------+        +---------+---------+
           |                            |
           |       +------------+       |
           +-------+            +-------+
                   |  FIREWALL  |
                   |  iptables  |
                   +------+-----+
                          |
             +------------+------------+
             |                         |
             v                         v

      DMZ 172.30.3.0/24        Dados 172.30.4.0/24
      +-------------------+    +-------------------+
      | prontuario   .10  |    | banco        .10  |
      | site         .20  |    | PostgreSQL        |
      +-------------------+    +-------------------+
```

Cada zona utiliza uma bridge de rede separada no Docker. A comunicação entre as redes deve passar pelo firewall, que verifica as regras antes de permitir ou bloquear o tráfego.

A configuração utiliza `NET_ADMIN` para administrar as regras de rede, `ip_forward=1` para habilitar o encaminhamento de pacotes e MASQUERADE para realizar a tradução de endereços quando necessário.

## 4. Regras de segurança do firewall

A política padrão utiliza as seguintes configurações:

* `INPUT DROP`: bloqueia, por padrão, conexões destinadas ao próprio firewall.
* `FORWARD DROP`: bloqueia, por padrão, o tráfego encaminhado entre redes.
* `OUTPUT ACCEPT`: permite, por padrão, o tráfego de saída do firewall.

As principais regras de comunicação são:

| Nº | Origem              | Destino                    | Porta/Protocolo       | Ação                | Motivo                                            |
| -- | ------------------- | -------------------------- | --------------------- | ------------------- | ------------------------------------------------- |
| 1  | Qualquer            | Qualquer                   | `ESTABLISHED,RELATED` | ACCEPT              | Permite respostas de conexões autorizadas         |
| 2  | Recepção            | Prontuário web             | TCP 80/443            | ACCEPT              | Permite que a equipe utilize o sistema            |
| 3  | Recepção            | Banco de dados             | TCP 5432              | LOG + DROP          | Impede o acesso direto ao banco                   |
| 4  | Prontuário web      | Banco de dados             | TCP 5432              | ACCEPT              | Permite a comunicação necessária com o PostgreSQL |
| 5  | Wi-Fi dos pacientes | Site público               | TCP 80                | ACCEPT              | Permite consultar informações da clínica          |
| 6  | Wi-Fi dos pacientes | Prontuário e rede de dados | Qualquer              | LOG + DROP          | Bloqueia o acesso aos serviços internos           |
| 7  | Qualquer            | Outros destinos            | Qualquer              | LOG limitado + DROP | Bloqueia tráfego não autorizado                   |

A utilização dessas regras segue o princípio do menor privilégio: cada rede recebe somente as permissões necessárias para realizar suas funções.

**Observação:** a regra da recepção permite as portas 80 e 443, mas o Nginx utilizado no laboratório não possui TLS configurado. Por isso, a porta 443 pode aparecer como `closed` nos testes com `nmap`.

## 5. Como executar o projeto

### Pré-requisitos

Para executar o ambiente, é necessário ter:

* Docker instalado.
* Docker Compose disponível.
* Docker Desktop em execução, caso esteja utilizando Windows ou macOS.

Para conferir as versões instaladas, execute:

```bash
docker --version
docker compose version
```

### Clonar o repositório

Clone o repositório e entre na pasta do projeto:

```bash
git clone <URL_DO_REPOSITORIO>
cd <PASTA_DO_REPOSITORIO>
```

Substitua os valores entre os sinais `< >` pelo endereço e pelo nome corretos do repositório.

### Iniciar os serviços

Execute o comando abaixo para construir as imagens e iniciar os containers:

```bash
docker compose up -d --build
```

### Verificar o funcionamento

Para conferir o estado dos serviços e consultar os logs do firewall:

```bash
docker compose ps
docker compose logs firewall
```

Os serviços devem permanecer em execução conforme a configuração do ambiente.

### Encerrar o ambiente

Para desligar os containers:

```bash
docker compose down
```

Se também quiser remover os volumes associados ao ambiente:

```bash
docker compose down -v
```

**Atenção:** o segundo comando pode apagar os dados armazenados nos volumes do projeto.

### Problemas comuns

| Problema                                     | Possível solução                                                     |
| -------------------------------------------- | -------------------------------------------------------------------- |
| `Cannot connect to the Docker daemon`        | Iniciar o Docker Desktop ou o serviço Docker no Linux                |
| Erro `no such file or directory` nos scripts | Verificar se os arquivos `entrypoint.sh` utilizam finais de linha LF |
| `Pool overlaps with other one`               | Verificar se a faixa de IP já está sendo utilizada                   |
| Container encerrando sozinho                 | Consultar os logs com `docker compose logs <servico>`                |

## 6. Testes e validação

Os testes servem para verificar se o firewall permite as conexões necessárias e bloqueia aquelas que não foram autorizadas.

Execute os comandos a partir da pasta que contém o arquivo `docker-compose.yml`.

### 6.1. Simular os usuários

Cada máquina da clínica é representada por um container. Para acessar o terminal de cada uma, utilize:

```bash
# Acessar a máquina da recepção
docker compose exec recepcao sh

# Acessar a máquina de um paciente
docker compose exec wifi_paciente sh
```

Para sair do terminal do container, execute `exit`.

Os testes seguintes também podem ser executados diretamente no terminal do host, sem entrar nos containers.

### 6.2. Testes de conexões permitidas

**Recepção acessando o prontuário:**

```bash
docker compose exec recepcao curl -s http://prontuario
docker compose exec recepcao nmap -Pn -p 80 prontuario
```

**Paciente acessando o site público:**

```bash
docker compose exec wifi_paciente curl -s http://site
```

**Prontuário web acessando o banco de dados:**

```bash
docker compose exec prontuario nc -zv -w3 banco 5432
```

**Resultado esperado:** as páginas devem responder e a conexão do prontuário web com o banco deve funcionar, desde que os serviços estejam configurados corretamente.

### 6.3. Testes de conexões bloqueadas

**Recepção tentando acessar diretamente o banco:**

```bash
docker compose exec recepcao nc -zv -w3 banco 5432
docker compose exec recepcao nmap -Pn -p 5432 banco
```

**Paciente tentando acessar o prontuário e o banco:**

```bash
docker compose exec wifi_paciente curl -m3 http://prontuario
docker compose exec wifi_paciente nmap -Pn -p 80,5432 prontuario banco
```

**Resultado esperado:** as conexões não autorizadas devem falhar ou apresentar as portas como `filtered`, dependendo das regras, das rotas e do comportamento dos serviços.

### 6.4. Verificar a necessidade do firewall

O comando abaixo tenta remover uma rota e acessar diretamente o prontuário:

```bash
docker compose exec recepcao sh -c 'ip route del 172.30.0.0/16; curl -m3 http://172.30.3.10'
```

O objetivo é demonstrar a importância do encaminhamento de tráfego pela arquitetura de rede. O resultado depende das rotas efetivamente configuradas no ambiente.

### 6.5. Conferir os registros do firewall

Para consultar as regras de encaminhamento e seus contadores:

```bash
docker compose exec firewall iptables -L FORWARD -n -v --line-numbers
```

Para procurar mensagens de log relacionadas ao firewall no kernel do host Linux:

```bash
dmesg | grep FW-
```

Os contadores das regras de bloqueio podem aumentar conforme as tentativas de acesso são realizadas. As mensagens de log dependem da configuração do ambiente e das permissões disponíveis.

## 7. Limitações do laboratório

Apesar de permitir a demonstração de conceitos importantes de segurança de redes, o ambiente apresenta algumas limitações:

* A rede Docker não representa, por si só, uma conexão real com a internet. O acesso dos pacientes é testado contra o site público do laboratório.
* O Nginx utilizado não possui TLS configurado. Em um ambiente real, o prontuário deve utilizar HTTPS.
* As credenciais utilizadas são destinadas exclusivamente ao laboratório e não devem ser reutilizadas em produção.
* Dependendo do sistema operacional e do backend utilizado, pode ser necessário ajustar a configuração do `iptables`, inclusive utilizando `iptables-legacy` quando houver incompatibilidade.

## 8. Conclusão

O projeto demonstra como a utilização de um firewall Linux com `iptables` pode ajudar a organizar e proteger uma infraestrutura de rede em um ambiente de saúde.

A separação entre recepção, Wi-Fi dos pacientes, serviços web e banco de dados reduz a exposição dos sistemas internos e limita as possibilidades de acesso indevido.

Além disso, os testes permitem verificar se as regras de segurança estão funcionando conforme o esperado, reforçando a importância do controle de tráfego, do monitoramento e do princípio do menor privilégio.

O desenvolvimento deste laboratório contribui para o aprendizado prático de segurança da informação, segmentação de redes, administração de firewall e utilização de containers com Docker.
