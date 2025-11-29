# Estágio 1: Build - Baseado no Fedora para usar o DNF
FROM fedora:40 AS build

# Instala dependências de compilação
RUN dnf install -y gcc-c++ cmake make git protobuf-devel grpc-devel grpc-plugins libpqxx-devel which libpq-devel

WORKDIR /app

# Copia tudo para o contêiner
COPY . .

# Gera os arquivos a partir do .proto
RUN protoc --grpc_out=. --plugin=protoc-gen-grpc=`which grpc_cpp_plugin` quiz.proto
RUN protoc --cpp_out=. quiz.proto

# Compila o servidor (Exemplo com CMake, ajuste se necessário)
# Assumindo que você tem um CMakeLists.txt simples
RUN cmake .
RUN make

# ---
# Estágio 2: Final - Imagem de execução enxuta
FROM fedora:40

# Instala apenas as bibliotecas de execução
RUN dnf install -y grpc-cpp libpqxx && dnf clean all

WORKDIR /app

# Copia apenas o executável compilado do estágio de build
# IMPORTANTE: Troque 'meu_executavel_quiz' pelo nome real do seu binário gerado pelo 'make'
COPY --from=build /app/quiz_server .

# Expõe a porta do servidor gRPC
EXPOSE 4242

# Comando para rodar o servidor
CMD ["./quiz_server"]
