FROM microsoft/aspnet:latest
ENTRYPOINT ["cmd"]
ARG SOURCE=.\\bin\\Debug
WORKDIR c:\\app
EXPOSE 80
COPY $SOURCE .