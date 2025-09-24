#!/bin/bash

set -e

# =============================================================================
# NeoMoto API - Azure Container Registry Build & Push
# DevOps Challenge 3 - FIAP
# =============================================================================

# Configuração do RM
export RM=557863

# Configuração Azure
export AZURE_RG=rg-neomoto-rm557863
export ACR_NAME=acrneomotorm557863
export ACR_LOGIN_SERVER=acrneomotorm557863.azurecr.io

# Configuração da Imagem
export IMAGE_NAME=neomoto-api
export POSTGRES_IMAGE_NAME=neomoto-postgres
export IMAGE_TAG=v1.0

echo "============================================================================="
echo "NeoMoto API - Build e Push para Azure Container Registry"
echo "============================================================================="
echo "Configurações:"
echo "   RM: ${RM}"
echo "   Resource Group: ${AZURE_RG}"
echo "   ACR: ${ACR_NAME}"
echo "   API Image: ${IMAGE_NAME}:${IMAGE_TAG}"
echo "   PostgreSQL Image: ${POSTGRES_IMAGE_NAME}:${IMAGE_TAG}"
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
# Criação do Resource Group
# ---------------------------------------------
echo ""
echo "Criando Resource Group: ${AZURE_RG}..."
az group create \
    --name "${AZURE_RG}" \
    --location "East US" \
    --output table

# ---------------------------------------------
# Criação do Azure Container Registry
# ---------------------------------------------
echo ""
echo "Criando Azure Container Registry: ${ACR_NAME}..."
az acr create \
    --resource-group "${AZURE_RG}" \
    --name "${ACR_NAME}" \
    --sku Basic \
    --admin-enabled true \
    --location "East US" \
    --output table || echo "AVISO: ACR já existe ou ocorreu um erro. Continuando..."

# Verificar se ACR existe
az acr show --name "${ACR_NAME}" --resource-group "${AZURE_RG}" --output table

# ---------------------------------------------
# Aguardar ACR ficar disponível
# ---------------------------------------------
echo ""
echo "Aguardando ACR ficar disponível..."
for i in {1..10}; do
    if az acr show --name "${ACR_NAME}" --resource-group "${AZURE_RG}" --query "provisioningState" --output tsv | grep -q "Succeeded"; then
        echo "ACR disponível e provisionado com sucesso!"
        break
    fi
    echo "   Aguardando... (${i}/10)"
    sleep 15
done

# ---------------------------------------------
# Login no Azure Container Registry
# ---------------------------------------------
echo ""
echo "Fazendo login no ACR..."
if ! az acr login --name "${ACR_NAME}"; then
    echo "AVISO: Login direto falhou. Tentando com credenciais admin..."
    ACR_USERNAME=$(az acr credential show --name "${ACR_NAME}" --query "username" --output tsv)
    ACR_PASSWORD=$(az acr credential show --name "${ACR_NAME}" --query "passwords[0].value" --output tsv)
    echo "${ACR_PASSWORD}" | docker login "${ACR_LOGIN_SERVER}" --username "${ACR_USERNAME}" --password-stdin
fi
echo "Login no ACR concluído!"

# ---------------------------------------------
# Build da imagem da API
# ---------------------------------------------
echo ""
echo "Fazendo build da imagem da API NeoMoto..."
docker build \
    -t "${IMAGE_NAME}:${IMAGE_TAG}" \
    -f Dockerfile \
    . \
    --no-cache

echo "Build da API concluído!"

# ---------------------------------------------
# Build da imagem PostgreSQL customizada
# ---------------------------------------------
echo ""
echo "Fazendo build da imagem PostgreSQL customizada..."
docker build \
    -t "${POSTGRES_IMAGE_NAME}:${IMAGE_TAG}" \
    -f Dockerfile.postgres \
    . \
    --no-cache

echo "Build do PostgreSQL concluído!"

# ---------------------------------------------
# Tag das imagens para o ACR
# ---------------------------------------------
echo ""
echo "Aplicando tags para ACR..."
docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"
docker tag "${POSTGRES_IMAGE_NAME}:${IMAGE_TAG}" "${ACR_LOGIN_SERVER}/${POSTGRES_IMAGE_NAME}:${IMAGE_TAG}"
echo "Tags aplicadas!"

# ---------------------------------------------
# Push das imagens para o ACR
# ---------------------------------------------
echo ""
echo "Fazendo push da imagem da API para ACR..."
docker push "${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"
echo "Push da API concluído!"

echo ""
echo "Fazendo push da imagem PostgreSQL para ACR..."
docker push "${ACR_LOGIN_SERVER}/${POSTGRES_IMAGE_NAME}:${IMAGE_TAG}"
echo "Push do PostgreSQL concluído!"

# ---------------------------------------------
# Verificação das imagens no ACR
# ---------------------------------------------
echo ""
echo "Verificando imagens no ACR..."
echo "Repositórios disponíveis:"
az acr repository list --name "${ACR_NAME}" --output table

echo ""
echo "Tags da API:"
az acr repository show-tags --name "${ACR_NAME}" --repository "${IMAGE_NAME}" --output table

echo ""
echo "Tags do PostgreSQL:"
az acr repository show-tags --name "${ACR_NAME}" --repository "${POSTGRES_IMAGE_NAME}" --output table

# ---------------------------------------------
# Resumo final
# ---------------------------------------------
echo ""
echo "============================================================================="
echo "BUILD E PUSH CONCLUÍDOS COM SUCESSO!"
echo "============================================================================="
echo "Resumo:"
echo "   Resource Group: ${AZURE_RG}"
echo "   ACR: ${ACR_NAME}"
echo "   API Image: ${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"
echo "   PostgreSQL Image: ${ACR_LOGIN_SERVER}/${POSTGRES_IMAGE_NAME}:${IMAGE_TAG}"
echo ""
echo "Próximo passo: Execute ./deploy.sh para fazer deploy no Azure Container Instances"
echo "============================================================================="
