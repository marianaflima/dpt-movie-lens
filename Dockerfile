# Imagem customizada do Metabase com suporte a DuckDB.
# Necessária porque a imagem oficial do Metabase é Alpine, e o driver
# DuckDB tem problemas de compatibilidade com glibc nela — por isso usamos
# uma base Debian/JRE (eclipse-temurin), como recomendado pelo próprio
# mantenedor do driver (MotherDuck).

FROM eclipse-temurin:21-jre-jammy

ARG METABASE_VERSION=v0.56.8
ARG METABASE_DUCKDB_DRIVER_VERSION=1.4.1.1

ENV MB_PLUGINS_DIR=/plugins

RUN apt-get update && \
    apt-get install -y --no-install-recommends bash fontconfig curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Baixa o Metabase e o driver DuckDB nas versões escolhidas
ADD https://downloads.metabase.com/${METABASE_VERSION}/metabase.jar /app/metabase.jar
ADD https://github.com/MotherDuck-Open-Source/metabase_duckdb_driver/releases/download/${METABASE_DUCKDB_DRIVER_VERSION}/duckdb.metabase-driver.jar ${MB_PLUGINS_DIR}/duckdb.metabase-driver.jar

RUN chmod 744 ${MB_PLUGINS_DIR}/duckdb.metabase-driver.jar

RUN curl https://install.duckdb.org | sh
RUN export PATH="/root/.duckdb/cli/latest/duckdb":$PATH

EXPOSE 3000

CMD ["java", "-jar", "/app/metabase.jar"]