FROM node:20-alpine

WORKDIR /app

# Install only production dependencies for a smaller image.
COPY package.json ./
RUN npm install --omit=dev

# Copy application source code.
COPY src ./src

EXPOSE 8080

# Start the reporting service.
CMD ["npm", "start"]
