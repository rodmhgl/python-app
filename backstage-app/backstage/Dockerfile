FROM node:18-bookworm-slim

# Set Python interpreter for `node-gyp` to use
ENV PYTHON=/usr/bin/python3

# Install isolate-vm dependencies, these are needed by the @backstage/plugin-scaffolder-backend.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        python3 \
        python3-pip \
        python3-venv \
        g++ \
        build-essential \
        gcc \
        musl-dev \
        openjdk-17-jdk \
        curl \
        graphviz \
        fonts-dejavu \
        fontconfig && \
    rm -rf /var/lib/apt/lists/*

ENV VIRTUAL_ENV=/opt/venv
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

RUN curl -o plantuml.jar -L "https://github.com/plantuml/plantuml/releases/download/v1.2024.6/plantuml-1.2024.6.jar" && \
    echo "3e944755cbed59e1ed9332691d92294bef7bbcda  plantuml.jar" | \
    sha1sum -c - && mv plantuml.jar /opt/plantuml.jar
RUN pip3 install mkdocs-techdocs-core
RUN pip install mkdocs-kroki-plugin

# RUN echo $'#!/bin/sh\n\njava -Dplantuml.include.path=${diagramDir} -jar '/opt/plantuml.jar ' ${@}' >> /usr/local/bin/plantuml
RUN echo '#!/bin/sh\n\njava -jar '/opt/plantuml.jar' ${@}' >> /usr/local/bin/plantuml
RUN chmod 755 /usr/local/bin/plantuml

RUN which plantuml
RUN java -jar /opt/plantuml.jar -version
RUN cat /usr/local/bin/plantuml
RUN plantuml -version

# From here on we use the least-privileged `node` user to run the backend.
USER node

WORKDIR /app

ENV NODE_ENV=production

# Copy files needed by Yarn
COPY --chown=node:node .yarn ./.yarn
COPY --chown=node:node .yarnrc.yml ./
COPY --chown=node:node backstage.json ./

# This disables node snapshot for Node 20 to work with the Scaffolder
ENV NODE_OPTIONS="--no-node-snapshot"

# Copy repo skeleton first, to avoid unnecessary docker cache invalidation.
# The skeleton contains the package.json of each package in the monorepo,
# and along with yarn.lock and the root package.json, that's enough to run yarn install.
COPY --chown=node:node yarn.lock package.json packages/backend/dist/skeleton.tar.gz ./
RUN tar xzf skeleton.tar.gz && rm skeleton.tar.gz

RUN --mount=type=cache,target=/home/node/.cache/yarn,sharing=locked,uid=1000,gid=1000 \
    yarn workspaces focus --all --production && rm -rf "$(yarn cache clean)"

# Then copy the rest of the backend bundle, along with any other files we might want.
COPY --chown=node:node packages/backend/dist/bundle.tar.gz app-config*.yaml ./
RUN tar xzf bundle.tar.gz && rm bundle.tar.gz

COPY --chown=node:node ./catalog/entities/*.yaml ./entities/

CMD ["node", "packages/backend", "--config", "app-config.yaml", "--config", "app-config.production.yaml"]