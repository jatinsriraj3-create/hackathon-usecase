# Use a lightweight Node.js base image
FROM node:18-alpine

# Set working directory inside container
WORKDIR /usr/src/app

# Copy package.json and package-lock.json first (for dependency install)
COPY package*.json ./



# Expose the port your app runs on
EXPOSE 3000

# Start the app
CMD ["node", "src/index.js"]
