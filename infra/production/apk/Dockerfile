# Atelier de construction des apps Android sur le serveur (`tara apk`), pour les téléphones de
# test sans Google Play. Même version de Flutter que la CI (les captures de référence en
# dépendent) ; le SDK Android est installé par Gradle au premier passage (cache conservé).
FROM eclipse-temurin:21-jdk-jammy
ARG FLUTTER_VERSION=3.47.9
ARG CMDLINE_TOOLS=11076708
RUN apt-get update -q && apt-get install -y -q --no-install-recommends curl git unzip xz-utils \
 && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    | tar -xJ -C /opt \
 && git config --global --add safe.directory /opt/flutter
ENV ANDROID_HOME=/opt/android-sdk PATH=/opt/flutter/bin:/opt/android-sdk/cmdline-tools/latest/bin:$PATH \
    PUB_CACHE=/cache/pub GRADLE_USER_HOME=/cache/gradle
RUN mkdir -p $ANDROID_HOME/cmdline-tools \
 && curl -fsSL -o /tmp/tools.zip "https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS}_latest.zip" \
 && unzip -q /tmp/tools.zip -d $ANDROID_HOME/cmdline-tools && mv $ANDROID_HOME/cmdline-tools/cmdline-tools $ANDROID_HOME/cmdline-tools/latest \
 && rm /tmp/tools.zip \
 && yes | sdkmanager --licenses >/dev/null \
 && flutter config --no-analytics >/dev/null && flutter --version
COPY build.sh /usr/local/bin/build-apk
CMD ["build-apk"]
