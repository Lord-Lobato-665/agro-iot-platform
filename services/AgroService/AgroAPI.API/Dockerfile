# ===== Build =====
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src


# Copiamos solución y csproj para restore con caché efectivo
COPY AgroAPI.sln ./
COPY AgroAPI.API/AgroAPI.API.csproj AgroAPI.API/
COPY AgroAPI.Application/AgroAPI.Application.csproj AgroAPI.Application/
COPY AgroAPI.Domain/AgroAPI.Domain.csproj AgroAPI.Domain/
COPY AgroAPI.Infrastructure/AgroAPI.Infrastructure.csproj AgroAPI.Infrastructure/
RUN dotnet restore AgroAPI.API/AgroAPI.API.csproj


# Copiamos todo y publicamos
COPY . .
RUN dotnet publish AgroAPI.API/AgroAPI.API.csproj -c Release -o /app/publish /p:UseAppHost=false


# ===== Runtime =====
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app
EXPOSE 8081
ENV ASPNETCORE_URLS=http://+:8081
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "AgroAPI.API.dll"]