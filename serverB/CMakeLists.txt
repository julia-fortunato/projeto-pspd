# Versão mínima do CMake necessária
cmake_minimum_required(VERSION 3.10)

# Nome do projeto e linguagem
project(GrpcUserProject CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)


# --- Encontrar as dependências ---
find_package(Protobuf REQUIRED)
find_package(gRPC REQUIRED)

# --- Definir os arquivos a serem gerados a partir do .proto ---
set(PROTO_FILE ${CMAKE_CURRENT_SOURCE_DIR}/user.proto)
set(GENERATED_DIR ${CMAKE_CURRENT_BINARY_DIR})

# Lista explícita dos arquivos que serão gerados
set(PROTO_GENERATED_SOURCES
    ${GENERATED_DIR}/user.pb.cc
    ${GENERATED_DIR}/user.grpc.pb.cc
)
set(PROTO_GENERATED_HEADERS
    ${GENERATED_DIR}/user.pb.h
    ${GENERATED_DIR}/user.grpc.pb.h
)

# Comando personalizado para executar o protoc com os argumentos corretos
add_custom_command(
    OUTPUT ${PROTO_GENERATED_SOURCES} ${PROTO_GENERATED_HEADERS}
    COMMAND ${Protobuf_PROTOC_EXECUTABLE}
        --grpc_out=${GENERATED_DIR}
        --cpp_out=${GENERATED_DIR}
        -I ${CMAKE_CURRENT_SOURCE_DIR}
        --plugin=protoc-gen-grpc=$<TARGET_FILE:gRPC::grpc_cpp_plugin>
        ${PROTO_FILE}
    DEPENDS ${PROTO_FILE}
)

# Cria um alvo para garantir que a geração de código seja executada
add_custom_target(user_proto_gen DEPENDS ${PROTO_GENERATED_SOURCES} ${PROTO_GENERATED_HEADERS})

# --- Executável do servidor ---
add_executable(user_server
    server.cpp
    ${PROTO_GENERATED_SOURCES}
)
# Garante que os arquivos do proto sejam gerados antes de compilar o servidor
add_dependencies(user_server user_proto_gen)

# Vincula as bibliotecas necessárias
target_link_libraries(user_server
    PUBLIC
    gRPC::grpc++
    protobuf::libprotobuf # <-- Usando o target moderno do Protobuf
    # Se precisasse do PostgreSQL, adicionaria aqui: pqxx pq
    pqxx   # <- adiciona libpqxx
    pq
)
# Garante que o servidor possa encontrar os headers gerados
target_include_directories(user_server PUBLIC ${GENERATED_DIR})

# --- Executável do cliente ---
#add_executable(user_client
#    client.cpp
#    ${PROTO_GENERATED_SOURCES}
#)
#add_dependencies(user_client user_proto_gen)
#target_link_libraries(user_client
#    PUBLIC
#    gRPC::grpc++
#    protobuf::libprotobuf # <-- Usando o target moderno do Protobuf
#    pqxx   # <- adiciona libpqxx
#    pq
#)
#target_include_directories(user_client PUBLIC ${GENERATED_DIR})

#message(STATUS "Configuração concluída. Para compilar, execute 'make'.")
