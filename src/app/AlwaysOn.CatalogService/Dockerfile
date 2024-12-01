# Create build environment
FROM mcr.microsoft.com/dotnet/sdk:9.0.100 AS build-env
WORKDIR /app
COPY . ./
RUN dotnet publish AlwaysOn.CatalogService -c Release -o AlwaysOn.CatalogService/out

# Create application container
FROM mcr.microsoft.com/dotnet/aspnet:8.0
# Update and upgrade
RUN apt-get update && apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/*


# Create a new user group and user to run the workload as non-root
RUN groupadd -r workload && useradd --no-log-init -r -g workload workload
USER workload

WORKDIR /app

# Copy build artifacts from previous stage build-env
COPY --from=build-env /app/AlwaysOn.CatalogService/out .

ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080
ENTRYPOINT ["dotnet", "AlwaysOn.CatalogService.dll"]