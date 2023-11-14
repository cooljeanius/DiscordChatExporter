# -- Build
# Specify the platform here so that we pull the SDK image matching the host platform,
# instead of the target platform specified during build by the `--platform` option.
# Use the .NET 8.0 preview because the `--arch` option is only available in that version.
# https://github.com/dotnet/dotnet-docker/issues/4388#issuecomment-1459038566
# TODO: switch images to Alpine once .NET 8.0 is released.
# Currently, the correct preview version is only available on Debian.
# https://github.com/dotnet/dotnet-docker/blob/main/samples/selecting-tags.md
FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:8.0-preview AS build

# Expose the target architecture set by the `docker build --platform` option, so that
# we can build the assembly for the correct platform.
ARG TARGETARCH

WORKDIR /tmp/app

COPY favicon.ico .
COPY NuGet.config .
COPY Directory.Build.props .
COPY DiscordChatExporter.Core DiscordChatExporter.Core
COPY DiscordChatExporter.Cli DiscordChatExporter.Cli

# Publish a self-contained assembly so we can use a slimmer runtime image
RUN dotnet publish DiscordChatExporter.Cli \
    -p:CSharpier_Bypass=true \
    --configuration Release \
    --self-contained \
    --use-current-runtime \
    --arch $TARGETARCH \
    --output DiscordChatExporter.Cli/bin/publish/

# -- Run
# Use `runtime-deps` instead of `runtime` because we have a self-contained assembly
FROM --platform=$TARGETPLATFORM mcr.microsoft.com/dotnet/runtime-deps:8.0 AS run

LABEL org.opencontainers.image.title="DiscordChatExporter.CLI"
LABEL org.opencontainers.image.description="DiscordChatExporter is an application that can be used to export message history from any Discord channel to a file."
LABEL org.opencontainers.image.authors="tyrrrz.me"
LABEL org.opencontainers.image.url="https://github.com/Tyrrrz/DiscordChatExporter"
LABEL org.opencontainers.image.source="https://github.com/Tyrrrz/DiscordChatExporter/blob/master/DiscordChatExporter.Cli.dockerfile"
LABEL org.opencontainers.image.licenses="MIT"

# Alpine image doesn't come with the ICU libraries pre-installed, so we need to install them manually
RUN apk add --no-cache icu-libs
RUN apk add --no-cache icu-data-full
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false
ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8

# This directory is exposed to the user for mounting purposes, so it's important that it always
# stays the same for backwards compatibility.
WORKDIR /out

COPY --from=build /tmp/dce/DiscordChatExporter.Cli/bin/publish /opt/app

USER $APP_UID
ENTRYPOINT ["/opt/app/DiscordChatExporter.Cli"]