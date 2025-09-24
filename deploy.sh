#!/bin/bash

set -e

# =============================================================================
# NeoMoto API - Azure Container Instances Deploy
# DevOps Challenge 3 - FIAP
# =============================================================================

# Configuração do RM
export RM=557863

# Configuração Azure
export AZURE_RG=rg-neomoto-rm557863
export ACR_NAME=acrneomotorm557863
export ACR_LOGIN_SERVER=acrneomotorm557863.azurecr.io

# Configuração das Imagens
export IMAGE_NAME=neomoto-api
export POSTGRES_IMAGE_NAME=neomoto-postgres
export IMAGE_TAG=v1.0

# Configuração da Aplicação
export API_PORT=8080
export DB_PORT=5432

# Configuração do Banco de Dados
export DB_NAME=neomoto
export DB_USER=neomoto_user
export DB_PASSWORD=neomoto_pass123

echo "============================================================================="
echo "NeoMoto API - Deploy no Azure Container Instances"
echo "============================================================================="
echo "Configurações:"
echo "   Resource Group: ${AZURE_RG}"
echo "   ACR: ${ACR_NAME}"
echo "   API Image: ${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"
echo "   PostgreSQL Image: ${ACR_LOGIN_SERVER}/${POSTGRES_IMAGE_NAME}:${IMAGE_TAG}"
echo ""

# ---------------------------------------------
# Verificação de login no Azure
# ---------------------------------------------
echo "Verificando login no Azure CLI..."
if ! az account show &> /dev/null; then
    echo "ERRO: Não logado no Azure CLI. Execute: az login"
    exit 1
fi

AZURE_ACCOUNT=$(az account show --query "name" --output tsv)
echo "Logado no Azure CLI - Conta: ${AZURE_ACCOUNT}"

# ---------------------------------------------
# Verificação das imagens no ACR
# ---------------------------------------------
echo ""
echo "Verificando se as imagens existem no ACR..."

if ! az acr repository show-tags --name "${ACR_NAME}" --repository "${IMAGE_NAME}" --output tsv | grep -q "^${IMAGE_TAG}$"; then
    echo "ERRO: Imagem da API ${IMAGE_NAME}:${IMAGE_TAG} não encontrada no ACR ${ACR_NAME}."
    echo "   Execute primeiro: ./build.sh"
    exit 1
fi

if ! az acr repository show-tags --name "${ACR_NAME}" --repository "${POSTGRES_IMAGE_NAME}" --output tsv | grep -q "^${IMAGE_TAG}$"; then
    echo "ERRO: Imagem PostgreSQL ${POSTGRES_IMAGE_NAME}:${IMAGE_TAG} não encontrada no ACR ${ACR_NAME}."
    echo "   Execute primeiro: ./build.sh"
    exit 1
fi

echo "Imagens encontradas no ACR!"

# ---------------------------------------------
# Obtendo credenciais do ACR
# ---------------------------------------------
echo ""
echo "Obtendo credenciais do ACR..."
ACR_USERNAME=$(az acr credential show --name "${ACR_NAME}" --query "username" --output tsv)
ACR_PASSWORD=$(az acr credential show --name "${ACR_NAME}" --query "passwords[0].value" --output tsv)
echo "Credenciais obtidas!"

# ---------------------------------------------
# Limpeza de containers existentes (se houver)
# ---------------------------------------------
echo ""
echo "Verificando containers existentes..."

if az container show --resource-group "${AZURE_RG}" --name "aci-neomoto-db-rm${RM}" &> /dev/null; then
    echo "AVISO: Container PostgreSQL existente encontrado. Removendo..."
    az container delete --resource-group "${AZURE_RG}" --name "aci-neomoto-db-rm${RM}" --yes
    echo "Container PostgreSQL removido!"
fi

if az container show --resource-group "${AZURE_RG}" --name "aci-neomoto-api-rm${RM}" &> /dev/null; then
    echo "AVISO: Container API existente encontrado. Removendo..."
    az container delete --resource-group "${AZURE_RG}" --name "aci-neomoto-api-rm${RM}" --yes
    echo "Container API removido!"
fi

# ---------------------------------------------
# Deploy do PostgreSQL no ACI
# ---------------------------------------------
echo ""
echo "Criando container PostgreSQL..."
az container create \
    --resource-group "${AZURE_RG}" \
    --name "aci-neomoto-db-rm${RM}" \
    --image "${ACR_LOGIN_SERVER}/${POSTGRES_IMAGE_NAME}:${IMAGE_TAG}" \
    --os-type Linux \
    --cpu 1 \
    --memory 2 \
    --ports ${DB_PORT} \
    --ip-address Public \
    --environment-variables \
        POSTGRES_DB="${DB_NAME}" \
        POSTGRES_USER="${DB_USER}" \
        POSTGRES_PASSWORD="${DB_PASSWORD}" \
        POSTGRES_HOST_AUTH_METHOD="md5" \
    --registry-login-server "${ACR_LOGIN_SERVER}" \
    --registry-username "${ACR_USERNAME}" \
    --registry-password "${ACR_PASSWORD}" \
    --restart-policy Always \
    --location "East US" \
    --output table

echo "Container PostgreSQL criado!"

# ---------------------------------------------
# Aguardar PostgreSQL inicializar
# ---------------------------------------------
echo ""
echo "Aguardando PostgreSQL inicializar completamente..."
sleep 45

