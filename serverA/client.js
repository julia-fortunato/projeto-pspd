const grpc = require('@grpc/grpc-js');
const protoLoader = require('@grpc/proto-loader');
const path = require('path');

// Caminho para o seu arquivo .proto
const PROTO_PATH = path.join(__dirname, 'quiz.proto');

// Carrega o pacote de definições do .proto
const packageDefinition = protoLoader.loadSync(PROTO_PATH, {
  keepCase: true,
  longs: String,
  enums: String,
  defaults: true,
  oneofs: true,
});

// Carrega o serviço Quiz do pacote 'quiz'
const quiz_proto = grpc.loadPackageDefinition(packageDefinition).quiz;

// Endereço do servidor gRPC (ajuste se necessário)
const SERVER_ADDRESS = 'localhost:4242';

// Cria o cliente gRPC sem credenciais (conexão insegura)
const client = new quiz_proto.Quiz(SERVER_ADDRESS, grpc.credentials.createInsecure());

// --- Funções para chamar os métodos RPC ---

// 1. Função para testar GetPerguntas
function getPerguntas() {
  client.GetPerguntas({}, (error, response) => {
    if (error) {
      console.error('Erro ao chamar GetPerguntas:', error.details);
      return;
    }
    console.log('--- Resposta de GetPerguntas ---');
    console.log(JSON.stringify(response.perguntas, null, 2));
  });
}

// 2. Função para testar CreatePergunta
function createPergunta() {


	const novaPergunta = {
		id: 0, // O ID pode ser definido pelo servidor
		texto: 'Qual a capital da França?', // <--- VÍRGULA ADICIONADA AQUI
		alternativas: ['Londres', 'Berlim', 'Paris', 'Madri'], //  <--- VÍRGULA ADICIONADA AQUI
		indice_resposta: 2, // <--- VÍRGULA ADICIONADA AQUI
		explicacao: 'Paris é a capital e a maior cidade da França.',
	};

	const request = {
		pergunta_criar: [novaPergunta],
	};
	client.CreatePergunta(request, (error, response) => {
		if (error) {
			console.error('Erro ao chamar CreatePergunta:', error.details);
			return;
		}
		console.log('\n--- Resposta de CreatePergunta ---');
		console.log('Pergunta criada com sucesso:');
		console.log(JSON.stringify(response.pergunta_criada, null, 2));
	});
}

// 3. Função para testar DeletePergunta
function deletePergunta(perguntaId) {
  const request = {
    dbid: perguntaId, // [cite: 1]
  };

  client.DeletePergunta(request, (error, response) => {
    if (error) {
      console.error(`Erro ao deletar pergunta ${perguntaId}:`, error.details);
      return;
    }
    console.log(`\n--- Resposta de DeletePergunta (ID: ${perguntaId}) ---`);
    if (response.statusRet === 1) {
      console.log('Pergunta deletada com sucesso.');
    } else {
      console.log('Falha ao deletar a pergunta.');
    }
  });
}


// --- Executando as chamadas de teste ---

function main() {
  console.log('*** Iniciando testes do cliente gRPC para o serviço Quiz ***');

  // Teste 1: Buscar todas as perguntas
  getPerguntas();

  // Teste 2: Criar uma nova pergunta
  // Aguarde um momento para a primeira chamada terminar (em um app real, use Promises/async-await)
  setTimeout(() => {
    createPergunta();
  }, 1000);

  // Teste 3: Deletar uma pergunta (ex: com ID 1)
  // Aguarde mais um pouco para a criação possivelmente ocorrer antes da deleção
  setTimeout(() => {
    deletePergunta(3);
  }, 2000);
}

main();
