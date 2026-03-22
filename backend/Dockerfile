FROM node:20-alpine

WORKDIR /app

# Install only production dependencies for a smaller image.
COPY backend/package.json ./package.json
RUN npm install --omit=dev

# Copy application source code.
COPY backend/src ./backend/src
COPY shared ./shared

EXPOSE 8080

# Start the reporting service.
CMD ["node", "backend/src/server.js"]
