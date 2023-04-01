FROM lukemathwalker/cargo-chef:latest-rust-1 as chef
WORKDIR /splitter_rust_orchestrator
EXPOSE 8080
RUN apt update && apt install lld clang -y
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive \
    apt-get install --no-install-recommends --assume-yes \
    protobuf-compiler

FROM chef as planner
COPY . .
# Compute a lock-like file for our project
RUN cargo chef prepare  --recipe-path recipe.json

FROM chef as builder
COPY --from=planner /splitter_rust_orchestrator/recipe.json recipe.json
# Build our project dependencies, not our application!
RUN cargo chef cook --release --recipe-path recipe.json
# Up to this point, if our dependency tree stays the same,
# all layers should be cached. 
COPY . .
# ENV SQLX_OFFLINE true
# Build our project
RUN cargo build --release --bin splitter_rust_orchestrator


FROM rust:1.68.0 as build-env
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive \
    apt-get install --no-install-recommends --assume-yes \
    protobuf-compiler
WORKDIR /splitter_rust_orchestrator
EXPOSE 8080
COPY . /splitter_rust_orchestrator
RUN cargo build --release

FROM gcr.io/distroless/cc
COPY --from=builder /splitter_rust_orchestrator/target/release/splitter_rust_orchestrator /
CMD ["./splitter_rust_orchestrator"]