# =============================================================================
# NeoMoto API - Dockerfile
# Aplicação .NET 9 Minimal API para gestão de frota de motos
# =============================================================================

# Estágio de build
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Copiar arquivos de projeto
COPY ["NeoMoto.Api/NeoMoto.Api.csproj", "NeoMoto.Api/"]
COPY ["NeoMoto.Domain/NeoMoto.Domain.csproj", "NeoMoto.Domain/"]
COPY ["NeoMoto.Infrastructure/NeoMoto.Infrastructure.csproj", "NeoMoto.Infrastructure/"]

# Restaurar dependências
RUN dotnet restore "NeoMoto.Api/NeoMoto.Api.csproj"

# Copiar código fonte
COPY . .

# Build da aplicação
WORKDIR "/src/NeoMoto.Api"
RUN dotnet build "NeoMoto.Api.csproj" -c Release -o /app/build

# Publish da aplicação
RUN dotnet publish "NeoMoto.Api.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Estágio de runtime
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
WORKDIR /app

# Criar usuário não-root para segurança
RUN addgroup --system --gid 1001 appgroup && \
    adduser --system --uid 1001 --gid 1001 --shell /bin/false appuser

# Copiar aplicação publicada
COPY --from=build /app/publish .

# Alterar permissões e proprietário
RUN chown -R appuser:appgroup /app
USER appuser

# Expor porta
EXPOSE 8080

# Configurar variáveis de ambiente
ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Production

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl --fail http://localhost:8080/api/filiais || exit 1

# Comando de inicialização
ENTRYPOINT ["dotnet", "NeoMoto.Api.dll"]
