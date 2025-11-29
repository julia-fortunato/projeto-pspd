const grpc = require('@grpc/grpc-js');
const protoLoader = require('@grpc/proto-loader');
const path = require('path');

// --- Configuração (executada apenas uma vez quando o módulo é importado) ---
const PROTO_PATH = path.join(__dirname, 'user.proto'); // Certifique-se que o nome do arquivo .proto está correto
const SERVER_ADDRESS = 'localhost:50051';

const packageDefinition = protoLoader.loadSync(PROTO_PATH, {
    keepCase: true,
    longs: String,
    enums: String,
    defaults: true,
    oneofs: true,
});

const userProto = grpc.loadPackageDefinition(packageDefinition).user;

const client = new userProto.User(SERVER_ADDRESS, grpc.credentials.createInsecure());
console.log('Cliente gRPC para o serviço User inicializado.');

// --- Funções que serão exportadas ---

/**
 * Cria um novo usuário.
 * @param {object} user - O objeto de usuário a ser criado.
 * @returns {Promise<object>} A resposta do servidor.
 */
function createUser(user) {
    return new Promise((resolve, reject) => {
        client.CreateUsuario({ usuario: user }, (error, response) => {
            if (error) return reject(error);
            resolve(response);
        });
    });
}

/**
 * Autentica um usuário.
 * @param {object} credentials - Contém loginreq e senhareq.
 * @returns {Promise<object>} A resposta do servidor contendo o token.
 */
function loginUser(credentials) {
    return new Promise((resolve, reject) => {
        client.Login(credentials, (error, response) => {
            if (error) return reject(error);
            resolve(response);
        });
    });
}

/**
 * Atualiza o score de um usuário.
 * @param {object} scoreData - Contém scorenew e remembertok.
 * @returns {Promise<object>} A resposta vazia do servidor.
 */
function updateScore(scoreData) {
    return new Promise((resolve, reject) => {
        client.UpdateScore(scoreData, (error, response) => {
            if (error) return reject(error);
            resolve(response);
        });
    });
}


/**
 * (NOVO) Lista todos os usuários, geralmente ordenados por score.
 * @returns {Promise<Array<object>>} Uma lista de objetos de usuário.
 */
function listUsersByScore() {
    return new Promise((resolve, reject) => {
        // A mensagem ListRequest é vazia, então passamos um objeto vazio {} como parâmetro.
        client.ListByScore({}, (error, response) => {
            if (error) return reject(error);
            // A resposta contém um campo 'users' que é um array.
            resolve(response.users);
        });
    });
}

// --- Exportação ---
// Disponibiliza as funções para outros arquivos que usem 'require'
module.exports = {
    createUser,
    loginUser,
    updateScore,
    listUsersByScore, // Adicionamos a nova função aqui
};