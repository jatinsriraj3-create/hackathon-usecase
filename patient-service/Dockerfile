FROM node:18-alpine

WORKDIR /usr/src

COPY package*.json ./
RUN npm install --production

# Copy source code
COPY src ./src

# EXPOSE 4000

# Run from src folder
ENTRYPOINT ["node", "src/index.js"]
