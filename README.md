# NeoMoto API - DevOps Challenge 3

## Descrição da Solução

NeoMoto é uma API RESTful para gestão da frota da Mottu (motos), organizada por filiais e com histórico de manutenções. Desenvolvida com .NET 9 Minimal API e PostgreSQL, containerizada com Docker e deployada na nuvem Azure usando Azure Container Registry (ACR) + Azure Container Instances (ACI).

## Benefícios para o Negócio

### Problemas Resolvidos:

- **Gestão Centralizada**: Controle unificado de toda a frota de motos distribuída em múltiplas filiais
- **Rastreabilidade**: Histórico completo de manutenções para cada veículo, permitindo análises de custo e performance
- **Escalabilidade**: Arquitetura em nuvem que permite crescimento conforme demanda
- **Disponibilidade**: Deploy em containers garante alta disponibilidade e facilidade de manutenção

### Melhorias Trazidas:

- **Redução de Custos**: Melhor planejamento de manutenções preventivas
- **Eficiência Operacional**: Consultas rápidas e paginadas para grandes volumes de dados
- **Tomada de Decisão**: Relatórios e estatísticas em tempo real
- **Integração**: HATEOAS permite navegação intuitiva entre recursos relacionados

## Tecnologias

- .NET 9.0 (Minimal API)
- Entity Framework Core 8.0
- PostgreSQL 15
- Docker e Azure Container Registry
- Azure Container Instances
- Swagger/OpenAPI

## CRUD Completo Implementado

### Filiais

- `GET /api/filiais` - Listar filiais (com paginação)
- `GET /api/filiais/{id}` - Buscar filial por ID
- `POST /api/filiais` - Criar nova filial
- `PUT /api/filiais/{id}` - Atualizar filial
- `DELETE /api/filiais/{id}` - Deletar filial

### Motos

- `GET /api/motos` - Listar motos (com paginação)
- `GET /api/motos/{id}` - Buscar moto por ID
- `POST /api/motos` - Criar nova moto
- `PUT /api/motos/{id}` - Atualizar moto
- `DELETE /api/motos/{id}` - Deletar moto

### Manutenções

- `GET /api/manutencoes` - Listar manutenções (com paginação)
- `GET /api/manutencoes/{id}` - Buscar manutenção por ID
- `POST /api/manutencoes` - Criar nova manutenção
- `PUT /api/manutencoes/{id}` - Atualizar manutenção
- `DELETE /api/manutencoes/{id}` - Deletar manutenção

## Banco de Dados na Nuvem

- **PostgreSQL 15** rodando em Azure Container Instance
- **Localização**: East US
- **Recursos**: 1 CPU, 2GB RAM
- **Dados de Exemplo**: Mais de 2 registros em cada tabela para demonstração

## PASSO A PASSO PARA DEPLOY

### IMPORTANTE: NÃO use docker-compose para deploy na Azure!

- O arquivo `docker-compose.yml` é APENAS para desenvolvimento local
- Para deploy na Azure, use APENAS os scripts `build.sh` e `deploy.sh`

### Pré-requisitos

- Azure CLI instalado e configurado
- Docker Desktop instalado e rodando
- Conta Azure ativa

### 1. Preparação

```bash
git clone https://github.com/[SEU-USUARIO]/DevopsChallenge3-NeoMoto.git
cd DevopsChallenge3-NeoMoto/ProjetoNetMottu
az login
```

### 2. Build e Push para ACR

```bash
./build.sh
```

**O que faz**: Cria Resource Group, ACR, faz build das imagens Docker e envia para Azure Container Registry

### 3. Deploy no ACI

```bash
./deploy.sh
```

**O que faz**: Cria containers PostgreSQL e API no Azure Container Instances, configura conexão entre eles

### 4. Verificar Deploy

```bash
az container list --resource-group rg-neomoto-rm557863 --output table
```

## COMO TESTAR A APLICAÇÃO

### URLs da Aplicação

