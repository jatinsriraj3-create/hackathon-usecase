FROM node:18-alpine

WORKDIR patient-service\src\index.js

COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE 4000

CMD ["node", "index.js"]
