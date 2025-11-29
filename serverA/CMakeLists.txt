# Versão mínima do CMake necessária
cmake_minimum_required(VERSION 3.10)

# Nome do projeto e linguagem
project(QuizServerProject CXX)

# --- Encontrar as dependências ---
find_package(Protobuf REQUIRED)
find_package(gRPC REQUIRED)

# --- Definir os arquivos a serem gerados a partir do .proto ---
set(PROTO_FILE ${CMAKE_CURRENT_SOURCE_DIR}/quiz.proto)
set(GENERATED_DIR ${CMAKE_CURRENT_BINARY_DIR})

set(PROTO_GENERATED_SOURCES
    ${GENERATED_DIR}/quiz.pb.cc
    ${GENERATED_DIR}/quiz.grpc.pb.cc
)
set(PROTO_GENERATED_HEADERS
    ${GENERATED_DIR}/quiz.pb.h
    ${GENERATED_DIR}/quiz.grpc.pb.h
)

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

add_custom_target(quiz_proto_gen DEPENDS ${PROTO_GENERATED_SOURCES} ${PROTO_GENERATED_HEADERS})

# --- Executável do servidor ---
add_executable(quiz_server
    server.cc
    ${PROTO_GENERATED_SOURCES}
)
add_dependencies(quiz_server quiz_proto_gen)
target_link_libraries(quiz_server
    PUBLIC
    gRPC::grpc++
    ${Protobuf_LIBRARIES}
    pqxx   # <- adiciona libpqxx
    pq
)
target_include_directories(quiz_server PUBLIC ${GENERATED_DIR})

# --- Executável do cliente ---
#add_executable(quiz_client
#    client.cc
#    ${PROTO_GENERATED_SOURCES}
#)
#add_dependencies(quiz_client quiz_proto_gen)
#target_link_libraries(quiz_client
#    PUBLIC
#    gRPC::grpc++
#    ${Protobuf_LIBRARIES}
#    pqxx   # <- adiciona libpqxx
#    pq
#)
#target_include_directories(quiz_client PUBLIC ${GENERATED_DIR})
#
#message(STATUS "Configuração concluída. Para compilar, execute 'make'.")

