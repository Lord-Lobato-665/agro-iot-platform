# ===== Build =====
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src


COPY AgroAPI.sln ./
COPY AgroAPI.Gateway/AgroAPI.Gateway.csproj AgroAPI.Gateway/
COPY AgroAPI.Application/AgroAPI.Application.csproj AgroAPI.Application/
COPY AgroAPI.Domain/AgroAPI.Domain.csproj AgroAPI.Domain/
COPY AgroAPI.Infrastructure/AgroAPI.Infrastructure.csproj AgroAPI.Infrastructure/
RUN dotnet restore AgroAPI.Gateway/AgroAPI.Gateway.csproj


COPY . .
RUN dotnet publish AgroAPI.Gateway/AgroAPI.Gateway.csproj -c Release -o /app/publish /p:UseAppHost=false


# ===== Runtime =====
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app
EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "AgroAPI.Gateway.dll"]