#FROM microsoft/aspnetcore:1.0.1
FROM microsoft/aspnet:latest
ENTRYPOINT ["dotnet", "Queue.dll"]
ARG source=.
WORKDIR /app
EXPOSE 80
COPY $source .
