const { app, initDb } = require("./app");

const PORT = process.env.PORT || 3001;
const HOST = process.env.HOST || "0.0.0.0";

initDb()
  .then(() => {
    app.listen(PORT, HOST, () => console.log(`Backend rodando em ${HOST}:${PORT}`));
  })
  .catch((err) => {
    console.error("Falha ao inicializar o banco:", err);
    process.exit(1);
  });