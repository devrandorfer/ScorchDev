FROM microsoft/aspnet:latest
ENTRYPOINT ["c:\\app\\QueuePublisher.exe"]
ARG SOURCE=.\\bin\\debug
WORKDIR c:\\app
COPY $SOURCE .