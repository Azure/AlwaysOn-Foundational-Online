FROM mcr.microsoft.com/dotnet/sdk:9.0.100 AS build-env
WORKDIR /app

COPY . ./
RUN dotnet publish AlwaysOn.BackgroundProcessor -c Release -o AlwaysOn.BackgroundProcessor/out

FROM mcr.microsoft.com/dotnet/aspnet:8.0

# Update and upgrade
RUN apt-get update && apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/*


# Create a new user group and user to run the workload as non-root
RUN groupadd -r workload && useradd --no-log-init -r -g workload workload
USER workload

WORKDIR /app

COPY --from=build-env /app/AlwaysOn.BackgroundProcessor/out .
ENTRYPOINT ["dotnet", "AlwaysOn.BackgroundProcessor.dll"]