# Obter IP do PostgreSQL com retry
echo "Obtendo IP do PostgreSQL..."
DB_IP=""
for i in {1..10}; do
    DB_IP=$(az container show --resource-group "${AZURE_RG}" --name "aci-neomoto-db-rm${RM}" --query "ipAddress.ip" --output tsv)
    if [ ! -z "$DB_IP" ] && [ "$DB_IP" != "null" ]; then
        echo "IP do PostgreSQL obtido: ${DB_IP}"
        break
    fi
    echo "   Tentativa $i: Aguardando IP do PostgreSQL..."
    sleep 10
done

if [ -z "$DB_IP" ] || [ "$DB_IP" = "null" ]; then
    echo "ERRO: Não foi possível obter o IP do PostgreSQL"
    exit 1
fi

# ---------------------------------------------
# Teste de conectividade com PostgreSQL
# ---------------------------------------------
echo ""
echo "Testando conectividade com PostgreSQL..."
for i in {1..5}; do
    if nc -z -w5 "${DB_IP}" ${DB_PORT} 2>/dev/null; then
        echo "PostgreSQL está respondendo na porta ${DB_PORT}!"
        break
    fi
    echo "   Tentativa $i: Aguardando PostgreSQL responder..."
    sleep 15
done

# ---------------------------------------------
# Deploy da API no ACI
# ---------------------------------------------
echo ""
echo "Criando container da API NeoMoto..."
az container create \
    --resource-group "${AZURE_RG}" \
    --name "aci-neomoto-api-rm${RM}" \
    --image "${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}" \
    --os-type Linux \
    --cpu 1 \
    --memory 1.5 \
    --ports ${API_PORT} \
    --dns-name-label "neomoto-api-rm${RM}" \
    --environment-variables \
        ASPNETCORE_ENVIRONMENT="Production" \
        ASPNETCORE_URLS="http://+:${API_PORT}" \
        ConnectionStrings__Default="Host=${DB_IP};Port=${DB_PORT};Database=${DB_NAME};Username=${DB_USER};Password=${DB_PASSWORD};Pooling=true;MinPoolSize=1;MaxPoolSize=20;" \
    --registry-login-server "${ACR_LOGIN_SERVER}" \
    --registry-username "${ACR_USERNAME}" \
    --registry-password "${ACR_PASSWORD}" \
    --restart-policy Always \
    --location "East US" \
    --output table

echo "Container da API criado!"

# ---------------------------------------------
# Aguardar API inicializar
# ---------------------------------------------
echo ""
echo "Aguardando API inicializar..."
sleep 30

# ---------------------------------------------
# Obter informações dos containers
# ---------------------------------------------
echo ""
echo "Obtendo informações dos containers..."

APP_FQDN=$(az container show --resource-group "${AZURE_RG}" --name "aci-neomoto-api-rm${RM}" --query "ipAddress.fqdn" --output tsv)
APP_IP=$(az container show --resource-group "${AZURE_RG}" --name "aci-neomoto-api-rm${RM}" --query "ipAddress.ip" --output tsv)

# ---------------------------------------------
# Status dos containers
# ---------------------------------------------
echo ""
echo "PostgreSQL Container Status:"
az container show --resource-group "${AZURE_RG}" --name "aci-neomoto-db-rm${RM}" \
    --query "{Name:name, State:containers[0].instanceView.currentState.state, IP:ipAddress.ip, Ports:ipAddress.ports[0].port}" \
    --output table

echo ""
echo "API Container Status:"
az container show --resource-group "${AZURE_RG}" --name "aci-neomoto-api-rm${RM}" \
    --query "{Name:name, State:containers[0].instanceView.currentState.state, IP:ipAddress.ip, FQDN:ipAddress.fqdn, Ports:ipAddress.ports[0].port}" \
    --output table

# ---------------------------------------------
# Teste da API
# ---------------------------------------------
echo ""
echo "Testando API..."
API_URL="http://${APP_FQDN}:${API_PORT}"

echo "   Aguardando API responder..."
sleep 20

for i in {1..5}; do
    if curl -s -f "${API_URL}/api/filiais" > /dev/null 2>&1; then
        echo "API está respondendo!"
        break
    fi
    echo "   Tentativa $i: Aguardando API responder..."
    sleep 15
done

# ---------------------------------------------
# Resumo final
# ---------------------------------------------
echo ""
echo "============================================================================="
echo "DEPLOY CONCLUÍDO COM SUCESSO!"
echo "============================================================================="
echo "Resumo dos Recursos:"
echo "   Resource Group: ${AZURE_RG}"
echo "   PostgreSQL: aci-neomoto-db-rm${RM} (IP: ${DB_IP}:${DB_PORT})"
echo "   API: aci-neomoto-api-rm${RM} (FQDN: ${APP_FQDN})"
echo ""
echo "URLs para teste da API:"
echo "   Base URL: ${API_URL}"
echo "   Swagger: ${API_URL}/swagger"
echo "   Filiais: ${API_URL}/api/filiais"
echo "   Motos: ${API_URL}/api/motos"
echo "   Manutenções: ${API_URL}/api/manutencoes"
echo ""
echo "Comandos úteis para monitoramento:"
echo "   Logs da API: az container logs --resource-group ${AZURE_RG} --name aci-neomoto-api-rm${RM}"
echo "   Logs do DB: az container logs --resource-group ${AZURE_RG} --name aci-neomoto-db-rm${RM}"
echo "   Status: az container list --resource-group ${AZURE_RG} --output table"
echo ""
echo "Teste rápido:"
echo "   curl ${API_URL}/api/filiais"
echo ""
echo "Para deletar todos os recursos:"
echo "   az group delete --name ${AZURE_RG} --yes --no-wait"
echo "============================================================================="
