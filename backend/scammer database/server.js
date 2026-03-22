const express = require("express");
const cors = require("cors");
const routes = require("./routes");

const app = express();
const PORT = process.env.PORT || 5000;

app.use(cors());
app.use(express.json());

app.use("/api", routes);

app.use((req, res) => {
  res.status(404).json({
    error: "Route not found.",
  });
});

app.use((err, req, res, next) => {
  console.error(err);

  res.status(500).json({
    error: "Internal server error.",
  });
});

app.listen(PORT, () => {
  console.log(`Scam detection API listening on port ${PORT}`);
});
