# ARGUMENTS --------------------------------------------------------------------
##
# Base Container version
# Using Flutter v3.27.x
##
ARG SDK_BASE_VERSION=SDK
##
# Base container version
##
ARG BASE_VERSION=runtime_release

##
# Board architecture
##
ARG IMAGE_ARCH=

##
# Directory of the application inside container
##
ARG APP_ROOT=

##
# Build/Deploy Step
##

# BUILD ------------------------------------------------------------------------
FROM crossware.app:5050/public-repos/flutter:${SDK_BASE_VERSION} AS build

ARG IMAGE_ARCH
ARG GPU
ARG APP_ROOT

COPY . ${APP_ROOT}
WORKDIR ${APP_ROOT}

RUN flutter-elinux clean; flutter-elinux pub get; flutter-elinux build elinux --release

# BUILD ------------------------------------------------------------------------


# DEPLOY -----------------------------------------------------------------------

FROM crossware.app:5050/public-repos/flutter:${BASE_VERSION} AS final

ARG APP_ROOT
ARG SSHUSERNAME

WORKDIR ${APP_ROOT}

COPY --chown=$SSHUSERNAME:$SSHUSERNAME run-release.sh ${APP_ROOT}/
RUN chmod +x ${APP_ROOT}/run-release.sh

COPY --from=build ${APP_ROOT}/build/elinux/arm64/release/bundle/ ${APP_ROOT}/bundle

ENV FLUTTER_DRM_DEVICE="/dev/dri/card0:/dev/dri/card1"
ENV APP_PATH=${APP_ROOT}/bundle

CMD ["run-release.sh"]
# DEPLOY -----------------------------------------------------------------------
