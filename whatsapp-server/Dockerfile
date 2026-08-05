FROM node:20-slim

WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev
COPY server.js ./

# La sessione WhatsApp viene salvata in /app/auth: montala come volume
# per non riscansionare il QR ad ogni riavvio.
VOLUME ["/app/auth"]

ENV PORT=3000
EXPOSE 3000

CMD ["node", "server.js"]
