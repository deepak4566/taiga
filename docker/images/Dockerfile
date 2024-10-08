

FROM python:3.11-slim
LABEL maintainer="support@taiga.io"


ENV DEBIAN_FRONTEND=noninteractive

ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONFAULTHANDLER=1

# Use a virtualenv
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install requirements
COPY python/apps/taiga/requirements/prod.txt /taiga/requirements.txt
WORKDIR /taiga
RUN set -eux; \
    apt-get update; \
    # install system dependencies
    apt-get install -y --no-install-recommends \
        build-essential \
        # libpq5 needed in runtime for psycopg2
        libpq5 \
        libpq-dev \
        wget\
    ; \
    # =====================================
    # install Taiga requirements
    python -m pip install --upgrade pip wheel setuptools; \
    python -m pip install -r requirements.txt; \
    # =====================================
    # create taiga group and user
    groupadd --system taiga --gid=999; \
    useradd --system --no-create-home --gid taiga --uid=999 --shell=/bin/bash taiga; \
    mkdir -p /taiga/media/exports; \
    mkdir -p /taiga/static; \
    # =====================================
    # remove unneeded files and packages
    rm -rf /taiga/requirements.txt; \
    rm -rf apps/taiga/requirements/; \
    find . -name '__pycache__' -exec rm -r '{}' +; \
    find . -name '*pyc' -exec rm -r '{}' +; \
    apt-get purge -y --auto-remove \
        build-essential \
        libpq-dev \
        wget \
    ; \
    rm -rf /var/lib/apt/lists/*; \
    rm -rf /root/.cache;

# Install Taiga
COPY python/apps/taiga/ /taiga/
WORKDIR /taiga
RUN set -eux; \
    python -m pip install -e .; \
    chown -R taiga:taiga /taiga; \
    python -m taiga i18n compile-catalog; \
    python -m taiga collectstatic; \
    # =====================================
    # clean taiga
    find . -name '__pycache__' -exec rm -r '{}' +; \
    find . -name '*pyc' -exec rm -r '{}' +; \
    find . -name '*po' -exec rm -r '{}' +;

USER taiga:taiga
ENTRYPOINT ["python", "-m", "taiga"]
CMD ["--help"]
