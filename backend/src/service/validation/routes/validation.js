const express = require("express");
const { runValidationOnce } = require("../worker");

const router = express.Router();

// Lightweight endpoint to verify validation service wiring.
router.get("/health", (req, res) => {
  res.json({ status: "ok", service: "validation" });
});

// Manual trigger for a single validation pass.
router.post("/run-once", async (req, res, next) => {
  try {
    const rawLimit = req.body && req.body.limit;
    const limit = Number.isInteger(rawLimit) && rawLimit > 0 ? rawLimit : 100;

    const result = await runValidationOnce(limit);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

module.exports = router;
