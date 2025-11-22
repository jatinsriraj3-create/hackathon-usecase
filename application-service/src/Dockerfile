FROM node:18-alpine

# Set working directory
WORKDIR application-service\src\index.js

# Copy package files and install dependencies
COPY package*.json ./
RUN npm ci --only=production

# Copy application code
COPY . .

# Expose port
EXPOSE 3000

# Start the app
CMD ["node", "index.js"]
