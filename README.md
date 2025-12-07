Aplicação desenvolvida para a disciplina de Programação para Sistemas Paralelos e Distribuídos, simulando um site de quiz com uma arquitetura de microserviços, com o uso de gRPC e Kubernetes.

## Descrição

Este projeto consiste em uma aplicação web de **quiz** no qual os usuários podem responder a perguntas. A arquitetura foi projetada para demonstrar conceitos de sistemas distribuídos, utilizando:

Dois servidores em C++: Um microserviço robusto e de alta performance responsável por toda a lógica de negócios e manipulação de dados (Criar, Ler, Atualizar, Deletar perguntas, usuários, pontuações, etc.).

Servidor Web em Node.js: Atua como um backend-for-frontend (BFF), servindo a interface do usuário e se comunicando com o servidor C++ via gRPC.

gRPC: Protocolo de comunicação RPC (Remote Procedure Call) de alta performance utilizado para a comunicação eficiente entre o servidor Node.js e o servidor C++.

Kubernetes (Kind): Plataforma de orquestração de contêineres utilizada para implantar, gerenciar e escalar os microserviços em um cluster multi-node.

## Tecnologias Utilizadas

- Comunicação: gRPC

- Backend: C++

- Frontend/BFF: React e Node.js

- Banco de dados: PostgreSQL

- Orquestração: Kubernetes (Kind)

- Contêineres: Docker

- Testes: locust

## Pré-requisitos

Antes de começar, certifique-se de que você tem as seguintes ferramentas instaladas e configuradas em sua máquina:

Git

Docker

kind 

helm

locust

kubectl

## Rodar

### 1. Clonar o repositório

Primeiro, clone este repositório para a sua máquina local.

```
    git clone <urlDoProjeto>
    cd projeto-pspd
```

### 2. Executar o script de deploy

O script deploy.sh automatiza todo o processo de build das imagens Docker e de deploy dos recursos (Deployments, Services) no cluster Kind.


```
./deploy.sh
```

### 3. Acesso ao Web Server do Grafana 

Utilizando o comando a seguir, tenha acesso a senha do Grafana:

```
    kubectl get secret -n monitoring monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d
```

Com isso, copie-a e acesse o localhost referente ao Grafana, com o usuário admin e a senha recebida do comando. E então, já é possível monitorar a aplicação. 

### 4. Executar o script de teste 

O script stress.sh automatiza todo o processo de testes de carga. Para executá-lo basta utilizar o comando a seguir. Cabe lembrar que ele pode ser alterado de acordo a qualquer momento. A branch main utiliza para testes a configuração básica presente na documentação do projeto (Relatório), já a branch test-default usa a configuração com o control plane não sendo taint.


```
./stress.sh
```

### 5. Acesso a aplicação

Também é possível acessar a aplicação em si. Para isso deve-se executar os seguintes comandos: 

```
    cd front
```

```
    npm i
```

```
    npm start
```

E então acessar o localhost na porta 3000.


## Equipe

Os nomes dos integrantes da equipe podem ser encontrados na tabela 1.

<div align="center">
<font size="3"><p style="text-align: center"><b>Tabela 1:</b> Integrantes da equipe</p></font>

<table>
  <tr>
    <td align="center"><a href="http://github.com/julia-fortunato"><img style="border-radius: 50%;" src="http://github.com/julia-fortunato.png" width="100px;" alt=""/><br /><sub><b>Júlia Fortunato</b></sub></a><br/><a href="Link git" title="Rocketseat"></a></td>
    <td align="center"><a href="http://github.com/Oleari19"><img style="border-radius: 50%;" src="http://github.com/Oleari19.png" width="100px;" alt=""/><br><sub><b>Maria Clara Oleari</b></sub></a><br/>
    <td align="center"><a href="https://github.com/MarcoTulioSoares"><img style="border-radius: 50%;" src="http://github.com/MarcoTulioSoares.png" width="100px;" alt=""/><br /><sub><b>Marco Tulio Soares</b></sub></a><br/><a href="Link git" title="Rocketseat"></a></td>
    <td align="center"><a href="https://github.com/mauricio-araujoo"><img style="border-radius: 50%;" src="https://github.com/mauricio-araujoo.png" width="100px;" alt=""/><br/><sub><b>Maurício Ferreira</b></sub></a><br/>

  </tr>
</table>

<font size="3"><p style="text-align: center"><b>Autor:</b> <a href="https://github.com/julia-fortunato">Júlia Fortunato</a>, 2025</p></font>

</div>
