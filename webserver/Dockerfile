# Use uma imagem oficial do Node.js como imagem base
FROM node:18-alpine

# Defina o diretório de trabalho no contêiner
WORKDIR /usr/src/app

# Copie os arquivos package.json e package-lock.json
COPY package*.json ./

# Instale as dependências da aplicação
RUN npm install

# Copie o restante do código-fonte da aplicação
COPY . .

# Exponha a porta em que o aplicativo é executado
EXPOSE 6969

# Comando para executar a aplicação
CMD [ "node", "server.js" ]
