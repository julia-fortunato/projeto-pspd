#include <iostream>
#include <string>
#include <memory>
#include <pqxx/pqxx>
#include <random>
#include <grpcpp/grpcpp.h>
#include "user.grpc.pb.h"
#include <sstream>
#include <random>

using grpc::Server;
using grpc::ServerBuilder;
using grpc::ServerContext;
using grpc::Status;
using user::User;
using user::CreateUserRequest;
using user::CreateUserResponse;
using user::Usuario;
using user::ScoreRequest;
using user::ScoreResponse;
using user::LoginRequest;
using user::LoginResponse;
using user::ListResponse;
using user::ListRequest;

// Lógica do serviço. Herdamos da classe de serviço gerada pelo protoc.
class UserServiceImpl final : public User::Service {
    // Implementação do método RPC CreateUsuario.
    Status CreateUsuario(ServerContext* context, const CreateUserRequest* request,
                         CreateUserResponse* response) override {
        
        pqxx::connection conn("dbname=serverB user=postgres password=password host=postgres-user-service port=5434");

		if (!conn.is_open()) {
			std::cerr << "Não foi possível conectar ao banco!\n";
			return Status::CANCELLED;
		}
		std::cout << "Conectado ao banco com sucesso!\n";

        std::random_device rd;
        std::mt19937 gen(rd());

        // Alfabeto permitido
        const std::string chars =
            "abcdefghijklmnopqrstuvwxyz"
            "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
            "0123456789";

        // Distribuição de índices (0 até tamanho do alfabeto - 1)
        std::uniform_int_distribution<> dis(0, chars.size() - 1);

        std::string random_str;
        random_str.reserve(200); // evita realocações

        for (int i = 0; i < 200; ++i) {
            random_str += chars[dis(gen)];
        }


        pqxx::work txn(conn);
		std::ostringstream sql;
		sql << "INSERT INTO public.usuario(nome, login, remembertoken, senha, score) VALUES ('"
        << request->usuario().nome() << "', '"
        << request->usuario().login() << "', '"
        << random_str << "', '"
        << request->usuario().senha() << "', "
        << 0 << ");";
		pqxx::result r = txn.exec(sql.str());
		txn.commit(); // Commit da transação, pois só estamos lendo dados
		
        response->set_remembertokenres(random_str);

        return Status::OK;
    }


    Status UpdateScore(ServerContext* context,
                       const ScoreRequest* request,
                       ScoreResponse* response) override {
        int newScore = request->scorenew();
        std::string tok = request->remembertok();
        
        // Aqui você faria a lógica de atualizar a pontuação no banco
        // Exemplo fictício:
        std::cout << "Atualizando pontuação para: " << newScore<<" e token ="<< tok << std::endl;

        pqxx::connection conn("dbname=serverB user=postgres password=password host=postgres-user-service port=5434");

		if (!conn.is_open()) {
			std::cerr << "Não foi possível conectar ao banco!\n";
			return Status::CANCELLED;
		}
		std::cout << "Conectado ao banco com sucesso!\n";

        pqxx::work txn(conn);
		std::ostringstream sql;
		sql << "update usuario set score = score + "<<newScore<<" where remembertoken  = '"<< tok <<"';";
		pqxx::result r = txn.exec(sql.str());
		txn.commit();
        return Status::OK;
    }

    Status Login(ServerContext* context, const LoginRequest* request,LoginResponse* response) override {
        std::string senha = request->senhareq();
        std::string login = request->loginreq();


        pqxx::connection conn("dbname=serverB user=postgres password=password host=postgres-user-service port=5434");

		if (!conn.is_open()) {
			std::cerr << "Não foi possível conectar ao banco!\n";
			return Status::CANCELLED;
		}
		std::cout << "Conectado ao banco com sucesso!\n";

        pqxx::work txn(conn);
		std::ostringstream sql;
		sql << "select rememberToken from usuario where login = '"<<login<<"' and senha = '"<<senha<<"';";
		pqxx::result r = txn.exec(sql.str());
		txn.commit();

        response->set_tokenrem(r[0]["remembertoken"].as<std::string>());
        
        return Status::OK;
    }

    Status ListByScore(ServerContext* context, const ListRequest* request, ListResponse* response) override {
    std::cout << "DEBUG: A REQUISIÇÃO CHEGOU DENTRO DA FUNÇÃO ListByScore." << std::endl;

    try {
        pqxx::connection conn("dbname=serverB user=postgres password=password host=postgres-user-service port=5434");

        if (!conn.is_open()) {
            std::cerr << "ERRO: Não foi possível conectar ao banco!" << std::endl;
            return Status(grpc::StatusCode::UNAVAILABLE, "Falha ao conectar no banco de dados.");
        }
        std::cout << "DEBUG: Conectado ao banco com sucesso." << std::endl;

        pqxx::work txn(conn);
        std::cout << "DEBUG: Executando a query 'select * from usuario order by score desc;'" << std::endl;
        
        pqxx::result r = txn.exec("select * from usuario order by score desc;");
        txn.commit();

        std::cout << "DEBUG: Query executada. Processando " << r.size() << " resultados." << std::endl;
        for (const auto& row : r) {
            Usuario* user = response->add_users();
            user->set_nome(row["nome"].as<std::string>());
            user->set_login("nulo");
            user->set_remembertoken("nulo");
            user->set_senha("nulo");
            user->set_score(row["score"].as<int32_t>());
        }

        std::cout << "DEBUG: Processamento concluído com sucesso." << std::endl;
        return Status::OK;

    } catch (const std::exception &e) {
        // ESSA É A PARTE MAIS IMPORTANTE! AGORA VOCÊ VERÁ O ERRO REAL.
        std::cerr << "ERRO FATAL: Uma exceção foi capturada em ListByScore: " << e.what() << std::endl;
        return Status(grpc::StatusCode::INTERNAL, "Erro interno no servidor ao consultar o banco de dados.");
    }
}
};

void RunServer() {
    std::string server_address("0.0.0.0:5050");
    UserServiceImpl service;

    ServerBuilder builder;
    // Escuta na porta especificada sem autenticação.
    builder.AddListeningPort(server_address, grpc::InsecureServerCredentials());
    // Registra nosso serviço para ser executado pelo servidor.
    builder.RegisterService(&service);

    // Constrói e inicia o servidor gRPC.
    std::unique_ptr<Server> server(builder.BuildAndStart());
    std::cout << "Servidor escutando em " << server_address << std::endl;


    // Aguarda o servidor ser finalizado. O servidor rodará até que o processo seja morto.
    server->Wait();
}

int main(int argc, char** argv) {
    RunServer();
    return 0;
}