- **Base URL**: `http://neomoto-api-rm557863.eastus.azurecontainer.io:8080`
- **Swagger UI**: `http://neomoto-api-rm557863.eastus.azurecontainer.io:8080/swagger`

### Teste Rápido

```bash
# Testar se API está respondendo
curl http://neomoto-api-rm557863.eastus.azurecontainer.io:8080/api/filiais
```

### Teste CRUD Completo

**1. Criar Filial**

```bash
curl -X POST http://neomoto-api-rm557863.eastus.azurecontainer.io:8080/api/filiais \
  -H "Content-Type: application/json" \
  -d '{"nome":"Filial Teste","endereco":"Rua Teste 123","cidade":"São Paulo","uf":"SP"}'
```

**2. Listar Filiais**

```bash
curl http://neomoto-api-rm557863.eastus.azurecontainer.io:8080/api/filiais
```

**3. Criar Moto (use o ID da filial retornado)**

```bash
curl -X POST http://neomoto-api-rm557863.eastus.azurecontainer.io:8080/api/motos \
  -H "Content-Type: application/json" \
  -d '{"placa":"TEST123","modelo":"Honda CG 160","ano":2024,"filialId":"[ID_DA_FILIAL]"}'
```

**4. Criar Manutenção (use o ID da moto retornado)**

```bash
curl -X POST http://neomoto-api-rm557863.eastus.azurecontainer.io:8080/api/manutencoes \
  -H "Content-Type: application/json" \
  -d '{"motoId":"[ID_DA_MOTO]","data":"2024-09-24T10:30:00Z","descricao":"Teste manutenção","custo":99.99}'
```

## Arquitetura na Azure

```
Azure Resource Group (rg-neomoto-rm557863)
├── Azure Container Registry (acrneomotorm557863)
│   ├── neomoto-api:v1.0
│   └── neomoto-postgres:v1.0
└── Azure Container Instances
    ├── aci-neomoto-db-rm557863 (PostgreSQL)
    └── aci-neomoto-api-rm557863 (API .NET)
```

## Comandos de Monitoramento

```bash
# Ver status dos containers
az container list --resource-group rg-neomoto-rm557863 --output table

# Ver logs da API
az container logs --resource-group rg-neomoto-rm557863 --name aci-neomoto-api-rm557863

# Ver logs do banco
az container logs --resource-group rg-neomoto-rm557863 --name aci-neomoto-db-rm557863

# DELETAR TODOS OS RECURSOS
az group delete --name rg-neomoto-rm557863 --yes --no-wait
```

## Segurança Implementada

- **Container não-root**: Aplicação roda com usuário `appuser` (UID 1001)
- **Imagens oficiais**: Microsoft .NET e PostgreSQL oficiais
- **Health checks**: Monitoramento automático da saúde dos containers

## Estrutura do Projeto

```
ProjetoNetMottu/
├── Dockerfile                  # Container da API .NET
├── Dockerfile.postgres         # Container PostgreSQL customizado
├── build.sh                    # Script de build para ACR
├── deploy.sh                   # Script de deploy para ACI
├── script_bd.sql              # DDL completo do banco
├── NeoMoto.Api/                # API principal
├── NeoMoto.Domain/             # Entidades do domínio
├── NeoMoto.Infrastructure/     # DbContext e configurações EF
└── NeoMoto.Tests/              # Testes automatizados
```

## Integrantes do Projeto

- **Afonso Correia Pereira** - RM557863
- **Adel Mouhaidly** - RM557705
- **Tiago Augusto Desiderato** - RM558485

## Resumo dos Comandos

```bash
# Deploy completo
git clone [REPO_URL]
cd DevopsChallenge3-NeoMoto/ProjetoNetMottu
az login
./build.sh
./deploy.sh

# Teste
curl http://neomoto-api-rm557863.eastus.azurecontainer.io:8080/api/filiais

# Limpeza
az group delete --name rg-neomoto-rm557863 --yes --no-wait
```
