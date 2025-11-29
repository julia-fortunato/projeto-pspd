CREATE TABLE usuario (
    nome VARCHAR(255),
    login VARCHAR(255) PRIMARY KEY,
    rememberToken VARCHAR(255),
    senha VARCHAR(255),
    score INTEGER
);