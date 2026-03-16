const express = require("express");
const {
  createReport,
  getAllReports,
  getReportById,
  getSummary,
  hasMatchingScriptPattern,
} = require("./database");

const router = express.Router();

function validateReportPayload(req, res, next) {
  const {
    suspectName,
    contact,
    scamType,
    description,
    riskScore,
    location,
    scriptPattern,
  } = req.body;

  if (!suspectName || !contact || !scamType || !description || !location || !scriptPattern) {
    return res.status(400).json({
      error: "suspectName, contact, scamType, description, location, and scriptPattern are required.",
    });
  }

  const parsedRiskScore = Number(riskScore);
  if (Number.isNaN(parsedRiskScore) || parsedRiskScore < 0 || parsedRiskScore > 100) {
    return res.status(400).json({
      error: "riskScore must be a number between 0 and 100.",
    });
  }

  req.body.riskScore = parsedRiskScore;
  return next();
}

router.get("/health", (req, res) => {
  res.json({
    status: "ok",
    service: "scam-detection-api",
    timestamp: new Date().toISOString(),
  });
});

router.get("/reports", (req, res) => {
  const reports = getAllReports(req.query);
  res.json({
    count: reports.length,
    reports,
  });
});

router.get("/reports/search", (req, res) => {
  const contact = String(req.query.contact || "").trim().toLowerCase();
  const suspectName = String(req.query.suspectName || "").trim().toLowerCase();

  const reports = getAllReports().filter((report) => {
    const matchesContact = !contact || report.contact.toLowerCase() === contact;
    const matchesSuspectName = !suspectName || report.suspectName.toLowerCase() === suspectName;

    return matchesContact && matchesSuspectName;
  });

  res.json({
    found: reports.length > 0,
    reports,
  });
});

router.get("/reports/:id", (req, res) => {
  const report = getReportById(req.params.id);

  if (!report) {
    return res.status(404).json({ error: "Report not found." });
  }

  return res.json(report);
});

router.post("/reports", validateReportPayload, (req, res) => {
  const hasSimilarScript = hasMatchingScriptPattern(req.body.scriptPattern);
  const report = createReport(req.body);

  const response = {
    message: "Scam report created successfully.",
    report,
  };

  if (hasSimilarScript) {
    response.warning = "Similar scam script detected in another region";
  }

  res.status(201).json(response);
});

router.get("/reports-summary", (req, res) => {
  res.json(getSummary());
});

module.exports = router;
