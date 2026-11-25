# syntax=docker/dockerfile:1

# 1) Front-end React (Node LTS ativa)
FROM node:24-alpine AS front
WORKDIR /src/PortalTarefas.Frontend
COPY PortalTarefas.Frontend/package*.json ./
RUN npm ci
COPY PortalTarefas.Frontend/ ./
RUN npm run build

# 2) Restore, publish da API com o build do React em wwwroot
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY PortalTarefas.sln ./
COPY PortalTarefas.Web/PortalTarefas.Web.csproj PortalTarefas.Web/
COPY PortalTarefas.Tests/PortalTarefas.Tests.csproj PortalTarefas.Tests/
RUN dotnet restore
COPY PortalTarefas.Web/ PortalTarefas.Web/
COPY --from=front /src/PortalTarefas.Frontend/dist/ PortalTarefas.Web/wwwroot/
RUN dotnet publish PortalTarefas.Web/PortalTarefas.Web.csproj -c Release -o /app/publish --no-restore /p:UseAppHost=false

# 3) Runtime enxuto, usuário não privilegiado, sem segredos
FROM mcr.microsoft.com/dotnet/aspnet:10.0-alpine AS final
WORKDIR /app
COPY --from=build /app/publish ./
ENV ASPNETCORE_URLS=http://+:8080 \
    ASPNETCORE_ENVIRONMENT=Production
EXPOSE 8080
USER $APP_UID
HEALTHCHECK --interval=30s --timeout=3s --start-period=20s --retries=3 \
  CMD wget -qO- http://localhost:8080/health/live || exit 1
ENTRYPOINT ["dotnet", "PortalTarefas.Web.dll"]
