#include <iostream>
#include <string>
#include <memory>
#include <pqxx/pqxx> 
#include <grpcpp/grpcpp.h>
#include "quiz.grpc.pb.h"
#include <sstream>

using grpc::Server;
using grpc::ServerBuilder;
using grpc::ServerContext;
using grpc::Status;

using quiz::Quiz;
using quiz::Pergunta;
using quiz::GetPerguntasRequest;
using quiz::GetPerguntasResponse;
using quiz::CreateRequest;
using quiz::CreateResponse;
using quiz::PerguntaId;
using quiz::StatusRetorno;

class QuizServiceImpl final : public Quiz::Service {


	Status DeletePergunta(ServerContext* context, const PerguntaId* request, StatusRetorno* response) override{

		pqxx::connection conn("dbname=meubanco user=meuusuario password=minhasenha host=postgres-quiz-service port=5433");

		if (!conn.is_open()) {
			std::cerr << "Não foi possível conectar ao banco!" << std::endl;
			return Status::CANCELLED;
		}
		std::cout << "Conectado ao banco com sucesso!" << std::endl;

		pqxx::work txn(conn);
		std::ostringstream sql;
		sql << "DELETE FROM quiz WHERE id ="
			<< request->dbid() << ";";
		pqxx::result r = txn.exec(sql.str());
		txn.commit(); // Commit da transação, pois só estamos lendo dados
		
		response->set_statusret(0);

		std::cout << "pergunta deletada com sucesso" << std::endl;


		return Status::OK;
	}
	Status GetPerguntas(ServerContext* context, const GetPerguntasRequest* request, GetPerguntasResponse* response) override {
		std::cout << "Recebida requisição para GetPerguntas" << std::endl;
		pqxx::connection conn("dbname=meubanco user=meuusuario password=minhasenha host=postgres-quiz-service port=5433");

		if (!conn.is_open()) {
			std::cerr << "Não foi possível conectar ao banco!" << std::endl;
			return Status::CANCELLED;
		}
		std::cout << "Conectado ao banco com sucesso!" << std::endl;

		pqxx::work txn(conn);
		std::string sql = R"(
            		SELECT
                		q.id,
                		q.texto,
        	        	q.indiceResposta,
	                	q.explicacao,
                		a.alternativa
            		FROM
                		quiz q
            		JOIN
                		alternativas a ON q.id = a.quiz_id
            		ORDER BY
                		q.id;
        	)";

		// 3. Execução da query
		pqxx::result r = txn.exec(sql);
		txn.commit(); // Commit da transação, pois só estamos lendo dados

		// 4. Processamento dos resultados
		Pergunta* pergunta_atual = nullptr;
		int id_quiz_anterior = -1;

		for (auto const &row : r) {
			int id_quiz_atual = row["id"].as<int>();

			// Se o ID da linha atual for diferente do anterior, é uma nova pergunta
			if (id_quiz_atual != id_quiz_anterior) {
				pergunta_atual = response->add_perguntas(); // Cria um novo objeto Pergunta na resposta

				// Preenche os dados que são únicos por pergunta
				pergunta_atual->set_id(id_quiz_atual);
				pergunta_atual->set_texto(row["texto"].as<std::string>());

				// Trata campos que podem ser nulos
				if (!row["indiceResposta"].is_null()) {
					pergunta_atual->set_indice_resposta(row["indiceResposta"].as<int>());
				}
				if (!row["explicacao"].is_null()) {
					pergunta_atual->set_explicacao(row["explicacao"].as<std::string>());
				}

				id_quiz_anterior = id_quiz_atual; // Atualiza o ID de controle
			}

			if (pergunta_atual) {
				pergunta_atual->add_alternativas(row["alternativa"].as<std::string>());
			}
		}
		return Status::OK;
	}

		Status CreatePergunta(ServerContext* context, const CreateRequest* request, CreateResponse* response) override {
		std::cout << "Criação de dados acionada" << std::endl;

		// Validação para garantir que há perguntas na requisição
		if (request->pergunta_criar_size() == 0) {
			std::cerr << "Nenhuma pergunta recebida para criação!" << std::endl;
			return Status(grpc::INVALID_ARGUMENT, "A requisição para criar pergunta está vazia.");
		}

		pqxx::connection conn("dbname=meubanco user=meuusuario password=minhasenha host=postgres-quiz-service port=5433");
		if (!conn.is_open()) {
			std::cerr << "Não foi possível conectar ao banco!" << std::endl;
			return Status(grpc::UNAVAILABLE, "Falha na conexão com o banco de dados.");
		}
		std::cout << "Conectado ao banco com sucesso!" << std::endl;

		// Inicia uma transação. Se algo der errado, o pqxx::work fará o rollback automaticamente.
		pqxx::work txn(conn);

		try {
			// Vamos processar a primeira pergunta da requisição
			const auto& p = request->pergunta_criar(0);

			// Passo 1: Inserir na tabela 'quiz' e obter o ID gerado usando 'RETURNING id'
			std::ostringstream insert_quiz_query;
			insert_quiz_query << "INSERT INTO quiz(texto, indiceResposta, explicacao) VALUES ("
				<< txn.quote(p.texto()) << ", "
				<< p.indice_resposta() << ", "
				<< txn.quote(p.explicacao()) << ") RETURNING id;";

			// txn.exec1() é usado pois esperamos exatamente 1 linha de retorno (o id)
			int new_quiz_id = txn.exec1(insert_quiz_query.str())[0].as<int>();

			// Passo 2: Iterar sobre as alternativas e inseri-las na tabela 'alternativas'
			if (p.alternativas_size() > 0) {
				for (const auto& alternativa_texto : p.alternativas()) {
					std::ostringstream insert_alternativa_query;
					insert_alternativa_query << "INSERT INTO alternativas(quiz_id, alternativa) VALUES ("
						<< new_quiz_id << ", "
						<< txn.quote(alternativa_texto) << ");";
					txn.exec(insert_alternativa_query.str());
				}
			}

			// Se tudo correu bem até aqui, efetiva as mudanças no banco de dados
			txn.commit();
			std::cout << "Pergunta e alternativas inseridas com sucesso. ID=" << new_quiz_id << std::endl;

			// Passo 3: Montar a resposta para o cliente com os dados criados
			auto* nova = response->add_pergunta_criada();
			nova->set_id(new_quiz_id); // Usa o ID real do banco
			nova->set_texto(p.texto());
			nova->set_indice_resposta(p.indice_resposta());
			nova->set_explicacao(p.explicacao());
			for (const auto& alt : p.alternativas()) {
				nova->add_alternativas(alt);
			}

			return Status::OK;

		} catch (const std::exception &e) {
			std::cerr << "Erro durante a transação: " << e.what() << std::endl;
			// A transação será revertida automaticamente pela destruição do objeto 'txn'
			return Status(grpc::INTERNAL, "Erro ao inserir dados no banco de dados.");
		}
	}

};

void RunServer() {
    std::string server_address("0.0.0.0:4242");
    QuizServiceImpl service;

    ServerBuilder builder;
    builder.AddListeningPort(server_address, grpc::InsecureServerCredentials());
    builder.RegisterService(&service);

    std::unique_ptr<Server> server(builder.BuildAndStart());
    std::cout << "Servidor escutando em " << server_address << std::endl;
    server->Wait();
}

int main() {
    RunServer();
    return 0;
}
